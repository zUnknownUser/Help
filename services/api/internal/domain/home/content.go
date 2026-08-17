package home

import (
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	"github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type Content struct {
	Frame      Frame
	Viewer     Viewer
	Promotions []promotions.Promotion
	Categories []categories.Category
	Services   []RecommendedService
	MatchRunID string
}

type RecommendedService struct {
	Service      catalog.Service
	Provider     providers.Provider
	MatchReasons []matchmaking.Reason
}

type Frame struct {
	SearchPlaceholder    string
	CategoriesTitle      string
	RecommendationsTitle string
	Benefits             []Benefit
}

type Viewer struct {
	Location                Location
	Notifications           []Notification
	UnreadNotificationCount int
}

type Location struct {
	Address           string
	AvailabilityLabel string
	Latitude          *float64
	Longitude         *float64
}

type Notification struct {
	ID        string
	Title     string
	Body      string
	Kind      string
	Data      map[string]string
	Read      bool
	CreatedAt string
}

type Benefit struct {
	ID      string
	Label   string
	IconKey string
}
