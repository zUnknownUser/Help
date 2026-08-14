package auth_test

import (
	"context"
	"errors"
	"testing"

	applicationauth "github.com/vendlydigital/help/services/api/internal/application/auth"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type verificationLinkStub struct {
	link string
	err  error
}

func (stub verificationLinkStub) GenerateEmailVerificationLink(
	context.Context,
	domainauth.Email,
) (string, error) {
	return stub.link, stub.err
}

type verificationMailerSpy struct {
	message ports.EmailVerificationEmail
	calls   int
}

func (spy *verificationMailerSpy) SendEmailVerification(
	_ context.Context,
	message ports.EmailVerificationEmail,
) error {
	spy.calls++
	spy.message = message
	return nil
}

func TestRequestEmailVerificationGeneratesOfficialLinkAndSendsEmail(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("user@example.com")
	mailer := &verificationMailerSpy{}
	requester := applicationauth.NewRequestEmailVerification(
		verificationLinkStub{link: "https://firebase.example/verify"},
		mailer,
	)

	if err := requester.Execute(context.Background(), email); err != nil {
		t.Fatalf("Execute() erro inesperado: %v", err)
	}
	if mailer.calls != 1 || mailer.message.To != email {
		t.Fatalf("mensagem não enviada ao usuário: %+v", mailer.message)
	}
	if mailer.message.VerificationLink != "https://firebase.example/verify" {
		t.Fatalf("link enviado = %q", mailer.message.VerificationLink)
	}
}

func TestRequestEmailVerificationDoesNotSendWhenLinkGenerationFails(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("user@example.com")
	mailer := &verificationMailerSpy{}
	requester := applicationauth.NewRequestEmailVerification(
		verificationLinkStub{err: errors.New("firebase unavailable")},
		mailer,
	)

	if err := requester.Execute(context.Background(), email); err == nil {
		t.Fatal("Execute() deveria falhar")
	}
	if mailer.calls != 0 {
		t.Fatal("mailer não deve ser chamado sem link")
	}
}
