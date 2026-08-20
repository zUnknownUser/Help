package servicerequests

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	postgrescatalog "github.com/vendlydigital/help/services/api/internal/adapters/postgres/catalog"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

func TestCreateAllowsOnlyOneConcurrentReservationForProvider(t *testing.T) {
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
	providerUID, firstCustomer, secondCustomer := "provider-"+uuid.NewString(), "customer-"+uuid.NewString(), "customer-"+uuid.NewString()
	providerID, serviceID := uuid.NewString(), uuid.NewString()
	defer func() {
		pool.Exec(context.Background(), `DELETE FROM service_requests WHERE service_id=$1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM notifications WHERE firebase_uid IN ($1,$2,$3)`, providerUID, firstCustomer, secondCustomer)
		pool.Exec(context.Background(), `DELETE FROM services WHERE id=$1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM providers WHERE id=$1`, providerID)
		pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid IN ($1,$2,$3)`, providerUID, firstCustomer, secondCustomer)
	}()
	seedCheckoutUser(t, pool, providerUID, "Prestador", "provider")
	seedCheckoutUser(t, pool, firstCustomer, "Cliente A", "customer")
	seedCheckoutUser(t, pool, secondCustomer, "Cliente B", "customer")
	execCheckoutSQL(t, pool, `INSERT INTO providers(id,name,active,accepting_requests,owner_uid,onboarding_status) VALUES($1,'Prestador',true,true,$2,'approved')`, providerID, providerUID)
	seedCheckoutSchedule(t, pool, providerID)
	execCheckoutSQL(t, pool, `INSERT INTO services(id,provider_id,title,description,rating,reviews,duration_minutes,price_cents,old_price_cents,active,published_at) VALUES($1,$2,'Serviço','','0','0',60,10000,NULL,true,now())`, serviceID, providerID)
	scheduled := time.Now().UTC().Add(3 * time.Hour).Truncate(15 * time.Minute)
	repository := NewRepository(pool)
	results := make(chan error, 2)
	start := make(chan struct{})
	for _, customer := range []string{firstCustomer, secondCustomer} {
		go func(uid string) {
			<-start
			draft, _ := domainrequests.NewDraft(uuid.NewString(), scheduled, "")
			_, err := repository.Create(ctx, uid, serviceID, draft)
			results <- err
		}(customer)
	}
	close(start)
	firstErr, secondErr := <-results, <-results
	successes, conflicts := 0, 0
	for _, result := range []error{firstErr, secondErr} {
		if result == nil {
			successes++
		} else if errors.Is(result, domainrequests.ErrSlotUnavailable) {
			conflicts++
		} else {
			t.Fatalf("unexpected error: %v", result)
		}
	}
	if successes != 1 || conflicts != 1 {
		t.Fatalf("successes=%d conflicts=%d", successes, conflicts)
	}
}

func TestCreateIsIdempotentAndSnapshotsCheckoutData(t *testing.T) {
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

	providerUID, customerUID := "provider-"+uuid.NewString(), "customer-"+uuid.NewString()
	providerID, serviceID := uuid.NewString(), uuid.NewString()
	defer func() {
		pool.Exec(context.Background(), `DELETE FROM service_requests WHERE service_id = $1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM notifications WHERE firebase_uid IN ($1, $2)`, providerUID, customerUID)
		pool.Exec(context.Background(), `DELETE FROM services WHERE id = $1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM providers WHERE id = $1`, providerID)
		pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid IN ($1, $2)`, providerUID, customerUID)
	}()
	seedCheckoutUser(t, pool, providerUID, "Prestador", "provider")
	seedCheckoutUser(t, pool, customerUID, "Cliente", "customer")
	execCheckoutSQL(t, pool, `INSERT INTO providers (
		id, name, active, accepting_requests, owner_uid, onboarding_status
	) VALUES ($1, 'Prestador', true, true, $2, 'approved')`, providerID, providerUID)
	seedCheckoutSchedule(t, pool, providerID)
	execCheckoutSQL(t, pool, `INSERT INTO services (
		id, provider_id, title, description, rating, reviews, duration_minutes,
		price_cents, old_price_cents, active, published_at
	) VALUES ($1, $2, 'Limpeza', 'Limpeza completa', 0, 0, 90, 15900, NULL, true, now())`, serviceID, providerID)

	repository := NewRepository(pool)
	draft, _ := domainrequests.NewDraft(uuid.NewString(), time.Now().UTC().Add(2*time.Hour).Truncate(15*time.Minute), "Levar material")
	first, err := repository.Create(ctx, customerUID, serviceID, draft)
	if err != nil {
		t.Fatal(err)
	}
	second, err := repository.Create(ctx, customerUID, serviceID, draft)
	if err != nil {
		t.Fatal(err)
	}
	if first.ID != second.ID || first.QuotedPriceCents != 15900 || first.Address != "Rua A, 10, Manaus - AM" {
		t.Fatalf("first = %+v second = %+v", first, second)
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM service_requests WHERE customer_uid = $1 AND client_request_id = $2`, customerUID, draft.ClientID).Scan(&count); err != nil || count != 1 {
		t.Fatalf("count = %d error = %v", count, err)
	}
	var notificationCount int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM notifications WHERE firebase_uid = $1 AND kind = 'service_request'`, providerUID).Scan(&notificationCount); err != nil || notificationCount != 1 {
		t.Fatalf("notifications = %d error = %v", notificationCount, err)
	}
	reschedule := domainrequests.Reschedule{ClientID: uuid.NewString(), ScheduledFor: draft.ScheduledFor.Add(2 * time.Hour), ExpectedVersion: first.Version}
	rescheduled, err := repository.Reschedule(ctx, customerUID, first.ID, reschedule)
	if err != nil || !rescheduled.ScheduledFor.Equal(reschedule.ScheduledFor) || rescheduled.Version != first.Version+1 || rescheduled.Status != domainrequests.StatusPending {
		t.Fatalf("rescheduled = %+v error = %v", rescheduled, err)
	}
	retriedReschedule, err := repository.Reschedule(ctx, customerUID, first.ID, reschedule)
	if err != nil || retriedReschedule.Version != rescheduled.Version {
		t.Fatalf("retried reschedule = %+v error = %v", retriedReschedule, err)
	}
	changedReschedule := reschedule
	changedReschedule.ScheduledFor = changedReschedule.ScheduledFor.Add(time.Hour)
	if _, err := repository.Reschedule(ctx, customerUID, first.ID, changedReschedule); !errors.Is(err, domainrequests.ErrIdempotencyConflict) {
		t.Fatalf("reschedule idempotency error = %v", err)
	}

	details, err := postgrescatalog.NewRepository(pool).FindDetails(ctx, customerUID, serviceID)
	if err != nil || !details.CanRequest || details.ProviderUserID != providerUID || details.ViewerAddress == nil {
		t.Fatalf("details = %+v error = %v", details, err)
	}
	ownDraft, _ := domainrequests.NewDraft(uuid.NewString(), time.Now().UTC().Add(3*time.Hour).Truncate(15*time.Minute), "")
	if _, err := repository.Create(ctx, providerUID, serviceID, ownDraft); !errors.Is(err, domainrequests.ErrOwnService) {
		t.Fatalf("own service error = %v", err)
	}

	conflicting := draft
	conflicting.Note = "Outra intencao"
	if _, err := repository.Create(ctx, customerUID, serviceID, conflicting); !errors.Is(err, domainrequests.ErrIdempotencyConflict) {
		t.Fatalf("conflict error = %v", err)
	}
}

