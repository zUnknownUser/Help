package main

import (
	"context"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/database"
)

func main() {
	databaseURL := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if databaseURL == "" {
		slog.Error("DATABASE_URL is required")
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	if err := database.SeedDevelopment(ctx, databaseURL); err != nil {
		slog.Error("development seed failed", "error", err)
		os.Exit(1)
	}
	slog.Info("development data is up to date")
}
