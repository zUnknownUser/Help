package profiles

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type UpdateProfile struct {
	writer ports.ProfileUpdaterRepository
}

func NewUpdateProfile(writer ports.ProfileUpdaterRepository) *UpdateProfile {
	return &UpdateProfile{writer: writer}
}

func (useCase *UpdateProfile) Execute(
	ctx context.Context,
	uid string,
	input ports.ProfileUpdateInput,
) (domainprofiles.Profile, error) {
	var professional *domainprofiles.Professional
	if input.Professional != nil {
		professional = &domainprofiles.Professional{
			Title: input.Professional.Title, Bio: input.Professional.Bio,
			YearsExperience: input.Professional.YearsExperience,
			ServiceRadiusKM: input.Professional.ServiceRadiusKM,
		}
	}
	update, err := domainprofiles.NewUpdate(domainprofiles.Update{
		DisplayName: input.DisplayName,
		Phone:       input.Phone,
		Preferences: domainprofiles.Preferences{
			ContactPreference:         input.ContactPreference,
			PhotoVisibility:           input.PhotoVisibility,
			LastSeenVisibility:        input.LastSeenVisibility,
			ShowOnline:                input.ShowOnline,
			AllowConversationRequests: input.AllowConversationRequests,
		},
		Professional: professional,
	})
	if err != nil {
		return domainprofiles.Profile{}, err
	}
	return useCase.writer.Update(ctx, uid, update)
}
