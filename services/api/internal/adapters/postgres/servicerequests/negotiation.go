package servicerequests

import (
	"context"
	"errors"
	"fmt"
	"time"

	sq "github.com/Masterminds/squirrel"
	"github.com/jackc/pgx/v5"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type negotiationQueryer interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}

func (repository *Repository) GetNegotiation(
	ctx context.Context,
	uid, requestID string,
) (domainrequests.Request, domainrequests.Negotiation, error) {
	return repository.loadNegotiation(ctx, repository.pool, uid, requestID, false)
}

func (repository *Repository) ProposeQuote(
	ctx context.Context,
	uid, requestID string,
	draft domainrequests.QuoteDraft,
) (domainrequests.Request, domainrequests.Negotiation, string, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("begin quote proposal: %w", err)
	}
	defer tx.Rollback(ctx)
	lockQuery, lockArgs, buildErr := database.Query.Select().
		Column(database.Expr("pg_advisory_xact_lock(hashtextextended(?, 0))", uid+":"+draft.ClientID)).
		ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote command lock: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, lockQuery, lockArgs...); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("lock quote command: %w", err)
	}
	existingQuery, existingArgs, buildErr := database.Query.
		Select("request_id::text", "intent_hash").
		From("service_request_quotes").
		Where(sq.Eq{"author_uid": uid, "client_command_id": draft.ClientID}).
		ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote idempotency query: %w", buildErr)
	}
	var previousRequestID, previousIntent string
	err = tx.QueryRow(ctx, existingQuery, existingArgs...).Scan(&previousRequestID, &previousIntent)
	if err == nil {
		if previousRequestID != requestID || previousIntent != draft.IntentHash {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrIdempotencyConflict
		}
		request, negotiation, loadErr := repository.loadNegotiation(ctx, tx, uid, requestID, false)
		return request, negotiation, "", loadErr
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("find quote command: %w", err)
	}

	request, err := repository.getParticipantRequest(ctx, tx, uid, requestID, true)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	if !domainrequests.CanNegotiate(request.Status) {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationClosed
	}
	if request.Version != draft.ExpectedVersion {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrVersionConflict
	}

	latestQuery, latestArgs, buildErr := database.Query.
		Select("id::text", "author_role", "revision").
		From("service_request_quotes").
		Where(sq.Eq{"request_id": requestID, "status": domainrequests.QuoteProposed}).
		Suffix("FOR UPDATE").
		ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build pending quote query: %w", buildErr)
	}
	var previousQuoteID, previousAuthor string
	var revision int
	err = tx.QueryRow(ctx, latestQuery, latestArgs...).Scan(&previousQuoteID, &previousAuthor, &revision)
	if errors.Is(err, pgx.ErrNoRows) {
		revisionQuery, revisionArgs, buildErr := database.Query.
			Select("COALESCE(max(revision), 0)").
			From("service_request_quotes").
			Where(sq.Eq{"request_id": requestID}).
			ToSql()
		if buildErr != nil {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote revision query: %w", buildErr)
		}
		if err = tx.QueryRow(ctx, revisionQuery, revisionArgs...).Scan(&revision); err != nil {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("load quote revision: %w", err)
		}
		if revision > 0 {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationClosed
		}
		if revision == 0 && request.ViewerRole != domainrequests.ViewerProvider {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationTurn
		}
	} else if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("load pending quote: %w", err)
	} else {
		if previousAuthor == string(request.ViewerRole) {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationTurn
		}
		updateQuery, updateArgs, buildErr := database.Query.
			Update("service_request_quotes").
			Set("status", domainrequests.QuoteSuperseded).
			Where(sq.Eq{"id": previousQuoteID, "status": domainrequests.QuoteProposed}).
			ToSql()
		if buildErr != nil {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote supersede: %w", buildErr)
		}
		if _, err = tx.Exec(ctx, updateQuery, updateArgs...); err != nil {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("supersede quote: %w", err)
		}
	}
	if revision >= domainrequests.MaximumQuoteRevisions {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationClosed
	}
	revision++
	insertQuery, insertArgs, buildErr := database.Query.
		Insert("service_request_quotes").
		Columns("request_id", "client_command_id", "author_uid", "author_role", "revision", "total_cents", "message", "intent_hash", "expires_at").
		Values(requestID, draft.ClientID, uid, request.ViewerRole, revision, draft.TotalCents, draft.Message, draft.IntentHash, draft.ExpiresAt).
		Suffix("RETURNING id::text").
		ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote insert: %w", buildErr)
	}
	var quoteID string
	if err = tx.QueryRow(ctx, insertQuery, insertArgs...).Scan(&quoteID); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("insert quote: %w", err)
	}
	itemsBuilder := database.Query.Insert("service_request_quote_items").
		Columns("quote_id", "kind", "description", "amount_cents", "position")
	for _, item := range draft.Items {
		itemsBuilder = itemsBuilder.Values(quoteID, item.Kind, item.Description, item.AmountCents, item.Position)
	}
	itemsQuery, itemsArgs, buildErr := itemsBuilder.ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote items insert: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, itemsQuery, itemsArgs...); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("insert quote items: %w", err)
	}
	if err = touchNegotiatedRequest(ctx, tx, requestID); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	recipient := counterpartUID(request, request.ViewerRole)
	if err = enqueueNegotiationNotification(ctx, tx, recipient, requestID, request.ServiceID,
		"Novo orçamento", "Você recebeu uma nova proposta para "+request.ServiceTitle+"."); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	updated, negotiation, err := repository.loadNegotiation(ctx, tx, uid, requestID, false)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	if err = tx.Commit(ctx); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("commit quote proposal: %w", err)
	}
	return updated, negotiation, recipient, nil
}

