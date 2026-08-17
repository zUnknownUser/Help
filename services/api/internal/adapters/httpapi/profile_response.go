package httpapi

import domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"

type profileEnvelope struct {
	Data profileResponse `json:"data"`
}

type profileResponse struct {
	Email                     string                       `json:"email"`
	DisplayName               string                       `json:"display_name"`
	ActiveRole                string                       `json:"active_role"`
	Roles                     []string                     `json:"roles"`
	ProviderStatus            *string                      `json:"provider_status,omitempty"`
	Phone                     string                       `json:"phone"`
	AvatarURL                 string                       `json:"avatar_url,omitempty"`
	ContactPreference         string                       `json:"contact_preference"`
	PhotoVisibility           string                       `json:"photo_visibility"`
	LastSeenVisibility        string                       `json:"last_seen_visibility"`
	ShowOnline                bool                         `json:"show_online"`
	AllowConversationRequests bool                         `json:"allow_conversation_requests"`
	Professional              *professionalProfileResponse `json:"professional,omitempty"`
	Portfolio                 []portfolioItemResponse      `json:"portfolio"`
	Rating                    float64                      `json:"rating"`
	ReviewCount               int                          `json:"review_count"`
	Completeness              int                          `json:"completeness"`
}

type professionalProfileResponse struct {
	Title           string `json:"title"`
	Bio             string `json:"bio"`
	YearsExperience *int   `json:"years_experience,omitempty"`
	ServiceRadiusKM int    `json:"service_radius_km"`
}

type portfolioItemResponse struct {
	ID      string `json:"id"`
	Caption string `json:"caption"`
	URL     string `json:"url"`
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
	portfolio := make([]portfolioItemResponse, 0, len(profile.Portfolio))
	for _, item := range profile.Portfolio {
		portfolio = append(portfolio, portfolioItemResponse{ID: item.ID, Caption: item.Caption, URL: "/v1/profile/portfolio/" + item.ID})
	}
	var professional *professionalProfileResponse
	if profile.Professional != nil {
		professional = &professionalProfileResponse{Title: profile.Professional.Title, Bio: profile.Professional.Bio,
			YearsExperience: profile.Professional.YearsExperience, ServiceRadiusKM: profile.Professional.ServiceRadiusKM}
	}
	avatarURL := ""
	if profile.AvatarPresent {
		avatarURL = "/v1/profile/avatar/" + profile.UID
	}
	return profileEnvelope{Data: profileResponse{
		Email:          profile.Email.String(),
		DisplayName:    profile.DisplayName,
		ActiveRole:     string(profile.ActiveRole),
		Roles:          roles,
		ProviderStatus: providerStatus,
		Phone:          profile.Phone, AvatarURL: avatarURL,
		ContactPreference:         profile.Preferences.ContactPreference,
		PhotoVisibility:           profile.Preferences.PhotoVisibility,
		LastSeenVisibility:        profile.Preferences.LastSeenVisibility,
		ShowOnline:                profile.Preferences.ShowOnline,
		AllowConversationRequests: profile.Preferences.AllowConversationRequests,
		Professional:              professional, Portfolio: portfolio,
		Rating: profile.Rating, ReviewCount: profile.ReviewCount, Completeness: profile.Completeness,
	}}
}
