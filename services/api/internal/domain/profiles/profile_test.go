package profiles_test

import (
	"testing"

	"github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

func TestParseRoleAcceptsPlatformRoles(t *testing.T) {
	t.Parallel()

	for _, value := range []string{"customer", "provider"} {
		if _, err := profiles.ParseRole(value); err != nil {
			t.Fatalf("ParseRole(%q) erro inesperado: %v", value, err)
		}
	}
	if _, err := profiles.ParseRole("admin"); err == nil {
		t.Fatal("papel administrativo não pode ser escolhido no cadastro público")
	}
}

func TestParseDisplayNameNormalizesAndValidates(t *testing.T) {
	t.Parallel()

	name, err := profiles.ParseDisplayName("  Maria da Silva  ")
	if err != nil || name.String() != "Maria da Silva" {
		t.Fatalf("nome = %q, erro = %v", name, err)
	}
	if _, err := profiles.ParseDisplayName("M"); err == nil {
		t.Fatal("nome muito curto deveria ser rejeitado")
	}
}

func TestParseProviderStatusAcceptsPersistedStates(t *testing.T) {
	t.Parallel()

	for _, value := range []string{"pending", "approved", "rejected"} {
		if _, err := profiles.ParseProviderStatus(value); err != nil {
			t.Fatalf("ParseProviderStatus(%q): %v", value, err)
		}
	}
}

func TestParseLocationNormalizesUserInput(t *testing.T) {
	t.Parallel()

	location, err := profiles.ParseLocation(profiles.Location{
		Label: " Casa ", Address: " Av. Brasil, 100 ", City: "Manaus", State: "am",
		Latitude: -3.1, Longitude: -60,
	})
	if err != nil {
		t.Fatalf("ParseLocation() erro inesperado: %v", err)
	}
	if location.Label != "Casa" || location.Address != "Av. Brasil, 100" {
		t.Fatalf("localização incorreta: %+v", location)
	}
	if _, err := profiles.ParseLocation(profiles.Location{Address: "Rua A"}); err == nil {
		t.Fatal("rótulo vazio deveria ser rejeitado")
	}
}
