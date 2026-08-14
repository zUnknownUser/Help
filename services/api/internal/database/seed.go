package database

import (
	"context"
	"database/sql"
	"embed"
	"fmt"

	_ "github.com/jackc/pgx/v5/stdlib"
)

//go:embed seeds/development.sql
var seedFiles embed.FS

func SeedDevelopment(ctx context.Context, databaseURL string) error {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return fmt.Errorf("open seed database: %w", err)
	}
	defer db.Close()

	seed, err := seedFiles.ReadFile("seeds/development.sql")
	if err != nil {
		return fmt.Errorf("read development seed: %w", err)
	}
	if _, err := db.ExecContext(ctx, string(seed)); err != nil {
		return fmt.Errorf("apply development seed: %w", err)
	}
	return nil
}
