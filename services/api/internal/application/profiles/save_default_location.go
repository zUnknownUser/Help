package profiles

import (
	"context"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type SaveDefaultLocation struct{ writer ports.DefaultLocationWriter }

func NewSaveDefaultLocation(writer ports.DefaultLocationWriter) *SaveDefaultLocation {
	return &SaveDefaultLocation{writer: writer}
}

func (useCase *SaveDefaultLocation) Execute(
	ctx context.Context,
	uid string,
	input domainprofiles.Location,
) error {
	location, err := domainprofiles.ParseLocation(input)
	if err != nil {
		return fmt.Errorf("parse location: %w", err)
	}
	return useCase.writer.SaveDefault(ctx, uid, location)
}
