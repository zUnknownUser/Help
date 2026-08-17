package helpnow

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

func TestDispatchAllowsExactlyOneProviderToAccept(t *testing.T) {
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
	now := time.Now().UTC().Truncate(time.Microsecond)
	categoryID := "help-now-" + uuid.NewString()
	customerUID := "customer-" + uuid.NewString()
	providerUIDs := []string{"provider-" + uuid.NewString(), "provider-" + uuid.NewString()}
	providerIDs := []string{uuid.NewString(), uuid.NewString()}
	serviceIDs := []string{uuid.NewString(), uuid.NewString()}
	defer cleanupHelpNowTest(pool, categoryID, customerUID, providerUIDs, providerIDs, serviceIDs)
	execHelpNowSQL(t, pool, `INSERT INTO categories(id,name,icon_key,position,active) VALUES($1,'Encanamento','plumbing',1,true)`, categoryID)
	seedHelpNowUser(t, pool, customerUID, "Cliente", "customer")
	for index := range providerUIDs {
		seedHelpNowUser(t, pool, providerUIDs[index], "Prestador", "provider")
		execHelpNowSQL(t, pool, `INSERT INTO providers(id,name,active,accepting_requests,owner_uid,onboarding_status)
			VALUES($1,'Prestador',true,true,$2,'approved')`, providerIDs[index], providerUIDs[index])
		execHelpNowSQL(t, pool, `INSERT INTO provider_schedule_settings(provider_id,buffer_minutes) VALUES($1,0)`, providerIDs[index])
		execHelpNowSQL(t, pool, `INSERT INTO services(id,provider_id,category_id,title,description,rating,reviews,duration_minutes,
			price_cents,old_price_cents,active,published_at) VALUES($1,$2,$3,'Reparo urgente','',0,0,60,10000,10000,true,now())`,
			serviceIDs[index], providerIDs[index], categoryID)
	}
	repository := NewRepository(pool)
	for index := range providerUIDs {
		_, err := repository.SetAvailability(ctx, providerUIDs[index], domainhelp.Availability{
			Enabled: true, Latitude: -3.0816 + float64(index)/1000, Longitude: -59.978,
			MaxDistanceKM: 10,
		}, now)
		if err != nil {
			t.Fatal(err)
		}
	}
	input, _ := domainhelp.NewCreateInput(uuid.NewString(), categoryID, "Vazamento", "Casa", "Rua A, 10, Manaus - AM", -3.0816, -59.978)
	request, err := repository.Create(ctx, customerUID, input, now)
	if err != nil {
		t.Fatal(err)
	}
	events, err := repository.DispatchDue(ctx, now, 10)
	if err != nil || len(events) != 2 {
		t.Fatalf("events = %+v error = %v", events, err)
	}
	type result struct {
		request domainhelp.Request
		err     error
	}
	results := make(chan result, 2)
	commands := make([]domainhelp.Command, 2)
	for index, uid := range providerUIDs {
		offers, listErr := repository.ListOffers(ctx, uid, now.Add(time.Second))
		if listErr != nil || len(offers) != 1 {
			t.Fatalf("offers = %+v error = %v", offers, listErr)
		}
		commands[index], _ = domainhelp.NewCommand(uuid.NewString(), offers[0].ID, "accept")
		go func(providerUID string, command domainhelp.Command) {
			accepted, _, acceptErr := repository.Respond(ctx, providerUID, command, now.Add(time.Second))
			results <- result{request: accepted, err: acceptErr}
		}(uid, commands[index])
	}
	successes, conflicts := 0, 0
	for range 2 {
		result := <-results
		if result.err == nil {
			successes++
			if result.request.ServiceRequestID == "" {
				t.Fatal("accepted request has no service request")
			}
			for index, uid := range providerUIDs {
				if result.request.AssignedProviderID == providerIDs[index] {
					_, _, retryErr := repository.Respond(ctx, uid, commands[index], now.Add(2*time.Second))
					if retryErr != nil {
						t.Fatalf("idempotent retry error = %v", retryErr)
					}
				}
			}
		} else if errors.Is(result.err, domainhelp.ErrAlreadyAssigned) {
			conflicts++
		} else {
			t.Fatalf("unexpected acceptance error = %v", result.err)
		}
	}
	if successes != 1 || conflicts != 1 {
		t.Fatalf("successes=%d conflicts=%d request=%s", successes, conflicts, request.ID)
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM service_requests WHERE customer_uid=$1 AND client_request_id=$2::uuid`, customerUID, input.ClientID).Scan(&count); err != nil || count != 1 {
		t.Fatalf("service request count=%d error=%v", count, err)
	}
}

func seedHelpNowUser(t *testing.T, pool *pgxpool.Pool, uid, name, role string) {
	t.Helper()
	execHelpNowSQL(t, pool, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role) VALUES($1,$1||'@example.com',$2,$3)`, uid, name, role)
	execHelpNowSQL(t, pool, `INSERT INTO user_roles(firebase_uid,role) VALUES($1,$2)`, uid, role)
}

func execHelpNowSQL(t *testing.T, pool *pgxpool.Pool, query string, args ...any) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), query, args...); err != nil {
		t.Fatal(err)
	}
}

func cleanupHelpNowTest(pool *pgxpool.Pool, categoryID, customerUID string, providerUIDs, providerIDs, serviceIDs []string) {
	ctx := context.Background()
	pool.Exec(ctx, `DELETE FROM help_now_requests WHERE customer_uid=$1`, customerUID)
	pool.Exec(ctx, `DELETE FROM service_requests WHERE customer_uid=$1`, customerUID)
	pool.Exec(ctx, `DELETE FROM services WHERE id=ANY($1)`, serviceIDs)
	pool.Exec(ctx, `DELETE FROM providers WHERE id=ANY($1)`, providerIDs)
	pool.Exec(ctx, `DELETE FROM user_profiles WHERE firebase_uid=$1 OR firebase_uid=ANY($2)`, customerUID, providerUIDs)
	pool.Exec(ctx, `DELETE FROM categories WHERE id=$1`, categoryID)
}
