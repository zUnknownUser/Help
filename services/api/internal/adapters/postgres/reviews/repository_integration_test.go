package reviews

import (
	"context"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	domainreviews "github.com/vendlydigital/help/services/api/internal/domain/reviews"
)

func TestReviewsAreMutualAuthorizedAndIdempotent(t *testing.T) {
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

	providerUID, customerUID := "review-provider-"+uuid.NewString(), "review-customer-"+uuid.NewString()
	providerID, serviceID, requestID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	defer func() {
		_, _ = pool.Exec(ctx, "DELETE FROM notifications WHERE firebase_uid IN ($1,$2)", providerUID, customerUID)
		_, _ = pool.Exec(ctx, "DELETE FROM service_requests WHERE id=$1", requestID)
		_, _ = pool.Exec(ctx, "DELETE FROM services WHERE id=$1", serviceID)
		_, _ = pool.Exec(ctx, "DELETE FROM providers WHERE id=$1", providerID)
		_, _ = pool.Exec(ctx, "DELETE FROM user_profiles WHERE firebase_uid IN ($1,$2)", providerUID, customerUID)
	}()
	seedReviewUser(t, pool, providerUID, "Prestador", "provider")
	seedReviewUser(t, pool, customerUID, "Cliente", "customer")
	mustReviewExec(t, pool, `INSERT INTO providers(id,name,active,owner_uid,onboarding_status)
		VALUES($1,'Prestador',true,$2,'approved')`, providerID, providerUID)
	mustReviewExec(t, pool, `INSERT INTO services(id,provider_id,title,rating,reviews,duration_minutes,price_cents,old_price_cents,active,published_at)
		VALUES($1,$2,'Serviço avaliado',0,0,60,10000,NULL,true,now())`, serviceID, providerID)
	mustReviewExec(t, pool, `INSERT INTO service_requests(id,client_request_id,service_id,provider_id,customer_uid,status,scheduled_for,scheduled_end_at,reservation_end_at,quoted_price_cents)
		VALUES($1,$2,$3,$4,$5,'completed',now(),now()+interval '1 hour',now()+interval '1 hour',10000)`, requestID, uuid.NewString(), serviceID, providerID, customerUID)

	repository := NewRepository(pool)
	draft, _ := domainreviews.NewDraft(5, "Excelente")
	first, err := repository.Upsert(ctx, customerUID, requestID, draft)
	if err != nil {
		t.Fatal(err)
	}
	second, err := repository.Upsert(ctx, customerUID, requestID, draft)
	if err != nil {
		t.Fatal(err)
	}
	if first.ID != second.ID {
		t.Fatalf("idempotency failed: %s != %s", first.ID, second.ID)
	}
	providerDraft, _ := domainreviews.NewDraft(4, "Ótimo cliente")
	if _, err = repository.Upsert(ctx, providerUID, requestID, providerDraft); err != nil {
		t.Fatal(err)
	}
	items, err := repository.ListForRequest(ctx, customerUID, requestID)
	if err != nil || len(items) != 2 {
		t.Fatalf("reviews = %d, err = %v", len(items), err)
	}

	var reviewCount, notificationCount int
	if err = pool.QueryRow(ctx, "SELECT reviews FROM services WHERE id=$1", serviceID).Scan(&reviewCount); err != nil {
		t.Fatal(err)
	}
	if reviewCount != 1 {
		t.Fatalf("service review count = %d", reviewCount)
	}
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM notifications WHERE firebase_uid=$1 AND kind='service_review'`, providerUID).Scan(&notificationCount); err != nil {
		t.Fatal(err)
	}
	if notificationCount != 1 {
		t.Fatalf("duplicate notification count = %d", notificationCount)
	}
	if _, err = repository.ListForRequest(ctx, "stranger", requestID); err != domainreviews.ErrForbidden {
		t.Fatalf("stranger error = %v", err)
	}
}

func seedReviewUser(t *testing.T, pool *pgxpool.Pool, uid, name, role string) {
	t.Helper()
	mustReviewExec(t, pool, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role)
		VALUES($1,$1||'@example.com',$2,$3)`, uid, name, role)
	mustReviewExec(t, pool, "INSERT INTO user_roles(firebase_uid,role) VALUES($1,$2)", uid, role)
}

func mustReviewExec(t *testing.T, pool *pgxpool.Pool, query string, args ...any) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), query, args...); err != nil {
		t.Fatal(err)
	}
}
