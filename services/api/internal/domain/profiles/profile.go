package profiles

import (
	"errors"
	"strings"
	"unicode/utf8"

	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

var (
	ErrInvalidRole           = errors.New("invalid profile role")
	ErrInvalidDisplayName    = errors.New("invalid display name")
	ErrProfileNotFound       = errors.New("profile not found")
	ErrInvalidProviderStatus = errors.New("invalid provider status")
)

type Role string

const (
	CustomerRole Role = "customer"
	ProviderRole Role = "provider"
)

type ProviderStatus string

const (
	PendingProviderStatus  ProviderStatus = "pending"
	ApprovedProviderStatus ProviderStatus = "approved"
	RejectedProviderStatus ProviderStatus = "rejected"
)

func ParseProviderStatus(value string) (ProviderStatus, error) {
	status := ProviderStatus(strings.TrimSpace(value))
	if status != PendingProviderStatus &&
		status != ApprovedProviderStatus &&
		status != RejectedProviderStatus {
		return "", ErrInvalidProviderStatus
	}
	return status, nil
}

func ParseRole(value string) (Role, error) {
	role := Role(strings.TrimSpace(value))
	if role != CustomerRole && role != ProviderRole {
		return "", ErrInvalidRole
	}
	return role, nil
}

type DisplayName string

func ParseDisplayName(value string) (DisplayName, error) {
	normalized := strings.Join(strings.Fields(value), " ")
	length := utf8.RuneCountInString(normalized)
	if length < 2 || length > 80 {
		return "", ErrInvalidDisplayName
	}
	return DisplayName(normalized), nil
}

func (name DisplayName) String() string { return string(name) }

type Profile struct {
	UID            string
	Email          domainauth.Email
	DisplayName    string
	ActiveRole     Role
	Roles          []Role
	ProviderStatus *ProviderStatus
}
