package catalog_test

import (
	"errors"
	"testing"

	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

func TestNewServiceDraftNormalizesValidInput(t *testing.T) {
	t.Parallel()

	draft, err := domaincatalog.NewServiceDraft(
		"  Limpeza residencial  ", "  Limpeza completa do imovel.  ",
		" house-cleaning ", 120, 15990, " https://example.com/image.jpg ", true,
	)

	if err != nil {
		t.Fatalf("NewServiceDraft() error = %v", err)
	}
	if draft.Title != "Limpeza residencial" || draft.CategoryID != "house-cleaning" {
		t.Fatalf("draft was not normalized: %+v", draft)
	}
}

func TestNewServiceDraftRejectsInvalidFields(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name        string
		title       string
		description string
		duration    int
		price       int
		imageURL    string
		want        error
	}{
		{name: "title", title: "x", description: "Descricao valida", duration: 60, price: 1000, want: domaincatalog.ErrInvalidServiceTitle},
		{name: "description", title: "Servico", description: "curta", duration: 60, price: 1000, want: domaincatalog.ErrInvalidServiceDescription},
		{name: "duration", title: "Servico", description: "Descricao valida", duration: 0, price: 1000, want: domaincatalog.ErrInvalidServiceDuration},
		{name: "price", title: "Servico", description: "Descricao valida", duration: 60, price: -1, want: domaincatalog.ErrInvalidServicePrice},
		{name: "image URL", title: "Servico", description: "Descricao valida", duration: 60, price: 1000, imageURL: "file:///tmp/a.jpg", want: domaincatalog.ErrInvalidServiceImageURL},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()
			_, err := domaincatalog.NewServiceDraft(
				test.title, test.description, "", test.duration, test.price,
				test.imageURL, false,
			)
			if !errors.Is(err, test.want) {
				t.Fatalf("error = %v, want %v", err, test.want)
			}
		})
	}
}
