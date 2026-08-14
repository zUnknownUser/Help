package auth

import (
	"context"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type TimeoutPasswordReset struct {
	source  ports.PasswordResetRequester
	timeout time.Duration
}

func NewTimeoutPasswordReset(
	source ports.PasswordResetRequester,
	timeout time.Duration,
) *TimeoutPasswordReset {
	return &TimeoutPasswordReset{source: source, timeout: timeout}
}

func (requester *TimeoutPasswordReset) Execute(
	ctx context.Context,
	email domainauth.Email,
) error {
	requestCtx, cancel := context.WithTimeout(ctx, requester.timeout)
	defer cancel()
	return requester.source.Execute(requestCtx, email)
}