func (repository *Repository) AcceptQuote(
	ctx context.Context,
	uid, requestID, quoteID, clientCommandID string,
	expectedVersion int,
	now time.Time,
) (domainrequests.Request, domainrequests.Negotiation, string, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("begin quote acceptance: %w", err)
	}
	defer tx.Rollback(ctx)
	lockQuery, lockArgs, buildErr := database.Query.Select().
		Column(database.Expr("pg_advisory_xact_lock(hashtextextended(?, 0))", uid+":"+clientCommandID)).
		ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote acceptance lock: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, lockQuery, lockArgs...); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("lock quote acceptance: %w", err)
	}
	commandQuery, commandArgs, buildErr := database.Query.
		Select("request_id::text", "quote_id::text").
		From("service_request_quote_accept_commands").
		Where(sq.Eq{"actor_uid": uid, "client_command_id": clientCommandID}).
		ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote acceptance command query: %w", buildErr)
	}
	var previousRequestID, previousQuoteID string
	err = tx.QueryRow(ctx, commandQuery, commandArgs...).Scan(&previousRequestID, &previousQuoteID)
	if err == nil {
		if previousRequestID != requestID || previousQuoteID != quoteID {
			return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrIdempotencyConflict
		}
		request, negotiation, loadErr := repository.loadNegotiation(ctx, tx, uid, requestID, false)
		return request, negotiation, "", loadErr
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("find quote acceptance command: %w", err)
	}
	request, err := repository.getParticipantRequest(ctx, tx, uid, requestID, true)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	if !domainrequests.CanNegotiate(request.Status) {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationClosed
	}
	if request.Version != expectedVersion {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrVersionConflict
	}
	quoteQuery, quoteArgs, buildErr := database.Query.
		Select("author_uid", "author_role", "status", "total_cents", "expires_at").
		From("service_request_quotes").
		Where(sq.Eq{"id": quoteID, "request_id": requestID}).
		Suffix("FOR UPDATE").ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build accepted quote query: %w", buildErr)
	}
	var authorUID, authorRole string
	var status domainrequests.QuoteStatus
	var totalCents int
	var expiresAt *time.Time
	if err = tx.QueryRow(ctx, quoteQuery, quoteArgs...).Scan(&authorUID, &authorRole, &status, &totalCents, &expiresAt); errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrQuoteNotFound
	} else if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("load quote for acceptance: %w", err)
	}
	if status != domainrequests.QuoteProposed || authorRole == string(request.ViewerRole) || (expiresAt != nil && !expiresAt.After(now)) {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", domainrequests.ErrNegotiationTurn
	}
	quoteUpdate, quoteUpdateArgs, buildErr := database.Query.Update("service_request_quotes").
		SetMap(map[string]any{"status": domainrequests.QuoteAccepted, "accepted_at": database.Expr("now()"), "accepted_by": uid}).
		Where(sq.Eq{"id": quoteID, "status": domainrequests.QuoteProposed}).ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote acceptance update: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, quoteUpdate, quoteUpdateArgs...); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("accept quote: %w", err)
	}
	requestUpdate, requestUpdateArgs, buildErr := database.Query.Update("service_requests").
		Set("quoted_price_cents", totalCents).
		Set("status", database.Expr("CASE WHEN status = 'pending' THEN 'accepted' ELSE status END")).
		Set("status_changed_at", database.Expr("CASE WHEN status = 'pending' THEN now() ELSE status_changed_at END")).
		Set("updated_at", database.Expr("now()")).
		Set("version", database.Expr("version + 1")).
		Where(sq.Eq{"id": requestID}).ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build accepted quote request update: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, requestUpdate, requestUpdateArgs...); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("apply accepted quote: %w", err)
	}
	commandInsert, commandInsertArgs, buildErr := database.Query.Insert("service_request_quote_accept_commands").
		Columns("actor_uid", "client_command_id", "request_id", "quote_id", "resulting_version").
		Values(uid, clientCommandID, requestID, quoteID, request.Version+1).ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("build quote acceptance command insert: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, commandInsert, commandInsertArgs...); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("record quote acceptance: %w", err)
	}
	if err = enqueueNegotiationNotification(ctx, tx, authorUID, requestID, request.ServiceID,
		"Orçamento aceito", "A proposta para "+request.ServiceTitle+" foi aceita."); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	updated, negotiation, err := repository.loadNegotiation(ctx, tx, uid, requestID, false)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", err
	}
	if err = tx.Commit(ctx); err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, "", fmt.Errorf("commit quote acceptance: %w", err)
	}
	return updated, negotiation, authorUID, nil
}

