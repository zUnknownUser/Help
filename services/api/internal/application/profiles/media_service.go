package profiles

import (
	"context"
	"io"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

const maxProfileImageBytes int64 = 5 << 20

var profileImageExtensions = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

type MediaService struct {
	repository ports.ProfileMediaRepository
	store      ports.ChatMediaStore
}

func NewMediaService(repository ports.ProfileMediaRepository, store ports.ChatMediaStore) *MediaService {
	return &MediaService{repository: repository, store: store}
}

func (service *MediaService) UploadAvatar(ctx context.Context, uid, contentType string, content io.Reader) error {
	stored, normalized, err := service.save(ctx, contentType, content)
	if err != nil {
		return err
	}
	oldKey, err := service.repository.SetAvatar(ctx, uid, stored.Key, normalized)
	if err != nil {
		_ = service.store.Delete(context.Background(), stored.Key)
		return err
	}
	if oldKey != "" && oldKey != stored.Key {
		_ = service.store.Delete(context.Background(), oldKey)
	}
	return nil
}

func (service *MediaService) OpenAvatar(ctx context.Context, viewerUID, targetUID string) (ports.MediaObject, error) {
	media, err := service.repository.GetAvatar(ctx, viewerUID, targetUID)
	if err != nil {
		return ports.MediaObject{}, err
	}
	return service.store.Open(ctx, media.StorageKey, media.ContentType)
}

func (service *MediaService) UploadPortfolio(
	ctx context.Context, uid, contentType, caption string, content io.Reader,
) (domainprofiles.PortfolioItem, error) {
	caption = strings.TrimSpace(caption)
	if len([]rune(caption)) > 120 {
		return domainprofiles.PortfolioItem{}, domainprofiles.ErrInvalidProfileDetails
	}
	stored, normalized, err := service.save(ctx, contentType, content)
	if err != nil {
		return domainprofiles.PortfolioItem{}, err
	}
	item, err := service.repository.AddPortfolio(ctx, uid, stored.Key, normalized, caption)
	if err != nil {
		_ = service.store.Delete(context.Background(), stored.Key)
	}
	return item, err
}

func (service *MediaService) OpenPortfolio(ctx context.Context, id string) (ports.MediaObject, error) {
	media, err := service.repository.GetPortfolio(ctx, id)
	if err != nil {
		return ports.MediaObject{}, err
	}
	return service.store.Open(ctx, media.StorageKey, media.ContentType)
}

func (service *MediaService) DeletePortfolio(ctx context.Context, uid, id string) error {
	key, err := service.repository.DeletePortfolio(ctx, uid, id)
	if err != nil {
		return err
	}
	return service.store.Delete(ctx, key)
}

func (service *MediaService) save(ctx context.Context, contentType string, content io.Reader) (ports.StoredMedia, string, error) {
	normalized := strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))
	extension, ok := profileImageExtensions[normalized]
	if !ok {
		return ports.StoredMedia{}, "", domainchat.ErrInvalidMedia
	}
	stored, err := service.store.Save(ctx, extension, content, maxProfileImageBytes)
	return stored, normalized, err
}
