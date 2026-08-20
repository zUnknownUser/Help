package servicerequests_test

import (
	"bytes"
	"context"
	"errors"
	"io"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	applicationrequests "github.com/vendlydigital/help/services/api/internal/application/servicerequests"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type negotiationRepositoryStub struct {
	proposedDraft domainrequests.QuoteDraft
	acceptedAt    time.Time
	createError   error
}

func (stub *negotiationRepositoryStub) GetNegotiation(context.Context, string, string) (domainrequests.Request, domainrequests.Negotiation, error) {
	return domainrequests.Request{ID: "request-1"}, domainrequests.Negotiation{}, nil
}

func (stub *negotiationRepositoryStub) ProposeQuote(_ context.Context, _, _ string, draft domainrequests.QuoteDraft) (domainrequests.Request, domainrequests.Negotiation, string, error) {
	stub.proposedDraft = draft
	return domainrequests.Request{ID: "request-1"}, domainrequests.Negotiation{}, "recipient-1", nil
}

func (stub *negotiationRepositoryStub) AcceptQuote(_ context.Context, _, _, _, _ string, _ int, now time.Time) (domainrequests.Request, domainrequests.Negotiation, string, error) {
	stub.acceptedAt = now
	return domainrequests.Request{ID: "request-1"}, domainrequests.Negotiation{}, "recipient-1", nil
}

func (stub *negotiationRepositoryStub) CreateAttachment(_ context.Context, _, _ string, attachment domainrequests.Attachment) (domainrequests.Attachment, string, error) {
	if stub.createError != nil {
		return domainrequests.Attachment{}, "", stub.createError
	}
	attachment.ID = "attachment-1"
	return attachment, "recipient-1", nil
}

func (stub *negotiationRepositoryStub) GetAttachment(context.Context, string, string) (domainrequests.Attachment, error) {
	return domainrequests.Attachment{}, nil
}

func (stub *negotiationRepositoryStub) DeleteAttachment(context.Context, string, string, string) (string, string, error) {
	return "stored.jpg", "recipient-1", nil
}

type mediaStoreStub struct {
	deleted []string
}

func (store *mediaStoreStub) Save(_ context.Context, extension string, content io.Reader, _ int64) (ports.StoredMedia, error) {
	value, err := io.ReadAll(content)
	if err != nil {
		return ports.StoredMedia{}, err
	}
	return ports.StoredMedia{Key: "stored" + extension, ByteSize: int64(len(value))}, nil
}

func (store *mediaStoreStub) Open(context.Context, string, string) (ports.MediaObject, error) {
	return ports.MediaObject{}, nil
}

func (store *mediaStoreStub) Delete(_ context.Context, key string) error {
	store.deleted = append(store.deleted, key)
	return nil
}

type realtimePublisherSpy struct {
	userID string
	event  ports.RealtimeEvent
}

func (spy *realtimePublisherSpy) Publish(userID string, event ports.RealtimeEvent) int {
	spy.userID, spy.event = userID, event
	return 1
}

func (spy *realtimePublisherSpy) IsOnline(string) bool { return true }

func TestNegotiationServiceBuildsQuoteWithInjectedClockAndPublishes(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 8, 19, 12, 0, 0, 0, time.UTC)
	repository := &negotiationRepositoryStub{}
	realtime := &realtimePublisherSpy{}
	service := applicationrequests.NewNegotiationService(
		repository, &mediaStoreStub{}, realtime, func() time.Time { return now },
	)

	_, err := service.Propose(context.Background(), "provider-1", "request-1", ports.ServiceRequestQuoteInput{
		ClientCommandID: "c349a83e-fbd9-4d59-984d-0516b7f981b2",
		ExpectedVersion: 2,
		Message:         " Inclui material ",
		ExpiresAt:       now.Add(24 * time.Hour).Format(time.RFC3339),
		Items: []domainrequests.QuoteItemDraft{
			{Kind: "labor", Description: "Mão de obra", AmountCents: 12000},
			{Kind: "discount", Description: "Desconto", AmountCents: 2000},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if repository.proposedDraft.TotalCents != 10000 || repository.proposedDraft.Message != "Inclui material" {
		t.Fatalf("draft = %+v", repository.proposedDraft)
	}
	if realtime.userID != "recipient-1" || realtime.event.Type != "service_request.quote_updated" {
		t.Fatalf("realtime = %+v to %q", realtime.event, realtime.userID)
	}

	_, err = service.Accept(context.Background(), "customer-1", "request-1", "quote-1", ports.ServiceRequestQuoteAcceptInput{
		ClientCommandID: "8280806e-c144-461a-8f06-f797d9be434b",
		ExpectedVersion: 2,
	})
	if err != nil || !repository.acceptedAt.Equal(now) {
		t.Fatalf("accepted at = %s, error = %v", repository.acceptedAt, err)
	}
}

func TestNegotiationServiceCleansStoredAttachmentWhenPersistenceFails(t *testing.T) {
	t.Parallel()
	repository := &negotiationRepositoryStub{createError: errors.New("database unavailable")}
	store := &mediaStoreStub{}
	service := applicationrequests.NewNegotiationService(repository, store, nil, time.Now)

	_, err := service.UploadAttachment(
		context.Background(), "customer-1", "request-1", "image/jpeg", " Antes ", bytes.NewBufferString("image"),
	)
	if err == nil || len(store.deleted) != 1 || store.deleted[0] != "stored.jpg" {
		t.Fatalf("deleted = %v, error = %v", store.deleted, err)
	}
}
