package firebasepush

import (
	"context"
	"fmt"

	"firebase.google.com/go/v4/messaging"
)

type Sender struct{ client *messaging.Client }

func NewSender(client *messaging.Client) *Sender { return &Sender{client: client} }

func (sender *Sender) SendNewMessage(
	ctx context.Context,
	tokens []string,
	conversationID string,
) ([]string, error) {
	invalid := make([]string, 0)
	for start := 0; start < len(tokens); start += 500 {
		end := min(start+500, len(tokens))
		batch := tokens[start:end]
		response, err := sender.client.SendEachForMulticast(ctx, &messaging.MulticastMessage{
			Tokens: batch,
			Notification: &messaging.Notification{
				Title: "Nova mensagem", Body: "Você recebeu uma nova mensagem.",
			},
			Data:    map[string]string{"type": "chat", "conversation_id": conversationID},
			Android: &messaging.AndroidConfig{Priority: "high"},
			APNS: &messaging.APNSConfig{
				Headers: map[string]string{"apns-priority": "10"},
				Payload: &messaging.APNSPayload{Aps: &messaging.Aps{
					Sound: "default", ContentAvailable: true, ThreadID: conversationID,
				}},
			},
		})
		if err != nil {
			return invalid, fmt.Errorf("send FCM batch: %w", err)
		}
		for index, item := range response.Responses {
			if item.Error != nil && messaging.IsUnregistered(item.Error) {
				invalid = append(invalid, batch[index])
			}
		}
	}
	return invalid, nil
}
