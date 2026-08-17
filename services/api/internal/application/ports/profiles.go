package ports

import (
	"context"
	"io"

	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type ProfileRegistrarRepository interface {
	Register(ctx context.Context, profile domainprofiles.Profile) (domainprofiles.Profile, error)
}

type ProfileUpdaterRepository interface {
	Update(ctx context.Context, uid string, update domainprofiles.Update) (domainprofiles.Profile, error)
}

type ProfileEmailRepository interface {
	SyncEmail(context.Context, string, string) (domainprofiles.Profile, error)
}

type ProfileReader interface {
	FindByUID(ctx context.Context, uid string) (domainprofiles.Profile, error)
}

type PublicUser struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	Role        string `json:"role"`
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

type ProfileUpdateInput struct {
	DisplayName               string
	Phone                     string
	ContactPreference         string
	PhotoVisibility           string
	LastSeenVisibility        string
	ShowOnline                bool
	AllowConversationRequests bool
	Professional              *ProfessionalProfileInput
}

type ProfessionalProfileInput struct {
	Title           string
	Bio             string
	YearsExperience *int
	ServiceRadiusKM int
}

type ProfileUpdater interface {
	Execute(context.Context, string, ProfileUpdateInput) (domainprofiles.Profile, error)
}

type ProfileEmailSynchronizer interface {
	Execute(context.Context, AuthenticatedIdentity) (domainprofiles.Profile, error)
}

type ProfileMedia struct {
	StorageKey  string
	ContentType string
	OldKey      string
}

type ProfileMediaRepository interface {
	SetAvatar(context.Context, string, string, string) (string, error)
	GetAvatar(context.Context, string, string) (ProfileMedia, error)
	AddPortfolio(context.Context, string, string, string, string) (domainprofiles.PortfolioItem, error)
	GetPortfolio(context.Context, string) (ProfileMedia, error)
	DeletePortfolio(context.Context, string, string) (string, error)
}

type ProfileMediaService interface {
	UploadAvatar(context.Context, string, string, io.Reader) error
	OpenAvatar(context.Context, string, string) (MediaObject, error)
	UploadPortfolio(context.Context, string, string, string, io.Reader) (domainprofiles.PortfolioItem, error)
	OpenPortfolio(context.Context, string) (MediaObject, error)
	DeletePortfolio(context.Context, string, string) error
}

type DefaultLocationWriter interface {
	SaveDefault(ctx context.Context, uid string, location domainprofiles.Location) error
}

type DefaultLocationSaver interface {
	Execute(ctx context.Context, uid string, location domainprofiles.Location) error
}
