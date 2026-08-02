# Archived SQL — applied out-of-band before migration tracking

These files were run manually against **ParkFinityDB** (`rkqduzjkkyplceipydir`) before
migrations were the source of truth. They are kept for history only. **Do not re-run.**
The live schema is now defined by `supabase/migrations/`.

| File | Live on remote? | Notes |
|---|---|---|
| `handle_new_user.sql` | YES | `on_auth_user_created` trigger → inserts profile from auth metadata. |
| `storage_policies.sql` | YES | Buckets `listings`, `documents` + per-owner RLS. |
| `wallet_transactions.sql` | YES | `transactions` table + `add_funds`/`deduct_funds` RPCs. |
| `vehicles_schema.CONFLICT.sql` | **NO — conflicts** | Redefined `vehicles` (rider_id/make/model). Remote uses the migration version (owner_id/type/brand). Discarded. |
| `decrement_slots.SUPERSEDED.sql` | (was live) | Flat-integer decrement. Replaced by race-safe `book_slot`/`release_slot` in `20260801220856_phase0_foundation.sql`. |

Drift resolved in Phase 0. Future schema changes: `supabase migration new` → `supabase db push --linked`.
