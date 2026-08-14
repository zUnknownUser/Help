package profiles

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type userCursor struct {
	Name string `json:"name"`
	ID   string `json:"id"`
}

func (repository *Repository) SearchUsers(
	ctx context.Context,
	requesterID, query string,
	limit int,
	cursorValue string,
) (ports.UserPage, error) {
	if limit < 1 {
		limit = 30
	}
	if limit > 50 {
		limit = 50
	}
	cursor, err := decodeUserCursor(cursorValue)
	if err != nil {
		return ports.UserPage{}, err
	}
	var cursorName, cursorID *string
	if cursor != nil {
		cursorName, cursorID = &cursor.Name, &cursor.ID
	}
	rows, err := repository.pool.Query(ctx, `
		SELECT firebase_uid, display_name
		FROM user_profiles
		WHERE firebase_uid <> $1
		  AND ($2 = '' OR display_name ILIKE '%' || $2 || '%')
		  AND ($3::text IS NULL OR (lower(display_name), firebase_uid) > ($3, $4))
		ORDER BY lower(display_name), firebase_uid
		LIMIT $5`, requesterID, strings.TrimSpace(query), cursorName, cursorID, limit+1)
	if err != nil {
		return ports.UserPage{}, fmt.Errorf("search users: %w", err)
	}
	defer rows.Close()
	users := make([]ports.PublicUser, 0, limit+1)
	for rows.Next() {
		var user ports.PublicUser
		if err := rows.Scan(&user.ID, &user.DisplayName); err != nil {
			return ports.UserPage{}, err
		}
		users = append(users, user)
	}
	page := ports.UserPage{Users: users}
	if len(users) > limit {
		last := users[limit-1]
		page.Users = users[:limit]
		page.NextCursor = encodeUserCursor(userCursor{Name: strings.ToLower(last.DisplayName), ID: last.ID})
	}
	return page, rows.Err()
}

func encodeUserCursor(cursor userCursor) string {
	raw, _ := json.Marshal(cursor)
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeUserCursor(value string) (*userCursor, error) {
	if value == "" {
		return nil, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return nil, errors.New("invalid user cursor")
	}
	var cursor userCursor
	if json.Unmarshal(raw, &cursor) != nil || cursor.Name == "" || cursor.ID == "" {
		return nil, errors.New("invalid user cursor")
	}
	return &cursor, nil
}
