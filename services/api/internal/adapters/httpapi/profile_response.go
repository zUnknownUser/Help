package httpapi

import domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"

type profileEnvelope struct {
	Data profileResponse `json:"data"`
}

type profileResponse struct {
	Email          string   `json:"email"`
	DisplayName    string   `json:"display_name"`
	ActiveRole     string   `json:"active_role"`
	Roles          []string `json:"roles"`
	ProviderStatus *string  `json:"provider_status,omitempty"`
}

func newProfileEnvelope(profile domainprofiles.Profile) profileEnvelope {
	roles := make([]string, len(profile.Roles))
	for index, role := range profile.Roles {
		roles[index] = string(role)
	}
	var providerStatus *string
	if profile.ProviderStatus != nil {
		value := string(*profile.ProviderStatus)
		providerStatus = &value
	}
	return profileEnvelope{Data: profileResponse{
		Email:          profile.Email.String(),
		DisplayName:    profile.DisplayName,
		ActiveRole:     string(profile.ActiveRole),
		Roles:          roles,
		ProviderStatus: providerStatus,
	}}
}
