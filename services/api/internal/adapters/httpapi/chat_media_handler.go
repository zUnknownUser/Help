package httpapi

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type ChatMediaHandler struct{ service *applicationchat.MediaService }

func NewChatMediaHandler(service *applicationchat.MediaService) *ChatMediaHandler {
	return &ChatMediaHandler{service: service}
}

func (handler *ChatMediaHandler) UploadVoice(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	durationMS, err := strconv.Atoi(r.Header.Get("X-Voice-Duration-Ms"))
	if err != nil {
		writeChatError(w, domainchat.ErrInvalidMedia)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, applicationchat.MaxVoiceBytes+1)
	asset, err := handler.service.UploadVoice(
		r.Context(), identity.UID, r.PathValue("id"), r.Header.Get("Content-Type"),
		durationMS, r.Body,
	)
	if err != nil {
		writeChatError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": asset.Media})
}

func (handler *ChatMediaHandler) Serve(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	asset, object, err := handler.service.Open(r.Context(), identity.UID, r.PathValue("id"))
	if err != nil {
		writeChatError(w, err)
		return
	}
	defer object.Reader.Close()
	extension := domainchat.SupportedVoiceContentTypes[strings.ToLower(object.ContentType)]
	w.Header().Set("Content-Type", object.ContentType)
	w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="%s%s"`, asset.ID, extension))
	w.Header().Set("Cache-Control", "private, max-age=86400")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	http.ServeContent(w, r, asset.ID+extension, object.ModifiedAt, object.Reader)
}
