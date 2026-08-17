package httpapi

import (
	"errors"
	"mime/multipart"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

const maxProfileUploadBody = 6 << 20

type ProfileMediaHandler struct{ service ports.ProfileMediaService }

func NewProfileMediaHandler(service ports.ProfileMediaService) *ProfileMediaHandler {
	return &ProfileMediaHandler{service: service}
}

func (handler *ProfileMediaHandler) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	file, contentType, ok := profileUpload(w, r)
	if !ok {
		return
	}
	defer file.Close()
	if err := handler.service.UploadAvatar(r.Context(), identity.UID, contentType, file); err != nil {
		handler.writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (handler *ProfileMediaHandler) Avatar(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	handler.serve(w, r, func() (ports.MediaObject, error) {
		return handler.service.OpenAvatar(r.Context(), identity.UID, r.PathValue("uid"))
	})
}

func (handler *ProfileMediaHandler) UploadPortfolio(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	file, contentType, ok := profileUpload(w, r)
	if !ok {
		return
	}
	defer file.Close()
	item, err := handler.service.UploadPortfolio(r.Context(), identity.UID, contentType, r.FormValue("caption"), file)
	if err != nil {
		handler.writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": portfolioItemResponse{
		ID: item.ID, Caption: item.Caption, URL: "/v1/profile/portfolio/" + item.ID,
	}})
}

func (handler *ProfileMediaHandler) Portfolio(w http.ResponseWriter, r *http.Request) {
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		http.NotFound(w, r)
		return
	}
	handler.serve(w, r, func() (ports.MediaObject, error) {
		return handler.service.OpenPortfolio(r.Context(), r.PathValue("id"))
	})
}

func (handler *ProfileMediaHandler) DeletePortfolio(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		http.NotFound(w, r)
		return
	}
	if err := handler.service.DeletePortfolio(r.Context(), identity.UID, r.PathValue("id")); err != nil {
		handler.writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (handler *ProfileMediaHandler) serve(w http.ResponseWriter, r *http.Request, open func() (ports.MediaObject, error)) {
	object, err := open()
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer object.Reader.Close()
	w.Header().Set("Content-Type", object.ContentType)
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.Header().Set("Content-Disposition", "inline")
	http.ServeContent(w, r, "profile-media", object.ModifiedAt, object.Reader)
}

func (handler *ProfileMediaHandler) writeError(w http.ResponseWriter, err error) {
	if errors.Is(err, domainchat.ErrInvalidMedia) || errors.Is(err, domainprofiles.ErrInvalidProfileDetails) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Envie uma imagem JPG, PNG ou WebP de até 5 MB."})
		return
	}
	if errors.Is(err, domainprofiles.ErrProfileNotFound) {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível salvar a imagem agora."})
}

func profileUpload(w http.ResponseWriter, r *http.Request) (multipart.File, string, bool) {
	r.Body = http.MaxBytesReader(w, r.Body, maxProfileUploadBody)
	if err := r.ParseMultipartForm(maxProfileUploadBody); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "A imagem excede o limite de 5 MB."})
		return nil, "", false
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Selecione uma imagem válida."})
		return nil, "", false
	}
	contentType := strings.TrimSpace(header.Header.Get("Content-Type"))
	if contentType == "" || contentType == "application/octet-stream" {
		buffer := make([]byte, 512)
		read, _ := file.Read(buffer)
		contentType = http.DetectContentType(buffer[:read])
		_, _ = file.Seek(0, 0)
	}
	return file, contentType, true
}
