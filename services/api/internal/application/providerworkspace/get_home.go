package providerworkspace

import (
	"context"
	"fmt"

	"golang.org/x/sync/errgroup"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type GetHome struct {
	workspace  ports.ProviderWorkspaceReader
	categories ports.ActiveCategoryReader
}

func NewGetHome(workspace ports.ProviderWorkspaceReader, categories ports.ActiveCategoryReader) *GetHome {
	return &GetHome{workspace: workspace, categories: categories}
}

func (useCase *GetHome) Execute(ctx context.Context, uid string) (providers.Workspace, error) {
	var (
		overview      providers.WorkspaceOverview
		services      []catalog.Service
		categoryList  []categories.Category
		requests      []providers.ServiceRequest
		notifications []providers.WorkspaceNotification
	)
	group, groupCtx := errgroup.WithContext(ctx)
	group.Go(func() (err error) { overview, err = useCase.workspace.GetOverview(groupCtx, uid); return err })
	group.Go(func() (err error) { services, err = useCase.workspace.ListServices(groupCtx, uid); return err })
	group.Go(func() (err error) { categoryList, err = useCase.categories.ListActive(groupCtx); return err })
	group.Go(func() (err error) { requests, err = useCase.workspace.ListRecentRequests(groupCtx, uid, 5); return err })
	group.Go(func() (err error) {
		notifications, err = useCase.workspace.ListNotifications(groupCtx, uid, 20)
		return err
	})
	if err := group.Wait(); err != nil {
		return providers.Workspace{}, fmt.Errorf("load provider workspace: %w", err)
	}
	workspace := providers.Workspace{
		Overview: overview, Services: nonNilServices(services), Categories: nonNilCategories(categoryList),
		RecentRequests: nonNilRequests(requests), Notifications: nonNilNotifications(notifications),
	}
	workspace.Summary = summarize(overview, services)
	workspace.Alerts = workspaceAlerts(workspace)
	return workspace, nil
}

func summarize(overview providers.WorkspaceOverview, services []catalog.Service) providers.WorkspaceSummary {
	summary := providers.WorkspaceSummary{
		TotalServices: len(services), PendingRequests: overview.PendingRequests,
		UnreadMessages: overview.UnreadMessages, UnreadNotifications: overview.UnreadNotifications,
	}
	for _, service := range services {
		if service.Active {
			summary.PublishedServices++
		} else {
			summary.PausedServices++
		}
	}
	return summary
}

func workspaceAlerts(workspace providers.Workspace) []providers.WorkspaceAlert {
	alerts := make([]providers.WorkspaceAlert, 0, 3)
	if workspace.Overview.Location.Latitude == nil {
		alerts = append(alerts, providers.WorkspaceAlert{Kind: "location", Title: "Defina sua area de atendimento", Message: "Adicione sua localizacao para aparecer para clientes proximos."})
	}
	if len(workspace.Services) == 0 {
		alerts = append(alerts, providers.WorkspaceAlert{Kind: "service", Title: "Cadastre seu primeiro servico", Message: "Informe o que voce faz, duracao e valor para comecar a receber contatos."})
	} else if workspace.Summary.PublishedServices == 0 {
		alerts = append(alerts, providers.WorkspaceAlert{Kind: "publication", Title: "Publique um servico", Message: "Seus servicos estao pausados e nao aparecem para clientes."})
	}
	if !workspace.Overview.AcceptingRequests {
		alerts = append(alerts, providers.WorkspaceAlert{Kind: "availability", Title: "Agenda pausada", Message: "Ative sua disponibilidade quando puder receber novas solicitacoes."})
	}
	return alerts
}

func nonNilServices(values []catalog.Service) []catalog.Service {
	if values == nil {
		return []catalog.Service{}
	}
	return values
}
func nonNilCategories(values []categories.Category) []categories.Category {
	if values == nil {
		return []categories.Category{}
	}
	return values
}
func nonNilRequests(values []providers.ServiceRequest) []providers.ServiceRequest {
	if values == nil {
		return []providers.ServiceRequest{}
	}
	return values
}

func nonNilNotifications(values []providers.WorkspaceNotification) []providers.WorkspaceNotification {
	if values == nil {
		return []providers.WorkspaceNotification{}
	}
	return values
}
