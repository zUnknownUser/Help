package chat

import "errors"

var (
	ErrForbidden            = errors.New("chat access forbidden")
	ErrConversationNotFound = errors.New("conversation not found")
	ErrRecipientNotFound    = errors.New("recipient not found")
	ErrInvalidMessage       = errors.New("invalid message")
	ErrMessageNotFound      = errors.New("message not found")
	ErrConversationPending  = errors.New("conversation awaiting acceptance")
	ErrRecipientOffline     = errors.New("recipient is offline")
	ErrInvalidCall          = errors.New("invalid call signal")
	ErrInvalidMedia         = errors.New("invalid chat media")
	ErrMediaNotFound        = errors.New("chat media not found")
)
