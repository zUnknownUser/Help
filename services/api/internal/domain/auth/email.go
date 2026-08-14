package auth

import (
	"errors"
	"net/mail"
	"strings"
)

var ErrInvalidEmail = errors.New("invalid email")

type Email string

func ParseEmail(raw string) (Email, error) {
	normalized := strings.ToLower(strings.TrimSpace(raw))
	if normalized == "" || len(normalized) > 254 {
		return "", ErrInvalidEmail
	}

	address, err := mail.ParseAddress(normalized)
	if err != nil || address.Address != normalized || address.Name != "" {
		return "", ErrInvalidEmail
	}

	parts := strings.Split(normalized, "@")
	if len(parts) != 2 || parts[0] == "" || !strings.Contains(parts[1], ".") {
		return "", ErrInvalidEmail
	}

	return Email(normalized), nil
}

func (e Email) String() string {
	return string(e)
}
