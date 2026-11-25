# ADR-006: Settlement, payouts and ledger

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. Stripe-dependent parts are conditional on the Stripe spikes (T-091, T-092).
- **Requirements:** CR-21, CR-02, CR-16. Client answers-02 Q7 (split preview), Q8 (event end plus three days), Q9 (failed payouts), Section 2 intro, Section 8 (payment, fiscal issue, admission and payout are independent states).
- **Related:** `data-model.md` migration 16 (`SettlementArrangement`, `LedgerEntry`, `Transfer`), `api-spec.yaml` `/v2/events/{eventId}/settlement`, `/v2/owner/settlements`, `/v2/admin/settlements`, `/v2/admin/transfers/{id}/retry`; ADR-003, ADR-005, ADR-007; existing `connect` module

## Context
Customer payments land on the Bookdia Night Stripe account. Partners (club, organizer) receive their share through Connect. The client wants automatic percentage splits chosen per event (EUR 10 example: EUR 1 platform, EUR 2 organizer, EUR 7 club, Technical Fee separate), payouts three calendar days after the event ends, shares shown as Pending then Confirmed, withdrawal disabled before release, holds for open refunds or disputes, reversals, and a retry policy. Admission and scan status are independent of settlement status: a no-show alone does not suspend settlement, and a paid admission must never be pending because a payout is.

## Decision
1. **Charge model: separate charges and transfers.** The customer is charged on the platform account when the booking is confirmed and a valid ticket is issued. Money moves to partners with `transfers` created by us later. Destination charges are not used because the transfer date is days after the event and amounts change with refunds.
2. **Split setup (Q7 = A).** Admin sets the Bookdia Night share (the Service Fee). The club owner proposes the remaining split; the organizer accepts in the app before sales open; an admin can step in. Amounts are visible privately to the parties. The settlement mode is selected before sales open. `SettlementArrangement` stores the agreed percentages and mode and is locked once sales open.
3. **Fallbacks.** If the organizer cannot receive payments, the organizer share is routed to the eligible club under the agreed fallback and the preview says so. If the club cannot receive funds, the arrangement is flagged `NEEDS_RESOLUTION` and sales of that event are blocked until resolved. For approved unregistered venues the onboarded organizer receives the seller proceeds (answers-01 Q3).
4. **Ledger.** `LedgerEntry` rows (per order item, payee, kind: PARTNER_SHARE, PLATFORM_SERVICE_FEE, TECHNICAL_FEE, REVERSAL, RECOVERY) with state `PENDING` until event end, then `CONFIRMED_SCHEDULED` with the expected transfer date, then `TRANSFERRED` / `REVERSED`. Customers and partners see the share state; internal states for payment, issue, admission and payout stay separate.
5. **Transfer timing (Q8 = A).** A scheduler job (not a request path) creates transfers three calendar days after the event end for eligible entries, subject to Stripe availability. Withdrawal stays disabled before release. For multi-day events, "event end" is the end of the last day.
6. **Holds.** The amount affected by an open refund request or dispute is held; undisputed amounts are released.
7. **Reversals.** Before transfer, reverse the affected internal shares including the applicable Service Fee. After transfer, use full or partial transfer reversals (`transfers.createReversal`) and record any unrecovered amount as a `PartnerDebit` (ADR-007). The platform must keep enough available balance; the spike confirms Stripe holding limits for advance sales and how the platform keeps sufficient available funds.
8. **Failed payouts (Q9).** Immediate notice to admin and partner. Transient failures retried up to 3 times in 3 days with an idempotency key per transfer. An invalid IBAN or a missing document produces an immediate notice with the required action. Funds stay in the Bookdia Night Stripe balance; we explain to the client where funds sit and when sales may continue under account restrictions (our proposal: sales continue).
9. **Reporting.** Allocations, transfers to connected accounts and bank payouts are shown as separate events in statements (`/v2/owner/settlements`, `/v2/admin/settlements`).
10. **Existing code.** The `connect` module and its webhook are kept; v1 owner earnings stay as they are (T-060 adds table purchases). No existing response field changes.

## What the Stripe spikes must confirm (tasks T-091, T-092)
- Available-balance behaviour and Stripe holding limits when charges are held weeks before the event; how the platform keeps enough available funds; any payout schedule delay.
- Separate charges and transfers across the launch countries and cross-border transfers (Italy, France, Monaco, Spain, US); Connect account types and onboarding per country.
- Monaco payout eligibility on the actual account (report feasibility).
- Transfer reversal behaviour for partial refunds and an insufficient partner balance (demonstrate both).
- Failed-transfer and payout events and their webhook payloads; idempotency of transfers.
- Connect pricing and per-transfer costs for the cost record (ADR-003).

## Consequences
- The live app is unaffected (settlement is backend and owner/admin side). Owner screens that show expected transfer dates need Flutter work (FL-130).
- Scheduler and worker gain jobs (`create-transfers`, `retry-transfer`); both need DB-backed tests.
- Legal and tax treatment of holding client money for days is for the client's advisers (answers-02 items 08, 13).

## Alternatives considered
- **Destination charges with instant split:** simple, but cannot hold, reverse or pay days after the event. Rejected.
- **Pay as sales happen:** exposes the platform to refunds and cancellations. Rejected (client chose A).
- **Club receives everything and pays the organizer:** no visibility or guarantee. Rejected (answers-01 Q3).

## Open points
- Which entity is liable for Stripe fees on transfers and reversals (accounting note owed to the client).
- Monaco eligibility and any country where Connect cannot pay out.
