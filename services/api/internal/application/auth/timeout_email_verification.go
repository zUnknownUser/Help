package auth

import (
	"context"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type TimeoutEmailVerification struct {
	source  ports.EmailVerificationRequester
	timeout time.Duration
}

func NewTimeoutEmailVerification(
	source ports.EmailVerificationRequester,
	timeout time.Duration,
) *TimeoutEmailVerification {
	return &TimeoutEmailVerification{source: source, timeout: timeout}
}

func (requester *TimeoutEmailVerification) Execute(
	ctx context.Context,
	email domainauth.Email,
) error {
	requestCtx, cancel := context.WithTimeout(ctx, requester.timeout)
	defer cancel()
	return requester.source.Execute(requestCtx, email)
}
