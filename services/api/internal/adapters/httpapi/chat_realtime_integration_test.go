package httpapi_test

import (
	"context"
	"encoding/json"
	"errors"
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
	"github.com/vendlydigital/help/services/api/internal/adapters/localmedia"
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
	t.Cleanup(pool.Close)

	suffix := uuid.NewString()
	userA, userB, outsider := "a-"+suffix, "b-"+suffix, "c-"+suffix
	for _, user := range []struct{ id, role string }{
		{userA, "customer"}, {userB, "provider"}, {outsider, "customer"},
	} {
		_, err = pool.Exec(ctx, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role)
			VALUES($1,$1||'@example.invalid',$1,$2)`, user.id, user.role)
		if err != nil {
			t.Fatal(err)
		}
	}
	providerID := "provider-" + suffix
	if _, err = pool.Exec(ctx, `INSERT INTO providers(id,name,active,verified,owner_uid,onboarding_status,accepting_requests) VALUES($1,$2,true,true,$3,'approved',true)`, providerID, userB, userB); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM conversations WHERE created_by = ANY($1)`, []string{userA, userB, outsider})
		_, _ = pool.Exec(context.Background(), `DELETE FROM providers WHERE id=$1`, providerID)
		_, _ = pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid = ANY($1)`, []string{userA, userB, outsider})
	})

	repository := postgreschat.NewRepository(pool)
	hub := realtime.NewHub()
	service := applicationchat.NewService(repository, hub, nil)
	mediaStore, err := localmedia.NewStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	mediaService := applicationchat.NewMediaService(repository, mediaStore)
	email, _ := domainauth.ParseEmail("integration@example.invalid")
	router := httpapi.NewRouter(httpapi.RouterDependencies{
		TokenVerifier: integrationTokenVerifier{identities: map[string]ports.AuthenticatedIdentity{
			"token-a": {UID: userA, Email: email}, "token-b": {UID: userB, Email: email},
			"token-c": {UID: outsider, Email: email},
		}},
		ChatService: service, ChatMediaService: mediaService, RealtimeHub: hub,
	})
	server := httptest.NewServer(router)
	defer server.Close()

	if _, _, _, err := repository.FindOrCreateDirect(ctx, userB, outsider); !errors.Is(err, domainchat.ErrForbidden) {
		t.Fatalf("provider cold contact error = %v", err)
	}
	conversation, _, _, err := repository.FindOrCreateDirect(ctx, userA, userB)
	if err != nil {
		t.Fatal(err)
	}
	if conversation.Status != domainchat.ConversationPending {
		t.Fatalf("new unrelated conversation status = %s", conversation.Status)
	}
	_, _, _, sendErr := repository.CreateMessage(ctx, userA, domainchat.SendMessage{
		ConversationID: conversation.ID, ClientID: uuid.NewString(), Content: "antes do aceite",
	})
	if !errors.Is(sendErr, domainchat.ErrConversationPending) {
		t.Fatalf("send before acceptance error = %v", sendErr)
	}
	decisionRequest, err := http.NewRequestWithContext(ctx, http.MethodPost,
		server.URL+"/v1/chat/conversations/"+conversation.ID+"/decision",
		strings.NewReader(`{"decision":"accept"}`))
	if err != nil {
		t.Fatal(err)
	}
	decisionRequest.Header.Set("Authorization", "Bearer token-b")
	decisionRequest.Header.Set("Content-Type", "application/json")
	decisionResponse, err := http.DefaultClient.Do(decisionRequest)
	if err != nil {
		t.Fatal(err)
	}
	defer decisionResponse.Body.Close()
	var decisionEnvelope struct {
		Data domainchat.Conversation `json:"data"`
	}
	if decisionResponse.StatusCode != http.StatusOK || json.NewDecoder(decisionResponse.Body).Decode(&decisionEnvelope) != nil || decisionEnvelope.Data.Status != domainchat.ConversationAccepted {
		t.Fatalf("accept conversation status=%d data=%+v", decisionResponse.StatusCode, decisionEnvelope.Data)
	}
	conversation = decisionEnvelope.Data
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/v1/realtime"
	a := dialRealtime(t, wsURL, "token-a")
	defer a.CloseNow()
	readType(t, a, "session.ready")
	b := dialRealtime(t, wsURL, "token-b")
	defer b.CloseNow()
	readType(t, b, "session.ready")
	online := readType(t, a, "presence.changed")["data"].(map[string]any)
	if online["user_id"] != userB || online["online"] != true {
		t.Fatalf("unexpected online presence: %+v", online)
	}

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

	callID := uuid.NewString()
	writeEvent(t, a, "call.invite", map[string]any{
		"call_id": callID, "conversation_id": conversation.ID, "media_type": "video",
	})
	callInvite := readType(t, b, "call.invite")["data"].(map[string]any)
	if callInvite["call_id"] != callID || callInvite["from_user_id"] != userA {
		t.Fatalf("unexpected authenticated call invite: %+v", callInvite)
	}
	writeEvent(t, b, "call.accept", map[string]any{
		"call_id": callID, "conversation_id": conversation.ID,
	})
	callAccepted := readType(t, a, "call.accept")["data"].(map[string]any)
	if callAccepted["from_user_id"] != userB {
		t.Fatalf("unexpected authenticated call acceptance: %+v", callAccepted)
	}

	voiceRequest, err := http.NewRequestWithContext(ctx, http.MethodPost,
		server.URL+"/v1/chat/conversations/"+conversation.ID+"/voice-media",
		strings.NewReader("encoded-audio"))
	if err != nil {
		t.Fatal(err)
	}
	voiceRequest.Header.Set("Authorization", "Bearer token-a")
	voiceRequest.Header.Set("Content-Type", "audio/mp4")
	voiceRequest.Header.Set("X-Voice-Duration-Ms", "1200")
	voiceResponse, err := http.DefaultClient.Do(voiceRequest)
	if err != nil {
		t.Fatal(err)
	}
	defer voiceResponse.Body.Close()
	var voiceEnvelope struct {
		Data domainchat.Media `json:"data"`
	}
	if voiceResponse.StatusCode != http.StatusCreated ||
		json.NewDecoder(voiceResponse.Body).Decode(&voiceEnvelope) != nil ||
		voiceEnvelope.Data.ID == "" {
		t.Fatalf("voice upload status=%d data=%+v", voiceResponse.StatusCode, voiceEnvelope.Data)
	}
	voiceClientID := uuid.NewString()
	writeEvent(t, a, "message.send", map[string]any{
		"conversation_id": conversation.ID, "client_id": voiceClientID,
		"content": "", "kind": "voice", "media_id": voiceEnvelope.Data.ID,
	})
	voiceACK := readType(t, a, "message.ack")["data"].(map[string]any)["message"].(map[string]any)
	voiceNew := readType(t, b, "message.new")["data"].(map[string]any)
	if voiceACK["kind"] != "voice" ||
		voiceNew["media"].(map[string]any)["id"] != voiceEnvelope.Data.ID {
		t.Fatalf("voice message was not reconciled: ack=%+v new=%+v", voiceACK, voiceNew)
	}

	writeEvent(t, a, "message.send", map[string]any{
		"conversation_id": conversation.ID, "client_id": clientID, "content": "mensagem real",
	})
	duplicateAck := readType(t, a, "message.ack")
	if ackMessageID(ack) != serverID || ackMessageID(duplicateAck) != serverID {
		t.Fatal("idempotent ACK did not return the persisted message")
	}

	editOperationID := uuid.NewString()
	writeEvent(t, a, "message.edit", map[string]any{
		"operation_id": editOperationID, "message_id": serverID, "content": "mensagem editada",
	})
	editAck := readType(t, a, "message.mutation.ack")
	updated := readType(t, b, "message.updated")["data"].(map[string]any)
	if editAck["data"].(map[string]any)["operation_id"] != editOperationID ||
		updated["content"] != "mensagem editada" || updated["version"] != float64(2) {
		t.Fatalf("unexpected edit events: ack=%+v updated=%+v", editAck, updated)
	}
	writeEvent(t, a, "message.edit", map[string]any{
		"operation_id": editOperationID, "message_id": serverID, "content": "mensagem editada",
	})
	idempotentEdit := readType(t, a, "message.mutation.ack")
	if ackMessageID(idempotentEdit) != serverID {
		t.Fatal("idempotent edit did not return persisted message")
	}

	deleteOperationID := uuid.NewString()
	writeEvent(t, a, "message.delete", map[string]any{
		"operation_id": deleteOperationID, "message_id": serverID,
	})
	readType(t, a, "message.mutation.ack")
	deleted := readType(t, b, "message.deleted")["data"].(map[string]any)
	if deleted["content"] != "" || deleted["deleted_at"] == nil || deleted["version"] != float64(3) {
		t.Fatalf("unexpected deleted message: %+v", deleted)
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
	writeEvent(t, c, "message.edit", map[string]any{
		"operation_id": uuid.NewString(), "message_id": serverID, "content": "invasÃ£o",
	})
	mutationError := readType(t, c, "message.mutation.error")
	if mutationError["data"].(map[string]any)["code"] != "forbidden" {
		t.Fatalf("unexpected mutation authorization error: %+v", mutationError)
	}
	writeEvent(t, c, "call.invite", map[string]any{
		"call_id": uuid.NewString(), "conversation_id": conversation.ID, "media_type": "audio",
	})
	callError := readType(t, c, "call.error")
	if callError["data"].(map[string]any)["code"] != "forbidden" {
		t.Fatalf("unexpected call authorization error: %+v", callError)
	}

	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM chat_messages WHERE conversation_id=$1`, conversation.ID).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 2 {
		t.Fatalf("message count = %d; expected text and voice rows", count)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM chat_message_mutations WHERE message_id=$1`, serverID).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 2 {
		t.Fatalf("mutation count = %d; expected idempotent edit and delete", count)
	}

	b.CloseNow()
	offline := readType(t, a, "presence.changed")["data"].(map[string]any)
	if offline["user_id"] != userB || offline["online"] != false || offline["last_seen_at"] == nil {
		t.Fatalf("unexpected offline presence: %+v", offline)
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
	t.Cleanup(pool.Close)
	suffix := uuid.NewString()
	userA, userB := "sequence-a-"+suffix, "sequence-b-"+suffix
	for _, user := range []struct{ id, role string }{
		{userA, "customer"}, {userB, "provider"},
	} {
		if _, err := pool.Exec(ctx, `INSERT INTO user_profiles(firebase_uid,email,display_name,active_role)
			VALUES($1,$1||'@example.invalid',$1,$2)`, user.id, user.role); err != nil {
			t.Fatal(err)
		}
	}
	providerID := "sequence-provider-" + suffix
	if _, err := pool.Exec(ctx, `INSERT INTO providers(id,name,active,verified,owner_uid,onboarding_status,accepting_requests) VALUES($1,$2,true,true,$3,'approved',true)`, providerID, userB, userB); err != nil {
		t.Fatal(err)
	}
	serviceID := "sequence-service-" + suffix
	if _, err := pool.Exec(ctx, `INSERT INTO services(id,provider_id,title,rating,duration_minutes,price_cents,old_price_cents,active,published_at) VALUES($1,$2,'Serviço de chat',5,60,10000,10000,true,now())`, serviceID, providerID); err != nil {
		t.Fatal(err)
	}
	scheduled := time.Now().Add(60 * 24 * time.Hour)
	if _, err := pool.Exec(ctx, `INSERT INTO service_requests(service_id,provider_id,customer_uid,status,client_request_id,quoted_price_cents,scheduled_for,scheduled_end_at,reservation_end_at) VALUES($1,$2,$3,'pending',$4,10000,$5,$6,$6)`, serviceID, providerID, userA, uuid.New(), scheduled, scheduled.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM conversations WHERE created_by = ANY($1)`, []string{userA, userB})
		_, _ = pool.Exec(context.Background(), `DELETE FROM service_requests WHERE service_id=$1`, serviceID)
		_, _ = pool.Exec(context.Background(), `DELETE FROM services WHERE id=$1`, serviceID)
		_, _ = pool.Exec(context.Background(), `DELETE FROM providers WHERE id=$1`, providerID)
		_, _ = pool.Exec(context.Background(), `DELETE FROM user_profiles WHERE firebase_uid = ANY($1)`, []string{userA, userB})
	})
	repository := postgreschat.NewRepository(pool)
	conversation, _, _, err := repository.FindOrCreateDirect(ctx, userA, userB)
	if err != nil {
		t.Fatal(err)
	}
	if conversation.Status != domainchat.ConversationAccepted {
		t.Fatalf("service-linked conversation status = %s", conversation.Status)
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
