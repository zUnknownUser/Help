package firebaseauth

import (
	"context"
	"fmt"

	firebaseadminauth "firebase.google.com/go/v4/auth"

	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type emailVerificationLinkClient interface {
	EmailVerificationLink(ctx context.Context, email string) (string, error)
}

type EmailVerificationLinkGenerator struct {
	client emailVerificationLinkClient
}

func NewEmailVerificationLinkGenerator(
	client *firebaseadminauth.Client,
) *EmailVerificationLinkGenerator {
	return &EmailVerificationLinkGenerator{client: client}
}

func (generator *EmailVerificationLinkGenerator) GenerateEmailVerificationLink(
	ctx context.Context,
	email domainauth.Email,
) (string, error) {
	link, err := generator.client.EmailVerificationLink(ctx, email.String())
	if err != nil {
		return "", fmt.Errorf("generate Firebase email verification link: %w", err)
	}
	return link, nil
}
