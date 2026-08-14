package main

import (
	"context"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/healthcheck"
)

func runHealthcheck() error {
	port := strings.TrimSpace(os.Getenv("PORT"))
	if port == "" {
		port = "8080"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	return healthcheck.Check(
		ctx,
		&http.Client{},
		"http://127.0.0.1:"+port+"/health",
	)
}
