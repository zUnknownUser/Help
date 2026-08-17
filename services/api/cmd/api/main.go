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
	"github.com/vendlydigital/help/services/api/internal/adapters/localmedia"
	"github.com/vendlydigital/help/services/api/internal/adapters/mailersend"
	postgrescatalog "github.com/vendlydigital/help/services/api/internal/adapters/postgres/catalog"
	postgrescategories "github.com/vendlydigital/help/services/api/internal/adapters/postgres/categories"
	postgreschat "github.com/vendlydigital/help/services/api/internal/adapters/postgres/chat"
	postgresdevices "github.com/vendlydigital/help/services/api/internal/adapters/postgres/devices"
	postgreshelpnow "github.com/vendlydigital/help/services/api/internal/adapters/postgres/helpnow"
	postgreshome "github.com/vendlydigital/help/services/api/internal/adapters/postgres/home"
	postgresnotifications "github.com/vendlydigital/help/services/api/internal/adapters/postgres/notifications"
	postgresprofiles "github.com/vendlydigital/help/services/api/internal/adapters/postgres/profiles"
	postgrespromotions "github.com/vendlydigital/help/services/api/internal/adapters/postgres/promotions"
	postgresprovider "github.com/vendlydigital/help/services/api/internal/adapters/postgres/providerworkspace"
	postgresreviews "github.com/vendlydigital/help/services/api/internal/adapters/postgres/reviews"
	postgresscheduling "github.com/vendlydigital/help/services/api/internal/adapters/postgres/scheduling"
	postgresrequests "github.com/vendlydigital/help/services/api/internal/adapters/postgres/servicerequests"
	"github.com/vendlydigital/help/services/api/internal/adapters/realtime"
	applicationauth "github.com/vendlydigital/help/services/api/internal/application/auth"
	applicationcatalog "github.com/vendlydigital/help/services/api/internal/application/catalog"
	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	applicationhelpnow "github.com/vendlydigital/help/services/api/internal/application/helpnow"
	applicationhome "github.com/vendlydigital/help/services/api/internal/application/home"
	applicationprofiles "github.com/vendlydigital/help/services/api/internal/application/profiles"
	applicationprovider "github.com/vendlydigital/help/services/api/internal/application/providerworkspace"
	applicationpush "github.com/vendlydigital/help/services/api/internal/application/push"
	applicationreviews "github.com/vendlydigital/help/services/api/internal/application/reviews"
	applicationscheduling "github.com/vendlydigital/help/services/api/internal/application/scheduling"
	applicationrequests "github.com/vendlydigital/help/services/api/internal/application/servicerequests"
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
	updateProfile := applicationprofiles.NewUpdateProfile(profileRepository)
	syncProfileEmail := applicationprofiles.NewSyncEmail(profileRepository)
	locationRepository := postgresprofiles.NewLocationRepository(pool)
	saveDefaultLocation := applicationprofiles.NewSaveDefaultLocation(locationRepository)
	viewerRepository := postgreshome.NewViewerRepository(pool)
	catalogRepository := postgrescatalog.NewRepository(pool)
	serviceDetails := applicationcatalog.NewGetDetails(catalogRepository)
	serviceRequestRepository := postgresrequests.NewRepository(pool)
	serviceRequests := applicationrequests.NewCreator(serviceRequestRepository, time.Now)
	serviceRequestLifecycle := applicationrequests.NewLifecycle(serviceRequestRepository)
	scheduleRepository := postgresscheduling.NewRepository(pool)
	scheduleService := applicationscheduling.NewService(scheduleRepository, scheduleRepository, time.Now)
	categoryRepository := postgrescategories.NewRepository(pool)
	providerRepository := postgresprovider.NewRepository(pool)
	providerHome := applicationprovider.NewGetHome(providerRepository, categoryRepository)
	providerManager := applicationprovider.NewManager(providerRepository)
	getHomeBase := applicationhome.NewGetHomeBase(
		categoryRepository,
		postgrespromotions.NewRepository(pool),
		postgreshome.NewRepository(pool),
	)
	cachedHomeBase := applicationhome.NewCachedHomeBase(getHomeBase, 30*time.Second)
	getHome := applicationhome.NewGetHome(cachedHomeBase, viewerRepository, catalogRepository)
	deviceRepository := postgresdevices.NewRepository(pool)
	notificationRepository := postgresnotifications.NewRepository(pool)
	pushSender := firebasepush.NewSender(firebaseMessaging)
	pushService := applicationpush.NewService(notificationRepository)
	pushDispatcher := applicationpush.NewDispatcher(deviceRepository, notificationRepository, pushSender)
	go pushDispatcher.Run(ctx)
	reminderScheduler := applicationpush.NewReminderScheduler(notificationRepository, time.Minute, time.Now)
	go reminderScheduler.Run(ctx)
	realtimeHub := realtime.NewHub()
	helpNowRepository := postgreshelpnow.NewRepository(pool)
	helpNowService := applicationhelpnow.NewService(helpNowRepository, realtimeHub, time.Now)
	helpNowDispatcher := applicationhelpnow.NewDispatcher(helpNowRepository, realtimeHub, 3*time.Second, time.Now)
	go helpNowDispatcher.Run(ctx)
	chatService := applicationchat.NewService(
		postgreschat.NewRepository(pool), realtimeHub, pushService,
	)
	mediaStore, err := localmedia.NewStore(cfg.ChatMediaDirectory)
	if err != nil {
		return err
	}
	chatMediaService := applicationchat.NewMediaService(postgreschat.NewRepository(pool), mediaStore)
	profileMediaService := applicationprofiles.NewMediaService(profileRepository, mediaStore)
	reviewService := applicationreviews.NewService(postgresreviews.NewRepository(pool))
	iceConfigService := applicationchat.NewICEConfigService(applicationchat.ICEConfig{
		STUNURLs:      cfg.RTC.STUNURLs,
		TURNURLs:      cfg.RTC.TURNURLs,
		TURNSecret:    cfg.RTC.TURNSecret,
		CredentialTTL: cfg.RTC.CredentialTTL,
	}, time.Now)
	router := httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester:     timedPasswordReset,
		PasswordResetLimiter:       httpapi.NewMemoryRateLimiter(5, time.Minute),
		EmailVerificationRequester: timedEmailVerification,
		EmailVerificationLimiter:   httpapi.NewMemoryRateLimiter(3, time.Minute),
		TokenVerifier:              tokenVerifier,
		ProfileRegistrar:           registerProfile,
		ProfileReader:              profileRepository,
		ProfileUpdater:             updateProfile,
		ProfileEmailSynchronizer:   syncProfileEmail,
		ProfileMediaService:        profileMediaService,
		DefaultLocationSaver:       saveDefaultLocation,
		NotificationMarker:         viewerRepository,
		HomeGetter:                 getHome,
		CatalogSearcher:            catalogRepository,
		ServiceDetailsGetter:       serviceDetails,
		ServiceRequestCreator:      serviceRequests,
		ServiceRequestLifecycle:    serviceRequestLifecycle,
		ReviewService:              reviewService,
		ProviderScheduleManager:    scheduleService,
		ServiceAvailability:        scheduleService,
		ProviderHomeGetter:         providerHome,
		ProviderServiceManager:     providerManager,
		DeviceRepository:           deviceRepository,
		UserDirectory:              profileRepository,
		ChatService:                chatService,
		ICEConfigService:           iceConfigService,
		ChatMediaService:           chatMediaService,
		RealtimeHub:                realtimeHub,
		HelpNowService:             helpNowService,
		ReadinessChecker:           pool,
		TrustProxyHeaders:          cfg.TrustProxyHeaders,
	})

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       35 * time.Second,
		WriteTimeout:      35 * time.Second,
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
