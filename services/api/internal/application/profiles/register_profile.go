package profiles

import (
	"context"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type RegisterProfileInput = ports.ProfileRegistrationInput

type RegisterProfile struct{ writer ports.ProfileWriter }

func NewRegisterProfile(writer ports.ProfileWriter) *RegisterProfile {
	return &RegisterProfile{writer: writer}
}

func (register *RegisterProfile) Execute(
	ctx context.Context,
	identity ports.AuthenticatedIdentity,
	input RegisterProfileInput,
) (domainprofiles.Profile, error) {
	name, err := domainprofiles.ParseDisplayName(input.DisplayName)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("parse display name: %w", err)
	}
	role, err := domainprofiles.ParseRole(input.Role)
	if err != nil {
		return domainprofiles.Profile{}, fmt.Errorf("parse role: %w", err)
	}
	profile := domainprofiles.Profile{
		UID: identity.UID, Email: identity.Email, DisplayName: name.String(),
		ActiveRole: role, Roles: []domainprofiles.Role{role},
	}
	return register.writer.Register(ctx, profile)
}