func (repository *Repository) CreateAttachment(
	ctx context.Context,
	uid, requestID string,
	attachment domainrequests.Attachment,
) (domainrequests.Attachment, string, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainrequests.Attachment{}, "", fmt.Errorf("begin request attachment: %w", err)
	}
	defer tx.Rollback(ctx)
	request, err := repository.getParticipantRequest(ctx, tx, uid, requestID, true)
	if err != nil {
		return domainrequests.Attachment{}, "", err
	}
	if !domainrequests.CanNegotiate(request.Status) {
		return domainrequests.Attachment{}, "", domainrequests.ErrNegotiationClosed
	}
	countQuery, countArgs, buildErr := database.Query.Select("count(*)").
		From("service_request_attachments").Where(sq.Eq{"request_id": requestID}).ToSql()
	if buildErr != nil {
		return domainrequests.Attachment{}, "", fmt.Errorf("build request attachment count: %w", buildErr)
	}
	var count int
	if err = tx.QueryRow(ctx, countQuery, countArgs...).Scan(&count); err != nil {
		return domainrequests.Attachment{}, "", fmt.Errorf("count request attachments: %w", err)
	}
	if count >= domainrequests.MaximumRequestAttachments {
		return domainrequests.Attachment{}, "", domainrequests.ErrAttachmentLimit
	}
	insertQuery, insertArgs, buildErr := database.Query.Insert("service_request_attachments").
		Columns("request_id", "uploader_uid", "storage_key", "content_type", "byte_size", "caption").
		Values(requestID, uid, attachment.StorageKey, attachment.ContentType, attachment.ByteSize, attachment.Caption).
		Suffix("RETURNING id::text, created_at").ToSql()
	if buildErr != nil {
		return domainrequests.Attachment{}, "", fmt.Errorf("build request attachment insert: %w", buildErr)
	}
	attachment.RequestID, attachment.UploaderUID = requestID, uid
	attachment.UploaderRole = request.ViewerRole
	attachment.UploaderName = participantName(request, request.ViewerRole)
	if err = tx.QueryRow(ctx, insertQuery, insertArgs...).Scan(&attachment.ID, &attachment.CreatedAt); err != nil {
		return domainrequests.Attachment{}, "", fmt.Errorf("insert request attachment: %w", err)
	}
	if err = touchNegotiatedRequest(ctx, tx, requestID); err != nil {
		return domainrequests.Attachment{}, "", err
	}
	recipient := counterpartUID(request, request.ViewerRole)
	if err = tx.Commit(ctx); err != nil {
		return domainrequests.Attachment{}, "", fmt.Errorf("commit request attachment: %w", err)
	}
	return attachment, recipient, nil
}

