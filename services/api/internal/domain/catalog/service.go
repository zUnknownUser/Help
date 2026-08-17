package catalog

import (
	"errors"
	"time"
)

var ErrServiceNotFound = errors.New("public service not found")

type Service struct {
	ID              string
	ProviderID      string
	CategoryID      string
	Title           string
	Description     string
	Rating          float64
	Reviews         int
	DurationMinutes int
	PriceCents      int
	OldPriceCents   int
	ImageURL        string
	ImageAlignment  float64
	Badge           string
	Active          bool
	DistanceKM      *float64
	PublishedAt     *time.Time
	CreatedAt       time.Time
	UpdatedAt       time.Time
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

type ViewerAddress struct {
	Label, FormattedAddress string
	Latitude, Longitude     float64
}

type Details struct {
	Listing
	ProviderUserID       string
	ServiceArea          string
	ViewerAddress        *ViewerAddress
	CanRequest           bool
	RequestBlockedReason string
}

type Page struct {
	Items      []Listing
	NextCursor string
}
