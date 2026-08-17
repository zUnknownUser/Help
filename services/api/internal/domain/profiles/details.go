package profiles

import (
	"errors"
	"regexp"
	"strings"
	"unicode/utf8"
)

var ErrInvalidProfileDetails = errors.New("invalid profile details")

var phoneDigits = regexp.MustCompile(`^[0-9]{10,13}$`)

type Preferences struct {
	ContactPreference         string
	PhotoVisibility           string
	LastSeenVisibility        string
	ShowOnline                bool
	AllowConversationRequests bool
}

type Professional struct {
	Title           string
	Bio             string
	YearsExperience *int
	ServiceRadiusKM int
}

type PortfolioItem struct {
	ID       string
	Caption  string
	Position int
}

type Update struct {
	DisplayName  string
	Phone        string
	Preferences  Preferences
	Professional *Professional
}

func NewUpdate(input Update) (Update, error) {
	name, err := ParseDisplayName(input.DisplayName)
	if err != nil {
		return Update{}, err
	}
	input.DisplayName = name.String()
	input.Phone = profileDigits(input.Phone)
	if input.Phone != "" && !phoneDigits.MatchString(input.Phone) {
		return Update{}, ErrInvalidProfileDetails
	}
	if !oneOf(input.Preferences.ContactPreference, "chat", "phone", "email") ||
		!oneOf(input.Preferences.PhotoVisibility, "everyone", "conversations", "nobody") ||
		!oneOf(input.Preferences.LastSeenVisibility, "everyone", "conversations", "nobody") {
		return Update{}, ErrInvalidProfileDetails
	}
	if input.Preferences.ContactPreference == "phone" && input.Phone == "" {
		return Update{}, ErrInvalidProfileDetails
	}
	if professional := input.Professional; professional != nil {
		professional.Title = strings.Join(strings.Fields(professional.Title), " ")
		professional.Bio = strings.TrimSpace(professional.Bio)
		if utf8.RuneCountInString(professional.Title) > 100 || utf8.RuneCountInString(professional.Bio) > 1000 ||
			professional.ServiceRadiusKM < 1 || professional.ServiceRadiusKM > 100 ||
			(professional.YearsExperience != nil && (*professional.YearsExperience < 0 || *professional.YearsExperience > 80)) {
			return Update{}, ErrInvalidProfileDetails
		}
	}
	return input, nil
}

func profileDigits(value string) string {
	var builder strings.Builder
	for _, char := range value {
		if char >= '0' && char <= '9' {
			builder.WriteRune(char)
		}
	}
	return builder.String()
}

func oneOf(value string, allowed ...string) bool {
	for _, candidate := range allowed {
		if value == candidate {
			return true
		}
	}
	return false
}
