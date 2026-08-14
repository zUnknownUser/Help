package httpapi

import (
	"testing"
	"time"
)

func TestMemoryRateLimiterLimitsRequestsWithinWindow(t *testing.T) {
	t.Parallel()

	now := time.Date(2026, 8, 14, 12, 0, 0, 0, time.UTC)
	limiter := newMemoryRateLimiter(2, time.Minute, func() time.Time { return now })

	if !limiter.Allow("client-a") || !limiter.Allow("client-a") {
		t.Fatal("as duas primeiras requisições deveriam ser aceitas")
	}
	if limiter.Allow("client-a") {
		t.Fatal("a terceira requisição deveria ser limitada")
	}
	if !limiter.Allow("client-b") {
		t.Fatal("clientes diferentes não devem compartilhar o limite")
	}
}

func TestMemoryRateLimiterResetsAfterWindow(t *testing.T) {
	t.Parallel()

	now := time.Date(2026, 8, 14, 12, 0, 0, 0, time.UTC)
	limiter := newMemoryRateLimiter(1, time.Minute, func() time.Time { return now })

	if !limiter.Allow("client") || limiter.Allow("client") {
		t.Fatal("limite inicial inválido")
	}
	now = now.Add(time.Minute)
	if !limiter.Allow("client") {
		t.Fatal("o limite deveria reiniciar após a janela")
	}
}
