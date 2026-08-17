package profiles

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type SyncEmail struct{ repository ports.ProfileEmailRepository }

func NewSyncEmail(repository ports.ProfileEmailRepository) *SyncEmail {
	return &SyncEmail{repository: repository}
}

func (useCase *SyncEmail) Execute(
	ctx context.Context,
	identity ports.AuthenticatedIdentity,
) (domainprofiles.Profile, error) {
	return useCase.repository.SyncEmail(ctx, identity.UID, identity.Email.String())
}
