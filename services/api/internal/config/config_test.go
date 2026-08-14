package config_test

import (
	"testing"

	"github.com/vendlydigital/help/services/api/internal/config"
)

func TestLoadUsesSecureDefaults(t *testing.T) {
	t.Setenv("MAILERSEND_API_TOKEN", "secret-token")
	t.Setenv("FIREBASE_PROJECT_ID", "help-9c4d1")
	t.Setenv("DATABASE_URL", "postgres://help:secret@localhost:5432/help")
	t.Setenv("PORT", "")
	t.Setenv("MAILERSEND_FROM_EMAIL", "")
	t.Setenv("MAILERSEND_FROM_NAME", "")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("Load() erro inesperado: %v", err)
	}
	if cfg.Port != "8080" {
		t.Fatalf("Port = %q; esperado 8080", cfg.Port)
	}
	if cfg.MailerSend.FromEmail != "nao-responda@vendlydigital.com.br" {
		t.Fatalf("FromEmail = %q", cfg.MailerSend.FromEmail)
	}
	if cfg.MailerSend.FromName != "Help" {
		t.Fatalf("FromName = %q", cfg.MailerSend.FromName)
	}
	if cfg.Database.MaxConnections != 10 || cfg.Database.MinConnections != 2 {
		t.Fatalf("pool defaults = %d/%d", cfg.Database.MinConnections, cfg.Database.MaxConnections)
	}
	if cfg.TrustProxyHeaders {
		t.Fatal("proxy headers não devem ser confiados por padrão")
	}
}

func TestLoadConfiguresPoolAndTrustedProxy(t *testing.T) {
	setRequiredEnvironment(t)
	t.Setenv("DB_MAX_CONNECTIONS", "24")
	t.Setenv("DB_MIN_CONNECTIONS", "4")
	t.Setenv("TRUST_PROXY_HEADERS", "true")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("Load() erro inesperado: %v", err)
	}
	if cfg.Database.MaxConnections != 24 || cfg.Database.MinConnections != 4 {
		t.Fatalf("pool configurado = %d/%d", cfg.Database.MinConnections, cfg.Database.MaxConnections)
	}
	if !cfg.TrustProxyHeaders {
		t.Fatal("TRUST_PROXY_HEADERS deveria estar habilitado")
	}
}

func TestLoadRejectsInvalidOperationalConfiguration(t *testing.T) {
	tests := map[string]map[string]string{
		"porta inválida":       {"PORT": "70000"},
		"máximo inválido":      {"DB_MAX_CONNECTIONS": "muitas"},
		"mínimo maior que max": {"DB_MIN_CONNECTIONS": "11", "DB_MAX_CONNECTIONS": "10"},
		"proxy inválido":       {"TRUST_PROXY_HEADERS": "talvez"},
		"remetente inválido":   {"MAILERSEND_FROM_EMAIL": "Help <user@example.com>"},
	}

	for name, environment := range tests {
		t.Run(name, func(t *testing.T) {
			setRequiredEnvironment(t)
			for key, value := range environment {
				t.Setenv(key, value)
			}
			if _, err := config.Load(); err == nil {
				t.Fatal("Load() deveria rejeitar a configuração")
			}
		})
	}
}

func TestLoadRequiresSecrets(t *testing.T) {
	t.Setenv("MAILERSEND_API_TOKEN", "")
	t.Setenv("FIREBASE_PROJECT_ID", "")
	t.Setenv("DATABASE_URL", "")

	if _, err := config.Load(); err == nil {
		t.Fatal("Load() deveria exigir configurações sensíveis")
	}
}

func setRequiredEnvironment(t *testing.T) {
	t.Helper()
	t.Setenv("MAILERSEND_API_TOKEN", "secret-token")
	t.Setenv("FIREBASE_PROJECT_ID", "help-9c4d1")
	t.Setenv("DATABASE_URL", "postgres://help:secret@localhost:5432/help")
	t.Setenv("PORT", "")
	t.Setenv("DB_MAX_CONNECTIONS", "")
	t.Setenv("DB_MIN_CONNECTIONS", "")
	t.Setenv("TRUST_PROXY_HEADERS", "")
}
