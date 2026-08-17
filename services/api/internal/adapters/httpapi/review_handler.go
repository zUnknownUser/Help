package httpapi

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainreviews "github.com/vendlydigital/help/services/api/internal/domain/reviews"
)

type ReviewHandler struct{ service ports.ReviewService }

func NewReviewHandler(service ports.ReviewService) *ReviewHandler {
	return &ReviewHandler{service: service}
}

func (handler *ReviewHandler) List(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validRequestID(w, r) {
		return
	}
	items, err := handler.service.List(r.Context(), identity.UID, r.PathValue("id"))
	if err != nil {
		writeReviewError(w, r, err)
		return
	}
	data := make([]map[string]any, 0, len(items))
	for _, item := range items {
		data = append(data, reviewResponse(item))
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"items": data}})
}

func (handler *ReviewHandler) Create(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if !validRequestID(w, r) {
		return
	}
	var input struct {
		Rating  int    `json:"rating"`
		Comment string `json:"comment"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Avaliação inválida."})
		return
	}
	item, err := handler.service.Create(r.Context(), identity.UID, r.PathValue("id"), ports.ReviewInput{Rating: input.Rating, Comment: input.Comment})
	if err != nil {
		writeReviewError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": reviewResponse(item)})
}

func reviewResponse(item domainreviews.Review) map[string]any {
	return map[string]any{
		"id": item.ID, "request_id": item.RequestID, "reviewer_uid": item.ReviewerUID,
		"reviewee_uid": item.RevieweeUID, "reviewer_role": item.ReviewerRole,
		"rating": item.Rating, "comment": item.Comment,
		"created_at": item.CreatedAt, "updated_at": item.UpdatedAt,
	}
}

func validRequestID(w http.ResponseWriter, r *http.Request) bool {
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Solicitação inválida."})
		return false
	}
	return true
}

func writeReviewError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, domainreviews.ErrInvalid):
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Escolha de 1 a 5 estrelas e revise o comentário."})
	case errors.Is(err, domainreviews.ErrNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Solicitação não encontrada."})
	case errors.Is(err, domainreviews.ErrForbidden):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "Você não participa deste atendimento."})
	case errors.Is(err, domainreviews.ErrIncomplete):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "A avaliação fica disponível após a conclusão do serviço."})
	default:
		slog.ErrorContext(r.Context(), "service review failed", "request_id", r.PathValue("id"), "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível salvar a avaliação agora."})
	}
}
