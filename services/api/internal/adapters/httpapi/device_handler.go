package httpapi

import (
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/devices"
)

type DeviceHandler struct{ repository ports.DeviceRepository }

func NewDeviceHandler(repository ports.DeviceRepository) *DeviceHandler {
	return &DeviceHandler{repository: repository}
}

func (handler *DeviceHandler) Register(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	var request struct {
		InstallationID string `json:"installation_id"`
		Platform       string `json:"platform"`
		FCMToken       string `json:"fcm_token"`
	}
	if decodeJSONBody(w, r, &request) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Requisição inválida."})
		return
	}
	request.Platform = strings.ToLower(strings.TrimSpace(request.Platform))
	request.FCMToken = strings.TrimSpace(request.FCMToken)
	if _, err := uuid.Parse(request.InstallationID); err != nil ||
		(request.Platform != "android" && request.Platform != "ios") ||
		request.FCMToken == "" || len(request.FCMToken) > 4096 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Dispositivo inválido."})
		return
	}
	err := handler.repository.Upsert(r.Context(), devices.Installation{
		ID: request.InstallationID, UserID: identity.UID,
		Platform: request.Platform, Token: request.FCMToken,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"message": "Não foi possível registrar o dispositivo."})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (handler *DeviceHandler) Disable(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	installationID := r.PathValue("id")
	if _, err := uuid.Parse(installationID); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Dispositivo inválido."})
		return
	}
	if err := handler.repository.Disable(r.Context(), identity.UID, installationID); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"message": "Não foi possível remover o dispositivo."})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
