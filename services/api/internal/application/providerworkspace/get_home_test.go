package providerworkspace_test

import (
	"context"
	"testing"

	applicationprovider "github.com/vendlydigital/help/services/api/internal/application/providerworkspace"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type workspaceReaderStub struct {
	overview      providers.WorkspaceOverview
	services      []catalog.Service
	requests      []providers.ServiceRequest
	notifications []providers.WorkspaceNotification
}

func (stub workspaceReaderStub) GetOverview(context.Context, string) (providers.WorkspaceOverview, error) {
	return stub.overview, nil
}

func (stub workspaceReaderStub) ListServices(context.Context, string) ([]catalog.Service, error) {
	return stub.services, nil
}

func (stub workspaceReaderStub) ListRecentRequests(context.Context, string, int) ([]providers.ServiceRequest, error) {
	return stub.requests, nil
}

func (stub workspaceReaderStub) ListNotifications(context.Context, string, int) ([]providers.WorkspaceNotification, error) {
	return stub.notifications, nil
}

type categoryReaderStub struct{ values []categories.Category }

func (stub categoryReaderStub) ListActive(context.Context) ([]categories.Category, error) {
	return stub.values, nil
}

func TestGetHomeBuildsRealSummaryAndAlerts(t *testing.T) {
	t.Parallel()

	reader := workspaceReaderStub{
		overview: providers.WorkspaceOverview{ProviderID: "provider-1", DisplayName: "Luis", Status: "approved", Active: true, AcceptingRequests: true, PendingRequests: 3},
		services: []catalog.Service{{ID: "published", Active: true}, {ID: "paused"}},
	}
	getHome := applicationprovider.NewGetHome(reader, categoryReaderStub{})

	home, err := getHome.Execute(context.Background(), "user-1")

	if err != nil {
		t.Fatalf("Execute() error = %v", err)
	}
	if home.Summary.TotalServices != 2 || home.Summary.PublishedServices != 1 || home.Summary.PendingRequests != 3 {
		t.Fatalf("summary = %+v", home.Summary)
	}
	if len(home.Alerts) != 1 || home.Alerts[0].Kind != "location" {
		t.Fatalf("alerts = %+v", home.Alerts)
	}
}
