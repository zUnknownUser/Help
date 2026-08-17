package config

import (
	"errors"
	"os"
	"strings"
	"time"
)

type Config struct {
	Port               string
	FirebaseProjectID  string
	TrustProxyHeaders  bool
	MailerSend         MailerSendConfig
	Database           DatabaseConfig
	RTC                RTCConfig
	ChatMediaDirectory string
	OpenAI             OpenAIConfig
}

type OpenAIConfig struct {
	Enabled        bool
	APIKey         string
	BaseURL        string
	EmbeddingModel string
	Timeout        time.Duration
}

type RTCConfig struct {
	STUNURLs      []string
	TURNURLs      []string
	TURNSecret    string
	CredentialTTL time.Duration
}

type DatabaseConfig struct {
	URL            string
	MaxConnections int32
	MinConnections int32
}

type MailerSendConfig struct {
	APIToken  string
	FromEmail string
	FromName  string
}

func Load() (Config, error) {
	port, err := readPort("PORT", 8080)
	if err != nil {
		return Config{}, err
	}
	maxConnections, err := readInt32("DB_MAX_CONNECTIONS", 10, 1, 1000)
	if err != nil {
		return Config{}, err
	}
	minConnections, err := readInt32("DB_MIN_CONNECTIONS", 2, 0, 1000)
	if err != nil {
		return Config{}, err
	}
	if minConnections > maxConnections {
		return Config{}, errors.New("DB_MIN_CONNECTIONS cannot exceed DB_MAX_CONNECTIONS")
	}
	trustProxyHeaders, err := readBool("TRUST_PROXY_HEADERS", false)
	if err != nil {
		return Config{}, err
	}
	turnTTLSeconds, err := readInt("TURN_CREDENTIAL_TTL_SECONDS", 3600, 300, 86400)
	if err != nil {
		return Config{}, err
	}
	openAIEnabled, err := readBool("MATCHMAKING_AI_ENABLED", false)
	if err != nil {
		return Config{}, err
	}
	openAITimeoutSeconds, err := readInt("OPENAI_TIMEOUT_SECONDS", 5, 1, 30)
	if err != nil {
		return Config{}, err
	}

	cfg := Config{
		Port:              port,
		FirebaseProjectID: strings.TrimSpace(os.Getenv("FIREBASE_PROJECT_ID")),
		TrustProxyHeaders: trustProxyHeaders,
		MailerSend: MailerSendConfig{
			APIToken:  strings.TrimSpace(os.Getenv("MAILERSEND_API_TOKEN")),
			FromEmail: valueOrDefault("MAILERSEND_FROM_EMAIL", "nao-responda@vendlydigital.com.br"),
			FromName:  valueOrDefault("MAILERSEND_FROM_NAME", "Help"),
		},
		Database: DatabaseConfig{
			URL:            strings.TrimSpace(os.Getenv("DATABASE_URL")),
			MaxConnections: maxConnections,
			MinConnections: minConnections,
		},
		RTC: RTCConfig{
			STUNURLs:      splitCSV(valueOrDefault("STUN_URLS", "stun:stun.l.google.com:19302")),
			TURNURLs:      splitCSV(os.Getenv("TURN_URLS")),
			TURNSecret:    strings.TrimSpace(os.Getenv("TURN_SHARED_SECRET")),
			CredentialTTL: time.Duration(turnTTLSeconds) * time.Second,
		},
		ChatMediaDirectory: valueOrDefault("CHAT_MEDIA_DIR", ".data/chat-media"),
		OpenAI: OpenAIConfig{
			Enabled: openAIEnabled, APIKey: strings.TrimSpace(os.Getenv("OPENAI_API_KEY")),
			BaseURL:        valueOrDefault("OPENAI_BASE_URL", "https://api.openai.com/v1"),
			EmbeddingModel: valueOrDefault("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small"),
			Timeout:        time.Duration(openAITimeoutSeconds) * time.Second,
		},
	}
	if cfg.FirebaseProjectID == "" {
		return Config{}, errors.New("FIREBASE_PROJECT_ID is required")
	}
	if cfg.MailerSend.APIToken == "" {
		return Config{}, errors.New("MAILERSEND_API_TOKEN is required")
	}
	if !isMailbox(cfg.MailerSend.FromEmail) {
		return Config{}, errors.New("MAILERSEND_FROM_EMAIL must be a valid mailbox")
	}
	if cfg.Database.URL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	if len(cfg.RTC.TURNURLs) > 0 && cfg.RTC.TURNSecret == "" {
		return Config{}, errors.New("TURN_SHARED_SECRET is required when TURN_URLS is configured")
	}
	if cfg.OpenAI.Enabled && cfg.OpenAI.APIKey == "" {
		return Config{}, errors.New("OPENAI_API_KEY is required when MATCHMAKING_AI_ENABLED is true")
	}
	return cfg, nil
}

func splitCSV(raw string) []string {
	values := make([]string, 0)
	for _, value := range strings.Split(raw, ",") {
		if value = strings.TrimSpace(value); value != "" {
			values = append(values, value)
		}
	}
	return values
}

func valueOrDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
