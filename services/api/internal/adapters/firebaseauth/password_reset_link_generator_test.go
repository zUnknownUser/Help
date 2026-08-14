package firebaseauth

import (
	"context"
	"errors"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type fakePasswordResetLinkClient struct {
	email string
	link  string
	err   error
}

func (f *fakePasswordResetLinkClient) PasswordResetLink(_ context.Context, email string) (string, error) {
	f.email = email
	return f.link, f.err
}

func TestPasswordResetLinkGeneratorReturnsFirebaseLink(t *testing.T) {
	t.Parallel()

	client := &fakePasswordResetLinkClient{link: "https://example.test/reset?code=abc"}
	generator := newPasswordResetLinkGenerator(client, func(error) bool { return false })
	email, _ := domainauth.ParseEmail("User@Example.com")

	link, err := generator.GeneratePasswordResetLink(context.Background(), email)

	if err != nil {
		t.Fatalf("GeneratePasswordResetLink() error = %v", err)
	}
	if link != client.link {
		t.Fatalf("link = %q; esperado %q", link, client.link)
	}
	if client.email != "user@example.com" {
		t.Fatalf("e-mail enviado ao Firebase = %q", client.email)
	}
}

func TestPasswordResetLinkGeneratorMapsUnknownUser(t *testing.T) {
	t.Parallel()

	firebaseErr := errors.New("firebase user not found")
	client := &fakePasswordResetLinkClient{err: firebaseErr}
	generator := newPasswordResetLinkGenerator(client, func(err error) bool {
		return errors.Is(err, firebaseErr)
	})
	email, _ := domainauth.ParseEmail("user@example.com")

	_, err := generator.GeneratePasswordResetLink(context.Background(), email)

	if !errors.Is(err, ports.ErrUserNotFound) {
		t.Fatalf("error = %v; esperado ErrUserNotFound", err)
	}
}

func TestPasswordResetLinkGeneratorPreservesInfrastructureFailure(t *testing.T) {
	t.Parallel()

	firebaseErr := errors.New("firebase unavailable")
	client := &fakePasswordResetLinkClient{err: firebaseErr}
	generator := newPasswordResetLinkGenerator(client, func(error) bool { return false })
	email, _ := domainauth.ParseEmail("user@example.com")

	_, err := generator.GeneratePasswordResetLink(context.Background(), email)

	if !errors.Is(err, firebaseErr) {
		t.Fatalf("error = %v; esperado erro original", err)
	}
}
