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
	ProfileUpdater             ports.ProfileUpdater
	ProfileEmailSynchronizer   ports.ProfileEmailSynchronizer
	ProfileMediaService        ports.ProfileMediaService
	DefaultLocationSaver       ports.DefaultLocationSaver
	NotificationMarker         ports.NotificationMarker
	HomeGetter                 ports.HomeGetter
	CatalogSearcher            ports.CatalogSearcher
	ServiceDetailsGetter       ports.ServiceDetailsGetter
	ServiceRequestCreator      ports.ServiceRequestCreator
	ServiceRequestLifecycle    ports.ServiceRequestLifecycle
	ReviewService              ports.ReviewService
	ProviderScheduleManager    ports.ProviderScheduleManager
	ServiceAvailability        ports.ServiceAvailability
	ProviderHomeGetter         ports.ProviderHomeGetter
	ProviderServiceManager     ports.ProviderServiceManager
	DeviceRepository           ports.DeviceRepository
	UserDirectory              ports.UserDirectory
	ChatService                *applicationchat.Service
	ICEConfigService           *applicationchat.ICEConfigService
	ChatMediaService           *applicationchat.MediaService
	RealtimeHub                *realtime.Hub
	HelpNowService             ports.HelpNowService
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
	profileHandler := NewProfileHandler(dependencies.ProfileRegistrar, dependencies.ProfileReader, dependencies.ProfileUpdater, dependencies.ProfileEmailSynchronizer)
	mux.Handle("GET /v1/profile", requireAuth(dependencies.TokenVerifier, profileHandler))
	mux.Handle("POST /v1/profile", requireAuth(dependencies.TokenVerifier, profileHandler))
	mux.Handle("PUT /v1/profile", requireAuth(dependencies.TokenVerifier, profileHandler))
	mux.Handle("POST /v1/profile/email/sync", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(profileHandler.SyncEmail)))
	profileMediaHandler := NewProfileMediaHandler(dependencies.ProfileMediaService)
	mux.Handle("PUT /v1/profile/avatar", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(profileMediaHandler.UploadAvatar)))
	mux.Handle("GET /v1/profile/avatar/{uid}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(profileMediaHandler.Avatar)))
	mux.Handle("POST /v1/profile/portfolio", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(profileMediaHandler.UploadPortfolio)))
	mux.HandleFunc("GET /v1/profile/portfolio/{id}", profileMediaHandler.Portfolio)
	mux.Handle("DELETE /v1/profile/portfolio/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(profileMediaHandler.DeletePortfolio)))
	mux.Handle(
		"PUT /v1/profile/location",
		requireAuth(dependencies.TokenVerifier, NewLocationHandler(dependencies.DefaultLocationSaver)),
	)
	mux.Handle(
		"POST /v1/notifications/{id}/read",
		requireAuth(dependencies.TokenVerifier, NewNotificationReadHandler(dependencies.NotificationMarker)),
	)
	mux.Handle(
		"POST /v1/notifications/read-all",
		requireAuth(dependencies.TokenVerifier, http.HandlerFunc(NewNotificationReadHandler(dependencies.NotificationMarker).MarkAll)),
	)
	mux.Handle(
		"GET /v1/home",
		requireAuth(dependencies.TokenVerifier, NewHomeHandler(dependencies.HomeGetter)),
	)
	mux.Handle(
		"GET /v1/services",
		requireAuth(dependencies.TokenVerifier, NewCatalogHandler(dependencies.CatalogSearcher)),
	)
	serviceHandler := NewServiceDetailsHandler(dependencies.ServiceDetailsGetter, dependencies.ServiceRequestCreator)
	mux.Handle("GET /v1/services/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(serviceHandler.Details)))
	mux.Handle("POST /v1/services/{id}/requests", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(serviceHandler.CreateRequest)))
	scheduleHandler := NewScheduleHandler(dependencies.ProviderScheduleManager, dependencies.ServiceAvailability)
	mux.Handle("GET /v1/services/{id}/available-slots", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(scheduleHandler.Slots)))
	requestHandler := NewServiceRequestHandler(dependencies.ServiceRequestLifecycle)
	mux.Handle("GET /v1/service-requests", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(requestHandler.List)))
	mux.Handle("GET /v1/provider/agenda", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(requestHandler.Agenda)))
	mux.Handle("GET /v1/service-requests/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(requestHandler.Details)))
	mux.Handle("POST /v1/service-requests/{id}/transitions", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(requestHandler.Transition)))
	mux.Handle("POST /v1/service-requests/{id}/reschedule", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(requestHandler.Reschedule)))
	reviewHandler := NewReviewHandler(dependencies.ReviewService)
	mux.Handle("GET /v1/service-requests/{id}/reviews", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(reviewHandler.List)))
	mux.Handle("PUT /v1/service-requests/{id}/reviews/mine", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(reviewHandler.Create)))
	providerHandler := NewProviderHandler(dependencies.ProviderHomeGetter, dependencies.ProviderServiceManager)
	mux.Handle("GET /v1/provider/home", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.Home)))
	mux.Handle("POST /v1/provider/services", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.CreateService)))
	mux.Handle("PUT /v1/provider/services/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.UpdateService)))
	mux.Handle("PATCH /v1/provider/services/{id}/publication", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.SetPublication)))
	mux.Handle("DELETE /v1/provider/services/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.DeleteService)))
	mux.Handle("PATCH /v1/provider/availability", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(providerHandler.SetAvailability)))
	mux.Handle("GET /v1/provider/schedule", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(scheduleHandler.Get)))
	mux.Handle("PUT /v1/provider/schedule", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(scheduleHandler.Replace)))
	mux.Handle("POST /v1/provider/schedule/blocks", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(scheduleHandler.AddBlock)))
	mux.Handle("DELETE /v1/provider/schedule/blocks/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(scheduleHandler.DeleteBlock)))
	deviceHandler := NewDeviceHandler(dependencies.DeviceRepository)
	mux.Handle("POST /v1/devices", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(deviceHandler.Register)))
	mux.Handle("DELETE /v1/devices/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(deviceHandler.Disable)))
	helpNowHandler := NewHelpNowHandler(dependencies.HelpNowService)
	mux.Handle("POST /v1/help-now/requests", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.Create)))
	mux.Handle("GET /v1/help-now/requests/active", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.Active)))
	mux.Handle("POST /v1/help-now/requests/{id}/cancel", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.Cancel)))
	mux.Handle("GET /v1/help-now/provider/availability", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.Availability)))
	mux.Handle("PUT /v1/help-now/provider/availability", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.SetAvailability)))
	mux.Handle("GET /v1/help-now/provider/offers", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.Offers)))
	mux.Handle("POST /v1/help-now/provider/offers/{id}/responses", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(helpNowHandler.Respond)))
	chatHandler := NewChatHandler(dependencies.ChatService)
	mux.Handle("POST /v1/chat/conversations/direct", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.DirectConversation)))
	mux.Handle("GET /v1/chat/conversations", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.Conversations)))
	mux.Handle("POST /v1/chat/conversations/{id}/decision", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.DecideConversation)))
	mux.Handle("GET /v1/chat/conversations/{id}/messages", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(chatHandler.Messages)))
	mediaHandler := NewChatMediaHandler(dependencies.ChatMediaService)
	mux.Handle("POST /v1/chat/conversations/{id}/voice-media", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(mediaHandler.UploadVoice)))
	mux.Handle("GET /v1/chat/media/{id}", requireAuth(dependencies.TokenVerifier, http.HandlerFunc(mediaHandler.Serve)))
	mux.Handle("GET /v1/realtime", requireAuth(dependencies.TokenVerifier, NewRealtimeHandler(dependencies.RealtimeHub, dependencies.ChatService)))
	mux.Handle("GET /v1/realtime/ice-config", requireAuth(dependencies.TokenVerifier, NewICEConfigHandler(dependencies.ICEConfigService)))
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
