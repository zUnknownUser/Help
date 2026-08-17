package httpapi

import (
	"net/http"

	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
)

type ICEConfigHandler struct {
	service *applicationchat.ICEConfigService
}

func NewICEConfigHandler(service *applicationchat.ICEConfigService) *ICEConfigHandler {
	return &ICEConfigHandler{service: service}
}

func (handler *ICEConfigHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	writeJSON(w, http.StatusOK, map[string]any{"data": handler.service.Issue(identity.UID)})
}
