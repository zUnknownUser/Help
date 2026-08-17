package scheduling

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/vendlydigital/help/services/api/internal/domain/scheduling"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) Get(ctx context.Context, uid string) (scheduling.Plan, error) {
	providerID, err := repository.providerID(ctx, uid)
	if err != nil {
		return scheduling.Plan{}, err
	}
	return repository.load(ctx, repository.pool, providerID)
}

func (repository *Repository) Replace(ctx context.Context, uid string, expectedVersion int, plan scheduling.Plan) (scheduling.Plan, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return scheduling.Plan{}, fmt.Errorf("begin schedule replace: %w", err)
	}
	defer tx.Rollback(ctx)
	providerID, err := providerIDQuery(ctx, tx, uid)
	if err != nil {
		return scheduling.Plan{}, err
	}
	var version int
	err = tx.QueryRow(ctx, `UPDATE provider_schedule_settings SET time_zone=$3, minimum_notice_minutes=$4, booking_horizon_days=$5, buffer_minutes=$6, slot_interval_minutes=$7, version=version+1, updated_at=now() WHERE provider_id=$1 AND version=$2 RETURNING version`, providerID, expectedVersion, plan.Settings.TimeZone, plan.Settings.MinimumNoticeMinutes, plan.Settings.BookingHorizonDays, plan.Settings.BufferMinutes, plan.Settings.SlotIntervalMinutes).Scan(&version)
	if errors.Is(err, pgx.ErrNoRows) {
		return scheduling.Plan{}, scheduling.ErrVersionConflict
	}
	if err != nil {
		return scheduling.Plan{}, fmt.Errorf("update schedule settings: %w", err)
	}
	if _, err = tx.Exec(ctx, `DELETE FROM provider_availability_rules WHERE provider_id=$1`, providerID); err != nil {
		return scheduling.Plan{}, fmt.Errorf("clear schedule rules: %w", err)
	}
	for _, rule := range plan.Rules {
		if _, err = tx.Exec(ctx, `INSERT INTO provider_availability_rules(provider_id,weekday,start_minute,end_minute) VALUES($1,$2,$3,$4)`, providerID, rule.Weekday, rule.StartMinute, rule.EndMinute); err != nil {
			return scheduling.Plan{}, fmt.Errorf("insert schedule rule: %w", err)
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return scheduling.Plan{}, fmt.Errorf("commit schedule replace: %w", err)
	}
	plan.Settings.Version = version
	confirmed, err := repository.Get(ctx, uid)
	if err != nil {
		return scheduling.Plan{}, err
	}
	return confirmed, nil
}

func (repository *Repository) AddBlock(ctx context.Context, uid string, block scheduling.Block) (scheduling.Block, error) {
	providerID, err := repository.providerID(ctx, uid)
	if err != nil {
		return scheduling.Block{}, err
	}
	err = repository.pool.QueryRow(ctx, `INSERT INTO provider_schedule_blocks(provider_id,starts_at,ends_at,reason) VALUES($1,$2,$3,$4) RETURNING id::text`, providerID, block.Start, block.End, block.Reason).Scan(&block.ID)
	if err != nil {
		return scheduling.Block{}, fmt.Errorf("insert schedule block: %w", err)
	}
	return block, nil
}

func (repository *Repository) DeleteBlock(ctx context.Context, uid, id string) error {
	providerID, err := repository.providerID(ctx, uid)
	if err != nil {
		return err
	}
	command, err := repository.pool.Exec(ctx, `DELETE FROM provider_schedule_blocks WHERE id=$1::uuid AND provider_id=$2`, id, providerID)
	if err != nil {
		return fmt.Errorf("delete schedule block: %w", err)
	}
	if command.RowsAffected() == 0 {
		return scheduling.ErrNotFound
	}
	return nil
}

type queryer interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}

func (repository *Repository) load(ctx context.Context, db queryer, providerID string) (scheduling.Plan, error) {
	var plan scheduling.Plan
	err := db.QueryRow(ctx, `SELECT time_zone,minimum_notice_minutes,booking_horizon_days,buffer_minutes,slot_interval_minutes,version FROM provider_schedule_settings WHERE provider_id=$1`, providerID).Scan(&plan.Settings.TimeZone, &plan.Settings.MinimumNoticeMinutes, &plan.Settings.BookingHorizonDays, &plan.Settings.BufferMinutes, &plan.Settings.SlotIntervalMinutes, &plan.Settings.Version)
	if errors.Is(err, pgx.ErrNoRows) {
		return scheduling.Plan{}, scheduling.ErrNotFound
	}
	if err != nil {
		return scheduling.Plan{}, fmt.Errorf("load schedule settings: %w", err)
	}
	rules, err := db.Query(ctx, `SELECT weekday,start_minute,end_minute FROM provider_availability_rules WHERE provider_id=$1 ORDER BY weekday,start_minute`, providerID)
	if err != nil {
		return scheduling.Plan{}, fmt.Errorf("load schedule rules: %w", err)
	}
	for rules.Next() {
		var rule scheduling.Rule
		if err := rules.Scan(&rule.Weekday, &rule.StartMinute, &rule.EndMinute); err != nil {
			rules.Close()
			return scheduling.Plan{}, fmt.Errorf("scan schedule rule: %w", err)
		}
		plan.Rules = append(plan.Rules, rule)
	}
	rules.Close()
	blocks, err := db.Query(ctx, `SELECT id::text,starts_at,ends_at,reason FROM provider_schedule_blocks WHERE provider_id=$1 AND ends_at>now() ORDER BY starts_at,id LIMIT 200`, providerID)
	if err != nil {
		return scheduling.Plan{}, fmt.Errorf("load schedule blocks: %w", err)
	}
	defer blocks.Close()
	for blocks.Next() {
		var block scheduling.Block
		if err := blocks.Scan(&block.ID, &block.Start, &block.End, &block.Reason); err != nil {
			return scheduling.Plan{}, fmt.Errorf("scan schedule block: %w", err)
		}
		plan.Blocks = append(plan.Blocks, block)
	}
	return plan, blocks.Err()
}

