package home

import (
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type Content struct {
	Frame      Frame
	Promotions []promotions.Promotion
	Categories []categories.Category
	Services   []RecommendedService
}

type RecommendedService struct {
	Service  catalog.Service
	Provider providers.Provider
}

type Frame struct {
	Location          Location
	SearchPlaceholder string
	Benefits          []Benefit
}

type Location struct {
	Address           string
	AvailabilityLabel string
}

type Benefit struct {
	ID      string
	Label   string
	IconKey string
}
