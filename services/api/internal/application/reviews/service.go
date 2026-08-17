package reviews

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainreviews "github.com/vendlydigital/help/services/api/internal/domain/reviews"
)

type Service struct{ repository ports.ReviewRepository }

func NewService(repository ports.ReviewRepository) *Service { return &Service{repository: repository} }

func (service *Service) Create(ctx context.Context, uid, requestID string, input ports.ReviewInput) (domainreviews.Review, error) {
	draft, err := domainreviews.NewDraft(input.Rating, input.Comment)
	if err != nil {
		return domainreviews.Review{}, err
	}
	return service.repository.Upsert(ctx, uid, requestID, draft)
}

func (service *Service) List(ctx context.Context, uid, requestID string) ([]domainreviews.Review, error) {
	return service.repository.ListForRequest(ctx, uid, requestID)
}
