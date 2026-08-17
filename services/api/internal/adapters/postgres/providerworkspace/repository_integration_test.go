package providerworkspace

import (
	"context"
	"errors"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	postgrescatalog "github.com/vendlydigital/help/services/api/internal/adapters/postgres/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

func TestPublishedProviderServiceAppearsInCustomerCatalog(t *testing.T) {
	databaseURL := os.Getenv("TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("TEST_DATABASE_URL not configured")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()

	providerUID := "provider-" + uuid.NewString()
	otherUID := "provider-" + uuid.NewString()
	categoryID := "category-" + uuid.NewString()
	defer cleanupProviderTestData(pool, categoryID, providerUID, otherUID)
	seedApprovedProvider(t, pool, providerUID, "Prestador integrado")
	seedApprovedProvider(t, pool, otherUID, "Outro prestador")
	if _, err := pool.Exec(ctx, `
		INSERT INTO categories (id, name, icon_key, position) VALUES ($1, 'Limpeza', 'cleaning', 0)`, categoryID); err != nil {
		t.Fatal(err)
	}

	repository := NewRepository(pool)
	draft, _ := catalog.NewServiceDraft(
		"Limpeza residencial", "Limpeza completa para casas e apartamentos.",
		categoryID, 120, 15000, nil, "", true,
	)
	created, err := repository.CreateService(ctx, providerUID, draft)
	if err != nil {
		t.Fatalf("CreateService() error = %v", err)
	}
	if !created.Active || created.ProviderID == "" {
		t.Fatalf("created service = %+v", created)
	}

	latitude, longitude, radius := -3.0816211, -59.9779892, 30.0
	page, err := postgrescatalog.NewRepository(pool).Search(ctx, catalog.Filters{
		Latitude: &latitude, Longitude: &longitude, RadiusKM: &radius,
		CategoryID: categoryID, Limit: 20,
	})
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if len(page.Items) != 1 || page.Items[0].Service.ID != created.ID {
		t.Fatalf("catalog page = %+v", page)
	}

	if _, err := repository.SetServicePublished(ctx, otherUID, created.ID, false); !errors.Is(err, providers.ErrServiceNotFound) {
		t.Fatalf("cross-provider update error = %v", err)
	}
	if err := repository.DeleteService(ctx, providerUID, created.ID); err != nil {
		t.Fatalf("DeleteService() error = %v", err)
	}
	page, err = postgrescatalog.NewRepository(pool).Search(ctx, catalog.Filters{
		Latitude: &latitude, Longitude: &longitude, RadiusKM: &radius,
		CategoryID: categoryID, Limit: 20,
	})
	if err != nil || len(page.Items) != 0 {
		t.Fatalf("catalog after delete = %+v, error = %v", page, err)
	}
}

func cleanupProviderTestData(pool *pgxpool.Pool, categoryID string, providerUIDs ...string) {
	ctx := context.Background()
	pool.Exec(ctx, `DELETE FROM service_requests WHERE provider_id IN (SELECT id FROM providers WHERE owner_uid = ANY($1))`, providerUIDs)
	pool.Exec(ctx, `DELETE FROM services WHERE provider_id IN (SELECT id FROM providers WHERE owner_uid = ANY($1))`, providerUIDs)
	pool.Exec(ctx, `DELETE FROM providers WHERE owner_uid = ANY($1)`, providerUIDs)
	pool.Exec(ctx, `DELETE FROM categories WHERE id = $1`, categoryID)
	pool.Exec(ctx, `DELETE FROM user_profiles WHERE firebase_uid = ANY($1)`, providerUIDs)
}

func seedApprovedProvider(t *testing.T, pool *pgxpool.Pool, uid, name string) {
	t.Helper()
	execSQL(t, pool, `
		INSERT INTO user_profiles (firebase_uid, email, display_name, active_role)
		VALUES ($1, $1 || '@example.com', $2, 'provider')`, uid, name)
	execSQL(t, pool, `
		INSERT INTO user_roles (firebase_uid, role) VALUES ($1, 'provider')`, uid)
	execSQL(t, pool, `
		INSERT INTO providers (id, name, active, owner_uid, onboarding_status)
		VALUES (gen_random_uuid()::text, $2, true, $1, 'approved')`, uid, name)
	execSQL(t, pool, `
		INSERT INTO user_addresses (
			firebase_uid, label, formatted_address, is_default,
			latitude, longitude, city, state
		) VALUES ($1, 'Atendimento', 'Manaus, AM', true, -3.0816211, -59.9779892, 'Manaus', 'AM')`, uid)
}

func execSQL(t *testing.T, pool *pgxpool.Pool, statement string, args ...any) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), statement, args...); err != nil {
		t.Fatal(err)
	}
}
