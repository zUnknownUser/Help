package helpnow

import (
	"errors"
	"strings"
	"testing"
)

func TestNewCreateInputNormalizesAndValidatesCoordinates(t *testing.T) {
	t.Parallel()
	input, err := NewCreateInput(
		"c349a83e-fbd9-4d59-984d-0516b7f981b2", "plumbing", "  vazamento   forte ",
		"Local atual", "Rua A, 10, Manaus - AM", -3.0816, -59.978,
	)
	if err != nil || input.Note != "vazamento forte" {
		t.Fatalf("input = %+v error = %v", input, err)
	}
	if _, err := NewCreateInput("invalid", "plumbing", "", "", "Rua A", 0, 0); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("invalid client id error = %v", err)
	}
	if _, err := NewCreateInput("c349a83e-fbd9-4d59-984d-0516b7f981b2", "plumbing", strings.Repeat("a", 501), "", "Rua A", 0, 0); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("oversized note error = %v", err)
	}
}

func TestNewAvailabilityProtectsDispatchRadius(t *testing.T) {
	t.Parallel()
	availability, err := NewAvailability(true, -3.1, -60, 0)
	if err != nil || availability.MaxDistanceKM != 10 {
		t.Fatalf("availability = %+v error = %v", availability, err)
	}
	if _, err := NewAvailability(true, 91, 0, 10); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("invalid coordinates error = %v", err)
	}
	if _, err := NewAvailability(true, 0, 0, 51); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("invalid radius error = %v", err)
	}
}

func TestNewCommandRequiresStableIdempotencyIdentity(t *testing.T) {
	t.Parallel()
	command, err := NewCommand(
		"c349a83e-fbd9-4d59-984d-0516b7f981b2",
		"c3dd4de2-e52f-4297-9d4a-a02585631eb4", "accept",
	)
	if err != nil || command.Action != "accept" {
		t.Fatalf("command = %+v error = %v", command, err)
	}
	if _, err := NewCommand(command.ClientID, command.OfferID, "maybe"); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("invalid action error = %v", err)
	}
}
