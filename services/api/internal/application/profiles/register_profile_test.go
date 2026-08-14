package profiles_test

import (
	"context"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	applicationprofiles "github.com/vendlydigital/help/services/api/internal/application/profiles"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type profileWriterSpy struct {
	profile domainprofiles.Profile
}

func (spy *profileWriterSpy) Register(_ context.Context, profile domainprofiles.Profile) (domainprofiles.Profile, error) {
	spy.profile = profile
	return profile, nil
}

func TestRegisterProfileBuildsProfileFromVerifiedIdentity(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("user@example.com")
	writer := &profileWriterSpy{}
	register := applicationprofiles.NewRegisterProfile(writer)

	profile, err := register.Execute(
		context.Background(),
		ports.AuthenticatedIdentity{UID: "firebase-uid", Email: email},
		applicationprofiles.RegisterProfileInput{
			DisplayName: "  Maria da Silva  ", Role: "provider",
		},
	)
	if err != nil {
		t.Fatalf("Execute() erro inesperado: %v", err)
	}
	if profile.UID != "firebase-uid" || profile.DisplayName != "Maria da Silva" {
		t.Fatalf("perfil incorreto: %+v", profile)
	}
	if profile.ActiveRole != domainprofiles.ProviderRole {
		t.Fatalf("papel ativo = %q", profile.ActiveRole)
	}
}
