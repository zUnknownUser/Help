package httpapi

import (
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type managedServiceResponse struct {
	ID              string  `json:"id"`
	CategoryID      string  `json:"category_id"`
	Title           string  `json:"title"`
	Description     string  `json:"description"`
	DurationMinutes int     `json:"duration_minutes"`
	PriceCents      int     `json:"price_cents"`
	ImageURL        string  `json:"image_url"`
	Rating          float64 `json:"rating"`
	Reviews         int     `json:"reviews"`
	Published       bool    `json:"published"`
	UpdatedAt       string  `json:"updated_at"`
}

func newManagedServiceResponse(service catalog.Service) managedServiceResponse {
	return managedServiceResponse{
		ID: service.ID, CategoryID: service.CategoryID, Title: service.Title,
		Description: service.Description, DurationMinutes: service.DurationMinutes,
		PriceCents: service.PriceCents, ImageURL: service.ImageURL,
		Rating: service.Rating, Reviews: service.Reviews, Published: service.Active,
		UpdatedAt: service.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

func newProviderHomeResponse(workspace providers.Workspace) map[string]any {
	services := make([]managedServiceResponse, 0, len(workspace.Services))
	for _, service := range workspace.Services {
		services = append(services, newManagedServiceResponse(service))
	}
	categories := make([]map[string]string, 0, len(workspace.Categories))
	for _, category := range workspace.Categories {
		categories = append(categories, map[string]string{
			"id": category.ID, "name": category.Name, "icon_key": category.IconKey,
		})
	}
	requests := make([]map[string]any, 0, len(workspace.RecentRequests))
	for _, request := range workspace.RecentRequests {
		requests = append(requests, newProviderRequestResponse(request))
	}
	notifications := make([]map[string]any, 0, len(workspace.Notifications))
	for _, notification := range workspace.Notifications {
		notifications = append(notifications, map[string]any{
			"id": notification.ID, "title": notification.Title,
			"body": notification.Body, "read": notification.Read,
			"created_at": notification.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	alerts := make([]map[string]string, 0, len(workspace.Alerts))
	for _, alert := range workspace.Alerts {
		alerts = append(alerts, map[string]string{
			"kind": alert.Kind, "title": alert.Title, "message": alert.Message,
		})
	}
	return map[string]any{
		"provider": map[string]any{
			"id": workspace.Overview.ProviderID, "display_name": workspace.Overview.DisplayName,
			"status": workspace.Overview.Status, "active": workspace.Overview.Active,
			"accepting_requests": workspace.Overview.AcceptingRequests,
		},
		"location": map[string]any{
			"address":   workspace.Overview.Location.Address,
			"latitude":  workspace.Overview.Location.Latitude,
			"longitude": workspace.Overview.Location.Longitude,
		},
		"summary": map[string]int{
			"total_services":       workspace.Summary.TotalServices,
			"published_services":   workspace.Summary.PublishedServices,
			"paused_services":      workspace.Summary.PausedServices,
			"pending_requests":     workspace.Summary.PendingRequests,
			"unread_messages":      workspace.Summary.UnreadMessages,
			"unread_notifications": workspace.Summary.UnreadNotifications,
		},
		"alerts":          alerts,
		"categories":      categories,
		"services":        services,
		"recent_requests": requests,
		"notifications":   notifications,
	}
}

func newProviderRequestResponse(request providers.ServiceRequest) map[string]any {
	response := map[string]any{
		"id": request.ID, "service_id": request.ServiceID,
		"service_title": request.ServiceTitle, "customer_name": request.CustomerName,
		"status": request.Status, "note": request.Note,
		"created_at": request.CreatedAt.UTC().Format(time.RFC3339),
	}
	if request.ScheduledFor != nil {
		response["scheduled_for"] = request.ScheduledFor.UTC().Format(time.RFC3339)
	}
	return response
}
