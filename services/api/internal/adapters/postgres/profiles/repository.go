package profiles

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) Register(
	ctx context.Context,
	profile domainprofiles.Profile,
) (domainprofiles.Profile, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("begin profile registration: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	query, args, buildErr := database.Query.Insert("user_profiles").
		Columns("firebase_uid", "email", "display_name", "active_role").
		Values(profile.UID, profile.Email.String(), profile.DisplayName, profile.ActiveRole).
		Suffix(`ON CONFLICT (firebase_uid) DO UPDATE SET
			email = EXCLUDED.email, display_name = EXCLUDED.display_name,
			active_role = EXCLUDED.active_role, updated_at = now()`).ToSql()
	if buildErr != nil {
		return domainprofiles.Profile{}, fmt.Errorf("build profile upsert: %w", buildErr)
	}
	_, err = tx.Exec(ctx, query, args...)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("upsert profile: %w", err)
	}
	query, args, buildErr = database.Query.Insert("user_roles").
		Columns("firebase_uid", "role").Values(profile.UID, profile.ActiveRole).
		Suffix("ON CONFLICT DO NOTHING").ToSql()
	if buildErr != nil {
		return domainprofiles.Profile{}, fmt.Errorf("build profile role insert: %w", buildErr)
	}
	_, err = tx.Exec(ctx, query, args...)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("add profile role: %w", err)
	}
	if profile.ActiveRole == domainprofiles.ProviderRole {
		if err := upsertProvider(ctx, tx, profile); err != nil {
			return domainprofiles.Profile{}, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("commit profile registration: %w", err)
	}
	return repository.FindByUID(ctx, profile.UID)
}

func upsertProvider(
	ctx context.Context,
	tx pgx.Tx,
	profile domainprofiles.Profile,
) error {
	query, args, buildErr := database.Query.Insert("providers").
		Columns("id", "name", "active", "owner_uid", "onboarding_status").
		Values(database.Expr("gen_random_uuid()::text"), profile.DisplayName, false, profile.UID, "pending").
		Suffix(`ON CONFLICT (owner_uid) WHERE owner_uid IS NOT NULL DO UPDATE SET
			name = EXCLUDED.name, updated_at = now()`).ToSql()
	if buildErr != nil {
		return fmt.Errorf("build provider profile upsert: %w", buildErr)
	}
	_, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("upsert provider profile: %w", err)
	}
	var providerID string
	query, args, buildErr = database.Query.Select("id").From("providers").Where("owner_uid = ?", profile.UID).ToSql()
	if buildErr != nil {
		return fmt.Errorf("build provider identity query: %w", buildErr)
	}
	if err := tx.QueryRow(ctx, query, args...).Scan(&providerID); err != nil {
		return fmt.Errorf("load provider schedule identity: %w", err)
	}
	query, args, buildErr = database.Query.Insert("provider_schedule_settings").Columns("provider_id").
		Values(providerID).Suffix("ON CONFLICT DO NOTHING").ToSql()
	if buildErr != nil {
		return fmt.Errorf("build provider schedule insert: %w", buildErr)
	}
	if _, err := tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("create provider schedule: %w", err)
	}
	defaults := database.Query.Select().
		Column("?", providerID).Column("weekday").Column("?", 480).Column("?", 1080).
		From("generate_series(1,6) weekday")
	query, args, buildErr = database.Query.Insert("provider_availability_rules").
		Columns("provider_id", "weekday", "start_minute", "end_minute").
		Select(defaults).Suffix("ON CONFLICT DO NOTHING").ToSql()
	if buildErr != nil {
		return fmt.Errorf("build provider schedule defaults: %w", buildErr)
	}
	if _, err := tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("create provider schedule defaults: %w", err)
	}
	return nil
}

func (repository *Repository) FindByUID(
	ctx context.Context,
	uid string,
) (domainprofiles.Profile, error) {
	var profile domainprofiles.Profile
	var email, activeRole string
	var roles []string
	var providerStatus, title, bio *string
	var yearsExperience, serviceRadius *int
	query, args, buildErr := profileQuery(uid)
	if buildErr != nil {
		return domainprofiles.Profile{}, fmt.Errorf("build profile query: %w", buildErr)
	}
	err := repository.pool.QueryRow(ctx, query, args...).Scan(
		&profile.UID, &email, &profile.DisplayName, &profile.Phone, &activeRole, &roles,
		&providerStatus, &profile.AvatarPresent,
		&profile.Preferences.ContactPreference, &profile.Preferences.PhotoVisibility,
		&profile.Preferences.LastSeenVisibility, &profile.Preferences.ShowOnline,
		&profile.Preferences.AllowConversationRequests,
		&title, &bio, &yearsExperience, &serviceRadius,
		&profile.Rating, &profile.ReviewCount,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainprofiles.Profile{}, domainprofiles.ErrProfileNotFound
	}
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("query profile: %w", err)
	}
	parsedEmail, err := domainauth.ParseEmail(email)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("parse stored profile email: %w", err)
	}
	profile.Email = parsedEmail
	profile.ActiveRole, err = domainprofiles.ParseRole(activeRole)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("parse stored active role: %w", err)
	}
	for _, value := range roles {
		role, parseErr := domainprofiles.ParseRole(value)
		if parseErr != nil {
			return domainprofiles.Profile{}, fmt.Errorf("parse stored role: %w", parseErr)
		}
		profile.Roles = append(profile.Roles, role)
	}
	if providerStatus != nil {
		status, parseErr := domainprofiles.ParseProviderStatus(*providerStatus)
		if parseErr != nil {
			return domainprofiles.Profile{}, fmt.Errorf("parse stored provider status: %w", parseErr)
		}
		profile.ProviderStatus = &status
		profile.Professional = &domainprofiles.Professional{
			Title: valueOrEmpty(title), Bio: valueOrEmpty(bio),
			YearsExperience: yearsExperience, ServiceRadiusKM: valueOrDefault(serviceRadius, 10),
		}
	}
	profile.Portfolio, err = repository.listPortfolio(ctx, uid)
	if err != nil {
		return domainprofiles.Profile{}, err
	}
	profile.Completeness = profileCompleteness(profile)
	return profile, nil
}

