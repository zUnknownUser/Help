package realtime

import (
	"encoding/json"
	"sync"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type Hub struct {
	mu     sync.RWMutex
	byUser map[string]map[*Connection]struct{}
}

func NewHub() *Hub { return &Hub{byUser: make(map[string]map[*Connection]struct{})} }

func (hub *Hub) Register(connection *Connection) {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	connections := hub.byUser[connection.UserID()]
	if connections == nil {
		connections = make(map[*Connection]struct{})
		hub.byUser[connection.UserID()] = connections
	}
	connections[connection] = struct{}{}
}

func (hub *Hub) Unregister(connection *Connection) {
	hub.mu.Lock()
	defer hub.mu.Unlock()
	connections := hub.byUser[connection.UserID()]
	delete(connections, connection)
	if len(connections) == 0 {
		delete(hub.byUser, connection.UserID())
	}
}

func (hub *Hub) Publish(userID string, event ports.RealtimeEvent) int {
	payload, err := json.Marshal(event)
	if err != nil {
		return 0
	}
	hub.mu.RLock()
	connections := make([]*Connection, 0, len(hub.byUser[userID]))
	for connection := range hub.byUser[userID] {
		connections = append(connections, connection)
	}
	hub.mu.RUnlock()
	delivered := 0
	for _, connection := range connections {
		if connection.Enqueue(payload) {
			delivered++
		}
	}
	return delivered
}

func (hub *Hub) IsOnline(userID string) bool {
	hub.mu.RLock()
	defer hub.mu.RUnlock()
	return len(hub.byUser[userID]) > 0
}
