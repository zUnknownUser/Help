package servicerequests

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

var (
	ErrInvalidQuote       = errors.New("invalid service request quote")
	ErrQuoteNotFound      = errors.New("service request quote not found")
	ErrNegotiationClosed  = errors.New("service request negotiation is closed")
	ErrNegotiationTurn    = errors.New("service request negotiation turn is invalid")
	ErrQuotePending       = errors.New("service request has a pending quote")
	ErrAttachmentLimit    = errors.New("service request attachment limit reached")
	ErrInvalidAttachment  = errors.New("invalid service request attachment")
)

const (
	MaximumRequestAttachments = 8
	MaximumQuoteItems         = 20
	MaximumQuoteRevisions     = 50
)

type QuoteStatus string

const (
	QuoteProposed   QuoteStatus = "proposed"
	QuoteAccepted   QuoteStatus = "accepted"
	QuoteSuperseded QuoteStatus = "superseded"
	QuoteWithdrawn  QuoteStatus = "withdrawn"
)

type QuoteItemKind string

const (
	QuoteLabor    QuoteItemKind = "labor"
	QuoteMaterial QuoteItemKind = "material"
	QuoteAddon    QuoteItemKind = "addon"
	QuoteDiscount QuoteItemKind = "discount"
)

type QuoteItemDraft struct {
	Kind        string
	Description string
	AmountCents int
}

type QuoteItem struct {
	ID, Description string
	Kind            QuoteItemKind
	AmountCents     int
	Position        int
}

type QuoteDraft struct {
	ClientID, Message, IntentHash string
	Items                         []QuoteItem
	TotalCents, ExpectedVersion   int
	ExpiresAt                     *time.Time
}

type Quote struct {
	ID, RequestID, AuthorUID, AuthorName, Message, Currency string
	AuthorRole                                               ViewerRole
	Revision, TotalCents                                     int
	Status                                                   QuoteStatus
	Items                                                    []QuoteItem
	ExpiresAt, AcceptedAt                                    *time.Time
	AcceptedBy                                               string
	CreatedAt                                                time.Time
}

type Attachment struct {
	ID, RequestID, UploaderUID, UploaderName, Caption, ContentType, StorageKey string
	UploaderRole                                                              ViewerRole
	ByteSize                                                                  int64
	CreatedAt                                                                 time.Time
}

type Negotiation struct {
	Attachments []Attachment
	Quotes      []Quote
}

func CanNegotiate(status Status) bool {
	return status == StatusPending || status == StatusAccepted
}

func NewQuoteDraft(
	clientID, message string,
	expectedVersion int,
	expiresAt *time.Time,
	items []QuoteItemDraft,
	now time.Time,
) (QuoteDraft, error) {
	if _, err := uuid.Parse(clientID); err != nil || expectedVersion < 0 || len(items) < 1 || len(items) > MaximumQuoteItems {
		return QuoteDraft{}, ErrInvalidQuote
	}
	message = strings.TrimSpace(message)
	if utf8.RuneCountInString(message) > 1000 {
		return QuoteDraft{}, ErrInvalidQuote
	}
	if expiresAt != nil {
		value := expiresAt.UTC().Truncate(time.Microsecond)
		if value.Before(now.Add(15*time.Minute)) || value.After(now.Add(30*24*time.Hour)) {
			return QuoteDraft{}, ErrInvalidQuote
		}
		expiresAt = &value
	}
	parsed := make([]QuoteItem, 0, len(items))
	total := 0
	for position, raw := range items {
		kind, ok := parseQuoteItemKind(raw.Kind)
		description := strings.Join(strings.Fields(raw.Description), " ")
		if !ok || utf8.RuneCountInString(description) < 2 || utf8.RuneCountInString(description) > 120 || raw.AmountCents < 1 || raw.AmountCents > 100000000 {
			return QuoteDraft{}, ErrInvalidQuote
		}
		if kind == QuoteDiscount {
			total -= raw.AmountCents
		} else {
			total += raw.AmountCents
		}
		parsed = append(parsed, QuoteItem{Kind: kind, Description: description, AmountCents: raw.AmountCents, Position: position})
	}
	if total < 1 || total > 100000000 {
		return QuoteDraft{}, ErrInvalidQuote
	}
	draft := QuoteDraft{ClientID: clientID, Message: message, Items: parsed, TotalCents: total, ExpectedVersion: expectedVersion, ExpiresAt: expiresAt}
	draft.IntentHash = quoteIntentHash(draft)
	return draft, nil
}

func ValidateAcceptCommand(clientID string, expectedVersion int) error {
	if _, err := uuid.Parse(clientID); err != nil || expectedVersion < 0 {
		return ErrInvalidQuote
	}
	return nil
}

func NormalizeAttachmentCaption(value string) (string, error) {
	value = strings.TrimSpace(value)
	if utf8.RuneCountInString(value) > 160 {
		return "", ErrInvalidAttachment
	}
	return value, nil
}

func parseQuoteItemKind(value string) (QuoteItemKind, bool) {
	kind := QuoteItemKind(strings.TrimSpace(value))
	switch kind {
	case QuoteLabor, QuoteMaterial, QuoteAddon, QuoteDiscount:
		return kind, true
	default:
		return "", false
	}
}

func quoteIntentHash(draft QuoteDraft) string {
	builder := strings.Builder{}
	builder.WriteString(draft.Message)
	builder.WriteString(fmt.Sprintf("|%d|%d|", draft.ExpectedVersion, draft.TotalCents))
	if draft.ExpiresAt != nil {
		builder.WriteString(draft.ExpiresAt.UTC().Format(time.RFC3339Nano))
	}
	for _, item := range draft.Items {
		builder.WriteString(fmt.Sprintf("|%s|%s|%d", item.Kind, item.Description, item.AmountCents))
	}
	sum := sha256.Sum256([]byte(builder.String()))
	return hex.EncodeToString(sum[:])
}
