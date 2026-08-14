package home

import (
	"context"
	"fmt"

	"golang.org/x/sync/errgroup"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
)

type GetHomeBase struct {
	categories ports.CategoryReader
	promotions ports.PromotionReader
	frame      ports.HomeFrameReader
}

func NewGetHomeBase(
	categories ports.CategoryReader,
	promotions ports.PromotionReader,
	frame ports.HomeFrameReader,
) *GetHomeBase {
	return &GetHomeBase{categories, promotions, frame}
}

func (uc *GetHomeBase) ExecuteBase(ctx context.Context) (domainhome.Content, error) {
	var (
		categoryList  []categories.Category
		promotionList []promotions.Promotion
		frame         domainhome.Frame
	)

	group, groupCtx := errgroup.WithContext(ctx)
	group.Go(func() (err error) {
		categoryList, err = uc.categories.ListPopular(groupCtx)
		return wrapSourceError("categories", err)
	})
	group.Go(func() (err error) {
		promotionList, err = uc.promotions.ListActive(groupCtx)
		return wrapSourceError("promotions", err)
	})
	group.Go(func() (err error) {
		frame, err = uc.frame.GetFrame(groupCtx)
		return wrapSourceError("home frame", err)
	})
	if err := group.Wait(); err != nil {
		return domainhome.Content{}, err
	}

	return domainhome.Content{
		Frame: frame, Promotions: promotionList,
		Categories: categoryList,
	}, nil
}

func wrapSourceError(source string, err error) error {
	if err == nil {
		return nil
	}
	return fmt.Errorf("load %s: %w", source, err)
}
