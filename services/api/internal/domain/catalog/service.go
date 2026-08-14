package catalog

type Service struct {
	ID              string
	ProviderID      string
	Title           string
	Rating          float64
	Reviews         int
	DurationMinutes int
	PriceCents      int
	OldPriceCents   int
	ImageURL        string
	ImageAlignment  float64
	Badge           string
}