func (repository *Repository) GetAttachment(
	ctx context.Context,
	uid, attachmentID string,
) (domainrequests.Attachment, error) {
	query, args, err := attachmentSelect().
		Where(sq.Eq{"attachment.id": attachmentID}).
		Where("(request.customer_uid = ? OR provider.owner_uid = ?)", uid, uid).
		ToSql()
	if err != nil {
		return domainrequests.Attachment{}, fmt.Errorf("build request attachment query: %w", err)
	}
	attachment, err := scanAttachment(repository.pool.QueryRow(ctx, query, args...))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Attachment{}, domainrequests.ErrNotFound
	}
	return attachment, err
}

func (repository *Repository) DeleteAttachment(
	ctx context.Context,
	uid, requestID, attachmentID string,
) (string, string, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return "", "", fmt.Errorf("begin request attachment delete: %w", err)
	}
	defer tx.Rollback(ctx)
	request, err := repository.getParticipantRequest(ctx, tx, uid, requestID, true)
	if err != nil {
		return "", "", err
	}
	if !domainrequests.CanNegotiate(request.Status) {
		return "", "", domainrequests.ErrNegotiationClosed
	}
	selectQuery, selectArgs, buildErr := database.Query.Select("storage_key").
		From("service_request_attachments").
		Where(sq.Eq{"id": attachmentID, "request_id": requestID, "uploader_uid": uid}).
		Suffix("FOR UPDATE").ToSql()
	if buildErr != nil {
		return "", "", fmt.Errorf("build request attachment delete query: %w", buildErr)
	}
	var key string
	if err = tx.QueryRow(ctx, selectQuery, selectArgs...).Scan(&key); errors.Is(err, pgx.ErrNoRows) {
		return "", "", domainrequests.ErrNotFound
	} else if err != nil {
		return "", "", fmt.Errorf("load request attachment for delete: %w", err)
	}
	deleteQuery, deleteArgs, buildErr := database.Query.Delete("service_request_attachments").
		Where(sq.Eq{"id": attachmentID, "request_id": requestID, "uploader_uid": uid}).ToSql()
	if buildErr != nil {
		return "", "", fmt.Errorf("build request attachment delete: %w", buildErr)
	}
	if _, err = tx.Exec(ctx, deleteQuery, deleteArgs...); err != nil {
		return "", "", fmt.Errorf("delete request attachment: %w", err)
	}
	if err = touchNegotiatedRequest(ctx, tx, requestID); err != nil {
		return "", "", err
	}
	recipient := counterpartUID(request, request.ViewerRole)
	if err = tx.Commit(ctx); err != nil {
		return "", "", fmt.Errorf("commit request attachment delete: %w", err)
	}
	return key, recipient, nil
}

