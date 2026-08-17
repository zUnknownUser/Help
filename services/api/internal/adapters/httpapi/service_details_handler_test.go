package httpapi_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type detailsGetterStub struct{ details catalog.Details }

func (stub detailsGetterStub) Execute(context.Context, string, string) (catalog.Details, error) {
	return stub.details, nil
}

type requestCreatorSpy struct {
	uid, serviceID string
	input          ports.ServiceRequestInput
}

func (spy *requestCreatorSpy) Execute(_ context.Context, uid, serviceID string, input ports.ServiceRequestInput) (domainrequests.Request, error) {
	spy.uid, spy.serviceID, spy.input = uid, serviceID, input
	return domainrequests.Request{
		ID: "request-1", ClientID: input.ClientID, ServiceID: serviceID,
		ServiceTitle: "Limpeza", ProviderID: "provider-1", ProviderName: "Luis",
		Status: "pending", ScheduledFor: time.Date(2026, 8, 17, 15, 0, 0, 0, time.UTC),
		QuotedPriceCents: 15000, AddressLabel: "Casa", Address: "Rua A, 10",
		CreatedAt: time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC),
	}, nil
}

func TestServiceDetailsReturnsCheckoutContext(t *testing.T) {
	t.Parallel()
	details := catalog.Details{
		Listing: catalog.Listing{
			Service:      catalog.Service{ID: "service-1", Title: "Limpeza", Description: "Completa", PriceCents: 15000},
			ProviderName: "Luis", ProviderVerified: true,
		},
		ProviderUserID: "provider-user", ServiceArea: "Manaus - AM", CanRequest: true,
		ViewerAddress: &catalog.ViewerAddress{Label: "Casa", FormattedAddress: "Rua A, 10"},
	}
	router := newServiceTestRouter(detailsGetterStub{details: details}, &requestCreatorSpy{})
	request := httptest.NewRequest(http.MethodGet, "/v1/services/service-1", nil)
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", response.Code, response.Body.String())
	}
	var body struct {
		Data struct {
			Description string `json:"description"`
			Provider    struct {
				UserID string `json:"user_id"`
			} `json:"provider"`
			Request struct {
				CanRequest bool `json:"can_request"`
			} `json:"request"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Data.Description != "Completa" || body.Data.Provider.UserID != "provider-user" || !body.Data.Request.CanRequest {
		t.Fatalf("body = %+v", body)
	}
}

func TestCreateServiceRequestUsesAuthenticatedIdentity(t *testing.T) {
	t.Parallel()
	creator := &requestCreatorSpy{}
	router := newServiceTestRouter(detailsGetterStub{}, creator)
	request := httptest.NewRequest(http.MethodPost, "/v1/services/service-1/requests", bytes.NewBufferString(`{
		"client_request_id":"c349a83e-fbd9-4d59-984d-0516b7f981b2",
		"scheduled_for":"2026-08-17T15:00:00Z",
		"note":"Levar material"
	}`))
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d body = %s", response.Code, response.Body.String())
	}
	if creator.uid != "customer-user" || creator.serviceID != "service-1" || creator.input.Note != "Levar material" {
		t.Fatalf("creator = %+v", creator)
	}
}

func newServiceTestRouter(details ports.ServiceDetailsGetter, creator ports.ServiceRequestCreator) http.Handler {
	return httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester: noopRequester{}, PasswordResetLimiter: httpapi.NewMemoryRateLimiter(5, 0),
		EmailVerificationRequester: &emailVerificationRequesterSpy{}, EmailVerificationLimiter: httpapi.NewMemoryRateLimiter(3, 0),
		TokenVerifier:    tokenVerifierStub{identity: ports.AuthenticatedIdentity{UID: "customer-user"}},
		ProfileRegistrar: &profileRegistrarSpy{}, ProfileReader: profileReaderStub{},
		HomeGetter: homeGetterStub{}, ServiceDetailsGetter: details,
		ServiceRequestCreator: creator, ReadinessChecker: readinessStub{},
	})
}
