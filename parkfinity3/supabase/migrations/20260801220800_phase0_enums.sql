-- Phase 0a - enum extensions (must commit before any function uses them).
-- Kept in its own migration; PG forbids using a new enum value in the same tx it is added.
ALTER TYPE booking_status   ADD VALUE IF NOT EXISTS 'Refunded';
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'refund';
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'overstay_charge';
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'commission';
