package chat

import "errors"

var (
	ErrForbidden            = errors.New("chat access forbidden")
	ErrConversationNotFound = errors.New("conversation not found")
	ErrRecipientNotFound    = errors.New("recipient not found")
	ErrInvalidMessage       = errors.New("invalid message")
)
