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
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type providerHomeStub struct{ workspace providers.Workspace }

func (stub providerHomeStub) Execute(context.Context, string) (providers.Workspace, error) {
	return stub.workspace, nil
}

type providerManagerSpy struct {
	uid   string
	input ports.ProviderServiceInput
}

func (spy *providerManagerSpy) Create(_ context.Context, uid string, input ports.ProviderServiceInput) (catalog.Service, error) {
	spy.uid, spy.input = uid, input
	return catalog.Service{ID: "service-1", Title: input.Title, Active: input.Published}, nil
}
func (*providerManagerSpy) Update(context.Context, string, string, ports.ProviderServiceInput) (catalog.Service, error) {
	return catalog.Service{}, nil
}
func (*providerManagerSpy) SetPublished(context.Context, string, string, bool) (catalog.Service, error) {
	return catalog.Service{}, nil
}
func (*providerManagerSpy) Delete(context.Context, string, string) error { return nil }
func (*providerManagerSpy) SetAcceptingRequests(context.Context, string, bool) error {
	return nil
}

func TestProviderHomeReturnsAggregatedWorkspace(t *testing.T) {
	t.Parallel()

	router := newProviderTestRouter(providerHomeStub{workspace: providers.Workspace{
		Overview: providers.WorkspaceOverview{ProviderID: "provider-1", DisplayName: "Luis", Status: "approved"},
		Services: []catalog.Service{},
	}}, &providerManagerSpy{})
	request := httptest.NewRequest(http.MethodGet, "/v1/provider/home", nil)
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body struct {
		Data struct {
			Provider struct {
				DisplayName string `json:"display_name"`
			} `json:"provider"`
			Services []json.RawMessage `json:"services"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Data.Provider.DisplayName != "Luis" || body.Data.Services == nil {
		t.Fatalf("body = %+v", body)
	}
}

func TestCreateProviderServiceUsesAuthenticatedUser(t *testing.T) {
	t.Parallel()

	manager := &providerManagerSpy{}
	router := newProviderTestRouter(providerHomeStub{}, manager)
	request := httptest.NewRequest(http.MethodPost, "/v1/provider/services", bytes.NewBufferString(`{
		"title":"Limpeza residencial",
		"description":"Limpeza completa para casas.",
		"category_id":"",
		"duration_minutes":120,
		"price_cents":15000,
		"image_url":"",
		"published":true
	}`))
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()

	router.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if manager.uid != "provider-user" || manager.input.Title != "Limpeza residencial" || !manager.input.Published {
		t.Fatalf("manager received uid %q input %+v", manager.uid, manager.input)
	}
}

func newProviderTestRouter(home ports.ProviderHomeGetter, manager ports.ProviderServiceManager) http.Handler {
	return httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester:     noopRequester{},
		PasswordResetLimiter:       httpapi.NewMemoryRateLimiter(5, 0),
		EmailVerificationRequester: &emailVerificationRequesterSpy{},
		EmailVerificationLimiter:   httpapi.NewMemoryRateLimiter(3, 0),
		TokenVerifier:              tokenVerifierStub{identity: ports.AuthenticatedIdentity{UID: "provider-user"}},
		ProfileRegistrar:           &profileRegistrarSpy{},
		ProfileReader:              profileReaderStub{},
		HomeGetter:                 homeGetterStub{},
		ProviderHomeGetter:         home,
		ProviderServiceManager:     manager,
		ReadinessChecker:           readinessStub{},
	})
}
