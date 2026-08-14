package firebaseauth

import (
	"context"
	"fmt"

	firebaseadminauth "firebase.google.com/go/v4/auth"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type passwordResetLinkClient interface {
	PasswordResetLink(ctx context.Context, email string) (string, error)
}

type PasswordResetLinkGenerator struct {
	client         passwordResetLinkClient
	isUserNotFound func(error) bool
}

func NewPasswordResetLinkGenerator(client *firebaseadminauth.Client) *PasswordResetLinkGenerator {
	return newPasswordResetLinkGenerator(client, firebaseadminauth.IsUserNotFound)
}

func newPasswordResetLinkGenerator(
	client passwordResetLinkClient,
	isUserNotFound func(error) bool,
) *PasswordResetLinkGenerator {
	return &PasswordResetLinkGenerator{
		client:         client,
		isUserNotFound: isUserNotFound,
	}
}

func (g *PasswordResetLinkGenerator) GeneratePasswordResetLink(
	ctx context.Context,
	email domainauth.Email,
) (string, error) {
	link, err := g.client.PasswordResetLink(ctx, email.String())
	if err == nil {
		return link, nil
	}
	if g.isUserNotFound(err) {
		return "", ports.ErrUserNotFound
	}
	return "", fmt.Errorf("generate Firebase password reset link: %w", err)
}
