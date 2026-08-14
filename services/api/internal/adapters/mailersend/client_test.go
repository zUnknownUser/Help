package mailersend_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/adapters/mailersend"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

func TestClientSendPasswordReset(t *testing.T) {
	t.Parallel()

	var authorization string
	var payload map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authorization = r.Header.Get("Authorization")
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Errorf("payload inválido: %v", err)
		}
		w.WriteHeader(http.StatusAccepted)
	}))
	defer server.Close()

	client := mailersend.NewClient(mailersend.Config{
		BaseURL:    server.URL,
		APIToken:   "test-token",
		FromEmail:  "nao-responda@vendlydigital.com.br",
		FromName:   "Help",
		HTTPClient: server.Client(),
	})
	email, _ := domainauth.ParseEmail("user@example.com")

	err := client.SendPasswordReset(context.Background(), ports.PasswordResetEmail{
		To:        email,
		ResetLink: "https://reset.example/link",
	})
	if err != nil {
		t.Fatalf("SendPasswordReset() erro inesperado: %v", err)
	}
	if authorization != "Bearer test-token" {
		t.Fatalf("Authorization = %q", authorization)
	}
	if payload["subject"] != "Redefina sua senha do Help" {
		t.Fatalf("subject inesperado: %v", payload["subject"])
	}
}

func TestClientRejectsUnexpectedProviderStatus(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
	}))
	defer server.Close()

	client := mailersend.NewClient(mailersend.Config{
		BaseURL:    server.URL,
		APIToken:   "invalid-token",
		FromEmail:  "nao-responda@vendlydigital.com.br",
		FromName:   "Help",
		HTTPClient: server.Client(),
	})
	email, _ := domainauth.ParseEmail("user@example.com")

	err := client.SendPasswordReset(context.Background(), ports.PasswordResetEmail{To: email, ResetLink: "https://reset.example/link"})
	if err == nil {
		t.Fatal("SendPasswordReset() deveria falhar")
	}
}

func TestClientDoesNotIncludeProviderBodyInErrors(t *testing.T) {
	t.Parallel()

	const sensitiveResponse = "recipient=user@example.com reset=https://secret.example/token"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(sensitiveResponse))
	}))
	defer server.Close()
	client := mailersend.NewClient(mailersend.Config{
		BaseURL: server.URL, APIToken: "token", FromEmail: "nao-responda@vendlydigital.com.br",
		HTTPClient: server.Client(),
	})
	email, _ := domainauth.ParseEmail("user@example.com")

	err := client.SendPasswordReset(context.Background(), ports.PasswordResetEmail{
		To: email, ResetLink: "https://secret.example/token",
	})
	if err == nil {
		t.Fatal("SendPasswordReset() deveria falhar")
	}
	if strings.Contains(err.Error(), "user@example.com") || strings.Contains(err.Error(), "secret.example") {
		t.Fatalf("erro expôs resposta sensível do provedor: %v", err)
	}
}

func TestClientSendsEmailVerification(t *testing.T) {
	t.Parallel()

	var payload map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, request *http.Request) {
		if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
			t.Errorf("payload inválido: %v", err)
		}
		w.WriteHeader(http.StatusAccepted)
	}))
	defer server.Close()
	client := mailersend.NewClient(mailersend.Config{
		BaseURL: server.URL, APIToken: "token", FromEmail: "nao-responda@vendlydigital.com.br",
		HTTPClient: server.Client(),
	})
	email, _ := domainauth.ParseEmail("user@example.com")

	err := client.SendEmailVerification(context.Background(), ports.EmailVerificationEmail{
		To: email, VerificationLink: "https://firebase.example/verify",
	})
	if err != nil {
		t.Fatalf("SendEmailVerification() erro inesperado: %v", err)
	}
	if payload["subject"] != "Confirme seu e-mail do Help" {
		t.Fatalf("subject inesperado: %v", payload["subject"])
	}
	if !strings.Contains(payload["html"].(string), "https://firebase.example/verify") {
		t.Fatal("link de verificação ausente no HTML")
	}
}
