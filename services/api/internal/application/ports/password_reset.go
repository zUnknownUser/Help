package ports

import (
	"context"
	"errors"

	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

var ErrUserNotFound = errors.New("user not found")

type PasswordResetLinkGenerator interface {
	GeneratePasswordResetLink(ctx context.Context, email domainauth.Email) (string, error)
}

type PasswordResetEmail struct {
	To        domainauth.Email
	ResetLink string
}

type PasswordResetMailer interface {
	SendPasswordReset(ctx context.Context, message PasswordResetEmail) error
}

type PasswordResetRequester interface {
	Execute(ctx context.Context, email domainauth.Email) error
}
