package servicerequests

import (
	"context"
	"errors"
	"io"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

const maxRequestAttachmentBytes int64 = 8 << 20

var requestImageExtensions = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

type NegotiationService struct {
	repository ports.ServiceRequestNegotiationRepository
	store      ports.MediaStore
	realtime   ports.RealtimePublisher
	now        func() time.Time
}

func NewNegotiationService(
	repository ports.ServiceRequestNegotiationRepository,
	store ports.MediaStore,
	realtime ports.RealtimePublisher,
	now func() time.Time,
) *NegotiationService {
	return &NegotiationService{repository: repository, store: store, realtime: realtime, now: now}
}

func (service *NegotiationService) Get(
	ctx context.Context,
	uid, requestID string,
) (ports.ServiceRequestNegotiationResult, error) {
	request, negotiation, err := service.repository.GetNegotiation(ctx, uid, strings.TrimSpace(requestID))
	return ports.ServiceRequestNegotiationResult{Request: request, Negotiation: negotiation}, err
}

func (service *NegotiationService) Propose(
	ctx context.Context,
	uid, requestID string,
	input ports.ServiceRequestQuoteInput,
) (ports.ServiceRequestNegotiationResult, error) {
	var expiresAt *time.Time
	if value := strings.TrimSpace(input.ExpiresAt); value != "" {
		parsed, err := time.Parse(time.RFC3339, value)
		if err != nil {
			return ports.ServiceRequestNegotiationResult{}, domainrequests.ErrInvalidQuote
		}
		expiresAt = &parsed
	}
	draft, err := domainrequests.NewQuoteDraft(
		input.ClientCommandID, input.Message, input.ExpectedVersion,
		expiresAt, input.Items, service.now(),
	)
	if err != nil {
		return ports.ServiceRequestNegotiationResult{}, err
	}
	request, negotiation, recipient, err := service.repository.ProposeQuote(
		ctx, uid, strings.TrimSpace(requestID), draft,
	)
	if err != nil {
		return ports.ServiceRequestNegotiationResult{}, err
	}
	service.publish(recipient, request.ID, "service_request.quote_updated")
	return ports.ServiceRequestNegotiationResult{Request: request, Negotiation: negotiation}, nil
}

func (service *NegotiationService) Accept(
	ctx context.Context,
	uid, requestID, quoteID string,
	input ports.ServiceRequestQuoteAcceptInput,
) (ports.ServiceRequestNegotiationResult, error) {
	if err := domainrequests.ValidateAcceptCommand(input.ClientCommandID, input.ExpectedVersion); err != nil {
		return ports.ServiceRequestNegotiationResult{}, err
	}
	request, negotiation, recipient, err := service.repository.AcceptQuote(
		ctx, uid, strings.TrimSpace(requestID), strings.TrimSpace(quoteID),
		input.ClientCommandID, input.ExpectedVersion, service.now(),
	)
	if err != nil {
		return ports.ServiceRequestNegotiationResult{}, err
	}
	service.publish(recipient, request.ID, "service_request.quote_accepted")
	return ports.ServiceRequestNegotiationResult{Request: request, Negotiation: negotiation}, nil
}

func (service *NegotiationService) UploadAttachment(
	ctx context.Context,
	uid, requestID, contentType, caption string,
	content io.Reader,
) (domainrequests.Attachment, error) {
	caption, err := domainrequests.NormalizeAttachmentCaption(caption)
	if err != nil {
		return domainrequests.Attachment{}, err
	}
	normalized := strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))
	extension, ok := requestImageExtensions[normalized]
	if !ok {
		return domainrequests.Attachment{}, domainrequests.ErrInvalidAttachment
	}
	stored, err := service.store.Save(ctx, extension, content, maxRequestAttachmentBytes)
	if errors.Is(err, domainchat.ErrInvalidMedia) {
		return domainrequests.Attachment{}, domainrequests.ErrInvalidAttachment
	}
	if err != nil {
		return domainrequests.Attachment{}, err
	}
	attachment := domainrequests.Attachment{
		RequestID: strings.TrimSpace(requestID), UploaderUID: uid,
		StorageKey: stored.Key, ContentType: normalized, ByteSize: stored.ByteSize, Caption: caption,
	}
	created, recipient, err := service.repository.CreateAttachment(ctx, uid, requestID, attachment)
	if err != nil {
		_ = service.store.Delete(context.Background(), stored.Key)
		return domainrequests.Attachment{}, err
	}
	service.publish(recipient, requestID, "service_request.attachment_added")
	return created, nil
}

func (service *NegotiationService) OpenAttachment(
	ctx context.Context,
	uid, attachmentID string,
) (domainrequests.Attachment, ports.MediaObject, error) {
	attachment, err := service.repository.GetAttachment(ctx, uid, strings.TrimSpace(attachmentID))
	if err != nil {
		return domainrequests.Attachment{}, ports.MediaObject{}, err
	}
	object, err := service.store.Open(ctx, attachment.StorageKey, attachment.ContentType)
	return attachment, object, err
}

func (service *NegotiationService) DeleteAttachment(
	ctx context.Context,
	uid, requestID, attachmentID string,
) error {
	key, recipient, err := service.repository.DeleteAttachment(
		ctx, uid, strings.TrimSpace(requestID), strings.TrimSpace(attachmentID),
	)
	if err != nil {
		return err
	}
	if err := service.store.Delete(ctx, key); err != nil {
		return err
	}
	service.publish(recipient, requestID, "service_request.attachment_deleted")
	return nil
}

func (service *NegotiationService) publish(recipient, requestID, eventType string) {
	if recipient == "" || service.realtime == nil {
		return
	}
	service.realtime.Publish(recipient, ports.RealtimeEvent{
		Type: eventType,
		Data: map[string]string{"request_id": requestID},
	})
}