func (repository *Repository) Update(
	ctx context.Context,
	uid string,
	update domainprofiles.Update,
) (domainprofiles.Profile, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("begin profile update: %w", err)
	}
	defer tx.Rollback(ctx)
	query, args, buildErr := database.Query.Update("user_profiles").SetMap(map[string]any{
		"display_name": update.DisplayName, "phone": update.Phone,
		"contact_preference":          update.Preferences.ContactPreference,
		"photo_visibility":            update.Preferences.PhotoVisibility,
		"last_seen_visibility":        update.Preferences.LastSeenVisibility,
		"show_online":                 update.Preferences.ShowOnline,
		"allow_conversation_requests": update.Preferences.AllowConversationRequests,
		"updated_at":                  database.Expr("now()"),
	}).Where("firebase_uid = ?", uid).ToSql()
	if buildErr != nil {
		return domainprofiles.Profile{}, fmt.Errorf("build profile update: %w", buildErr)
	}
	result, err := tx.Exec(ctx, query, args...)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("update profile: %w", err)
	}
	if result.RowsAffected() == 0 {
		return domainprofiles.Profile{}, domainprofiles.ErrProfileNotFound
	}
	if professional := update.Professional; professional != nil {
		query, args, buildErr = database.Query.Update("providers").SetMap(map[string]any{
			"name": update.DisplayName, "professional_title": professional.Title,
			"bio": professional.Bio, "years_experience": professional.YearsExperience,
			"service_radius_km": professional.ServiceRadiusKM,
			"updated_at":        database.Expr("now()"),
		}).Where("owner_uid = ?", uid).ToSql()
		if buildErr != nil {
			return domainprofiles.Profile{}, fmt.Errorf("build professional profile update: %w", buildErr)
		}
		if _, err = tx.Exec(ctx, query, args...); err != nil {
			return domainprofiles.Profile{}, fmt.Errorf("update professional profile: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("commit profile update: %w", err)
	}
	return repository.FindByUID(ctx, uid)
}

func (repository *Repository) SyncEmail(
	ctx context.Context,
	uid, email string,
) (domainprofiles.Profile, error) {
	query, args, err := database.Query.Update("user_profiles").
		Set("email", email).Set("updated_at", database.Expr("now()")).
		Where("firebase_uid = ?", uid).ToSql()
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("build profile email sync: %w", err)
	}
	result, err := repository.pool.Exec(ctx, query, args...)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("sync profile email: %w", err)
	}
	if result.RowsAffected() == 0 {
		return domainprofiles.Profile{}, domainprofiles.ErrProfileNotFound
	}
	return repository.FindByUID(ctx, uid)
}

func profileQuery(uid string) (string, []any, error) {
	return database.Query.Select(
		"profile.firebase_uid", "profile.email", "profile.display_name", "profile.phone", "profile.active_role",
		"ARRAY(SELECT role.role FROM user_roles role WHERE role.firebase_uid=profile.firebase_uid ORDER BY role.role)",
		"provider.onboarding_status", "profile.avatar_storage_key IS NOT NULL",
		"profile.contact_preference", "profile.photo_visibility", "profile.last_seen_visibility",
		"profile.show_online", "profile.allow_conversation_requests",
		"provider.professional_title", "provider.bio", "provider.years_experience", "provider.service_radius_km",
		"COALESCE((SELECT avg(review.rating)::float8 FROM service_reviews review WHERE review.reviewee_uid=profile.firebase_uid),0)",
		"(SELECT count(*) FROM service_reviews review WHERE review.reviewee_uid=profile.firebase_uid)",
	).From("user_profiles profile").LeftJoin("providers provider ON provider.owner_uid=profile.firebase_uid").
		Where("profile.firebase_uid = ?", uid).ToSql()
}

func (repository *Repository) listPortfolio(ctx context.Context, uid string) ([]domainprofiles.PortfolioItem, error) {
	query, args, err := database.Query.Select("item.id::text", "item.caption", "item.position").
		From("provider_portfolio_items item").Join("providers provider ON provider.id=item.provider_id").
		Where("provider.owner_uid = ?", uid).OrderBy("item.position", "item.created_at", "item.id").ToSql()
	if err != nil {
		return nil, fmt.Errorf("build portfolio query: %w", err)
	}
	rows, err := repository.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("query portfolio: %w", err)
	}
	defer rows.Close()
	items := make([]domainprofiles.PortfolioItem, 0)
	for rows.Next() {
		var item domainprofiles.PortfolioItem
		if err := rows.Scan(&item.ID, &item.Caption, &item.Position); err != nil {
			return nil, fmt.Errorf("scan portfolio: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func profileCompleteness(profile domainprofiles.Profile) int {
	completed, total := 2, 4
	if profile.Phone != "" {
		completed++
	}
	if profile.AvatarPresent {
		completed++
	}
	if profile.Professional != nil {
		total += 4
		if profile.Professional.Title != "" {
			completed++
		}
		if profile.Professional.Bio != "" {
			completed++
		}
		if profile.Professional.YearsExperience != nil {
			completed++
		}
		if len(profile.Portfolio) > 0 {
			completed++
		}
	}
	return completed * 100 / total
}

func valueOrEmpty(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func valueOrDefault(value *int, fallback int) int {
	if value == nil {
		return fallback
	}
	return *value
}
