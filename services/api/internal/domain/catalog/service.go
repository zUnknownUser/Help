package catalog

import "time"

type Service struct {
	ID              string
	ProviderID      string
	CategoryID      string
	Title           string
	Rating          float64
	Reviews         int
	DurationMinutes int
	PriceCents      int
	OldPriceCents   int
	ImageURL        string
	ImageAlignment  float64
	Badge           string
	DistanceKM      *float64
	CreatedAt       time.Time
}

type Filters struct {
	Query      string
	CategoryID string
	MinPrice   *int
	MaxPrice   *int
	MinRating  *float64
	Verified   *bool
	Latitude   *float64
	Longitude  *float64
	RadiusKM   *float64
	Sort       string
	Cursor     string
	Limit      int
}

type Listing struct {
	Service          Service
	ProviderName     string
	ProviderVerified bool
}

type Page struct {
	Items      []Listing
	NextCursor string
}
