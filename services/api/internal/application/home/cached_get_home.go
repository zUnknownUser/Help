package home

import (
	"context"
	"sync"
	"time"

	"golang.org/x/sync/singleflight"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
)

type CachedHome struct {
	source      ports.HomeGetter
	ttl         time.Duration
	loadTimeout time.Duration
	now         func() time.Time
	group       singleflight.Group
	mu          sync.RWMutex
	value       domainhome.Content
	until       time.Time
}

const defaultHomeLoadTimeout = 5 * time.Second

func NewCachedHome(source ports.HomeGetter, ttl time.Duration) *CachedHome {
	return newCachedHome(source, ttl, time.Now)
}

func newCachedHome(source ports.HomeGetter, ttl time.Duration, now func() time.Time) *CachedHome {
	return &CachedHome{
		source: source, ttl: ttl, loadTimeout: defaultHomeLoadTimeout, now: now,
	}
}

func (c *CachedHome) Execute(ctx context.Context) (domainhome.Content, error) {
	if value, ok := c.current(); ok {
		return value, nil
	}
	resultChannel := c.group.DoChan("home", func() (any, error) {
		if value, ok := c.current(); ok {
			return value, nil
		}
		loadCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), c.loadTimeout)
		defer cancel()
		value, err := c.source.Execute(loadCtx)
		if err != nil {
			return domainhome.Content{}, err
		}
		c.mu.Lock()
		c.value = value
		c.until = c.now().Add(c.ttl)
		c.mu.Unlock()
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

func (c *CachedHome) current() (domainhome.Content, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.value, !c.until.IsZero() && c.now().Before(c.until)
}
