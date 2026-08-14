package chat

import (
	"context"
	"fmt"
	"time"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

func (repository *Repository) ListConversations(
	ctx context.Context,
	userID, query string,
	limit int,
	cursorValue string,
) (domainchat.ConversationPage, error) {
	cursor, err := decodeConversationCursor(cursorValue)
	if err != nil {
		return domainchat.ConversationPage{}, err
	}
	var cursorTime *time.Time
	var cursorID *string
	if cursor != nil {
		cursorTime, cursorID = &cursor.UpdatedAt, &cursor.ID
	}
	rows, err := repository.pool.Query(ctx, `
		SELECT c.id::text, other.firebase_uid, profile.display_name,
		       member.last_read_sequence, c.last_sequence,
		       (SELECT count(*) FROM chat_messages unread
		        WHERE unread.conversation_id = c.id
		          AND unread.sender_uid <> $1
		          AND unread.sequence > member.last_read_sequence),
		       c.updated_at,
		       message.id::text, message.client_id::text, message.sender_uid,
		       message.content, message.sequence, message.created_at,
		       CASE
		         WHEN message.id IS NULL THEN NULL
		         WHEN NOT EXISTS (
		           SELECT 1 FROM conversation_members receipt
		           WHERE receipt.conversation_id = c.id
		             AND receipt.firebase_uid <> message.sender_uid
		             AND receipt.last_read_sequence < message.sequence
		         ) THEN 'read'
		         WHEN NOT EXISTS (
		           SELECT 1 FROM conversation_members receipt
		           WHERE receipt.conversation_id = c.id
		             AND receipt.firebase_uid <> message.sender_uid
		             AND receipt.last_delivered_sequence < message.sequence
		         ) THEN 'delivered'
		         ELSE 'sent'
		       END
		FROM conversation_members member
		JOIN conversations c ON c.id = member.conversation_id
		JOIN conversation_members other
		  ON other.conversation_id = c.id AND other.firebase_uid <> $1
		JOIN user_profiles profile ON profile.firebase_uid = other.firebase_uid
		LEFT JOIN LATERAL (
		  SELECT * FROM chat_messages m
		  WHERE m.conversation_id = c.id
		  ORDER BY m.sequence DESC LIMIT 1
		) message ON true
		WHERE member.firebase_uid = $1
		  AND ($2 = '' OR profile.display_name ILIKE '%' || $2 || '%')
		  AND ($3::timestamptz IS NULL OR (c.updated_at, c.id) < ($3, $4::uuid))
		ORDER BY c.updated_at DESC, c.id DESC
		LIMIT $5`, userID, query, cursorTime, cursorID, limit+1)
	if err != nil {
		return domainchat.ConversationPage{}, fmt.Errorf("query conversations: %w", err)
	}
	defer rows.Close()

	items := make([]domainchat.Conversation, 0, limit+1)
	for rows.Next() {
		conversation, scanErr := scanConversation(rows)
		if scanErr != nil {
			return domainchat.ConversationPage{}, scanErr
		}
		items = append(items, conversation)
	}
	if err := rows.Err(); err != nil {
		return domainchat.ConversationPage{}, fmt.Errorf("iterate conversations: %w", err)
	}
	page := domainchat.ConversationPage{Conversations: items}
	if len(items) > limit {
		last := items[limit-1]
		page.Conversations = items[:limit]
		page.NextCursor = encodeConversationCursor(conversationCursor{UpdatedAt: last.UpdatedAt, ID: last.ID})
	}
	return page, nil
}

type rowScanner interface{ Scan(...any) error }

func scanConversation(row rowScanner) (domainchat.Conversation, error) {
	var conversation domainchat.Conversation
	var messageID, clientID, senderID, content, status *string
	var sequence *int64
	var createdAt *time.Time
	err := row.Scan(
		&conversation.ID, &conversation.OtherUserID, &conversation.OtherDisplayName,
		&conversation.LastReadSequence, &conversation.LastMessageSequence,
		&conversation.UnreadCount, &conversation.UpdatedAt,
		&messageID, &clientID, &senderID, &content, &sequence, &createdAt, &status,
	)
	if err != nil {
		return domainchat.Conversation{}, fmt.Errorf("scan conversation: %w", err)
	}
	if messageID != nil {
		conversation.LastMessage = &domainchat.Message{
			ID: *messageID, ClientID: *clientID, ConversationID: conversation.ID,
			SenderUID: *senderID, Content: *content, Sequence: *sequence,
			CreatedAt: *createdAt, Status: domainchat.MessageStatus(*status),
		}
	}
	return conversation, nil
}
