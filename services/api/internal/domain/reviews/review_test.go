package reviews_test

import (
	"strings"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/domain/reviews"
)

func TestNewDraftValidatesRatingAndComment(t *testing.T) {
	t.Parallel()
	if _, err := reviews.NewDraft(0, ""); err == nil {
		t.Fatal("rating zero should fail")
	}
	if _, err := reviews.NewDraft(5, strings.Repeat("a", 801)); err == nil {
		t.Fatal("long comment should fail")
	}
	draft, err := reviews.NewDraft(4, "  ótimo atendimento  ")
	if err != nil || draft.Comment != "ótimo atendimento" {
		t.Fatalf("draft = %+v, err = %v", draft, err)
	}
}
