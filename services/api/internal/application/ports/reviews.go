package ports

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/domain/reviews"
)

type ReviewRepository interface {
	Upsert(context.Context, string, string, reviews.Draft) (reviews.Review, error)
	ListForRequest(context.Context, string, string) ([]reviews.Review, error)
}

type ReviewService interface {
	Create(context.Context, string, string, ReviewInput) (reviews.Review, error)
	List(context.Context, string, string) ([]reviews.Review, error)
}

type ReviewInput struct {
	Rating  int
	Comment string
}
