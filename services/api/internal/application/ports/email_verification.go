package ports

import (
	"context"

	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type AuthenticatedIdentity struct {
	UID           string
	Email         domainauth.Email
	EmailVerified bool
}

type IDTokenVerifier interface {
	VerifyIDToken(ctx context.Context, rawToken string) (AuthenticatedIdentity, error)
}

type EmailVerificationLinkGenerator interface {
	GenerateEmailVerificationLink(ctx context.Context, email domainauth.Email) (string, error)
}

type EmailVerificationEmail struct {
	To               domainauth.Email
	VerificationLink string
}

type EmailVerificationMailer interface {
	SendEmailVerification(ctx context.Context, message EmailVerificationEmail) error
}

type EmailVerificationRequester interface {
	Execute(ctx context.Context, email domainauth.Email) error
}
