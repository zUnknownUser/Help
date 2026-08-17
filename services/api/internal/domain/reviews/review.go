package reviews

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"
)

var (
	ErrInvalid    = errors.New("invalid review")
	ErrForbidden  = errors.New("review forbidden")
	ErrNotFound   = errors.New("service request not found")
	ErrIncomplete = errors.New("service request is not completed")
)

type Review struct {
	ID, RequestID, ReviewerUID, RevieweeUID, ReviewerRole, Comment string
	Rating                                                         int
	CreatedAt, UpdatedAt                                           time.Time
}

type Draft struct {
	Rating  int
	Comment string
}

func NewDraft(rating int, comment string) (Draft, error) {
	comment = strings.TrimSpace(comment)
	if rating < 1 || rating > 5 || utf8.RuneCountInString(comment) > 800 {
		return Draft{}, ErrInvalid
	}
	return Draft{Rating: rating, Comment: comment}, nil
}
