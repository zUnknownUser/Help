package ports

import (
	"context"

	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type ProfileWriter interface {
	Register(ctx context.Context, profile domainprofiles.Profile) (domainprofiles.Profile, error)
}

type ProfileReader interface {
	FindByUID(ctx context.Context, uid string) (domainprofiles.Profile, error)
}

type PublicUser struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

type UserPage struct {
	Users      []PublicUser
	NextCursor string
}

type UserDirectory interface {
	SearchUsers(context.Context, string, string, int, string) (UserPage, error)
}

type ProfileRegistrar interface {
	Execute(
		ctx context.Context,
		identity AuthenticatedIdentity,
		input ProfileRegistrationInput,
	) (domainprofiles.Profile, error)
}

type ProfileRegistrationInput struct {
	DisplayName string
	Role        string
}

type DefaultLocationWriter interface {
	SaveDefault(ctx context.Context, uid string, location domainprofiles.Location) error
}

type DefaultLocationSaver interface {
	Execute(ctx context.Context, uid string, location domainprofiles.Location) error
}
