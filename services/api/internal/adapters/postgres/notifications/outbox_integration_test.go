package notifications

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

func TestPushOutboxClaimRetryAndDelivery(t *testing.T) {
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
	uid := "push-" + uuid.NewString()
	defer pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid = $1`, uid)
	if _, err := pool.Exec(ctx, `INSERT INTO user_profiles (firebase_uid, email, display_name, active_role)
		VALUES ($1, $1 || '@example.com', 'Push Test', 'customer')`, uid); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `WITH notification AS (
		INSERT INTO notifications (firebase_uid, title, body, kind, data)
		VALUES ($1, 'Pedido atualizado', 'Status alterado', 'service_request', '{"request_id":"request-1"}')
		RETURNING id
	) INSERT INTO notification_push_outbox (notification_id) SELECT id FROM notification`, uid); err != nil {
		t.Fatal(err)
	}
	repository := NewRepository(pool)
	deliveries, err := repository.Claim(ctx, 100)
	delivery := deliveryForUser(deliveries, uid)
	if err != nil || delivery == nil || delivery.Message.Data["request_id"] != "request-1" || delivery.Message.Data["type"] != "service_request" {
		t.Fatalf("deliveries = %+v error = %v", deliveries, err)
	}
	id := delivery.NotificationID
	if err := repository.Reschedule(ctx, id, time.Now().Add(-time.Second), "temporary"); err != nil {
		t.Fatal(err)
	}
	deliveries, err = repository.Claim(ctx, 100)
	delivery = deliveryForUser(deliveries, uid)
	if err != nil || delivery == nil || delivery.Attempts != 2 {
		t.Fatalf("retried deliveries = %+v error = %v", deliveries, err)
	}
	if err := repository.MarkDelivered(ctx, id); err != nil {
		t.Fatal(err)
	}
	deliveries, err = repository.Claim(ctx, 100)
	if err != nil || deliveryForUser(deliveries, uid) != nil {
		t.Fatalf("delivered items = %+v error = %v", deliveries, err)
	}
}

func deliveryForUser(deliveries []ports.PushDelivery, uid string) *ports.PushDelivery {
	for index := range deliveries {
		if deliveries[index].UserID == uid {
			return &deliveries[index]
		}
	}
	return nil
}

func TestServiceRequestRemindersAreQueuedOncePerRecipientAndWindow(t *testing.T) {
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
	providerUID, customerUID := "reminder-provider-"+uuid.NewString(), "reminder-customer-"+uuid.NewString()
	providerID, serviceID := uuid.NewString(), uuid.NewString()
	defer func() {
		pool.Exec(context.Background(), `DELETE FROM service_requests WHERE service_id=$1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM notifications WHERE firebase_uid IN ($1,$2)`, providerUID, customerUID)
		pool.Exec(context.Background(), `DELETE FROM services WHERE id=$1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM providers WHERE id=$1`, providerID)
		pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid IN ($1,$2)`, providerUID, customerUID)
	}()
	for _, user := range []struct{ uid, role string }{{providerUID, "provider"}, {customerUID, "customer"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role) VALUES($1,$1||'@example.com','Reminder',$2)`, user.uid, user.role); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := pool.Exec(ctx, `INSERT INTO providers(id,name,active,accepting_requests,owner_uid,onboarding_status) VALUES($1,'Prestador',true,true,$2,'approved')`, providerID, providerUID); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO services(id,provider_id,title,description,rating,reviews,duration_minutes,price_cents,old_price_cents,active,published_at) VALUES($1,$2,'Limpeza','',0,0,60,10000,10000,true,now())`, serviceID, providerID); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	scheduled := now.Add(3 * time.Hour)
	if _, err := pool.Exec(ctx, `INSERT INTO service_requests(service_id,provider_id,customer_uid,status,client_request_id,scheduled_for,scheduled_end_at,reservation_end_at,quoted_price_cents) VALUES($1,$2,$3,'accepted',$4,$5,$6,$6,10000)`, serviceID, providerID, customerUID, uuid.New(), scheduled, scheduled.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	repository := NewRepository(pool)
	var due int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM service_requests WHERE service_id=$1 AND status='accepted' AND scheduled_for>$2 AND scheduled_for<=$2+interval '24 hours'`, serviceID, now).Scan(&due); err != nil || due != 1 {
		t.Fatalf("due=%d error=%v", due, err)
	}
	first, err := repository.EnqueueDueReminders(ctx, now, 200)
	var dispatchCount, notificationCount int
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM service_request_reminder_dispatches dispatch JOIN service_requests request ON request.id=dispatch.request_id WHERE request.service_id=$1`, serviceID).Scan(&dispatchCount)
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM notifications WHERE firebase_uid IN ($1,$2) AND kind='service_request_reminder'`, providerUID, customerUID).Scan(&notificationCount)
	if err != nil || first != 2 {
		t.Fatalf("first=%d dispatches=%d notifications=%d error=%v", first, dispatchCount, notificationCount, err)
	}
	second, err := repository.EnqueueDueReminders(ctx, now.Add(time.Minute), 200)
	if err != nil || second != 0 {
		t.Fatalf("second=%d error=%v", second, err)
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM service_request_reminder_dispatches dispatch JOIN service_requests request ON request.id=dispatch.request_id WHERE request.service_id=$1 AND dispatch.reminder_kind='24h'`, serviceID).Scan(&count); err != nil || count != 2 {
		t.Fatalf("dispatches=%d error=%v", count, err)
	}
}
