package auth_test

import (
	"context"
	"errors"
	"testing"

	appauth "github.com/vendlydigital/help/services/api/internal/application/auth"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type fakeLinkGenerator struct {
	link  string
	err   error
	email domainauth.Email
}

func (f *fakeLinkGenerator) GeneratePasswordResetLink(_ context.Context, email domainauth.Email) (string, error) {
	f.email = email
	return f.link, f.err
}

type fakeMailer struct {
	message ports.PasswordResetEmail
	err     error
	calls   int
}

func (f *fakeMailer) SendPasswordReset(_ context.Context, message ports.PasswordResetEmail) error {
	f.calls++
	f.message = message
	return f.err
}

func TestRequestPasswordResetExecute(t *testing.T) {
	t.Parallel()

	email, err := domainauth.ParseEmail("user@example.com")
	if err != nil {
		t.Fatal(err)
	}
	links := &fakeLinkGenerator{link: "https://reset.example/link"}
	mailer := &fakeMailer{}
	useCase := appauth.NewRequestPasswordReset(links, mailer)

	if err := useCase.Execute(context.Background(), email); err != nil {
		t.Fatalf("Execute() erro inesperado: %v", err)
	}
	if links.email != email {
		t.Fatalf("gerador recebeu %q; esperado %q", links.email, email)
	}
	if mailer.calls != 1 {
		t.Fatalf("mailer chamado %d vezes; esperado 1", mailer.calls)
	}
	if mailer.message.To != email || mailer.message.ResetLink != links.link {
		t.Fatalf("mensagem enviada incorretamente: %+v", mailer.message)
	}
}

func TestRequestPasswordResetDoesNotRevealUnknownUser(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("unknown@example.com")
	links := &fakeLinkGenerator{err: ports.ErrUserNotFound}
	mailer := &fakeMailer{}
	useCase := appauth.NewRequestPasswordReset(links, mailer)

	if err := useCase.Execute(context.Background(), email); err != nil {
		t.Fatalf("usuário inexistente deve parecer sucesso: %v", err)
	}
	if mailer.calls != 0 {
		t.Fatal("mailer não deve ser chamado para usuário inexistente")
	}
}

func TestRequestPasswordResetPropagatesInfrastructureFailure(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("user@example.com")
	wantErr := errors.New("mailer indisponível")
	useCase := appauth.NewRequestPasswordReset(
		&fakeLinkGenerator{link: "https://reset.example/link"},
		&fakeMailer{err: wantErr},
	)

	err := useCase.Execute(context.Background(), email)
	if !errors.Is(err, wantErr) {
		t.Fatalf("Execute() erro = %v; esperado %v", err, wantErr)
	}
}