func TestLifecycleTransitionIsAuthorizedVersionedAndIdempotent(t *testing.T) {
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
	providerUID, customerUID, strangerUID := "provider-"+uuid.NewString(), "customer-"+uuid.NewString(), "stranger-"+uuid.NewString()
	providerID, serviceID := uuid.NewString(), uuid.NewString()
	defer func() {
		pool.Exec(context.Background(), `DELETE FROM service_requests WHERE service_id = $1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM notifications WHERE firebase_uid IN ($1, $2, $3)`, providerUID, customerUID, strangerUID)
		pool.Exec(context.Background(), `DELETE FROM services WHERE id = $1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM providers WHERE id = $1`, providerID)
		pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid IN ($1, $2, $3)`, providerUID, customerUID, strangerUID)
	}()
	seedCheckoutUser(t, pool, providerUID, "Prestador", "provider")
	seedCheckoutUser(t, pool, customerUID, "Cliente", "customer")
	seedCheckoutUser(t, pool, strangerUID, "Estranho", "customer")
	execCheckoutSQL(t, pool, `INSERT INTO providers (id, name, active, accepting_requests, owner_uid, onboarding_status)
		VALUES ($1, 'Prestador', true, true, $2, 'approved')`, providerID, providerUID)
	seedCheckoutSchedule(t, pool, providerID)
	execCheckoutSQL(t, pool, `INSERT INTO services (id, provider_id, title, description, rating, reviews, duration_minutes,
		price_cents, old_price_cents, active, published_at) VALUES ($1, $2, 'Limpeza', '', 0, 0, 60, 10000, NULL, true, now())`, serviceID, providerID)
	repository := NewRepository(pool)
	draft, _ := domainrequests.NewDraft(uuid.NewString(), time.Now().UTC().Add(2*time.Hour).Truncate(15*time.Minute), "")
	created, err := repository.Create(ctx, customerUID, serviceID, draft)
	if err != nil {
		t.Fatal(err)
	}
	command := domainrequests.Transition{ClientID: uuid.NewString(), Target: domainrequests.StatusAccepted, ExpectedVersion: 0}
	accepted, err := repository.Transition(ctx, providerUID, created.ID, command)
	if err != nil || accepted.Status != domainrequests.StatusAccepted || accepted.Version != 1 {
		t.Fatalf("accepted = %+v error = %v", accepted, err)
	}
	retried, err := repository.Transition(ctx, providerUID, created.ID, command)
	if err != nil || retried.Version != 1 {
		t.Fatalf("retried = %+v error = %v", retried, err)
	}
	changedIntent := command
	changedIntent.Reason = "Outro motivo"
	if _, err := repository.Transition(ctx, providerUID, created.ID, changedIntent); !errors.Is(err, domainrequests.ErrIdempotencyConflict) {
		t.Fatalf("idempotency intent error = %v", err)
	}
	if _, err := repository.Transition(ctx, strangerUID, created.ID, domainrequests.Transition{ClientID: uuid.NewString(), Target: domainrequests.StatusCancelled, ExpectedVersion: 1}); !errors.Is(err, domainrequests.ErrForbidden) {
		t.Fatalf("stranger error = %v", err)
	}
	if _, err := repository.Transition(ctx, providerUID, created.ID, domainrequests.Transition{ClientID: uuid.NewString(), Target: domainrequests.StatusInProgress, ExpectedVersion: 0}); !errors.Is(err, domainrequests.ErrVersionConflict) {
		t.Fatalf("version error = %v", err)
	}
}

func TestNegotiationAlternatesQuotesAndAcceptsAtomically(t *testing.T) {
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
	customerUID := "customer-" + uuid.NewString()
	providerID, serviceID := uuid.NewString(), uuid.NewString()
	defer func() {
		pool.Exec(context.Background(), `DELETE FROM service_requests WHERE service_id = $1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM notifications WHERE firebase_uid IN ($1, $2)`, providerUID, customerUID)
		pool.Exec(context.Background(), `DELETE FROM services WHERE id = $1`, serviceID)
		pool.Exec(context.Background(), `DELETE FROM providers WHERE id = $1`, providerID)
		pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid IN ($1, $2)`, providerUID, customerUID)
	}()
	seedCheckoutUser(t, pool, providerUID, "Prestador", "provider")
	seedCheckoutUser(t, pool, customerUID, "Cliente", "customer")
	execCheckoutSQL(t, pool, `INSERT INTO providers (id, name, active, accepting_requests, owner_uid, onboarding_status)
		VALUES ($1, 'Prestador', true, true, $2, 'approved')`, providerID, providerUID)
	seedCheckoutSchedule(t, pool, providerID)
	execCheckoutSQL(t, pool, `INSERT INTO services (id, provider_id, title, description, rating, reviews, duration_minutes,
		price_cents, old_price_cents, active, published_at) VALUES ($1, $2, 'Reparo', '', 0, 0, 60, 10000, NULL, true, now())`, serviceID, providerID)

	repository := NewRepository(pool)
	requestDraft, _ := domainrequests.NewDraft(
		uuid.NewString(), time.Now().UTC().Add(2*time.Hour).Truncate(15*time.Minute), "",
	)
	created, err := repository.Create(ctx, customerUID, serviceID, requestDraft)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	providerQuote, _ := domainrequests.NewQuoteDraft(
		uuid.NewString(), "Inclui material", created.Version, nil,
		[]domainrequests.QuoteItemDraft{
			{Kind: "labor", Description: "Mão de obra", AmountCents: 12000},
			{Kind: "material", Description: "Material", AmountCents: 3000},
		}, now,
	)
	_, firstNegotiation, recipient, err := repository.ProposeQuote(
		ctx, providerUID, created.ID, providerQuote,
	)
	if err != nil || recipient != customerUID || len(firstNegotiation.Quotes) != 1 {
		t.Fatalf("first negotiation = %+v, recipient = %q, error = %v", firstNegotiation, recipient, err)
	}
	if _, _, _, err = repository.ProposeQuote(ctx, providerUID, created.ID, providerQuote); err != nil {
		t.Fatalf("idempotent proposal error = %v", err)
	}
	secondProviderQuote, _ := domainrequests.NewQuoteDraft(
		uuid.NewString(), "Outra proposta", created.Version, nil,
		[]domainrequests.QuoteItemDraft{{Kind: "labor", Description: "Mão de obra", AmountCents: 14000}}, now,
	)
	if _, _, _, err = repository.ProposeQuote(ctx, providerUID, created.ID, secondProviderQuote); !errors.Is(err, domainrequests.ErrNegotiationTurn) {
		t.Fatalf("same-side proposal error = %v", err)
	}
	confirmed, err := repository.Transition(ctx, providerUID, created.ID, domainrequests.Transition{
		ClientID: uuid.NewString(), Target: domainrequests.StatusAccepted, ExpectedVersion: created.Version,
	})
	if err != nil {
		t.Fatalf("confirm request error = %v", err)
	}
	if _, err = repository.Transition(ctx, providerUID, created.ID, domainrequests.Transition{
		ClientID: uuid.NewString(), Target: domainrequests.StatusInProgress, ExpectedVersion: confirmed.Version,
	}); !errors.Is(err, domainrequests.ErrQuotePending) {
		t.Fatalf("pending quote start error = %v", err)
	}

	attachment, attachmentRecipient, err := repository.CreateAttachment(ctx, providerUID, created.ID, domainrequests.Attachment{
		StorageKey: "request-" + uuid.NewString() + ".jpg", ContentType: "image/jpeg", ByteSize: 1200,
	})
	if err != nil || attachmentRecipient != customerUID {
		t.Fatalf("attachment = %+v, recipient = %q, error = %v", attachment, attachmentRecipient, err)
	}
	if _, err = repository.GetAttachment(ctx, customerUID, attachment.ID); err != nil {
		t.Fatalf("participant attachment read error = %v", err)
	}
	if _, _, err = repository.DeleteAttachment(ctx, customerUID, created.ID, attachment.ID); !errors.Is(err, domainrequests.ErrNotFound) {
		t.Fatalf("other participant delete error = %v", err)
	}
	if _, _, err = repository.DeleteAttachment(ctx, providerUID, created.ID, attachment.ID); err != nil {
		t.Fatalf("uploader delete error = %v", err)
	}

	customerQuote, _ := domainrequests.NewQuoteDraft(
		uuid.NewString(), "Sem adicional", confirmed.Version, nil,
		[]domainrequests.QuoteItemDraft{{Kind: "labor", Description: "Valor combinado", AmountCents: 13000}}, now,
	)
	_, counterNegotiation, _, err := repository.ProposeQuote(ctx, customerUID, created.ID, customerQuote)
	if err != nil || len(counterNegotiation.Quotes) != 2 || counterNegotiation.Quotes[1].Status != domainrequests.QuoteSuperseded {
		t.Fatalf("counter negotiation = %+v, error = %v", counterNegotiation, err)
	}
	acceptedQuoteID := counterNegotiation.Quotes[0].ID
	acceptCommandID := uuid.NewString()
	accepted, acceptedNegotiation, _, err := repository.AcceptQuote(
		ctx, providerUID, created.ID, acceptedQuoteID, acceptCommandID, confirmed.Version, now,
	)
	if err != nil || accepted.Status != domainrequests.StatusAccepted || accepted.Version != 2 || accepted.QuotedPriceCents != 13000 || acceptedNegotiation.Quotes[0].Status != domainrequests.QuoteAccepted {
		t.Fatalf("accepted = %+v, negotiation = %+v, error = %v", accepted, acceptedNegotiation, err)
	}
	retried, _, retryRecipient, err := repository.AcceptQuote(
		ctx, providerUID, created.ID, acceptedQuoteID, acceptCommandID, confirmed.Version, now,
	)
	if err != nil || retried.Version != accepted.Version || retryRecipient != "" {
		t.Fatalf("retried = %+v, recipient = %q, error = %v", retried, retryRecipient, err)
	}
	started, err := repository.Transition(ctx, providerUID, created.ID, domainrequests.Transition{
		ClientID: uuid.NewString(), Target: domainrequests.StatusInProgress, ExpectedVersion: accepted.Version,
	})
	if err != nil || started.Status != domainrequests.StatusInProgress {
		t.Fatalf("started = %+v, error = %v", started, err)
	}
}

