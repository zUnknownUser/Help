package firebaseauth

import (
	"context"
	"errors"
	"fmt"

	firebaseadminauth "firebase.google.com/go/v4/auth"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type idTokenClient interface {
	VerifyIDToken(ctx context.Context, idToken string) (*firebaseadminauth.Token, error)
}

type IDTokenVerifier struct{ client idTokenClient }

func NewIDTokenVerifier(client *firebaseadminauth.Client) *IDTokenVerifier {
	return &IDTokenVerifier{client: client}
}

func (verifier *IDTokenVerifier) VerifyIDToken(
	ctx context.Context,
	rawToken string,
) (ports.AuthenticatedIdentity, error) {
	token, err := verifier.client.VerifyIDToken(ctx, rawToken)
	if err != nil {
		return ports.AuthenticatedIdentity{}, fmt.Errorf("verify Firebase ID token: %w", err)
	}
	emailValue, ok := token.Claims["email"].(string)
	if !ok || token.UID == "" {
		return ports.AuthenticatedIdentity{}, errors.New("Firebase token has no user email")
	}
	email, err := domainauth.ParseEmail(emailValue)
	if err != nil {
		return ports.AuthenticatedIdentity{}, errors.New("Firebase token has invalid user email")
	}
	verified, _ := token.Claims["email_verified"].(bool)
	return ports.AuthenticatedIdentity{
		UID: token.UID, Email: email, EmailVerified: verified,
	}, nil
}
