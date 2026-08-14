package httpapi

import (
	"context"
	"net"
	"net/http"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type RequestLimiter interface {
	Allow(key string) bool
}

type ReadinessChecker interface {
	Ping(context.Context) error
}

type RouterDependencies struct {
	PasswordResetRequester ports.PasswordResetRequester
	PasswordResetLimiter   RequestLimiter
	HomeGetter             ports.HomeGetter
	ReadinessChecker       ReadinessChecker
	TrustProxyHeaders      bool
}

func NewRouter(dependencies RouterDependencies) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.Handle("GET /ready", NewReadinessHandler(dependencies.ReadinessChecker))
	mux.Handle(
		"POST /v1/auth/password-reset",
		rateLimit(
			dependencies.PasswordResetLimiter,
			dependencies.TrustProxyHeaders,
			NewPasswordResetHandler(dependencies.PasswordResetRequester),
		),
	)
	mux.Handle("GET /v1/home", NewHomeHandler(dependencies.HomeGetter))
	return securityHeaders(mux)
}

func rateLimit(limiter RequestLimiter, trustProxyHeaders bool, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !limiter.Allow(clientIP(r, trustProxyHeaders)) {
			w.Header().Set("Retry-After", "60")
			writeJSON(w, http.StatusTooManyRequests, map[string]string{
				"message": "Muitas tentativas. Aguarde um minuto e tente novamente.",
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

func clientIP(r *http.Request, trustProxyHeaders bool) string {
	if trustProxyHeaders {
		forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0])
		if net.ParseIP(forwarded) != nil {
			return forwarded
		}
	}
	return remoteIP(r.RemoteAddr)
}

func remoteIP(address string) string {
	host, _, err := net.SplitHostPort(address)
	if err == nil {
		return host
	}
	return address
}
