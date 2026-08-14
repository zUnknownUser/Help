package home

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
)

type countingHomeGetter struct {
	mu    sync.Mutex
	calls int
}

type cancellableHomeGetter struct {
	started chan struct{}
	release chan struct{}
	once    sync.Once
	calls   atomic.Int32
}

func (g *cancellableHomeGetter) Execute(ctx context.Context) (domainhome.Content, error) {
	g.calls.Add(1)
	g.once.Do(func() { close(g.started) })
	select {
	case <-g.release:
		return domainhome.Content{}, nil
	case <-ctx.Done():
		return domainhome.Content{}, ctx.Err()
	}
}

func (g *countingHomeGetter) Execute(context.Context) (domainhome.Content, error) {
	g.mu.Lock()
	g.calls++
	g.mu.Unlock()
	return domainhome.Content{}, nil
}

func TestCachedHomeSharesAggregateWithinTTL(t *testing.T) {
	t.Parallel()

	now := time.Date(2026, 8, 14, 12, 0, 0, 0, time.UTC)
	source := &countingHomeGetter{}
	cached := newCachedHome(source, time.Minute, func() time.Time { return now })

	for range 3 {
		if _, err := cached.Execute(context.Background()); err != nil {
			t.Fatal(err)
		}
	}
	if source.calls != 1 {
		t.Fatalf("source calls = %d; esperado 1", source.calls)
	}

	now = now.Add(time.Minute)
	if _, err := cached.Execute(context.Background()); err != nil {
		t.Fatal(err)
	}
	if source.calls != 2 {
		t.Fatalf("source calls após expirar = %d; esperado 2", source.calls)
	}
}

func TestCachedHomeCoalescesConcurrentMisses(t *testing.T) {
	t.Parallel()

	source := &countingHomeGetter{}
	cached := NewCachedHome(source, time.Minute)
	var group sync.WaitGroup
	for range 20 {
		group.Add(1)
		go func() {
			defer group.Done()
			_, _ = cached.Execute(context.Background())
		}()
	}
	group.Wait()

	if source.calls != 1 {
		t.Fatalf("source calls concorrentes = %d; esperado 1", source.calls)
	}
}

func TestCachedHomeDoesNotLetFirstCallerCancellationPoisonSharedLoad(t *testing.T) {
	t.Parallel()

	source := &cancellableHomeGetter{
		started: make(chan struct{}),
		release: make(chan struct{}),
	}
	cached := NewCachedHome(source, time.Minute)
	firstCtx, cancelFirst := context.WithCancel(context.Background())
	firstResult := make(chan error, 1)
	go func() {
		_, err := cached.Execute(firstCtx)
		firstResult <- err
	}()

	<-source.started
	cancelFirst()
	if err := <-firstResult; err != context.Canceled {
		t.Fatalf("primeiro erro = %v; esperado context.Canceled", err)
	}

	secondResult := make(chan error, 1)
	go func() {
		_, err := cached.Execute(context.Background())
		secondResult <- err
	}()
	close(source.release)
	if err := <-secondResult; err != nil {
		t.Fatalf("segunda chamada herdou cancelamento: %v", err)
	}
	if calls := source.calls.Load(); calls != 1 {
		t.Fatalf("source calls = %d; esperado 1 carga compartilhada", calls)
	}
}

func BenchmarkCachedHomeHit(b *testing.B) {
	source := &countingHomeGetter{}
	cached := NewCachedHome(source, time.Minute)
	if _, err := cached.Execute(context.Background()); err != nil {
		b.Fatal(err)
	}

	b.ReportAllocs()
	b.RunParallel(func(parallel *testing.PB) {
		for parallel.Next() {
			if _, err := cached.Execute(context.Background()); err != nil {
				b.Fatal(err)
			}
		}
	})
}
