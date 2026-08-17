package httpapi_test

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type requestLifecycleSpy struct {
	uid, requestID string
	transition     ports.ServiceRequestTransitionInput
}

func (spy *requestLifecycleSpy) List(_ context.Context, uid string, input ports.ServiceRequestListInput) (ports.ServiceRequestPage, error) {
	spy.uid = uid
	return ports.ServiceRequestPage{Items: []domainrequests.Request{requestFixture(domainrequests.ViewerCustomer)}}, nil
}
func (spy *requestLifecycleSpy) Get(_ context.Context, uid, id string) (domainrequests.Request, error) {
	spy.uid, spy.requestID = uid, id
	return requestFixture(domainrequests.ViewerCustomer), nil
}
func (spy *requestLifecycleSpy) Transition(_ context.Context, uid, id string, input ports.ServiceRequestTransitionInput) (domainrequests.Request, error) {
	spy.uid, spy.requestID, spy.transition = uid, id, input
	value := requestFixture(domainrequests.ViewerProvider)
	value.Status, value.Version = domainrequests.StatusAccepted, 1
	return value, nil
}

func (spy *requestLifecycleSpy) Reschedule(context.Context, string, string, ports.ServiceRequestRescheduleInput) (domainrequests.Request, error) {
	return domainrequests.Request{}, nil
}

func (spy *requestLifecycleSpy) Agenda(context.Context, string, ports.ServiceRequestAgendaInput) ([]domainrequests.Request, error) {
	return nil, nil
}

func TestServiceRequestTransitionUsesAuthenticatedActorAndVersion(t *testing.T) {
	t.Parallel()
	spy := &requestLifecycleSpy{}
	router := requestLifecycleRouter(spy)
	request := httptest.NewRequest(http.MethodPost, "/v1/service-requests/c349a83e-fbd9-4d59-984d-0516b7f981b2/transitions", bytes.NewBufferString(`{
		"client_command_id":"d349a83e-fbd9-4d59-984d-0516b7f981b2",
		"target_status":"accepted","expected_version":0
	}`))
	request.Header.Set("Authorization", "Bearer valid-token")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK || spy.uid != "customer-user" || spy.transition.ExpectedVersion != 0 || spy.transition.TargetStatus != "accepted" {
		t.Fatalf("status = %d spy = %+v body = %s", response.Code, spy, response.Body.String())
	}
}

func requestLifecycleRouter(lifecycle ports.ServiceRequestLifecycle) http.Handler {
	return httpapi.NewRouter(httpapi.RouterDependencies{
		PasswordResetRequester: noopRequester{}, PasswordResetLimiter: httpapi.NewMemoryRateLimiter(5, 0),
		EmailVerificationRequester: &emailVerificationRequesterSpy{}, EmailVerificationLimiter: httpapi.NewMemoryRateLimiter(3, 0),
		TokenVerifier:    tokenVerifierStub{identity: ports.AuthenticatedIdentity{UID: "customer-user"}},
		ProfileRegistrar: &profileRegistrarSpy{}, ProfileReader: profileReaderStub{},
		HomeGetter: homeGetterStub{}, ServiceRequestLifecycle: lifecycle, ReadinessChecker: readinessStub{},
	})
}

func requestFixture(role domainrequests.ViewerRole) domainrequests.Request {
	return domainrequests.Request{
		ID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", ClientID: "d349a83e-fbd9-4d59-984d-0516b7f981b2",
		ServiceID: "service-1", ServiceTitle: "Limpeza", ProviderID: "provider-1",
		ProviderUID: "provider-user", ProviderName: "Luis", CustomerUID: "customer-user",
		CustomerName: "Cliente", ViewerRole: role, Status: domainrequests.StatusPending,
		ScheduledFor: time.Date(2026, 8, 17, 15, 0, 0, 0, time.UTC), CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}
}
