package realtime

import (
	"context"
	"errors"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
)

const (
	writeTimeout = 5 * time.Second
	pingInterval = 25 * time.Second
	maxEventSize = 16 << 10
	queueSize    = 256
)

type Connection struct {
	id     string
	userID string
	socket *websocket.Conn
	queue  chan []byte
}

func Accept(ctx context.Context, socket *websocket.Conn, userID string) *Connection {
	socket.SetReadLimit(maxEventSize)
	return &Connection{id: uuid.NewString(), userID: userID, socket: socket, queue: make(chan []byte, queueSize)}
}

func (connection *Connection) ID() string     { return connection.id }
func (connection *Connection) UserID() string { return connection.userID }

func (connection *Connection) Enqueue(payload []byte) bool {
	select {
	case connection.queue <- payload:
		return true
	default:
		_ = connection.socket.Close(websocket.StatusPolicyViolation, "client too slow")
		return false
	}
}

func (connection *Connection) Read(ctx context.Context) ([]byte, error) {
	messageType, payload, err := connection.socket.Read(ctx)
	if err != nil {
		return nil, err
	}
	if messageType != websocket.MessageText {
		return nil, errors.New("binary realtime events are not supported")
	}
	return payload, nil
}

func (connection *Connection) WriteLoop(ctx context.Context) error {
	ticker := time.NewTicker(pingInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case payload := <-connection.queue:
			writeCtx, cancel := context.WithTimeout(ctx, writeTimeout)
			err := connection.socket.Write(writeCtx, websocket.MessageText, payload)
			cancel()
			if err != nil {
				return err
			}
		case <-ticker.C:
			pingCtx, cancel := context.WithTimeout(ctx, writeTimeout)
			err := connection.socket.Ping(pingCtx)
			cancel()
			if err != nil {
				return err
			}
		}
	}
}

func (connection *Connection) Close() {
	_ = connection.socket.Close(websocket.StatusNormalClosure, "session closed")
}
