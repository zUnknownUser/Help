package home

import (
	"context"
	"sync"
	"testing"
	"time"

	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
)

type countingBaseGetter struct {
	mu    sync.Mutex
	calls int
}

func (getter *countingBaseGetter) ExecuteBase(context.Context) (domainhome.Content, error) {
	getter.mu.Lock()
	getter.calls++
	getter.mu.Unlock()
	return domainhome.Content{}, nil
}

func TestCachedHomeBaseCoalescesConcurrentCatalogLoads(t *testing.T) {
	t.Parallel()

	source := &countingBaseGetter{}
	cache := NewCachedHomeBase(source, time.Minute)
	var wait sync.WaitGroup
	for range 20 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			_, _ = cache.ExecuteBase(context.Background())
		}()
	}
	wait.Wait()
	if source.calls != 1 {
		t.Fatalf("cargas do catálogo = %d; esperado 1", source.calls)
	}
}
