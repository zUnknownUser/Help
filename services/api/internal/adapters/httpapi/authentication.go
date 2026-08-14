package httpapi

import (
	"context"
	"net/http"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type identityContextKey struct{}

func requireAuth(verifier ports.IDTokenVerifier, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rawToken, ok := bearerToken(r.Header.Get("Authorization"))
		if !ok || verifier == nil {
			writeUnauthorized(w)
			return
		}
		identity, err := verifier.VerifyIDToken(r.Context(), rawToken)
		if err != nil {
			writeUnauthorized(w)
			return
		}
		ctx := context.WithValue(r.Context(), identityContextKey{}, identity)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func authenticatedIdentity(ctx context.Context) (ports.AuthenticatedIdentity, bool) {
	identity, ok := ctx.Value(identityContextKey{}).(ports.AuthenticatedIdentity)
	return identity, ok
}

func bearerToken(header string) (string, bool) {
	scheme, token, found := strings.Cut(strings.TrimSpace(header), " ")
	return token, found && strings.EqualFold(scheme, "Bearer") && token != ""
}

func writeUnauthorized(w http.ResponseWriter) {
	writeJSON(w, http.StatusUnauthorized, map[string]string{"message": "Autenticação necessária."})
}
