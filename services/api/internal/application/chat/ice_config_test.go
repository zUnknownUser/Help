package chat

import (
	"testing"
	"time"
)

func TestICEConfigIssuesStableTemporaryTURNCredentials(t *testing.T) {
	now := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)
	service := NewICEConfigService(ICEConfig{
		STUNURLs:      []string{"stun:stun.example.com:3478"},
		TURNURLs:      []string{"turn:turn.example.com:3478?transport=udp"},
		TURNSecret:    "secret",
		CredentialTTL: time.Hour,
	}, func() time.Time { return now })

	issued := service.Issue("firebase-user")
	if len(issued.Servers) != 2 {
		t.Fatalf("servers = %d", len(issued.Servers))
	}
	turn := issued.Servers[1]
	if turn.Username != "1786885200:firebase-user" || turn.Credential == "" {
		t.Fatalf("unexpected TURN credentials: %+v", turn)
	}
	if !issued.ExpiresAt.Equal(now.Add(time.Hour)) {
		t.Fatalf("expires at = %s", issued.ExpiresAt)
	}
}
