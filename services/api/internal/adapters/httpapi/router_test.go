package httpapi_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type denyingLimiter struct{}

func (denyingLimiter) Allow(string) bool { return false }

type capturingLimiter struct {
	mu  sync.Mutex
	key string
}

func (l *capturingLimiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.key = key
	return true
}

type readinessStub struct{ err error }

func (stub readinessStub) Ping(context.Context) error { return stub.err }

type tokenVerifierStub struct {
	identity ports.AuthenticatedIdentity
	err      error
}

func (stub tokenVerifierStub) VerifyIDToken(
	context.Context,
	string,
) (ports.AuthenticatedIdentity, error) {
	return stub.identity, stub.err
}

type emailVerificationRequesterSpy struct {
	email domainauth.Email
	calls int
}

func (spy *emailVerificationRequesterSpy) Execute(_ context.Context, email domainauth.Email) error {
	spy.calls++
	spy.email = email
	return nil
}

type noopRequester struct{}

func (noopRequester) Execute(context.Context, domainauth.Email) error { return nil }

func TestRouterHealthCheck(t *testing.T) {
	t.Parallel()

	router := newTestRouter(noopRequester{}, httpapi.NewMemoryRateLimiter(5, time.Minute))
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	res := httptest.NewRecorder()

	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusOK)
	}
	if got := res.Header().Get("X-Content-Type-Options"); got != "nosniff" {
		t.Fatalf("X-Content-Type-Options = %q", got)
	}
}

func TestRouterRateLimitsPasswordReset(t *testing.T) {
	t.Parallel()

	router := newTestRouter(noopRequester{}, denyingLimiter{})
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/password-reset", nil)
	req.RemoteAddr = "203.0.113.9:4567"
	res := httptest.NewRecorder()

	router.ServeHTTP(res, req)

	if res.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusTooManyRequests)
	}
}

func TestRouterIgnoresForwardedIPFromUntrustedClients(t *testing.T) {
	t.Parallel()

	limiter := &capturingLimiter{}
	router := newTestRouter(noopRequester{}, limiter)
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/password-reset", nil)
	req.RemoteAddr = "203.0.113.9:4567"
	req.Header.Set("X-Forwarded-For", "198.51.100.20")

	router.ServeHTTP(httptest.NewRecorder(), req)

	if limiter.key != "203.0.113.9" {
		t.Fatalf("chave do rate limit = %q; esperado IP remoto", limiter.key)
	}
}

func TestRouterUsesValidForwardedIPWhenProxyIsTrusted(t *testing.T) {
	t.Parallel()

	limiter := &capturingLimiter{}
	router := httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester: noopRequester{},
		PasswordResetLimiter:   limiter,
		HomeGetter:             homeGetterStub{},
		ReadinessChecker:       readinessStub{},
		TrustProxyHeaders:      true,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/password-reset", nil)
	req.RemoteAddr = "203.0.113.9:4567"
	req.Header.Set("X-Forwarded-For", "198.51.100.20")

	router.ServeHTTP(httptest.NewRecorder(), req)

	if limiter.key != "198.51.100.20" {
		t.Fatalf("chave do rate limit = %q; esperado IP encaminhado", limiter.key)
	}
}

func TestRouterReadinessReflectsDatabaseState(t *testing.T) {
	t.Parallel()

	for name, test := range map[string]struct {
		err        error
		wantStatus int
	}{
		"ready":       {wantStatus: http.StatusOK},
		"unavailable": {err: context.DeadlineExceeded, wantStatus: http.StatusServiceUnavailable},
	} {
		t.Run(name, func(t *testing.T) {
			router := httpapi.NewRouter(httpapi.RouterDependencies{
				PasswordResetRequester: noopRequester{},
				PasswordResetLimiter:   httpapi.NewMemoryRateLimiter(5, time.Minute),
				HomeGetter:             homeGetterStub{},
				ReadinessChecker:       readinessStub{err: test.err},
			})
			res := httptest.NewRecorder()
			router.ServeHTTP(res, httptest.NewRequest(http.MethodGet, "/ready", nil))
			if res.Code != test.wantStatus {
				t.Fatalf("status = %d; esperado %d", res.Code, test.wantStatus)
			}
		})
	}
}

func TestRouterProtectsAndSendsEmailVerification(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("user@example.com")
	requester := &emailVerificationRequesterSpy{}
	router := httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester:     noopRequester{},
		PasswordResetLimiter:       httpapi.NewMemoryRateLimiter(5, time.Minute),
		EmailVerificationRequester: requester,
		EmailVerificationLimiter:   httpapi.NewMemoryRateLimiter(3, time.Minute),
		TokenVerifier: tokenVerifierStub{identity: ports.AuthenticatedIdentity{
			UID: "firebase-uid", Email: email,
		}},
		HomeGetter:       homeGetterStub{},
		ReadinessChecker: readinessStub{},
	})

	unauthorized := httptest.NewRecorder()
	router.ServeHTTP(
		unauthorized,
		httptest.NewRequest(http.MethodPost, "/v1/auth/email-verification", nil),
	)
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("sem token status = %d; esperado 401", unauthorized.Code)
	}

	request := httptest.NewRequest(http.MethodPost, "/v1/auth/email-verification", nil)
	request.Header.Set("Authorization", "Bearer valid-token")
	accepted := httptest.NewRecorder()
	router.ServeHTTP(accepted, request)
	if accepted.Code != http.StatusAccepted {
		t.Fatalf("com token status = %d; esperado 202", accepted.Code)
	}
	if requester.calls != 1 || requester.email != email {
		t.Fatalf("requester recebeu e-mail incorreto: %q", requester.email)
	}
}

func newTestRouter(requester noopRequester, limiter httpapi.RequestLimiter) http.Handler {
	return httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester:     requester,
		PasswordResetLimiter:       limiter,
		EmailVerificationRequester: &emailVerificationRequesterSpy{},
		EmailVerificationLimiter:   httpapi.NewMemoryRateLimiter(3, time.Minute),
		TokenVerifier:              tokenVerifierStub{},
		HomeGetter:                 homeGetterStub{},
		ReadinessChecker:           readinessStub{},
	})
}
