# ADR-003: Fee and commission rules with effective dates

- **Status:** Accepted for the structure; rule VALUES wait for client answer Q2 (spec diff approved 2026-11-21)
- **Requirements:** CR-15 (partial), CR-06 (free orders), CR-16 (refund treatment). Tracker E2 to E5.
- **Related:** `data-model.md` 8.2 (`PricingRule`), 8.5, migration 6; `api-spec.yaml` `/v2/admin/pricing-rules`, `/v2/admin/financials`

## Context
Today there is one flat `ServiceCharge` (`id = 'GLOBAL'`, `purchase.services.ts:137,264,480`) and one `ApplicationCharge` percentage per `Service` (EVENT, CLUB; `purchase.services.ts:134,261,477`). Tables (modules) use the EVENT rate. The client wants rules per product category, per client and per event, as percentage or fixed amount, with effective dates, a clear precedence, and no rewriting of past orders. Technical fee and commission must stay separate.

## Decision
- One table `PricingRule` with `ruleType` (FEE | COMMISSION), `productCategory` (TICKET | TABLE | EXTRA | CLUB_BOOKING), `scope` (GLOBAL | CLIENT | EVENT, with `scopeId`), `valueType` (PERCENT | FIXED, `perUnit` for FIXED), `value`, optional `minAmount`, `priority`, `effectiveFrom`, `effectiveTo`.
- **Resolution** at order creation, once per (ruleType, productCategory), at `now()`: candidates are rules where `effectiveFrom <= now` and (`effectiveTo` is null or `> now`). Winner: scope rank EVENT > CLIENT > GLOBAL, then higher `priority`, then later `effectiveFrom`. Amounts use `Decimal`, rounded half up to 2 places (as commission is today).
- **History is immutable.** The order keeps its existing amount snapshots and stores `appliedFeeRuleId` and `appliedCommissionRuleId`. A rule never changes an existing order or a settled payout. Orders created before the release have NULL rule ids.
- **Rules are append-only.** A rule already in force can only be end-dated. Value, priority and start can change only while `effectiveFrom` is in the future.
- **Seeding.** Migration 6 creates GLOBAL rules from the current `ServiceCharge` and `ApplicationCharge` values, effective from 1970-01-01, so behaviour is unchanged on day one.
- **v1 stays and writes through.** `PATCH /admin/commission` and `PATCH /admin/service-charge` (deprecated, not removed) end the current GLOBAL rule and create a new one effective immediately, then update the old table, so the Admin pages and the live app keep working. This is the only path allowed to start a rule "now"; `POST /v2/admin/pricing-rules` requires a future `effectiveFrom` except for the first rule of a combination.
- **DB CHECKs on `Order` change** (`data-model.md` 8.5): service charge `>= 0` (free orders), and commission equality applies only when no commission rule id is stored.
- Free orders: opt-in only (`freeCheckout: true` on `POST /purchase/event`), the buyer fee is then waived (provisional, Q2). Without the flag the live app keeps today's behaviour: a price-0 order still carries the service fee. Refunds: `Refund.returnServiceFee` records the decision; default keeps the fee, as event-cancellation refunds do today.

## Alternatives considered
- **Two tables (FeeRule, CommissionRule):** duplicate columns and code. Rejected.
- **Extend `ApplicationCharge` with columns:** cannot express scope, history or fixed amounts. Rejected.
- **Compute fees at read time from current rules:** rewrites history. Rejected.

## Consequences
- Checkout gets a rule-resolution step (one extra query per order); needs an index (`data-model.md` 8.4).
- Two sources of truth exist until v1 is sunset; the write-through must ship in the same release as migration 6.
- Open: who pays commission (club vs customer), fee on tables/extras, minimums (Q2). The structure supports each answer without a schema change.
