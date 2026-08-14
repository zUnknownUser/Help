package httpapi

import (
	"sync"
	"time"
)

type requestWindow struct {
	startedAt time.Time
	count     int
}

type MemoryRateLimiter struct {
	mu          sync.Mutex
	limit       int
	window      time.Duration
	now         func() time.Time
	clients     map[string]requestWindow
	lastCleanup time.Time
}

func NewMemoryRateLimiter(limit int, window time.Duration) *MemoryRateLimiter {
	return newMemoryRateLimiter(limit, window, time.Now)
}

func newMemoryRateLimiter(limit int, window time.Duration, now func() time.Time) *MemoryRateLimiter {
	return &MemoryRateLimiter{
		limit:   limit,
		window:  window,
		now:     now,
		clients: make(map[string]requestWindow),
	}
}

func (l *MemoryRateLimiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	if l.lastCleanup.IsZero() || now.Sub(l.lastCleanup) >= l.window {
		for client, current := range l.clients {
			if now.Sub(current.startedAt) >= l.window {
				delete(l.clients, client)
			}
		}
		l.lastCleanup = now
	}
	current, exists := l.clients[key]
	if !exists || now.Sub(current.startedAt) >= l.window {
		l.clients[key] = requestWindow{startedAt: now, count: 1}
		return true
	}
	if current.count >= l.limit {
		return false
	}
	current.count++
	l.clients[key] = current
	return true
}
