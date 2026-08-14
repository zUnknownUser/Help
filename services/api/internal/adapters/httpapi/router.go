package httpapi

import (
	"context"
	"net"
	"net/http"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/adapters/realtime"
	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type RequestLimiter interface {
	Allow(key string) bool
}

type ReadinessChecker interface {
	Ping(context.Context) error
}

type RouterDependencies struct {
	PasswordResetRequester     ports.PasswordResetRequester
	PasswordResetLimiter       RequestLimiter
	EmailVerificationRequester ports.EmailVerificationRequester
	EmailVerificationLimiter   RequestLimiter
	TokenVerifier              ports.IDTokenVerifier
	ProfileRegistrar           ports.ProfileRegistrar
	ProfileReader              ports.ProfileReader
	DefaultLocationSaver       ports.DefaultLocationSaver
	NotificationMarker         ports.NotificationMarker
	HomeGetter                 ports.HomeGetter
	CatalogSearcher            ports.CatalogSearcher
	ProviderHomeGetter         ports.ProviderHomeGetter
	ProviderServiceManager     ports.ProviderServiceManager
	DeviceRepository           ports.DeviceRepository
	UserDirectory              ports.UserDirectory
	ChatService                *applicationchat.Service
	RealtimeHub                *realtime.Hub
	ReadinessChecker           ReadinessChecker
	TrustProxyHeaders          bool
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
	mux.Handle(
		"POST /v1/auth/email-verification",
		requireAuth(
			dependencies.TokenVerifier,
			rateLimitAuthenticated(
				dependencies.EmailVerificationLimiter,
				NewEmailVerificationHandler(dependencies.EmailVerificationRequester),
			),
		),
	)
	profileHandler := NewProfileHandler(dependencies.ProfileRegistrar, dependencies.ProfileReader)
	mux.Handle("GET /v1/profile", requireAuth(dependencies.TokenVerifier, profileHandler))
	mux.Handle("POST /v1/profile", requireAuth(dependencies.TokenVerifier, profileHandler))
	mux.Handle(
		"PUT /v1/profile/location",
		requireAuth(dependencies.TokenVerifier, NewLocationHandler(dependencies.DefaultLocationSaver)),
	)
	mux.Handle(
		"POST /v1/notifications/{id}/read",
		requireAuth(dependencies.TokenVerifier, NewNotificationReadHandler(dependencies.NotificationMarker)),
	)
	mux.Handle(
		"GET /v1/home",
		requireAuth(dependencies.TokenVerifier, NewHomeHandler(dependencies.HomeGetter)),
	)
	mux.Handle(
		"GET /v1/services",
		requireAuth(dependencies.TokenVerifier, NewCatalogHandler(dependencies.CatalogSearcher)),
	)
	providerHandler := NewProviderHandler(dependencies.ProviderHomeGetter, dependencies.ProviderServiceManager)
	mux.Handle("GET /v1/provider/home", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.Home)))
	mux.Handle("POST /v1/provider/services", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.CreateService)))
	mux.Handle("PUT /v1/provider/services/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.UpdateService)))
	mux.Handle("PATCH /v1/provider/services/{id}/publication", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.SetPublication)))
	mux.Handle("DELETE /v1/provider/services/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.DeleteService)))
	mux.Handle("PATCH /v1/provider/availability", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.SetAvailability)))
	deviceHandler := NewDeviceHandler(dependencies.DeviceRepository)
	mux.Handle("POST /v1/devices", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(deviceHandler.Register)))
	mux.Handle("DELETE /v1/devices/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(deviceHandler.Disable)))
	chatHandler := NewChatHandler(dependencies.ChatService)
	mux.Handle("POST /v1/chat/conversations/direct", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.DirectConversation)))
	mux.Handle("GET /v1/chat/conversations", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.Conversations)))
	mux.Handle("GET /v1/chat/conversations/{id}/messages", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.Messages)))
	mux.Handle("GET /v1/realtime", requireAuth(dependencies.TokenVerifier, NewRealtimeHandler(dependencies.RealtimeHub, dependencies.ChatService)))
	mux.Handle("GET /v1/users", requireAuth(dependencies.TokenVerifier, NewUserHandler(dependencies.UserDirectory)))
	return securityHeaders(mux)
}

func rateLimitAuthenticated(limiter RequestLimiter, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		identity, ok := authenticatedIdentity(r.Context())
		if !ok || !limiter.Allow(identity.UID) {
			w.Header().Set("Retry-After", "60")
			writeJSON(w, http.StatusTooManyRequests, map[string]string{
				"message": "Muitas tentativas. Aguarde um minuto e tente novamente.",
			})
			return
		}
		next.ServeHTTP(w, r)
	})
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
