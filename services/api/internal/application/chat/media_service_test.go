package chat

import (
	"bytes"
	"context"
	"io"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type mediaRepositoryFake struct{ created domainchat.MediaAsset }

func (fake *mediaRepositoryFake) CreateMedia(_ context.Context, asset domainchat.MediaAsset) (domainchat.MediaAsset, error) {
	fake.created = asset
	asset.ID = "ca6ab880-a728-47a5-b4d3-005e10932489"
	return asset, nil
}

func (fake *mediaRepositoryFake) GetMedia(context.Context, string, string) (domainchat.MediaAsset, error) {
	return domainchat.MediaAsset{}, nil
}

type mediaStoreFake struct{ saves int }

func (fake *mediaStoreFake) Save(_ context.Context, extension string, content io.Reader, _ int64) (ports.StoredMedia, error) {
	fake.saves++
	data, _ := io.ReadAll(content)
	return ports.StoredMedia{Key: "voice" + extension, ByteSize: int64(len(data))}, nil
}

func (fake *mediaStoreFake) Open(context.Context, string, string) (ports.MediaObject, error) {
	return ports.MediaObject{}, nil
}

func (fake *mediaStoreFake) Delete(context.Context, string) error { return nil }

func TestMediaServiceUploadsValidatedVoiceThroughPorts(t *testing.T) {
	repository := &mediaRepositoryFake{}
	store := &mediaStoreFake{}
	service := NewMediaService(repository, store)

	asset, err := service.UploadVoice(
		context.Background(), "user", "conversation", "audio/mp4; codecs=aac",
		1250, bytes.NewBufferString("audio"),
	)
	if err != nil {
		t.Fatal(err)
	}
	if asset.ID == "" || repository.created.StorageKey != "voice.m4a" || repository.created.ByteSize != 5 {
		t.Fatalf("unexpected persisted asset: %+v", repository.created)
	}
	if store.saves != 1 {
		t.Fatalf("store saves = %d", store.saves)
	}
}

func TestMediaServiceRejectsInvalidVoiceBeforeStorage(t *testing.T) {
	store := &mediaStoreFake{}
	service := NewMediaService(&mediaRepositoryFake{}, store)

	_, err := service.UploadVoice(
		context.Background(), "user", "conversation", "application/octet-stream",
		100, bytes.NewBufferString("audio"),
	)
	if err != domainchat.ErrInvalidMedia || store.saves != 0 {
		t.Fatalf("error=%v saves=%d", err, store.saves)
	}
}
