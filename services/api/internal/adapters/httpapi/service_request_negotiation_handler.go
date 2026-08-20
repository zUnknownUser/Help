package httpapi

import (
	"errors"
	"fmt"
	"log/slog"
	"mime/multipart"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

const maxRequestAttachmentUploadBody = 9 << 20

type ServiceRequestNegotiationHandler struct {
	service ports.ServiceRequestNegotiationService
}

func NewServiceRequestNegotiationHandler(
	service ports.ServiceRequestNegotiationService,
) *ServiceRequestNegotiationHandler {
	return &ServiceRequestNegotiationHandler{service: service}
}

func (handler *ServiceRequestNegotiationHandler) Get(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validUUIDPath(w, r, "id", "Solicitação inválida.") {
		return
	}
	result, err := handler.service.Get(r.Context(), identity.UID, r.PathValue("id"))
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, negotiationEnvelope(result))
}

func (handler *ServiceRequestNegotiationHandler) Propose(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validUUIDPath(w, r, "id", "Solicitação inválida.") {
		return
	}
	var input struct {
		ClientCommandID string `json:"client_command_id"`
		ExpectedVersion int    `json:"expected_version"`
		Message         string `json:"message"`
		ExpiresAt       string `json:"expires_at"`
		Items           []struct {
			Kind        string `json:"kind"`
			Description string `json:"description"`
			AmountCents int    `json:"amount_cents"`
		} `json:"items"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Orçamento inválido."})
		return
	}
	items := make([]domainrequests.QuoteItemDraft, 0, len(input.Items))
	for _, item := range input.Items {
		items = append(items, domainrequests.QuoteItemDraft{
			Kind: item.Kind, Description: item.Description, AmountCents: item.AmountCents,
		})
	}
	result, err := handler.service.Propose(r.Context(), identity.UID, r.PathValue("id"), ports.ServiceRequestQuoteInput{
		ClientCommandID: input.ClientCommandID, ExpectedVersion: input.ExpectedVersion,
		Message: input.Message, ExpiresAt: input.ExpiresAt, Items: items,
	})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	slog.InfoContext(r.Context(), "service request quote proposed",
		"user_id", identity.UID, "request_id", result.Request.ID,
	)
	writeJSON(w, http.StatusCreated, negotiationEnvelope(result))
}

func (handler *ServiceRequestNegotiationHandler) Accept(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validUUIDPath(w, r, "id", "Solicitação inválida.") ||
		!validUUIDPath(w, r, "quoteId", "Orçamento inválido.") {
		return
	}
	var input struct {
		ClientCommandID string `json:"client_command_id"`
		ExpectedVersion int    `json:"expected_version"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Aceite inválido."})
		return
	}
	result, err := handler.service.Accept(
		r.Context(), identity.UID, r.PathValue("id"), r.PathValue("quoteId"),
		ports.ServiceRequestQuoteAcceptInput{
			ClientCommandID: input.ClientCommandID, ExpectedVersion: input.ExpectedVersion,
		},
	)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	slog.InfoContext(r.Context(), "service request quote accepted",
		"user_id", identity.UID, "request_id", result.Request.ID,
		"quote_id", r.PathValue("quoteId"), "version", result.Request.Version,
	)
	writeJSON(w, http.StatusOK, negotiationEnvelope(result))
}

func (handler *ServiceRequestNegotiationHandler) UploadAttachment(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validUUIDPath(w, r, "id", "Solicitação inválida.") {
		return
	}
	file, contentType, ok := requestAttachmentUpload(w, r)
	if !ok {
		return
	}
	defer file.Close()
	if r.MultipartForm != nil {
		defer r.MultipartForm.RemoveAll()
	}
	attachment, err := handler.service.UploadAttachment(
		r.Context(), identity.UID, r.PathValue("id"), contentType, r.FormValue("caption"), file,
	)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": attachmentResponse(attachment, identity.UID)})
}

