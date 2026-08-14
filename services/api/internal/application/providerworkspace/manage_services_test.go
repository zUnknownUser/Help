package providerworkspace_test

import (
	"context"
	"errors"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	applicationprovider "github.com/vendlydigital/help/services/api/internal/application/providerworkspace"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

type serviceWriterSpy struct {
	uid   string
	draft catalog.ServiceDraft
}

func (spy *serviceWriterSpy) CreateService(_ context.Context, uid string, draft catalog.ServiceDraft) (catalog.Service, error) {
	spy.uid, spy.draft = uid, draft
	return catalog.Service{ID: "service-1", Title: draft.Title, Active: draft.Published}, nil
}

func (*serviceWriterSpy) UpdateService(context.Context, string, string, catalog.ServiceDraft) (catalog.Service, error) {
	return catalog.Service{}, nil
}
func (*serviceWriterSpy) SetServicePublished(context.Context, string, string, bool) (catalog.Service, error) {
	return catalog.Service{}, nil
}
func (*serviceWriterSpy) DeleteService(context.Context, string, string) error      { return nil }
func (*serviceWriterSpy) SetAcceptingRequests(context.Context, string, bool) error { return nil }

func TestManagerValidatesBeforeCreatingService(t *testing.T) {
	t.Parallel()

	writer := &serviceWriterSpy{}
	manager := applicationprovider.NewManager(writer)
	created, err := manager.Create(context.Background(), "user-1", ports.ProviderServiceInput{
		Title: "  Eletricista residencial ", Description: "Instalacao e manutencao eletrica.",
		DurationMinutes: 90, PriceCents: 12000, Published: true,
	})

	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if writer.uid != "user-1" || writer.draft.Title != "Eletricista residencial" || !created.Active {
		t.Fatalf("writer input = uid %q draft %+v created %+v", writer.uid, writer.draft, created)
	}
}

func TestManagerDoesNotWriteInvalidService(t *testing.T) {
	t.Parallel()

	writer := &serviceWriterSpy{}
	manager := applicationprovider.NewManager(writer)
	_, err := manager.Create(context.Background(), "user-1", ports.ProviderServiceInput{Title: "x"})

	if !errors.Is(err, catalog.ErrInvalidServiceTitle) || writer.uid != "" {
		t.Fatalf("error = %v, writer uid = %q", err, writer.uid)
	}
}
