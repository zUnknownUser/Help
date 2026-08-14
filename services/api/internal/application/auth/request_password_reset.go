package auth

import (
	"context"
	"errors"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type RequestPasswordReset struct {
	links  ports.PasswordResetLinkGenerator
	mailer ports.PasswordResetMailer
}

func NewRequestPasswordReset(
	links ports.PasswordResetLinkGenerator,
	mailer ports.PasswordResetMailer,
) *RequestPasswordReset {
	return &RequestPasswordReset{links: links, mailer: mailer}
}

func (uc *RequestPasswordReset) Execute(ctx context.Context, email domainauth.Email) error {
	link, err := uc.links.GeneratePasswordResetLink(ctx, email)
	if errors.Is(err, ports.ErrUserNotFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("generate password reset link: %w", err)
	}

	message := ports.PasswordResetEmail{To: email, ResetLink: link}
	if err := uc.mailer.SendPasswordReset(ctx, message); err != nil {
		return fmt.Errorf("send password reset email: %w", err)
	}
	return nil
}
