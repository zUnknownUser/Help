package reviews

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainreviews "github.com/vendlydigital/help/services/api/internal/domain/reviews"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

type participants struct{ serviceID, customerUID, providerUID, status string }

func (repository *Repository) Upsert(ctx context.Context, uid, requestID string, draft domainreviews.Draft) (domainreviews.Review, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainreviews.Review{}, fmt.Errorf("begin review: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	people, err := loadParticipants(ctx, tx, requestID)
	if err != nil {
		return domainreviews.Review{}, err
	}
	role, reviewee, err := people.authorize(uid)
	if err != nil {
		return domainreviews.Review{}, err
	}
	if people.status != "completed" {
		return domainreviews.Review{}, domainreviews.ErrIncomplete
	}

	query, args, err := database.Query.Insert("service_reviews").
		Columns("service_request_id", "service_id", "reviewer_uid", "reviewee_uid", "reviewer_role", "rating", "comment").
		Values(requestID, people.serviceID, uid, reviewee, role, draft.Rating, draft.Comment).
		Suffix(`ON CONFLICT (service_request_id, reviewer_uid) DO NOTHING
			RETURNING id::text, service_request_id::text, reviewer_uid, reviewee_uid,
			reviewer_role, rating, comment, created_at, updated_at`).ToSql()
	if err != nil {
		return domainreviews.Review{}, fmt.Errorf("build review upsert: %w", err)
	}
	var review domainreviews.Review
	err = tx.QueryRow(ctx, query, args...).Scan(&review.ID, &review.RequestID, &review.ReviewerUID,
		&review.RevieweeUID, &review.ReviewerRole, &review.Rating, &review.Comment,
		&review.CreatedAt, &review.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		review, err = loadReview(ctx, tx, requestID, uid)
		if err != nil {
			return domainreviews.Review{}, err
		}
		if err = tx.Commit(ctx); err != nil {
			return domainreviews.Review{}, fmt.Errorf("commit duplicate review: %w", err)
		}
		return review, nil
	}
	if err != nil {
		return domainreviews.Review{}, fmt.Errorf("upsert review: %w", err)
	}
	if role == "customer" {
		if err = updateServiceRating(ctx, tx, people.serviceID); err != nil {
			return domainreviews.Review{}, err
		}
	}
	if err = notifyReviewee(ctx, tx, reviewee, requestID); err != nil {
		return domainreviews.Review{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return domainreviews.Review{}, fmt.Errorf("commit review: %w", err)
	}
	return review, nil
}

func loadReview(ctx context.Context, querier rowQuerier, requestID, uid string) (domainreviews.Review, error) {
	query, args, err := database.Query.Select("id::text", "service_request_id::text", "reviewer_uid", "reviewee_uid",
		"reviewer_role", "rating", "comment", "created_at", "updated_at").From("service_reviews").
		Where("service_request_id = ?::uuid", requestID).Where("reviewer_uid = ?", uid).ToSql()
	if err != nil {
		return domainreviews.Review{}, fmt.Errorf("build existing review: %w", err)
	}
	var item domainreviews.Review
	err = querier.QueryRow(ctx, query, args...).Scan(&item.ID, &item.RequestID, &item.ReviewerUID, &item.RevieweeUID,
		&item.ReviewerRole, &item.Rating, &item.Comment, &item.CreatedAt, &item.UpdatedAt)
	if err != nil {
		return domainreviews.Review{}, fmt.Errorf("load existing review: %w", err)
	}
	return item, nil
}

func (repository *Repository) ListForRequest(ctx context.Context, uid, requestID string) ([]domainreviews.Review, error) {
	people, err := loadParticipants(ctx, repository.pool, requestID)
	if err != nil {
		return nil, err
	}
	if _, _, err = people.authorize(uid); err != nil {
		return nil, err
	}
	query, args, err := database.Query.Select("id::text", "service_request_id::text", "reviewer_uid", "reviewee_uid",
		"reviewer_role", "rating", "comment", "created_at", "updated_at").From("service_reviews").
		Where("service_request_id = ?::uuid", requestID).OrderBy("created_at", "id").ToSql()
	if err != nil {
		return nil, fmt.Errorf("build review list: %w", err)
	}
	rows, err := repository.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list reviews: %w", err)
	}
	defer rows.Close()
	items := make([]domainreviews.Review, 0, 2)
	for rows.Next() {
		var item domainreviews.Review
		if err = rows.Scan(&item.ID, &item.RequestID, &item.ReviewerUID, &item.RevieweeUID,
			&item.ReviewerRole, &item.Rating, &item.Comment, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan review: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

type rowQuerier interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func loadParticipants(ctx context.Context, querier rowQuerier, requestID string) (participants, error) {
	query, args, err := database.Query.Select("request.service_id", "request.customer_uid", "provider.owner_uid", "request.status").
		From("service_requests request").Join("providers provider ON provider.id=request.provider_id").
		Where("request.id = ?::uuid", requestID).ToSql()
	if err != nil {
		return participants{}, fmt.Errorf("build review participants: %w", err)
	}
	var value participants
	err = querier.QueryRow(ctx, query, args...).Scan(&value.serviceID, &value.customerUID, &value.providerUID, &value.status)
	if errors.Is(err, pgx.ErrNoRows) {
		return participants{}, domainreviews.ErrNotFound
	}
	if err != nil {
		return participants{}, fmt.Errorf("load review participants: %w", err)
	}
	return value, nil
}

func (value participants) authorize(uid string) (string, string, error) {
	if uid == value.customerUID {
		return "customer", value.providerUID, nil
	}
	if uid == value.providerUID {
		return "provider", value.customerUID, nil
	}
	return "", "", domainreviews.ErrForbidden
}

func updateServiceRating(ctx context.Context, tx pgx.Tx, serviceID string) error {
	query, args, err := database.Query.Update("services").SetMap(map[string]any{
		"rating":  database.Expr("COALESCE((SELECT avg(rating) FROM service_reviews WHERE service_id=? AND reviewer_role='customer'),0)", serviceID),
		"reviews": database.Expr("(SELECT count(*) FROM service_reviews WHERE service_id=? AND reviewer_role='customer')", serviceID),
	}).Where("id = ?", serviceID).ToSql()
	if err != nil {
		return fmt.Errorf("build service rating update: %w", err)
	}
	if _, err = tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("update service rating: %w", err)
	}
	return nil
}

func notifyReviewee(ctx context.Context, tx pgx.Tx, uid, requestID string) error {
	payload, _ := json.Marshal(map[string]string{"request_id": requestID, "route": "service_request"})
	query, args, err := database.Query.Insert("notifications").
		Columns("firebase_uid", "title", "body", "kind", "data").
		Values(uid, "Você recebeu uma avaliação", "Veja como foi a experiência deste atendimento.", "service_review", database.Expr("?::jsonb", payload)).
		Suffix("RETURNING id").ToSql()
	if err != nil {
		return fmt.Errorf("build review notification: %w", err)
	}
	var notificationID string
	if err = tx.QueryRow(ctx, query, args...).Scan(&notificationID); err != nil {
		return fmt.Errorf("create review notification: %w", err)
	}
	query, args, err = database.Query.Insert("notification_push_outbox").Columns("notification_id").Values(notificationID).
		Suffix("ON CONFLICT DO NOTHING").ToSql()
	if err != nil {
		return fmt.Errorf("build review push: %w", err)
	}
	if _, err = tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("enqueue review push: %w", err)
	}
	return nil
}
