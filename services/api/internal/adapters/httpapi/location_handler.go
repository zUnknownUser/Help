package httpapi

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type LocationHandler struct{ saver ports.DefaultLocationSaver }

func NewLocationHandler(saver ports.DefaultLocationSaver) *LocationHandler {
	return &LocationHandler{saver: saver}
}

func (handler *LocationHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return
	}
	var input struct {
		Label        string  `json:"label"`
		Address      string  `json:"address"`
		PostalCode   string  `json:"postal_code"`
		Street       string  `json:"street"`
		StreetNumber string  `json:"street_number"`
		Complement   string  `json:"complement"`
		District     string  `json:"district"`
		City         string  `json:"city"`
		State        string  `json:"state"`
		Latitude     float64 `json:"latitude"`
		Longitude    float64 `json:"longitude"`
	}
	if err := decodeJSONBody(w, r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Requisição inválida."})
		return
	}
	err := handler.saver.Execute(r.Context(), identity.UID, domainprofiles.Location{
		Label: input.Label, Address: input.Address, PostalCode: input.PostalCode,
		Street: input.Street, StreetNumber: input.StreetNumber, Complement: input.Complement,
		District: input.District, City: input.City, State: input.State,
		Latitude: input.Latitude, Longitude: input.Longitude,
	})
	if errors.Is(err, domainprofiles.ErrInvalidLocation) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Informe um endereço válido."})
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "save location failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"message": "Não foi possível salvar o endereço agora.",
		})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
