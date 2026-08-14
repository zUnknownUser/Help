package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type profileRegistrarSpy struct {
	identity ports.AuthenticatedIdentity
	input    ports.ProfileRegistrationInput
	profile  domainprofiles.Profile
	err      error
}

func (spy *profileRegistrarSpy) Execute(
	_ context.Context,
	identity ports.AuthenticatedIdentity,
	input ports.ProfileRegistrationInput,
) (domainprofiles.Profile, error) {
	spy.identity = identity
	spy.input = input
	return spy.profile, spy.err
}

type profileReaderStub struct {
	profile domainprofiles.Profile
	err     error
}

func (stub profileReaderStub) FindByUID(context.Context, string) (domainprofiles.Profile, error) {
	return stub.profile, stub.err
}

func TestProfileHandlerRegistersAuthenticatedProfile(t *testing.T) {
	t.Parallel()

	email, _ := domainauth.ParseEmail("maria@example.com")
	profile := domainprofiles.Profile{
		DisplayName: "Maria Silva", Email: email,
		ActiveRole: domainprofiles.ProviderRole,
		Roles:      []domainprofiles.Role{domainprofiles.ProviderRole},
	}
	registrar := &profileRegistrarSpy{profile: profile}
	router := newProfileTestRouter(registrar, profileReaderStub{}, ports.AuthenticatedIdentity{
		UID: "firebase-uid", Email: email,
	})
	request := httptest.NewRequest(
		http.MethodPost,
		"/v1/profile",
		bytes.NewBufferString(`{"display_name":" Maria Silva ","role":"provider"}`),
	)
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d; esperado %d", response.Code, http.StatusCreated)
	}
	if registrar.identity.UID != "firebase-uid" || registrar.input.Role != "provider" {
		t.Fatalf("cadastro recebido incorretamente: identity=%+v input=%+v", registrar.identity, registrar.input)
	}
	var body struct {
		Data struct {
			DisplayName string   `json:"display_name"`
			ActiveRole  string   `json:"active_role"`
			Roles       []string `json:"roles"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("resposta JSON inválida: %v", err)
	}
	if body.Data.DisplayName != "Maria Silva" || body.Data.ActiveRole != "provider" {
		t.Fatalf("resposta incorreta: %+v", body.Data)
	}
}

func TestProfileHandlerRejectsInvalidRegistration(t *testing.T) {
	t.Parallel()

	router := newProfileTestRouter(
		&profileRegistrarSpy{err: domainprofiles.ErrInvalidDisplayName},
		profileReaderStub{},
		ports.AuthenticatedIdentity{UID: "uid"},
	)
	request := httptest.NewRequest(
		http.MethodPost,
		"/v1/profile",
		bytes.NewBufferString(`{"display_name":"A","role":"admin"}`),
	)
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d; esperado %d", response.Code, http.StatusBadRequest)
	}
}

func TestProfileHandlerReturnsMissingProfile(t *testing.T) {
	t.Parallel()

	router := newProfileTestRouter(
		&profileRegistrarSpy{},
		profileReaderStub{err: domainprofiles.ErrProfileNotFound},
		ports.AuthenticatedIdentity{UID: "uid"},
	)
	request := httptest.NewRequest(http.MethodGet, "/v1/profile", nil)
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusNotFound {
		t.Fatalf("status = %d; esperado %d", response.Code, http.StatusNotFound)
	}
}

func newProfileTestRouter(
	registrar ports.ProfileRegistrar,
	reader ports.ProfileReader,
	identity ports.AuthenticatedIdentity,
) http.Handler {
	return httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester:     noopRequester{},
		PasswordResetLimiter:       httpapi.NewMemoryRateLimiter(5, 0),
		EmailVerificationRequester: &emailVerificationRequesterSpy{},
		EmailVerificationLimiter:   httpapi.NewMemoryRateLimiter(3, 0),
		TokenVerifier:              tokenVerifierStub{identity: identity},
		ProfileRegistrar:           registrar,
		ProfileReader:              reader,
		HomeGetter:                 homeGetterStub{},
		ReadinessChecker:           readinessStub{},
	})
}
