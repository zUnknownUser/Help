package catalog

import (
	"errors"
	"net/url"
	"strings"
	"unicode/utf8"
)

var (
	ErrInvalidServiceTitle       = errors.New("invalid service title")
	ErrInvalidServiceDescription = errors.New("invalid service description")
	ErrInvalidServiceCategory    = errors.New("invalid service category")
	ErrInvalidServiceDuration    = errors.New("invalid service duration")
	ErrInvalidServicePrice       = errors.New("invalid service price")
	ErrInvalidServiceImageURL    = errors.New("invalid service image URL")
)

type ServiceDraft struct {
	Title           string
	Description     string
	CategoryID      string
	DurationMinutes int
	PriceCents      int
	OldPriceCents   *int
	ImageURL        string
	Published       bool
}

func NewServiceDraft(
	title, description, categoryID string,
	durationMinutes, priceCents int,
	oldPriceCents *int,
	imageURL string,
	published bool,
) (ServiceDraft, error) {
	draft := ServiceDraft{
		Title: strings.TrimSpace(title), Description: strings.TrimSpace(description),
		CategoryID: strings.TrimSpace(categoryID), DurationMinutes: durationMinutes,
		PriceCents: priceCents, OldPriceCents: oldPriceCents,
		ImageURL: strings.TrimSpace(imageURL), Published: published,
	}
	if length := utf8.RuneCountInString(draft.Title); length < 3 || length > 100 {
		return ServiceDraft{}, ErrInvalidServiceTitle
	}
	if length := utf8.RuneCountInString(draft.Description); length < 10 || length > 1000 {
		return ServiceDraft{}, ErrInvalidServiceDescription
	}
	if utf8.RuneCountInString(draft.CategoryID) > 100 {
		return ServiceDraft{}, ErrInvalidServiceCategory
	}
	if draft.DurationMinutes < 15 || draft.DurationMinutes > 1440 {
		return ServiceDraft{}, ErrInvalidServiceDuration
	}
	if draft.PriceCents < 0 || draft.PriceCents > 100_000_000 {
		return ServiceDraft{}, ErrInvalidServicePrice
	}
	if draft.OldPriceCents != nil && (*draft.OldPriceCents <= draft.PriceCents || *draft.OldPriceCents > 100_000_000) {
		return ServiceDraft{}, ErrInvalidServicePrice
	}
	if !validImageURL(draft.ImageURL) {
		return ServiceDraft{}, ErrInvalidServiceImageURL
	}
	return draft, nil
}

func validImageURL(value string) bool {
	if value == "" {
		return true
	}
	if len(value) > 2048 {
		return false
	}
	parsed, err := url.ParseRequestURI(value)
	return err == nil && (parsed.Scheme == "https" || parsed.Scheme == "http") && parsed.Host != ""
}