func (repository *Repository) loadNegotiation(
	ctx context.Context,
	queryer negotiationQueryer,
	uid, requestID string,
	lock bool,
) (domainrequests.Request, domainrequests.Negotiation, error) {
	request, err := repository.getParticipantRequest(ctx, queryer, uid, requestID, lock)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, err
	}
	attachmentQuery, attachmentArgs, buildErr := attachmentSelect().
		Where(sq.Eq{"attachment.request_id": requestID}).
		OrderBy("attachment.created_at", "attachment.id").ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("build request attachments: %w", buildErr)
	}
	attachmentRows, err := queryer.Query(ctx, attachmentQuery, attachmentArgs...)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("query request attachments: %w", err)
	}
	attachments := make([]domainrequests.Attachment, 0)
	for attachmentRows.Next() {
		attachment, scanErr := scanAttachment(attachmentRows)
		if scanErr != nil {
			attachmentRows.Close()
			return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("scan request attachment: %w", scanErr)
		}
		attachments = append(attachments, attachment)
	}
	if err = attachmentRows.Err(); err != nil {
		attachmentRows.Close()
		return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("read request attachments: %w", err)
	}
	attachmentRows.Close()

	quoteQuery, quoteArgs, buildErr := database.Query.Select(
		"quote.id::text", "quote.request_id::text", "quote.author_uid", "profile.display_name",
		"quote.author_role", "quote.revision", "quote.status", "quote.currency", "quote.total_cents",
		"quote.message", "quote.expires_at", "quote.accepted_at", "COALESCE(quote.accepted_by, '')", "quote.created_at",
	).From("service_request_quotes quote").
		Join("user_profiles profile ON profile.firebase_uid = quote.author_uid").
		Where(sq.Eq{"quote.request_id": requestID}).
		OrderBy("quote.revision DESC").Limit(domainrequests.MaximumQuoteRevisions).ToSql()
	if buildErr != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("build request quote history: %w", buildErr)
	}
	quoteRows, err := queryer.Query(ctx, quoteQuery, quoteArgs...)
	if err != nil {
		return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("query request quote history: %w", err)
	}
	quotes := make([]domainrequests.Quote, 0)
	quoteIDs := make([]string, 0)
	for quoteRows.Next() {
		var quote domainrequests.Quote
		if err = quoteRows.Scan(
			&quote.ID, &quote.RequestID, &quote.AuthorUID, &quote.AuthorName,
			&quote.AuthorRole, &quote.Revision, &quote.Status, &quote.Currency, &quote.TotalCents,
			&quote.Message, &quote.ExpiresAt, &quote.AcceptedAt, &quote.AcceptedBy, &quote.CreatedAt,
		); err != nil {
			quoteRows.Close()
			return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("scan request quote: %w", err)
		}
		quote.Items = []domainrequests.QuoteItem{}
		quotes = append(quotes, quote)
		quoteIDs = append(quoteIDs, quote.ID)
	}
	if err = quoteRows.Err(); err != nil {
		quoteRows.Close()
		return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("read request quote history: %w", err)
	}
	quoteRows.Close()
	if len(quoteIDs) > 0 {
		itemQuery, itemArgs, buildErr := database.Query.Select(
			"id::text", "quote_id::text", "kind", "description", "amount_cents", "position",
		).From("service_request_quote_items").
			Where(sq.Eq{"quote_id": quoteIDs}).OrderBy("quote_id", "position").ToSql()
		if buildErr != nil {
			return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("build quote items: %w", buildErr)
		}
		itemRows, itemErr := queryer.Query(ctx, itemQuery, itemArgs...)
		if itemErr != nil {
			return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("query quote items: %w", itemErr)
		}
		byID := make(map[string]int, len(quotes))
		for index := range quotes {
			byID[quotes[index].ID] = index
		}
		for itemRows.Next() {
			var item domainrequests.QuoteItem
			var quoteID string
			if err = itemRows.Scan(&item.ID, &quoteID, &item.Kind, &item.Description, &item.AmountCents, &item.Position); err != nil {
				itemRows.Close()
				return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("scan quote item: %w", err)
			}
			if index, ok := byID[quoteID]; ok {
				quotes[index].Items = append(quotes[index].Items, item)
			}
		}
		if err = itemRows.Err(); err != nil {
			itemRows.Close()
			return domainrequests.Request{}, domainrequests.Negotiation{}, fmt.Errorf("read quote items: %w", err)
		}
		itemRows.Close()
	}
	return request, domainrequests.Negotiation{Attachments: attachments, Quotes: quotes}, nil
}

