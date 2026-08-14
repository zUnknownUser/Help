package profiles

import (
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"
)

var ErrInvalidLocation = errors.New("invalid location")

type Location struct {
	Label        string
	Address      string
	PostalCode   string
	Street       string
	StreetNumber string
	Complement   string
	District     string
	City         string
	State        string
	Latitude     float64
	Longitude    float64
}

func ParseLocation(input Location) (Location, error) {
	input.Label = normalize(input.Label)
	input.Address = normalize(input.Address)
	input.PostalCode = digitsOnly(input.PostalCode)
	input.Street = normalize(input.Street)
	input.StreetNumber = normalize(input.StreetNumber)
	input.Complement = normalize(input.Complement)
	input.District = normalize(input.District)
	input.City = normalize(input.City)
	input.State = strings.ToUpper(normalize(input.State))
	normalizedLabel := input.Label
	normalizedAddress := input.Address
	if length := utf8.RuneCountInString(normalizedLabel); length < 1 || length > 40 {
		return Location{}, ErrInvalidLocation
	}
	if length := utf8.RuneCountInString(normalizedAddress); length < 5 || length > 240 {
		return Location{}, ErrInvalidLocation
	}
	if input.Latitude < -90 || input.Latitude > 90 || input.Longitude < -180 || input.Longitude > 180 {
		return Location{}, ErrInvalidLocation
	}
	if input.City == "" || len(input.State) != 2 {
		return Location{}, ErrInvalidLocation
	}
	if input.PostalCode != "" && len(input.PostalCode) != 8 {
		return Location{}, ErrInvalidLocation
	}
	return input, nil
}

func normalize(value string) string { return strings.Join(strings.Fields(value), " ") }

func digitsOnly(value string) string {
	var result strings.Builder
	for _, character := range value {
		if character >= '0' && character <= '9' {
			result.WriteRune(character)
		}
	}
	return result.String()
}

func (location Location) String() string {
	return fmt.Sprintf("%s, %s - %s/%s", location.Street, location.StreetNumber, location.City, location.State)
}
