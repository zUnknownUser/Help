package healthcheck_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/healthcheck"
)

func TestCheckAcceptsOnlyHealthyResponse(t *testing.T) {
	t.Parallel()

	for name, status := range map[string]int{
		"healthy":   http.StatusOK,
		"unhealthy": http.StatusServiceUnavailable,
	} {
		t.Run(name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(status)
			}))
			defer server.Close()

			err := healthcheck.Check(context.Background(), server.Client(), server.URL)
			if status == http.StatusOK && err != nil {
				t.Fatalf("Check() erro inesperado: %v", err)
			}
			if status != http.StatusOK && err == nil {
				t.Fatal("Check() deveria rejeitar serviço indisponível")
			}
		})
	}
}
