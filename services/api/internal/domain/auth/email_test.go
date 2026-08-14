package auth_test

import (
	"testing"

	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

func TestParseEmail(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "normaliza espaços e caixa", input: "  User@Example.COM ", want: "user@example.com"},
		{name: "rejeita vazio", input: "", wantErr: true},
		{name: "rejeita formato inválido", input: "usuario@", wantErr: true},
		{name: "rejeita nome com endereço", input: "User <user@example.com>", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			email, err := domainauth.ParseEmail(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatal("ParseEmail() deveria retornar erro")
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseEmail() erro inesperado: %v", err)
			}
			if email.String() != tt.want {
				t.Fatalf("ParseEmail() = %q; esperado %q", email, tt.want)
			}
		})
	}
}
