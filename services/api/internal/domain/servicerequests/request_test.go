package servicerequests_test

import (
	"errors"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

func TestNoShowOnlyBecomesAvailableAfterScheduledTime(t *testing.T) {
	scheduled := time.Date(2026, 8, 17, 12, 0, 0, 0, time.UTC)
	request := servicerequests.Request{Status: servicerequests.StatusAccepted, ViewerRole: servicerequests.ViewerProvider, ScheduledFor: scheduled}
	before := servicerequests.AvailableTransitionsFor(request, scheduled.Add(-time.Minute))
	after := servicerequests.AvailableTransitionsFor(request, scheduled)
	contains := func(values []servicerequests.Status, target servicerequests.Status) bool {
		for _, value := range values {
			if value == target {
				return true
			}
		}
		return false
	}
	if contains(before, servicerequests.StatusNoShow) {
		t.Fatalf("before=%v", before)
	}
	if !contains(after, servicerequests.StatusNoShow) {
		t.Fatalf("after=%v", after)
	}
}

func TestNewDraftNormalizesValidInput(t *testing.T) {
	t.Parallel()
	scheduled := time.Date(2026, 8, 17, 15, 30, 0, 0, time.UTC)
	draft, err := servicerequests.NewDraft(
		"c349a83e-fbd9-4d59-984d-0516b7f981b2", scheduled, "  Levar material, por favor.  ",
	)
	if err != nil {
		t.Fatal(err)
	}
	if draft.Note != "Levar material, por favor." || !draft.ScheduledFor.Equal(scheduled) {
		t.Fatalf("draft = %+v", draft)
	}
}

func TestNewDraftRejectsMalformedInput(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name, clientID, note string
		scheduled            time.Time
		want                 error
	}{
		{name: "client id", clientID: "invalid", scheduled: time.Now(), want: servicerequests.ErrInvalidClientID},
		{name: "schedule", clientID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", want: servicerequests.ErrInvalidSchedule},
		{name: "note", clientID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", scheduled: time.Now(), note: string(make([]byte, 1001)), want: servicerequests.ErrInvalidNote},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			_, err := servicerequests.NewDraft(test.clientID, test.scheduled, test.note)
			if !errors.Is(err, test.want) {
				t.Fatalf("error = %v, want %v", err, test.want)
			}
		})
	}
}

func TestLifecycleTransitionsAreExplicitPerActor(t *testing.T) {
	t.Parallel()
	allowed := []struct {
		from, to servicerequests.Status
		role     servicerequests.ViewerRole
	}{
		{servicerequests.StatusPending, servicerequests.StatusAccepted, servicerequests.ViewerProvider},
		{servicerequests.StatusPending, servicerequests.StatusRejected, servicerequests.ViewerProvider},
		{servicerequests.StatusAccepted, servicerequests.StatusInProgress, servicerequests.ViewerProvider},
		{servicerequests.StatusInProgress, servicerequests.StatusCompleted, servicerequests.ViewerProvider},
		{servicerequests.StatusPending, servicerequests.StatusCancelled, servicerequests.ViewerCustomer},
		{servicerequests.StatusAccepted, servicerequests.StatusCancelled, servicerequests.ViewerCustomer},
	}
	for _, transition := range allowed {
		if !servicerequests.CanTransition(transition.from, transition.to, transition.role) {
			t.Fatalf("expected %s -> %s for %s", transition.from, transition.to, transition.role)
		}
	}
	if servicerequests.CanTransition(servicerequests.StatusPending, servicerequests.StatusCompleted, servicerequests.ViewerProvider) ||
		servicerequests.CanTransition(servicerequests.StatusPending, servicerequests.StatusAccepted, servicerequests.ViewerCustomer) {
		t.Fatal("invalid transition was accepted")
	}
}
