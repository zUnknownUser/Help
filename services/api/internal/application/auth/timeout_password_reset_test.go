package auth_test

import (
	"context"
	"errors"
	"testing"
	"time"

	applicationauth "github.com/vendlydigital/help/services/api/internal/application/auth"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type blockingPasswordResetRequester struct{}

func (blockingPasswordResetRequester) Execute(ctx context.Context, _ domainauth.Email) error {
	<-ctx.Done()
	return ctx.Err()
}

func TestTimeoutPasswordResetBoundsProviderLatency(t *testing.T) {
	t.Parallel()

	requester := applicationauth.NewTimeoutPasswordReset(
		blockingPasswordResetRequester{},
		10*time.Millisecond,
	)
	email, _ := domainauth.ParseEmail("user@example.com")

	err := requester.Execute(context.Background(), email)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("erro = %v; esperado deadline exceeded", err)
	}
}
