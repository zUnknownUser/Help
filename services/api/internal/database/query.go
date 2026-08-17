package database

import sq "github.com/Masterminds/squirrel"

// Query is the single PostgreSQL-aware statement builder used by adapters.
// Keeping placeholder configuration here prevents repositories from knowing
// or duplicating driver-specific formatting rules.
var Query = sq.StatementBuilder.PlaceholderFormat(sq.Dollar)

func Expr(expression string, args ...any) sq.Sqlizer {
	return sq.Expr(expression, args...)
}
