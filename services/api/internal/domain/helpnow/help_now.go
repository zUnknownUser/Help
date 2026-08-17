package helpnow

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

var (
	ErrInvalidInput       = errors.New("invalid help now input")
	ErrNotFound           = errors.New("help now request not found")
	ErrActiveRequest      = errors.New("customer already has an active help now request")
	ErrForbidden          = errors.New("help now action forbidden")
	ErrProviderIneligible = errors.New("provider is not eligible for help now")
	ErrOfferExpired       = errors.New("help now offer expired")
	ErrAlreadyAssigned    = errors.New("help now request already assigned")
	ErrProviderBusy       = errors.New("provider is no longer available")
	ErrIdempotency        = errors.New("help now idempotency conflict")
	ErrRateLimited        = errors.New("too many help now requests")
)

type Status string

const (
	StatusSearching  Status = "searching"
	StatusAssigned   Status = "assigned"
	StatusNoProvider Status = "no_provider"
	StatusCancelled  Status = "cancelled"
)

type CreateInput struct {
	ClientID, CategoryID, Note, AddressLabel, Address string
	Latitude, Longitude                               float64
}

type Request struct {
	ID, ClientID, CustomerID, CustomerName, CategoryID, CategoryName string
	Note, AddressLabel, Address                                      string
	Status                                                           Status
	Latitude, Longitude                                              float64
	Wave                                                             int
	AssignedProviderID, AssignedProviderName, ServiceRequestID       string
	CreatedAt, UpdatedAt, SearchExpiresAt                            time.Time
}

type Offer struct {
	ID, RequestID, CategoryID, CategoryName, Note, Area string
	DistanceMeters, Wave                                int
	OfferedAt, ExpiresAt                                time.Time
}

type Availability struct {
	Enabled                bool
	Latitude, Longitude    float64
	MaxDistanceKM          int
	HeartbeatAt, ExpiresAt time.Time
}

type Command struct {
	ClientID, OfferID, Action string
}

type DispatchEvent struct {
	UserID, Type, RequestID, OfferID string
}

func NewCreateInput(clientID, categoryID, note, label, address string, latitude, longitude float64) (CreateInput, error) {
	if _, err := uuid.Parse(clientID); err != nil ||
		latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 {
		return CreateInput{}, ErrInvalidInput
	}
	note = strings.Join(strings.Fields(note), " ")
	label, address = strings.TrimSpace(label), strings.TrimSpace(address)
	if utf8.RuneCountInString(note) > 500 || len(label) > 40 || len(address) < 5 || len(address) > 240 {
		return CreateInput{}, ErrInvalidInput
	}
	return CreateInput{ClientID: clientID, CategoryID: strings.TrimSpace(categoryID), Note: note,
		AddressLabel: label, Address: address, Latitude: latitude, Longitude: longitude}, nil
}

func NewAvailability(enabled bool, latitude, longitude float64, maxDistanceKM int) (Availability, error) {
	if maxDistanceKM == 0 {
		maxDistanceKM = 10
	}
	if maxDistanceKM < 2 || maxDistanceKM > 50 || (enabled && (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180)) {
		return Availability{}, ErrInvalidInput
	}
	return Availability{Enabled: enabled, Latitude: latitude, Longitude: longitude, MaxDistanceKM: maxDistanceKM}, nil
}

func NewCommand(clientID, offerID, action string) (Command, error) {
	if _, err := uuid.Parse(clientID); err != nil {
		return Command{}, ErrInvalidInput
	}
	if _, err := uuid.Parse(offerID); err != nil || (action != "accept" && action != "decline") {
		return Command{}, ErrInvalidInput
	}
	return Command{ClientID: clientID, OfferID: offerID, Action: action}, nil
}