func (repository *Repository) Snapshot(ctx context.Context, serviceID string, from, until time.Time) (scheduling.Snapshot, error) {
	var snapshot scheduling.Snapshot
	var providerID string
	err := repository.pool.QueryRow(ctx, `SELECT service.provider_id,service.duration_minutes,setting.time_zone,setting.minimum_notice_minutes,setting.booking_horizon_days,setting.buffer_minutes,setting.slot_interval_minutes,setting.version FROM services service JOIN providers provider ON provider.id=service.provider_id AND provider.active AND provider.accepting_requests AND provider.onboarding_status='approved' JOIN provider_schedule_settings setting ON setting.provider_id=provider.id WHERE service.id=$1 AND service.active AND service.deleted_at IS NULL`, serviceID).Scan(&providerID, &snapshot.DurationMinutes, &snapshot.Settings.TimeZone, &snapshot.Settings.MinimumNoticeMinutes, &snapshot.Settings.BookingHorizonDays, &snapshot.Settings.BufferMinutes, &snapshot.Settings.SlotIntervalMinutes, &snapshot.Settings.Version)
	if errors.Is(err, pgx.ErrNoRows) {
		return scheduling.Snapshot{}, scheduling.ErrNotFound
	}
	if err != nil {
		return scheduling.Snapshot{}, fmt.Errorf("load availability service: %w", err)
	}
	rules, err := repository.pool.Query(ctx, `SELECT weekday,start_minute,end_minute FROM provider_availability_rules WHERE provider_id=$1 ORDER BY weekday,start_minute`, providerID)
	if err != nil {
		return scheduling.Snapshot{}, fmt.Errorf("load availability rules: %w", err)
	}
	for rules.Next() {
		var rule scheduling.Rule
		if err := rules.Scan(&rule.Weekday, &rule.StartMinute, &rule.EndMinute); err != nil {
			rules.Close()
			return scheduling.Snapshot{}, err
		}
		snapshot.Rules = append(snapshot.Rules, rule)
	}
	rules.Close()
	blocks, err := repository.pool.Query(ctx, `SELECT starts_at,ends_at FROM provider_schedule_blocks WHERE provider_id=$1 AND starts_at<$3 AND ends_at>$2 ORDER BY starts_at`, providerID, from, until)
	if err != nil {
		return scheduling.Snapshot{}, fmt.Errorf("load availability blocks: %w", err)
	}
	for blocks.Next() {
		var item scheduling.TimeRange
		if err := blocks.Scan(&item.Start, &item.End); err != nil {
			blocks.Close()
			return scheduling.Snapshot{}, err
		}
		snapshot.Blocks = append(snapshot.Blocks, item)
	}
	blocks.Close()
	reservations, err := repository.pool.Query(ctx, `SELECT scheduled_for,reservation_end_at FROM service_requests WHERE provider_id=$1 AND status IN ('pending','accepted','in_progress') AND scheduled_for<$3 AND reservation_end_at>$2 ORDER BY scheduled_for`, providerID, from, until)
	if err != nil {
		return scheduling.Snapshot{}, fmt.Errorf("load availability reservations: %w", err)
	}
	defer reservations.Close()
	for reservations.Next() {
		var item scheduling.TimeRange
		if err := reservations.Scan(&item.Start, &item.End); err != nil {
			return scheduling.Snapshot{}, err
		}
		snapshot.Reservations = append(snapshot.Reservations, item)
	}
	return snapshot, reservations.Err()
}

func (repository *Repository) providerID(ctx context.Context, uid string) (string, error) {
	return providerIDQuery(ctx, repository.pool, uid)
}

type rowQueryer interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func providerIDQuery(ctx context.Context, db rowQueryer, uid string) (string, error) {
	var id string
	err := db.QueryRow(ctx, `SELECT id FROM providers WHERE owner_uid=$1 AND active AND onboarding_status='approved'`, uid).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", scheduling.ErrForbidden
	}
	if err != nil {
		return "", fmt.Errorf("authorize provider schedule: %w", err)
	}
	return id, nil
}
