package httpapi

import domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"

type homeEnvelope struct {
	Data homeData `json:"data"`
}

type homeData struct {
	Location            homeLocation    `json:"location"`
	SearchPlaceholder   string          `json:"search_placeholder"`
	Promotions          []homePromotion `json:"promotions"`
	Categories          []homeCategory  `json:"categories"`
	RecommendedServices []homeService   `json:"recommended_services"`
	Benefits            []homeBenefit   `json:"benefits"`
}

type homeLocation struct {
	Address           string `json:"address"`
	AvailabilityLabel string `json:"availability_label"`
}

type homePromotion struct {
	ID       string             `json:"id"`
	Eyebrow  string             `json:"eyebrow"`
	Title    string             `json:"title"`
	ImageURL string             `json:"image_url,omitempty"`
	Features []promotionFeature `json:"features"`
	Actions  []promotionAction  `json:"actions"`
}

type promotionFeature struct {
	IconKey string `json:"icon_key"`
	Label   string `json:"label"`
}

type promotionAction struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	IconKey string `json:"icon_key"`
	Style   string `json:"style"`
}

type homeCategory struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	IconKey string `json:"icon_key"`
}

type homeService struct {
	ID              string       `json:"id"`
	Title           string       `json:"title"`
	Rating          float64      `json:"rating"`
	Reviews         int          `json:"reviews"`
	DurationMinutes int          `json:"duration_minutes"`
	PriceCents      int          `json:"price_cents"`
	OldPriceCents   int          `json:"old_price_cents"`
	ImageURL        string       `json:"image_url,omitempty"`
	ImageAlignment  float64      `json:"image_alignment"`
	Badge           string       `json:"badge,omitempty"`
	Provider        homeProvider `json:"provider"`
}

type homeProvider struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Verified bool   `json:"verified"`
}

type homeBenefit struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	IconKey string `json:"icon_key"`
}

func newHomeResponse(content domainhome.Content) homeEnvelope {
	data := homeData{
		Location: homeLocation{
			Address: content.Frame.Location.Address, AvailabilityLabel: content.Frame.Location.AvailabilityLabel,
		},
		SearchPlaceholder:   content.Frame.SearchPlaceholder,
		Promotions:          make([]homePromotion, 0, len(content.Promotions)),
		Categories:          make([]homeCategory, 0, len(content.Categories)),
		RecommendedServices: make([]homeService, 0, len(content.Services)),
		Benefits:            make([]homeBenefit, 0, len(content.Frame.Benefits)),
	}
	for _, promotion := range content.Promotions {
		item := homePromotion{
			ID: promotion.ID, Eyebrow: promotion.Eyebrow,
			Title: promotion.Title, ImageURL: promotion.ImageURL,
			Features: make([]promotionFeature, 0, len(promotion.Features)),
			Actions:  make([]promotionAction, 0, len(promotion.Actions)),
		}
		for _, feature := range promotion.Features {
			item.Features = append(item.Features, promotionFeature{IconKey: feature.IconKey, Label: feature.Label})
		}
		for _, action := range promotion.Actions {
			item.Actions = append(item.Actions, promotionAction{ID: action.ID, Label: action.Label, IconKey: action.IconKey, Style: action.Style})
		}
		data.Promotions = append(data.Promotions, item)
	}
	for _, category := range content.Categories {
		data.Categories = append(data.Categories, homeCategory{ID: category.ID, Name: category.Name, IconKey: category.IconKey})
	}
	for _, recommendation := range content.Services {
		service, provider := recommendation.Service, recommendation.Provider
		data.RecommendedServices = append(data.RecommendedServices, homeService{
			ID: service.ID, Title: service.Title, Rating: service.Rating, Reviews: service.Reviews,
			DurationMinutes: service.DurationMinutes, PriceCents: service.PriceCents,
			OldPriceCents: service.OldPriceCents, ImageURL: service.ImageURL,
			ImageAlignment: service.ImageAlignment, Badge: service.Badge,
			Provider: homeProvider{ID: provider.ID, Name: provider.Name, Verified: provider.Verified},
		})
	}
	for _, benefit := range content.Frame.Benefits {
		data.Benefits = append(data.Benefits, homeBenefit{ID: benefit.ID, Label: benefit.Label, IconKey: benefit.IconKey})
	}
	return homeEnvelope{Data: data}
}
