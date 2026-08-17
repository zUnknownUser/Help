package firebasepush

import (
	"context"
	"os"
	"testing"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestFirebaseCredentialsAndLatestDeviceTokenWithDryRun(t *testing.T) {
	if os.Getenv("RUN_FCM_DRY_RUN") != "1" {
		t.Skip("RUN_FCM_DRY_RUN not enabled")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, os.Getenv("TEST_DATABASE_URL"))
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	var token string
	if err := pool.QueryRow(ctx, `SELECT fcm_token FROM device_installations
		WHERE enabled ORDER BY last_seen_at DESC LIMIT 1`).Scan(&token); err != nil {
		t.Fatal("no enabled FCM installation available for dry-run")
	}
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: os.Getenv("FIREBASE_PROJECT_ID")})
	if err != nil {
		t.Fatal(err)
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.SendDryRun(ctx, &messaging.Message{
		Token: token,
		Data:  map[string]string{"type": "validation"},
	}); err != nil {
		t.Fatalf("FCM dry-run failed: %v", err)
	}
}
