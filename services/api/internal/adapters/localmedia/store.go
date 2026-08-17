package localmedia

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type Store struct{ directory string }

func NewStore(directory string) (*Store, error) {
	directory, err := filepath.Abs(directory)
	if err != nil {
		return nil, fmt.Errorf("resolve chat media directory: %w", err)
	}
	if err := os.MkdirAll(directory, 0o750); err != nil {
		return nil, fmt.Errorf("create chat media directory: %w", err)
	}
	return &Store{directory: directory}, nil
}

func (store *Store) Save(
	ctx context.Context,
	extension string,
	content io.Reader,
	maxBytes int64,
) (ports.StoredMedia, error) {
	if !strings.HasPrefix(extension, ".") || strings.ContainsAny(extension, `/\\`) {
		return ports.StoredMedia{}, domainchat.ErrInvalidMedia
	}
	temporary, err := os.CreateTemp(store.directory, ".upload-*")
	if err != nil {
		return ports.StoredMedia{}, fmt.Errorf("create media upload: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	written, copyErr := io.Copy(temporary, io.LimitReader(content, maxBytes+1))
	closeErr := temporary.Close()
	if copyErr != nil || closeErr != nil {
		return ports.StoredMedia{}, fmt.Errorf("write media upload: %w", errors.Join(copyErr, closeErr))
	}
	if err := ctx.Err(); err != nil {
		return ports.StoredMedia{}, err
	}
	if written < 1 || written > maxBytes {
		return ports.StoredMedia{}, domainchat.ErrInvalidMedia
	}
	key := uuid.NewString() + extension
	if err := os.Rename(temporaryPath, store.path(key)); err != nil {
		return ports.StoredMedia{}, fmt.Errorf("commit media upload: %w", err)
	}
	return ports.StoredMedia{Key: key, ByteSize: written}, nil
}

func (store *Store) Open(_ context.Context, key, contentType string) (ports.MediaObject, error) {
	file, err := os.Open(store.path(key))
	if errors.Is(err, os.ErrNotExist) {
		return ports.MediaObject{}, domainchat.ErrMediaNotFound
	}
	if err != nil {
		return ports.MediaObject{}, fmt.Errorf("open media: %w", err)
	}
	info, err := file.Stat()
	if err != nil {
		_ = file.Close()
		return ports.MediaObject{}, fmt.Errorf("stat media: %w", err)
	}
	return ports.MediaObject{
		Reader: file, ContentType: contentType, ByteSize: info.Size(), ModifiedAt: info.ModTime(),
	}, nil
}

func (store *Store) Delete(_ context.Context, key string) error {
	err := os.Remove(store.path(key))
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

func (store *Store) path(key string) string {
	return filepath.Join(store.directory, filepath.Base(key))
}
