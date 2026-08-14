package catalog

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

type catalogCursor struct {
	Sort  string `json:"sort"`
	Value string `json:"value"`
	ID    string `json:"id"`
}

func (repository *Repository) Search(
	ctx context.Context,
	filters domaincatalog.Filters,
) (domaincatalog.Page, error) {
	filters = normalizeFilters(filters)
	cursor, err := decodeCursor(filters.Cursor, filters.Sort)
	if err != nil {
		return domaincatalog.Page{}, err
	}
	query, order := catalogQuery(filters.Sort, cursor != nil)
	var cursorValue, cursorID *string
	if cursor != nil {
		cursorValue, cursorID = &cursor.Value, &cursor.ID
	}
	rows, err := repository.pool.Query(ctx, query+order+` LIMIT $12`,
		filters.Query, filters.CategoryID, filters.MinPrice, filters.MaxPrice,
		filters.MinRating, filters.Verified, filters.Latitude, filters.Longitude,
		filters.RadiusKM, cursorValue, cursorID, filters.Limit+1,
	)
	if err != nil {
		return domaincatalog.Page{}, fmt.Errorf("search catalog: %w", err)
	}
	defer rows.Close()
	items := make([]domaincatalog.Listing, 0, filters.Limit+1)
	for rows.Next() {
		var item domaincatalog.Listing
		if err := rows.Scan(
			&item.Service.ID, &item.Service.ProviderID, &item.Service.CategoryID,
			&item.Service.Title, &item.Service.Rating, &item.Service.Reviews,
			&item.Service.DurationMinutes, &item.Service.PriceCents,
			&item.Service.OldPriceCents, &item.Service.ImageURL,
			&item.Service.ImageAlignment, &item.Service.Badge,
			&item.ProviderName, &item.ProviderVerified, &item.Service.DistanceKM,
			&item.Service.CreatedAt,
		); err != nil {
			return domaincatalog.Page{}, fmt.Errorf("scan catalog item: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return domaincatalog.Page{}, fmt.Errorf("iterate catalog: %w", err)
	}
	page := domaincatalog.Page{Items: items}
	if len(items) > filters.Limit {
		last := items[filters.Limit-1]
		page.Items = items[:filters.Limit]
		page.NextCursor = encodeCursor(cursorFor(last, filters.Sort))
	}
	return page, nil
}

func normalizeFilters(filters domaincatalog.Filters) domaincatalog.Filters {
	filters.Query = strings.TrimSpace(filters.Query)
	filters.CategoryID = strings.TrimSpace(filters.CategoryID)
	if filters.Limit < 1 {
		filters.Limit = 20
	} else if filters.Limit > 50 {
		filters.Limit = 50
	}
	if filters.Sort == "" {
		if filters.Latitude != nil {
			filters.Sort = "distance"
		} else {
			filters.Sort = "newest"
		}
	}
	if filters.Sort != "newest" && filters.Sort != "price" &&
		filters.Sort != "rating" && filters.Sort != "distance" {
		filters.Sort = "newest"
	}
	if filters.Sort == "distance" && filters.Latitude == nil {
		filters.Sort = "newest"
	}
	return filters
}

func catalogQuery(sort string, hasCursor bool) (string, string) {
	base := `WITH listing AS (
		SELECT s.id, s.provider_id, COALESCE(s.category_id, ''), s.title,
		       s.rating::float8, s.reviews, s.duration_minutes, s.price_cents,
		       s.old_price_cents, s.image_url, s.image_alignment, s.badge,
		       p.name, p.verified, s.created_at,
		       CASE WHEN $7::float8 IS NULL OR a.latitude IS NULL THEN NULL ELSE
		         6371 * acos(LEAST(1, GREATEST(-1,
		           cos(radians($7)) * cos(radians(a.latitude)) *
		           cos(radians(a.longitude) - radians($8)) +
		           sin(radians($7)) * sin(radians(a.latitude))
		         )))
		       END AS distance_km
		FROM services s
		JOIN providers p ON p.id = s.provider_id AND p.active AND p.onboarding_status = 'approved'
		LEFT JOIN user_addresses a
		  ON a.firebase_uid = p.owner_uid AND a.is_default AND a.active
		WHERE s.active
		  AND ($1 = '' OR s.title ILIKE '%' || $1 || '%' OR p.name ILIKE '%' || $1 || '%')
		  AND ($2 = '' OR s.category_id = $2)
		  AND ($3::int IS NULL OR s.price_cents >= $3)
		  AND ($4::int IS NULL OR s.price_cents <= $4)
		  AND ($5::float8 IS NULL OR s.rating >= $5)
		  AND ($6::bool IS NULL OR p.verified = $6)
		  AND ($7::float8 IS NULL OR $9::float8 IS NULL OR (
		    a.latitude BETWEEN $7 - ($9 / 111.045) AND $7 + ($9 / 111.045)
		    AND a.longitude BETWEEN
		      $8 - ($9 / (111.045 * GREATEST(cos(radians($7)), 0.01))) AND
		      $8 + ($9 / (111.045 * GREATEST(cos(radians($7)), 0.01)))
		  ))
	), filtered AS (
		SELECT * FROM listing
		WHERE ($7::float8 IS NULL OR distance_km IS NOT NULL)
		  AND ($9::float8 IS NULL OR distance_km <= $9)
	)
	SELECT id, provider_id, category_id, title, rating, reviews, duration_minutes,
	       price_cents, old_price_cents, image_url, image_alignment, badge,
	       name, verified, distance_km, created_at
	FROM filtered`
	cursor := ""
	if hasCursor {
		cursor = map[string]string{
			"newest":   ` WHERE (created_at, id) < ($10::timestamptz, $11)`,
			"price":    ` WHERE (price_cents, id) > ($10::int, $11)`,
			"rating":   ` WHERE (rating, id) < ($10::float8, $11)`,
			"distance": ` WHERE (distance_km, id) > ($10::float8, $11)`,
		}[sort]
	}
	order := map[string]string{
		"newest":   ` ORDER BY created_at DESC, id DESC`,
		"price":    ` ORDER BY price_cents, id`,
		"rating":   ` ORDER BY rating DESC, id DESC`,
		"distance": ` ORDER BY distance_km, id`,
	}[sort]
	return base + cursor, order
}

func cursorFor(item domaincatalog.Listing, sort string) catalogCursor {
	value := ""
	switch sort {
	case "price":
		value = fmt.Sprintf("%d", item.Service.PriceCents)
	case "rating":
		value = fmt.Sprintf("%.6f", item.Service.Rating)
	case "distance":
		if item.Service.DistanceKM != nil {
			value = fmt.Sprintf("%.9f", *item.Service.DistanceKM)
		}
	default:
		value = item.Service.CreatedAt.UTC().Format(time.RFC3339Nano)
	}
	return catalogCursor{Sort: sort, Value: value, ID: item.Service.ID}
}

func encodeCursor(cursor catalogCursor) string {
	raw, _ := json.Marshal(cursor)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeCursor(value, sort string) (*catalogCursor, error) {
	if value == "" {
		return nil, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return nil, errors.New("invalid catalog cursor")
	}
	var cursor catalogCursor
	if json.Unmarshal(raw, &cursor) != nil || cursor.Sort != sort || cursor.Value == "" || cursor.ID == "" {
		return nil, errors.New("invalid catalog cursor")
	}
	return &cursor, nil
}
