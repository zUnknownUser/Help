package servicerequests_test

import (
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

const quoteCommandID = "c349a83e-fbd9-4d59-984d-0516b7f981b2"

func TestNewQuoteDraftNormalizesItemsAndCalculatesDiscountedTotal(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 8, 19, 12, 0, 0, 0, time.UTC)
	expiresAt := now.Add(48 * time.Hour)
	items := []servicerequests.QuoteItemDraft{
		{Kind: "labor", Description: "  Mão   de obra ", AmountCents: 20000},
		{Kind: "material", Description: "Resistência", AmountCents: 7500},
		{Kind: "discount", Description: "Desconto comercial", AmountCents: 2500},
	}

	draft, err := servicerequests.NewQuoteDraft(
		quoteCommandID, "  Inclui instalação.  ", 3, &expiresAt, items, now,
	)
	if err != nil {
		t.Fatal(err)
	}
	if draft.TotalCents != 25000 || draft.Message != "Inclui instalação." {
		t.Fatalf("draft = %+v", draft)
	}
	if draft.Items[0].Description != "Mão de obra" || draft.Items[2].Position != 2 {
		t.Fatalf("items = %+v", draft.Items)
	}
	if len(draft.IntentHash) != 64 {
		t.Fatalf("intent hash = %q", draft.IntentHash)
	}

	retry, err := servicerequests.NewQuoteDraft(
		quoteCommandID, "Inclui instalação.", 3, &expiresAt, items, now,
	)
	if err != nil || retry.IntentHash != draft.IntentHash {
		t.Fatalf("retry hash = %q, error = %v", retry.IntentHash, err)
	}
}

func TestNewQuoteDraftRejectsInvalidMoneyItemsAndExpiry(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 8, 19, 12, 0, 0, 0, time.UTC)
	valid := []servicerequests.QuoteItemDraft{
		{Kind: "labor", Description: "Mão de obra", AmountCents: 10000},
	}
	tooSoon := now.Add(14 * time.Minute)
	tooLate := now.Add(31 * 24 * time.Hour)
	cases := []struct {
		name      string
		clientID  string
		expiresAt *time.Time
		items     []servicerequests.QuoteItemDraft
	}{
		{name: "command", clientID: "invalid", items: valid},
		{name: "empty", clientID: quoteCommandID, items: nil},
		{name: "kind", clientID: quoteCommandID, items: []servicerequests.QuoteItemDraft{{Kind: "fee", Description: "Taxa", AmountCents: 100}}},
		{name: "description", clientID: quoteCommandID, items: []servicerequests.QuoteItemDraft{{Kind: "labor", Description: "x", AmountCents: 100}}},
		{name: "amount", clientID: quoteCommandID, items: []servicerequests.QuoteItemDraft{{Kind: "labor", Description: "Trabalho", AmountCents: 0}}},
		{name: "discount exceeds total", clientID: quoteCommandID, items: []servicerequests.QuoteItemDraft{{Kind: "labor", Description: "Trabalho", AmountCents: 100}, {Kind: "discount", Description: "Desconto", AmountCents: 100}}},
		{name: "expiry too soon", clientID: quoteCommandID, expiresAt: &tooSoon, items: valid},
		{name: "expiry too late", clientID: quoteCommandID, expiresAt: &tooLate, items: valid},
	}

	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			_, err := servicerequests.NewQuoteDraft(
				test.clientID, "", 0, test.expiresAt, test.items, now,
			)
			if !errors.Is(err, servicerequests.ErrInvalidQuote) {
				t.Fatalf("error = %v", err)
			}
		})
	}
}

func TestAttachmentCaptionAndNegotiableStatuses(t *testing.T) {
	t.Parallel()
	caption, err := servicerequests.NormalizeAttachmentCaption("  Antes do reparo  ")
	if err != nil || caption != "Antes do reparo" {
		t.Fatalf("caption = %q, error = %v", caption, err)
	}
	if _, err := servicerequests.NormalizeAttachmentCaption(strings.Repeat("a", 161)); !errors.Is(err, servicerequests.ErrInvalidAttachment) {
		t.Fatalf("error = %v", err)
	}
	if !servicerequests.CanNegotiate(servicerequests.StatusPending) ||
		!servicerequests.CanNegotiate(servicerequests.StatusAccepted) ||
		servicerequests.CanNegotiate(servicerequests.StatusInProgress) {
		t.Fatal("negotiable status policy changed")
	}
}
