package chat

import (
	"context"
	"io"
	"strings"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

const MaxVoiceBytes int64 = 10 << 20

type MediaService struct {
	repository ports.ChatMediaRepository
	store      ports.ChatMediaStore
}

func NewMediaService(repository ports.ChatMediaRepository, store ports.ChatMediaStore) *MediaService {
	return &MediaService{repository: repository, store: store}
}

func (service *MediaService) UploadVoice(
	ctx context.Context,
	userID, conversationID, contentType string,
	durationMS int,
	content io.Reader,
) (domainchat.MediaAsset, error) {
	contentType = strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))
	extension, supported := domainchat.SupportedVoiceContentTypes[contentType]
	if !supported || durationMS < 250 || durationMS > 300_000 {
		return domainchat.MediaAsset{}, domainchat.ErrInvalidMedia
	}
	stored, err := service.store.Save(ctx, extension, content, MaxVoiceBytes)
	if err != nil {
		return domainchat.MediaAsset{}, err
	}
	asset, err := service.repository.CreateMedia(ctx, domainchat.MediaAsset{
		Media: domainchat.Media{
			ContentType: contentType,
			ByteSize:    stored.ByteSize,
			DurationMS:  durationMS,
		},
		ConversationID: conversationID,
		OwnerUID:       userID,
		StorageKey:     stored.Key,
	})
	if err != nil {
		_ = service.store.Delete(context.Background(), stored.Key)
		return domainchat.MediaAsset{}, err
	}
	return asset, nil
}

func (service *MediaService) Open(
	ctx context.Context,
	userID, mediaID string,
) (domainchat.MediaAsset, ports.MediaObject, error) {
	if _, err := uuid.Parse(mediaID); err != nil {
		return domainchat.MediaAsset{}, ports.MediaObject{}, domainchat.ErrMediaNotFound
	}
	asset, err := service.repository.GetMedia(ctx, userID, mediaID)
	if err != nil {
		return domainchat.MediaAsset{}, ports.MediaObject{}, err
	}
	object, err := service.store.Open(ctx, asset.StorageKey, asset.ContentType)
	return asset, object, err
}