func seedCheckoutUser(t *testing.T, pool *pgxpool.Pool, uid, name, role string) {
	t.Helper()
	execCheckoutSQL(t, pool, `INSERT INTO user_profiles (firebase_uid, email, display_name, active_role)
		VALUES ($1, $1 || '@example.com', $2, $3)`, uid, name, role)
	execCheckoutSQL(t, pool, `INSERT INTO user_roles (firebase_uid, role) VALUES ($1, $2)`, uid, role)
	execCheckoutSQL(t, pool, `INSERT INTO user_addresses (
		firebase_uid, label, formatted_address, is_default, postal_code, street,
		street_number, district, city, state, latitude, longitude
	) VALUES ($1, 'Casa', 'Rua A, 10, Manaus - AM', true, '69000000', 'Rua A',
	          '10', 'Centro', 'Manaus', 'AM', -3.0816, -59.9780)`, uid)
}

func seedCheckoutSchedule(t *testing.T, pool *pgxpool.Pool, providerID string) {
	t.Helper()
	execCheckoutSQL(t, pool, `INSERT INTO provider_schedule_settings (
		provider_id, time_zone, minimum_notice_minutes, booking_horizon_days,
		buffer_minutes, slot_interval_minutes
	) VALUES ($1, 'UTC', 15, 180, 0, 15)`, providerID)
	execCheckoutSQL(t, pool, `INSERT INTO provider_availability_rules (
		provider_id, weekday, start_minute, end_minute
	) SELECT $1, weekday, 0, 1440 FROM generate_series(0, 6) weekday`, providerID)
}

func execCheckoutSQL(t *testing.T, pool *pgxpool.Pool, statement string, args ...any) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), statement, args...); err != nil {
		t.Fatal(err)
	}
}
