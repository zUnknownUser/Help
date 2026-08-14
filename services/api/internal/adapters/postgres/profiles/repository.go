package profiles

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

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

	_, err = tx.Exec(ctx, `
		INSERT INTO user_profiles (firebase_uid, email, display_name, active_role)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (firebase_uid) DO UPDATE SET
			email = EXCLUDED.email,
			display_name = EXCLUDED.display_name,
			active_role = EXCLUDED.active_role,
			updated_at = now()`,
		profile.UID, profile.Email.String(), profile.DisplayName, profile.ActiveRole,
	)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("upsert profile: %w", err)
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO user_roles (firebase_uid, role)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING`, profile.UID, profile.ActiveRole)
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
	_, err := tx.Exec(ctx, `
		INSERT INTO providers (id, name, active, owner_uid, onboarding_status)
		VALUES (gen_random_uuid()::text, $1, false, $2, 'pending')
		ON CONFLICT (owner_uid) WHERE owner_uid IS NOT NULL DO UPDATE SET
			name = EXCLUDED.name,
			updated_at = now()`, profile.DisplayName, profile.UID)
	if err != nil {
		return fmt.Errorf("upsert provider profile: %w", err)
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
	var providerStatus *string
	err := repository.pool.QueryRow(ctx, `
		SELECT p.firebase_uid, p.email, p.display_name, p.active_role,
		       ARRAY(
		           SELECT r.role
		           FROM user_roles r
		           WHERE r.firebase_uid = p.firebase_uid
		           ORDER BY r.role
		       ),
		       (SELECT pr.onboarding_status FROM providers pr WHERE pr.owner_uid = p.firebase_uid)
		FROM user_profiles p
		WHERE p.firebase_uid = $1`, uid).Scan(
		&profile.UID, &email, &profile.DisplayName, &activeRole, &roles, &providerStatus,
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
	}
	return profile, nil
}
