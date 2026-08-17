package catalog

import (
	"context"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

type GetDetails struct{ reader ports.ServiceDetailsReader }

func NewGetDetails(reader ports.ServiceDetailsReader) *GetDetails { return &GetDetails{reader: reader} }

func (useCase *GetDetails) Execute(ctx context.Context, uid, serviceID string) (domaincatalog.Details, error) {
	return useCase.reader.FindDetails(ctx, uid, strings.TrimSpace(serviceID))
}
