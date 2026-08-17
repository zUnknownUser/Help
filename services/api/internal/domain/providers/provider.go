package providers

import (
	"errors"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
)

var (
	ErrWorkspaceNotFound   = errors.New("provider workspace not found")
	ErrProviderUnavailable = errors.New("provider is not approved and active")
	ErrServiceNotFound     = errors.New("provider service not found")
)

type Provider struct {
	ID       string
	Name     string
	Verified bool
}

type WorkspaceLocation struct {
	Address   string
	Latitude  *float64
	Longitude *float64
}

type WorkspaceOverview struct {
	ProviderID          string
	DisplayName         string
	Status              string
	Active              bool
	AcceptingRequests   bool
	UnreadMessages      int
	UnreadNotifications int
	PendingRequests     int
	Location            WorkspaceLocation
}

type WorkspaceSummary struct {
	TotalServices       int
	PublishedServices   int
	PausedServices      int
	PendingRequests     int
	UnreadMessages      int
	UnreadNotifications int
}

type WorkspaceAlert struct {
	Kind    string
	Title   string
	Message string
}

type ServiceRequest struct {
	ID, ServiceID, ServiceTitle, CustomerName string
	Status, Note, Address                     string
	QuotedPriceCents                          int
	ScheduledFor                              *time.Time
	CreatedAt                                 time.Time
}

type Workspace struct {
	Overview       WorkspaceOverview
	Summary        WorkspaceSummary
	Alerts         []WorkspaceAlert
	Services       []catalog.Service
	Categories     []categories.Category
	RecentRequests []ServiceRequest
	Notifications  []WorkspaceNotification
}

type WorkspaceNotification struct {
	ID        string
	Title     string
	Body      string
	Kind      string
	Data      map[string]string
	Read      bool
	CreatedAt time.Time
}
