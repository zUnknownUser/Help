package catalog

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

func TestSearchWithLocationReturnsEmptyPageWithoutListings(t *testing.T) {
	databaseURL := os.Getenv("TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("TEST_DATABASE_URL not configured")
	}
	pool, err := pgxpool.New(context.Background(), databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	latitude, longitude, radius := -3.0816211, -59.9779892, 30.0
	missingCategory := "missing-category-for-empty-catalog-test"

	for _, test := range []struct {
		name   string
		cursor string
	}{
		{name: "first page"},
		{
			name: "page with cursor",
			cursor: encodeCursor(catalogCursor{
				Sort: "distance", Value: "1", ID: "00000000-0000-0000-0000-000000000000",
			}),
		},
	} {
		t.Run(test.name, func(t *testing.T) {
			page, err := NewRepository(pool).Search(context.Background(), domaincatalog.Filters{
				Latitude: &latitude, Longitude: &longitude, RadiusKM: &radius,
				CategoryID: missingCategory, Cursor: test.cursor, Limit: 20,
			})

			if err != nil {
				t.Fatalf("Search() returned an error for an empty localized catalog: %v", err)
			}
			if len(page.Items) != 0 || page.NextCursor != "" {
				t.Fatalf("expected an empty page, got %+v", page)
			}
		})
	}
}
