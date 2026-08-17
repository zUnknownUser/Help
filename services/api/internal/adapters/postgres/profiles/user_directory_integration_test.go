package profiles

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestSearchUsersAppliesRoleAwareContactPolicy(t *testing.T) {
	databaseURL := os.Getenv("TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("TEST_DATABASE_URL not configured")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)

	suffix := uuid.NewString()
	customerID, unrelatedID := "customer-"+suffix, "unrelated-"+suffix
	providerID, providerUID := "provider-"+suffix, "provider-user-"+suffix
	serviceID := "service-" + suffix
	customerName, providerName := "Cliente "+suffix, "Profissional "+suffix
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, `DELETE FROM service_requests WHERE service_id=$1`, serviceID)
		_, _ = pool.Exec(ctx, `DELETE FROM services WHERE id=$1`, serviceID)
		_, _ = pool.Exec(ctx, `DELETE FROM providers WHERE id=$1`, providerID)
		_, _ = pool.Exec(ctx, `DELETE FROM user_profiles WHERE firebase_uid=ANY($1)`, []string{customerID, unrelatedID, providerUID})
	})
	for _, user := range []struct{ id, name, role string }{
		{customerID, customerName, "customer"},
		{unrelatedID, "Sem vínculo " + suffix, "customer"},
		{providerUID, providerName, "provider"},
	} {
		if _, err = pool.Exec(ctx, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role) VALUES($1,$1||'@example.test',$2,$3)`, user.id, user.name, user.role); err != nil {
			t.Fatal(err)
		}
	}
	if _, err = pool.Exec(ctx, `INSERT INTO providers(id,name,verified,active,owner_uid,onboarding_status,accepting_requests) VALUES($1,'Profissional',true,true,$2,'approved',true)`, providerID, providerUID); err != nil {
		t.Fatal(err)
	}
	if _, err = pool.Exec(ctx, `INSERT INTO services(id,provider_id,title,rating,duration_minutes,price_cents,old_price_cents,active,published_at) VALUES($1,$2,'Serviço de teste',5,60,10000,10000,true,now())`, serviceID, providerID); err != nil {
		t.Fatal(err)
	}
	scheduled := time.Now().Add(30 * 24 * time.Hour)
	if _, err = pool.Exec(ctx, `INSERT INTO service_requests(service_id,provider_id,customer_uid,status,client_request_id,quoted_price_cents,scheduled_for,scheduled_end_at,reservation_end_at) VALUES($1,$2,$3,'pending',$4,10000,$5,$6,$6)`, serviceID, providerID, customerID, uuid.New(), scheduled, scheduled.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	repository := NewRepository(pool)
	customerPage, err := repository.SearchUsers(ctx, customerID, providerName, 20, "")
	if err != nil || len(customerPage.Users) != 1 || customerPage.Users[0].ID != providerUID || customerPage.Users[0].Role != "provider" {
		t.Fatalf("customer directory = %+v, error = %v", customerPage, err)
	}
	providerPage, err := repository.SearchUsers(ctx, providerUID, customerName, 20, "")
	if err != nil || len(providerPage.Users) != 1 || providerPage.Users[0].ID != customerID || providerPage.Users[0].Role != "customer" {
		t.Fatalf("provider directory = %+v, error = %v", providerPage, err)
	}
	if _, err = pool.Exec(ctx, `UPDATE service_requests SET status='cancelled' WHERE service_id=$1`, serviceID); err != nil {
		t.Fatal(err)
	}
	providerPage, err = repository.SearchUsers(ctx, providerUID, customerName, 20, "")
	if err != nil || len(providerPage.Users) != 0 {
		t.Fatalf("cancelled request leaked into provider directory: %+v, error = %v", providerPage, err)
	}
}
