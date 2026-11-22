# ADR-004: Updating ticket tiers in place, with a matching fallback for clients that send no ids

- **Status:** Accepted (spec diff approved 2026-11-21)
- **Requirements:** CR-04 (BUG-B24, High)
- **Related:** `api-spec.yaml` `PUT /event/{id}`, `data-model.md` 8.3 and migration 5, `known-issues.md` B-24

## Context
`PUT /event/{id}` with `ticketTiers` runs `eventTicketTier.deleteMany({ where: { eventId } })` and recreates every tier (`event.services.ts:223-243`). The incoming `id` is dropped, so `soldCount` returns to 0 and tier ids change. An owner who edits an event name and re-sends tiers can oversell. The live Flutter app is not known to send tier ids (⚠️ UNVERIFIED), so requiring them would break it.

## Decision
All inside one transaction:
1. **Tiers with an `id`** that belongs to this event are updated in place (`soldCount` and id kept). An id from another event returns 404.
2. **Tiers without an `id` when at least one incoming tier has an id:** created as new.
3. **Fallback when no incoming tier has an id** (legacy clients): match by key, one existing tier per incoming tier. Section (no parent): `(groupName, tierName)`. Child: `(matched parent id, tierName)`. Keys are compared after `trim()`, case-insensitively, with a null `groupName` treated as empty. Unmatched incoming tiers are created.
   **Duplicate names in the same group** (the same key appears more than once, among existing tiers, incoming tiers, or both). Duplicates are legal today (no unique constraint), so they are neither rejected nor merged. Rule, in this order:
   1. Among tiers sharing a key, first pair incoming and existing tiers that also have the same `price` and `capacity` (exact pairs).
   2. Pair the remaining ones by position: existing tiers ordered by `(sortOrder, createdAt, id)`, incoming tiers in array order, first with first.
   3. Surplus incoming tiers (more incoming than existing) are created. Surplus existing tiers (fewer incoming) are the later ones and follow decision 4 below.
   4. If a pairing in step 2 joins tiers with different `price` or `soldCount`, the pair is still made (position wins) and the server logs `TIER_MATCH_AMBIGUOUS` with the event id and tier ids. It is a warning, not an error, because the live app cannot disambiguate.
   Example: existing `Early` (10 EUR, sold 7) and `Early` (12 EUR, sold 0); the app sends `Early` 12 EUR then `Early` 10 EUR. Step 1 pairs them by price, so the 7 sold stay on the 10 EUR tier even though the order changed.
4. **Existing tiers not matched:** deleted if `soldCount = 0`, otherwise deactivated (`isActive = false`) and kept, so sold history, `EventPurchase.ticketTierId` and reports stay valid. Customers no longer see deactivated tiers.
5. **Edits after sales:** `price`, `description`, dates and `sortOrder` may change (past orders hold their own price snapshot). `capacity` below `soldCount` returns 409 `TIER_CAPACITY_BELOW_SOLD`. Moving a tier to another parent is allowed.
6. `soldCount` is never accepted from the client.
7. `lineup` is out of scope here and keeps its current replace behaviour.

## Alternatives considered
- **Reject duplicate names (422):** cleaner, but existing data may already contain duplicates and the live app does not prevent them. Rejected; revisit with the Flutter release.
- **Require ids (400 without):** correct but breaks the live app. Rejected for v1; fine for a future v2.
- **Never delete tiers, only deactivate:** keeps history but clutters the owner form. Rejected for unsold tiers.
- **Unique key `(eventId, groupName, tierName)` in the DB:** existing data may contain duplicates, so the migration could fail. Rejected; a plain index is added instead.

## Consequences
- A rename without an id looks like "remove old, add new": if the old tier had sales it stays deactivated and the renamed one starts at 0. Clients should send ids (Flutter milestone M8).
- Stock that was already leaked before this fix is not recovered (`data-model.md` 8.6.3).
- Existing tiers keep their `soldCount` through migration 5; the migration does not touch tier rows.
