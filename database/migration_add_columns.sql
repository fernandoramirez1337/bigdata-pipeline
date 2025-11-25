-- Migration script to add missing columns to daily_summary table

ALTER TABLE daily_summary ADD COLUMN IF NOT EXISTS credit_card_trips BIGINT DEFAULT 0;
ALTER TABLE daily_summary ADD COLUMN IF NOT EXISTS cash_trips BIGINT DEFAULT 0;
ALTER TABLE daily_summary ADD COLUMN IF NOT EXISTS avg_tip DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE daily_summary ADD COLUMN IF NOT EXISTS max_fare DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE daily_summary ADD COLUMN IF NOT EXISTS min_fare DOUBLE PRECISION DEFAULT 0.0;
