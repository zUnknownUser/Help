package httpapi_test

import (
	"bytes"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

type fakePasswordResetRequester struct {
	email domainauth.Email
	err   error
	calls int
}

func (f *fakePasswordResetRequester) Execute(_ context.Context, email domainauth.Email) error {
	f.calls++
	f.email = email
	return f.err
}

func TestPasswordResetHandlerAcceptsValidRequest(t *testing.T) {
	t.Parallel()

	requester := &fakePasswordResetRequester{}
	handler := httpapi.NewPasswordResetHandler(requester)
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/password-reset", bytes.NewBufferString(`{"email":" User@Example.COM "}`))
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()

	handler.ServeHTTP(res, req)

	if res.Code != http.StatusAccepted {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusAccepted)
	}
	if requester.email.String() != "user@example.com" {
		t.Fatalf("e-mail recebido = %q", requester.email)
	}
	if !strings.Contains(res.Body.String(), "Se existir uma conta") {
		t.Fatalf("resposta não é genérica: %s", res.Body.String())
	}
}

func TestPasswordResetHandlerRejectsInvalidInput(t *testing.T) {
	t.Parallel()

	requester := &fakePasswordResetRequester{}
	handler := httpapi.NewPasswordResetHandler(requester)
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/password-reset", bytes.NewBufferString(`{"email":"invalid"}`))
	res := httptest.NewRecorder()

	handler.ServeHTTP(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusBadRequest)
	}
	if requester.calls != 0 {
		t.Fatal("caso de uso não deve ser chamado com entrada inválida")
	}
}

func TestPasswordResetHandlerRejectsAdditionalJSONValue(t *testing.T) {
	t.Parallel()

	requester := &fakePasswordResetRequester{}
	handler := httpapi.NewPasswordResetHandler(requester)
	req := httptest.NewRequest(
		http.MethodPost,
		"/v1/auth/password-reset",
		bytes.NewBufferString(`{"email":"user@example.com"}{"email":"second@example.com"}`),
	)
	res := httptest.NewRecorder()

	handler.ServeHTTP(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusBadRequest)
	}
	if requester.calls != 0 {
		t.Fatal("caso de uso não deve ser chamado com dois valores JSON")
	}
}

func TestPasswordResetHandlerHidesAccountExistenceWhenProviderFails(t *testing.T) {
	t.Parallel()

	requester := &fakePasswordResetRequester{err: errors.New("token secreto vazou")}
	handler := httpapi.NewPasswordResetHandler(requester)
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/password-reset", bytes.NewBufferString(`{"email":"user@example.com"}`))
	res := httptest.NewRecorder()

	handler.ServeHTTP(res, req)

	if res.Code != http.StatusAccepted {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusAccepted)
	}
	if strings.Contains(res.Body.String(), "token secreto") {
		t.Fatal("resposta expôs detalhe interno")
	}
	if !strings.Contains(res.Body.String(), "Se existir uma conta") {
		t.Fatalf("resposta não é genérica: %s", res.Body.String())
	}
}
