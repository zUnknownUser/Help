package httpapi_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	postgreschat "github.com/vendlydigital/help/services/api/internal/adapters/postgres/chat"
	"github.com/vendlydigital/help/services/api/internal/adapters/realtime"
	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type integrationTokenVerifier struct {
	identities map[string]ports.AuthenticatedIdentity
}

func (verifier integrationTokenVerifier) VerifyIDToken(_ context.Context, token string) (ports.AuthenticatedIdentity, error) {
	identity, ok := verifier.identities[token]
	if !ok {
		return ports.AuthenticatedIdentity{}, context.Canceled
	}
	return identity, nil
}

func TestRealtimeTwoClientsIdempotencyReceiptsAndAuthorization(t *testing.T) {
	databaseURL := os.Getenv("CHAT_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("CHAT_TEST_DATABASE_URL not configured")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()

	suffix := uuid.NewString()
	userA, userB, outsider := "a-"+suffix, "b-"+suffix, "c-"+suffix
	for _, user := range []string{userA, userB, outsider} {
		_, err = pool.Exec(ctx, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role)
			VALUES($1,$1||'@example.invalid',$1,'customer')`, user)
		if err != nil {
			t.Fatal(err)
		}
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid = ANY($1)`, []string{userA, userB, outsider})
	})

	repository := postgreschat.NewRepository(pool)
	conversation, err := repository.FindOrCreateDirect(ctx, userA, userB)
	if err != nil {
		t.Fatal(err)
	}
	hub := realtime.NewHub()
	service := applicationchat.NewService(repository, hub, nil)
	email, _ := domainauth.ParseEmail("integration@example.invalid")
	router := httpapi.NewRouter(httpapi.RouterDependencies{
		TokenVerifier: integrationTokenVerifier{identities: map[string]ports.AuthenticatedIdentity{
			"token-a": {UID: userA, Email: email}, "token-b": {UID: userB, Email: email},
			"token-c": {UID: outsider, Email: email},
		}},
		ChatService: service, RealtimeHub: hub,
	})
	server := httptest.NewServer(router)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/v1/realtime"
	a := dialRealtime(t, wsURL, "token-a")
	defer a.CloseNow()
	b := dialRealtime(t, wsURL, "token-b")
	defer b.CloseNow()
	readType(t, a, "session.ready")
	readType(t, b, "session.ready")

	clientID := uuid.NewString()
	writeEvent(t, a, "message.send", map[string]any{
		"conversation_id": conversation.ID, "client_id": clientID, "content": "mensagem real",
	})
	ack := readType(t, a, "message.ack")
	newMessage := readType(t, b, "message.new")
	message := newMessage["data"].(map[string]any)
	sequence := int64(message["sequence"].(float64))
	serverID := message["id"].(string)
	if sequence != 1 {
		t.Fatalf("sequence = %d", sequence)
	}

	writeEvent(t, b, "message.delivered", map[string]any{"conversation_id": conversation.ID, "up_to_sequence": sequence})
	readType(t, a, "message.delivered")
	writeEvent(t, b, "message.read", map[string]any{"conversation_id": conversation.ID, "up_to_sequence": sequence})
	readType(t, a, "message.read")

	writeEvent(t, a, "message.send", map[string]any{
		"conversation_id": conversation.ID, "client_id": clientID, "content": "mensagem real",
	})
	duplicateAck := readType(t, a, "message.ack")
	if ackMessageID(ack) != serverID || ackMessageID(duplicateAck) != serverID {
		t.Fatal("idempotent ACK did not return the persisted message")
	}

	c := dialRealtime(t, wsURL, "token-c")
	defer c.CloseNow()
	readType(t, c, "session.ready")
	writeEvent(t, c, "message.send", map[string]any{
		"conversation_id": conversation.ID, "client_id": uuid.NewString(), "content": "invasão",
	})
	errorEvent := readType(t, c, "message.error")
	if errorEvent["data"].(map[string]any)["code"] != "forbidden" {
		t.Fatalf("unexpected authorization error: %+v", errorEvent)
	}

	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM chat_messages WHERE conversation_id=$1`, conversation.ID).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("message count = %d; expected idempotent single row", count)
	}
}

func TestChatRepositoryConcurrentSequenceAndCursorPagination(t *testing.T) {
	databaseURL := os.Getenv("CHAT_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("CHAT_TEST_DATABASE_URL not configured")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	suffix := uuid.NewString()
	userA, userB := "sequence-a-"+suffix, "sequence-b-"+suffix
	for _, user := range []string{userA, userB} {
		if _, err := pool.Exec(ctx, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role)
			VALUES($1,$1||'@example.invalid',$1,'customer')`, user); err != nil {
			t.Fatal(err)
		}
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid = ANY($1)`, []string{userA, userB})
	})
	repository := postgreschat.NewRepository(pool)
	conversation, err := repository.FindOrCreateDirect(ctx, userA, userB)
	if err != nil {
		t.Fatal(err)
	}

	const total = 20
	sequences := make(chan int64, total)
	errorsChannel := make(chan error, total)
	var group sync.WaitGroup
	for index := range total {
		group.Add(1)
		go func(index int) {
			defer group.Done()
			message, _, _, err := repository.CreateMessage(ctx, userA, domainchat.SendMessage{
				ConversationID: conversation.ID, ClientID: uuid.NewString(), Content: "message",
			})
			if err != nil {
				errorsChannel <- err
				return
			}
			sequences <- message.Sequence
		}(index)
	}
	group.Wait()
	close(errorsChannel)
	for err := range errorsChannel {
		t.Fatal(err)
	}
	close(sequences)
	seen := make(map[int64]bool, total)
	for sequence := range sequences {
		seen[sequence] = true
	}
	for expected := int64(1); expected <= total; expected++ {
		if !seen[expected] {
			t.Fatalf("missing deterministic sequence %d: %+v", expected, seen)
		}
	}
	page, err := repository.ListMessages(ctx, userA, conversation.ID, 7, nil, nil)
	if err != nil || len(page.Messages) != 7 || page.NextCursor == "" {
		t.Fatalf("first page invalid: %+v %v", page, err)
	}
	before := page.Messages[0].Sequence
	older, err := repository.ListMessages(ctx, userA, conversation.ID, 7, &before, nil)
	if err != nil || len(older.Messages) == 0 || older.Messages[len(older.Messages)-1].Sequence >= before {
		t.Fatalf("cursor page invalid: %+v %v", older, err)
	}
}

func dialRealtime(t *testing.T, url, token string) *websocket.Conn {
	t.Helper()
	connection, _, err := websocket.Dial(context.Background(), url, &websocket.DialOptions{
		HTTPHeader: http.Header{"Authorization": []string{"Bearer " + token}},
	})
	if err != nil {
		t.Fatal(err)
	}
	return connection
}

func writeEvent(t *testing.T, connection *websocket.Conn, eventType string, data map[string]any) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := wsjson.Write(ctx, connection, map[string]any{"type": eventType, "data": data}); err != nil {
		t.Fatal(err)
	}
}

func readType(t *testing.T, connection *websocket.Conn, wanted string) map[string]any {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for {
		var event map[string]any
		if err := wsjson.Read(ctx, connection, &event); err != nil {
			t.Fatalf("waiting for %s: %v", wanted, err)
		}
		if event["type"] == wanted {
			return normalizeJSON(event).(map[string]any)
		}
	}
}

func normalizeJSON(value any) any {
	raw, _ := json.Marshal(value)
	var normalized any
	_ = json.Unmarshal(raw, &normalized)
	return normalized
}

func ackMessageID(event map[string]any) string {
	return event["data"].(map[string]any)["message"].(map[string]any)["id"].(string)
}
