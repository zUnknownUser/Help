package chat

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"strconv"
	"time"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type ICEConfig struct {
	STUNURLs      []string
	TURNURLs      []string
	TURNSecret    string
	CredentialTTL time.Duration
}

type ICEConfigService struct {
	config ICEConfig
	now    func() time.Time
}

func NewICEConfigService(config ICEConfig, now func() time.Time) *ICEConfigService {
	return &ICEConfigService{config: config, now: now}
}

func (service *ICEConfigService) Issue(userID string) domainchat.ICEConfiguration {
	now := service.now().UTC()
	expiresAt := now.Add(service.config.CredentialTTL)
	servers := make([]domainchat.ICEServer, 0, 2)
	if len(service.config.STUNURLs) > 0 {
		servers = append(servers, domainchat.ICEServer{URLs: service.config.STUNURLs})
	}
	if len(service.config.TURNURLs) > 0 && service.config.TURNSecret != "" {
		username := strconv.FormatInt(expiresAt.Unix(), 10) + ":" + userID
		mac := hmac.New(sha1.New, []byte(service.config.TURNSecret))
		_, _ = mac.Write([]byte(username))
		servers = append(servers, domainchat.ICEServer{
			URLs:       service.config.TURNURLs,
			Username:   username,
			Credential: base64.StdEncoding.EncodeToString(mac.Sum(nil)),
		})
	}
	return domainchat.ICEConfiguration{Servers: servers, ExpiresAt: expiresAt}
}
