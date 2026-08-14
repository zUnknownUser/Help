package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	firebase "firebase.google.com/go/v4"

	"github.com/vendlydigital/help/services/api/internal/adapters/firebaseauth"
	"github.com/vendlydigital/help/services/api/internal/adapters/firebasepush"
	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/adapters/mailersend"
	postgrescatalog "github.com/vendlydigital/help/services/api/internal/adapters/postgres/catalog"
	postgrescategories "github.com/vendlydigital/help/services/api/internal/adapters/postgres/categories"
	postgreschat "github.com/vendlydigital/help/services/api/internal/adapters/postgres/chat"
	postgresdevices "github.com/vendlydigital/help/services/api/internal/adapters/postgres/devices"
	postgreshome "github.com/vendlydigital/help/services/api/internal/adapters/postgres/home"
	postgresnotifications "github.com/vendlydigital/help/services/api/internal/adapters/postgres/notifications"
	postgresprofiles "github.com/vendlydigital/help/services/api/internal/adapters/postgres/profiles"
	postgrespromotions "github.com/vendlydigital/help/services/api/internal/adapters/postgres/promotions"
	"github.com/vendlydigital/help/services/api/internal/adapters/realtime"
	applicationauth "github.com/vendlydigital/help/services/api/internal/application/auth"
	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	applicationhome "github.com/vendlydigital/help/services/api/internal/application/home"
	applicationprofiles "github.com/vendlydigital/help/services/api/internal/application/profiles"
	applicationpush "github.com/vendlydigital/help/services/api/internal/application/push"
	"github.com/vendlydigital/help/services/api/internal/config"
	"github.com/vendlydigital/help/services/api/internal/database"
)

func main() {
	if err := run(); err != nil {
		slog.Error("api stopped", "error", err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) == 2 && os.Args[1] == "healthcheck" {
		return runHealthcheck()
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	firebaseApp, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: cfg.FirebaseProjectID})
	if err != nil {
		return err
	}
	firebaseAuth, err := firebaseApp.Auth(ctx)
	if err != nil {
		return err
	}
	firebaseMessaging, err := firebaseApp.Messaging(ctx)
	if err != nil {
		return err
	}
	pool, err := database.NewPool(ctx, cfg.Database)
	if err != nil {
		return err
	}
	defer pool.Close()

	linkGenerator := firebaseauth.NewPasswordResetLinkGenerator(firebaseAuth)
	verificationLinkGenerator := firebaseauth.NewEmailVerificationLinkGenerator(firebaseAuth)
	tokenVerifier := firebaseauth.NewIDTokenVerifier(firebaseAuth)
	mailer := mailersend.NewClient(mailersend.Config{
		APIToken:  cfg.MailerSend.APIToken,
		FromEmail: cfg.MailerSend.FromEmail,
		FromName:  cfg.MailerSend.FromName,
	})
	requestPasswordReset := applicationauth.NewRequestPasswordReset(linkGenerator, mailer)
	timedPasswordReset := applicationauth.NewTimeoutPasswordReset(requestPasswordReset, 12*time.Second)
	requestEmailVerification := applicationauth.NewRequestEmailVerification(
		verificationLinkGenerator,
		mailer,
	)
	timedEmailVerification := applicationauth.NewTimeoutEmailVerification(
		requestEmailVerification,
		12*time.Second,
	)
	profileRepository := postgresprofiles.NewRepository(pool)
	registerProfile := applicationprofiles.NewRegisterProfile(profileRepository)
	locationRepository := postgresprofiles.NewLocationRepository(pool)
	saveDefaultLocation := applicationprofiles.NewSaveDefaultLocation(locationRepository)
	viewerRepository := postgreshome.NewViewerRepository(pool)
	catalogRepository := postgrescatalog.NewRepository(pool)
	getHomeBase := applicationhome.NewGetHomeBase(
		postgrescategories.NewRepository(pool),
		postgrespromotions.NewRepository(pool),
		postgreshome.NewRepository(pool),
	)
	cachedHomeBase := applicationhome.NewCachedHomeBase(getHomeBase, 30*time.Second)
	getHome := applicationhome.NewGetHome(cachedHomeBase, viewerRepository, catalogRepository)
	deviceRepository := postgresdevices.NewRepository(pool)
	pushService := applicationpush.NewService(
		deviceRepository,
		postgresnotifications.NewRepository(pool),
		firebasepush.NewSender(firebaseMessaging),
	)
	realtimeHub := realtime.NewHub()
	chatService := applicationchat.NewService(
		postgreschat.NewRepository(pool), realtimeHub, pushService,
	)
	router := httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester:     timedPasswordReset,
		PasswordResetLimiter:       httpapi.NewMemoryRateLimiter(5, time.Minute),
		EmailVerificationRequester: timedEmailVerification,
		EmailVerificationLimiter:   httpapi.NewMemoryRateLimiter(3, time.Minute),
		TokenVerifier:              tokenVerifier,
		ProfileRegistrar:           registerProfile,
		ProfileReader:              profileRepository,
		DefaultLocationSaver:       saveDefaultLocation,
		NotificationMarker:         viewerRepository,
		HomeGetter:                 getHome,
		CatalogSearcher:            catalogRepository,
		DeviceRepository:           deviceRepository,
		UserDirectory:              profileRepository,
		ChatService:                chatService,
		RealtimeHub:                realtimeHub,
		ReadinessChecker:           pool,
		TrustProxyHeaders:          cfg.TrustProxyHeaders,
	})

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		slog.Info("api listening", "address", server.Addr)
		serverErrors <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return server.Shutdown(shutdownCtx)
	case err := <-serverErrors:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