func (handler *ServiceRequestNegotiationHandler) ServeAttachment(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validUUIDPath(w, r, "attachmentId", "Imagem inválida.") {
		return
	}
	attachment, object, err := handler.service.OpenAttachment(r.Context(), identity.UID, r.PathValue("attachmentId"))
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	defer object.Reader.Close()
	extension := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[object.ContentType]
	w.Header().Set("Content-Type", object.ContentType)
	w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="%s%s"`, attachment.ID, extension))
	w.Header().Set("Cache-Control", "private, max-age=3600")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	http.ServeContent(w, r, attachment.ID+extension, object.ModifiedAt, object.Reader)
}

func (handler *ServiceRequestNegotiationHandler) DeleteAttachment(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validUUIDPath(w, r, "id", "Solicitação inválida.") ||
		!validUUIDPath(w, r, "attachmentId", "Imagem inválida.") {
		return
	}
	if err := handler.service.DeleteAttachment(
		r.Context(), identity.UID, r.PathValue("id"), r.PathValue("attachmentId"),
	); err != nil {
		handler.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (handler *ServiceRequestNegotiationHandler) writeError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, domainrequests.ErrInvalidQuote), errors.Is(err, domainrequests.ErrInvalidAttachment):
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Revise os dados, valores e imagens informados."})
	case errors.Is(err, domainrequests.ErrNotFound), errors.Is(err, domainrequests.ErrQuoteNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Negociação não encontrada."})
	case errors.Is(err, domainrequests.ErrForbidden):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "Você não participa desta negociação."})
	case errors.Is(err, domainrequests.ErrAttachmentLimit):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "O limite de 8 imagens por solicitação foi atingido."})
	case errors.Is(err, domainrequests.ErrNegotiationClosed), errors.Is(err, domainrequests.ErrNegotiationTurn), errors.Is(err, domainrequests.ErrQuotePending):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esta negociação não permite essa ação agora."})
	case errors.Is(err, domainrequests.ErrVersionConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "A solicitação mudou em outro dispositivo. Recarregue antes de continuar."})
	case errors.Is(err, domainrequests.ErrIdempotencyConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esta tentativa já foi usada em outra negociação."})
	default:
		slog.ErrorContext(r.Context(), "service request negotiation failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível atualizar a negociação agora."})
	}
}

func negotiationEnvelope(result ports.ServiceRequestNegotiationResult) map[string]any {
	return map[string]any{"data": map[string]any{
		"request": newServiceRequestResponse(result.Request),
		"negotiation": negotiationResponse(result.Request, result.Negotiation),
	}}
}

func negotiationResponse(request domainrequests.Request, negotiation domainrequests.Negotiation) map[string]any {
	attachments := make([]map[string]any, 0, len(negotiation.Attachments))
	for _, attachment := range negotiation.Attachments {
		attachments = append(attachments, attachmentResponse(attachment, participantUID(request)))
	}
	quotes := make([]map[string]any, 0, len(negotiation.Quotes))
	for _, quote := range negotiation.Quotes {
		items := make([]map[string]any, 0, len(quote.Items))
		for _, item := range quote.Items {
			items = append(items, map[string]any{
				"id": item.ID, "kind": item.Kind, "description": item.Description,
				"amount_cents": item.AmountCents, "position": item.Position,
			})
		}
		canAccept := quote.Status == domainrequests.QuoteProposed && quote.AuthorRole != request.ViewerRole &&
			(quote.ExpiresAt == nil || quote.ExpiresAt.After(time.Now())) && domainrequests.CanNegotiate(request.Status)
		quotes = append(quotes, map[string]any{
			"id": quote.ID, "author_name": quote.AuthorName, "author_role": quote.AuthorRole,
			"revision": quote.Revision, "status": quote.Status, "currency": quote.Currency,
			"total_cents": quote.TotalCents, "message": quote.Message, "items": items,
			"expires_at": quote.ExpiresAt, "accepted_at": quote.AcceptedAt,
			"created_at": quote.CreatedAt, "can_accept": canAccept,
		})
	}
	canPropose := false
	if domainrequests.CanNegotiate(request.Status) {
		if len(negotiation.Quotes) == 0 {
			canPropose = request.ViewerRole == domainrequests.ViewerProvider
		} else if negotiation.Quotes[0].Status == domainrequests.QuoteProposed {
			canPropose = negotiation.Quotes[0].AuthorRole != request.ViewerRole
		}
	}
	return map[string]any{
		"attachments": attachments, "quotes": quotes,
		"can_add_attachment": domainrequests.CanNegotiate(request.Status) && len(attachments) < domainrequests.MaximumRequestAttachments,
		"can_propose": canPropose,
	}
}

func attachmentResponse(attachment domainrequests.Attachment, viewerUID string) map[string]any {
	return map[string]any{
		"id": attachment.ID, "uploader_name": attachment.UploaderName, "uploader_role": attachment.UploaderRole,
		"caption": attachment.Caption, "content_type": attachment.ContentType, "byte_size": attachment.ByteSize,
		"created_at": attachment.CreatedAt,
		"url": "/v1/service-request-attachments/" + attachment.ID,
		"can_delete": attachment.UploaderUID == viewerUID,
	}
}

func participantUID(request domainrequests.Request) string {
	if request.ViewerRole == domainrequests.ViewerCustomer {
		return request.CustomerUID
	}
	return request.ProviderUID
}

func validUUIDPath(w http.ResponseWriter, r *http.Request, name, message string) bool {
	if _, err := uuid.Parse(r.PathValue(name)); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": message})
		return false
	}
	return true
}

func requestAttachmentUpload(w http.ResponseWriter, r *http.Request) (multipart.File, string, bool) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestAttachmentUploadBody)
	if err := r.ParseMultipartForm(maxRequestAttachmentUploadBody); err != nil {
		if r.MultipartForm != nil {
			_ = r.MultipartForm.RemoveAll()
		}
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "A imagem excede o limite de 8 MB."})
		return nil, "", false
	}
	file, _, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Selecione uma imagem válida."})
		return nil, "", false
	}
	buffer := make([]byte, 512)
	read, _ := file.Read(buffer)
	contentType := strings.TrimSpace(http.DetectContentType(buffer[:read]))
	_, _ = file.Seek(0, 0)
	return file, contentType, true
}
