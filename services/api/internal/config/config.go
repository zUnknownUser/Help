package config

import (
	"errors"
	"os"
	"strings"
)

type Config struct {
	Port              string
	FirebaseProjectID string
	TrustProxyHeaders bool
	MailerSend        MailerSendConfig
	Database          DatabaseConfig
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
	return cfg, nil
}

func valueOrDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
