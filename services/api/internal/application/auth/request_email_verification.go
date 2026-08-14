package auth

import (
	"context"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type RequestEmailVerification struct {
	links  ports.EmailVerificationLinkGenerator
	mailer ports.EmailVerificationMailer
}

func NewRequestEmailVerification(
	links ports.EmailVerificationLinkGenerator,
	mailer ports.EmailVerificationMailer,
) *RequestEmailVerification {
	return &RequestEmailVerification{links: links, mailer: mailer}
}

func (requester *RequestEmailVerification) Execute(
	ctx context.Context,
	email domainauth.Email,
) error {
	link, err := requester.links.GenerateEmailVerificationLink(ctx, email)
	if err != nil {
		return fmt.Errorf("generate email verification link: %w", err)
	}
	message := ports.EmailVerificationEmail{To: email, VerificationLink: link}
	if err := requester.mailer.SendEmailVerification(ctx, message); err != nil {
		return fmt.Errorf("send email verification: %w", err)
	}
	return nil
}
