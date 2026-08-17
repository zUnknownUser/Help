package chat

import "time"

type ICEServer struct {
	URLs       []string `json:"urls"`
	Username   string   `json:"username,omitempty"`
	Credential string   `json:"credential,omitempty"`
}

type ICEConfiguration struct {
	Servers   []ICEServer `json:"ice_servers"`
	ExpiresAt time.Time   `json:"expires_at"`
}