func (repository *Repository) getParticipantRequest(
	ctx context.Context,
	queryer interface{ QueryRow(context.Context, string, ...any) pgx.Row },
	uid, requestID string,
	lock bool,
) (domainrequests.Request, error) {
	builder := database.Query.Select(
		"request.id::text", "request.client_request_id::text", "request.service_id",
		"service.title", "request.provider_id", "provider.owner_uid", "provider.name",
		"request.customer_uid", "customer.display_name", "request.status", "request.note",
		"request.scheduled_for", "request.scheduled_end_at", "request.quoted_price_cents",
		"request.address_label", "request.formatted_address", "request.latitude", "request.longitude",
		"request.created_at", "request.updated_at", "request.version", "request.status_reason",
	).From("service_requests request").
		Join("services service ON service.id = request.service_id").
		Join("providers provider ON provider.id = request.provider_id").
		Join("user_profiles customer ON customer.firebase_uid = request.customer_uid").
		Where(sq.Eq{"request.id": requestID}).
		Where("(request.customer_uid = ? OR provider.owner_uid = ?)", uid, uid)
	if lock {
		builder = builder.Suffix("FOR UPDATE OF request")
	}
	query, args, err := builder.ToSql()
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("build participant request query: %w", err)
	}
	request, err := repository.scanRequest(queryer.QueryRow(ctx, query, args...))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.ErrNotFound
	}
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("load participant request: %w", err)
	}
	request.ViewerRole = viewerRole(request, uid)
	return request, nil
}

func attachmentSelect() sq.SelectBuilder {
	return database.Query.Select(
		"attachment.id::text", "attachment.request_id::text", "attachment.uploader_uid",
		"profile.display_name",
		"CASE WHEN attachment.uploader_uid = request.customer_uid THEN 'customer' ELSE 'provider' END",
		"attachment.storage_key", "attachment.content_type", "attachment.byte_size", "attachment.caption", "attachment.created_at",
	).From("service_request_attachments attachment").
		Join("service_requests request ON request.id = attachment.request_id").
		Join("providers provider ON provider.id = request.provider_id").
		Join("user_profiles profile ON profile.firebase_uid = attachment.uploader_uid")
}

func scanAttachment(row interface{ Scan(...any) error }) (domainrequests.Attachment, error) {
	var attachment domainrequests.Attachment
	err := row.Scan(
		&attachment.ID, &attachment.RequestID, &attachment.UploaderUID, &attachment.UploaderName,
		&attachment.UploaderRole, &attachment.StorageKey, &attachment.ContentType,
		&attachment.ByteSize, &attachment.Caption, &attachment.CreatedAt,
	)
	return attachment, err
}

func enqueueNegotiationNotification(
	ctx context.Context,
	tx pgx.Tx,
	recipient, requestID, serviceID, title, body string,
) error {
	insertQuery, insertArgs, err := database.Query.Insert("notifications").
		Columns("firebase_uid", "title", "body", "kind", "data").
		Values(recipient, title, body, "service_request", database.Expr(
			"jsonb_build_object('request_id', ?::text, 'service_id', ?::text, 'route', 'service_request')",
			requestID, serviceID,
		)).Suffix("RETURNING id::text").ToSql()
	if err != nil {
		return fmt.Errorf("build negotiation notification: %w", err)
	}
	var notificationID string
	if err = tx.QueryRow(ctx, insertQuery, insertArgs...).Scan(&notificationID); err != nil {
		return fmt.Errorf("insert negotiation notification: %w", err)
	}
	outboxQuery, outboxArgs, err := database.Query.Insert("notification_push_outbox").
		Columns("notification_id").Values(notificationID).ToSql()
	if err != nil {
		return fmt.Errorf("build negotiation push outbox: %w", err)
	}
	if _, err = tx.Exec(ctx, outboxQuery, outboxArgs...); err != nil {
		return fmt.Errorf("insert negotiation push outbox: %w", err)
	}
	return nil
}

func touchNegotiatedRequest(ctx context.Context, tx pgx.Tx, requestID string) error {
	query, args, err := database.Query.Update("service_requests").
		Set("updated_at", database.Expr("now()")).
		Where(sq.Eq{"id": requestID}).ToSql()
	if err != nil {
		return fmt.Errorf("build negotiated request timestamp: %w", err)
	}
	if _, err = tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("touch negotiated request: %w", err)
	}
	return nil
}

func counterpartUID(request domainrequests.Request, role domainrequests.ViewerRole) string {
	if role == domainrequests.ViewerCustomer {
		return request.ProviderUID
	}
	return request.CustomerUID
}

func participantName(request domainrequests.Request, role domainrequests.ViewerRole) string {
	if role == domainrequests.ViewerCustomer {
		return request.CustomerName
	}
	return request.ProviderName
}
