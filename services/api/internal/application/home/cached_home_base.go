package home

import (
	"context"
	"sync"
	"time"

	"golang.org/x/sync/singleflight"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
)

const defaultHomeBaseLoadTimeout = 5 * time.Second

type CachedHomeBase struct {
	source ports.HomeBaseGetter
	ttl    time.Duration
	group  singleflight.Group
	mu     sync.RWMutex
	value  domainhome.Content
	until  time.Time
}

func NewCachedHomeBase(source ports.HomeBaseGetter, ttl time.Duration) *CachedHomeBase {
	return &CachedHomeBase{source: source, ttl: ttl}
}

func (cache *CachedHomeBase) ExecuteBase(ctx context.Context) (domainhome.Content, error) {
	if value, ok := cache.current(); ok {
		return value, nil
	}
	resultChannel := cache.group.DoChan("home-base", func() (any, error) {
		if value, ok := cache.current(); ok {
			return value, nil
		}
		loadCtx, cancel := context.WithTimeout(
			context.WithoutCancel(ctx), defaultHomeBaseLoadTimeout,
		)
		defer cancel()
		value, err := cache.source.ExecuteBase(loadCtx)
		if err != nil {
			return domainhome.Content{}, err
		}
		cache.mu.Lock()
		cache.value = value
		cache.until = time.Now().Add(cache.ttl)
		cache.mu.Unlock()
		return value, nil
	})
	select {
	case <-ctx.Done():
		return domainhome.Content{}, ctx.Err()
	case result := <-resultChannel:
		if result.Err != nil {
			return domainhome.Content{}, result.Err
		}
		return result.Val.(domainhome.Content), nil
	}
}

func (cache *CachedHomeBase) current() (domainhome.Content, bool) {
	cache.mu.RLock()
	defer cache.mu.RUnlock()
	return cache.value, !cache.until.IsZero() && time.Now().Before(cache.until)
}
