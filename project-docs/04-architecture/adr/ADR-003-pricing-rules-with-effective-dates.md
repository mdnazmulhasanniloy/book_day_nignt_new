# ADR-003: Fee and commission rules with effective dates

- **Status:** Accepted for the structure (spec diff approved 2026-11-21). Rule values received 2026-11-24 (client answers-02 Q1-Q2). Structure amended 2026-11-24 (proposed, awaiting product owner confirmation): see 'Amendment 2026-11-24'. Migration 6 (T-022) is not written yet and must follow the amendment.
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

## Amendment 2026-11-24 (client answers-02, Q1, Q2; Section 8 Technical Fee and accounting)
Terminology (client): **Technical Fee** is the customer booking fee; **Service Fee** is the partner commission included in the base price. Earlier documents called the customer fee "service fee" and the partner share "commission". Docs and admin labels follow the client; API and DB names (`serviceChargeAmount`, `/service-charge`, `ApplicationCharge`, `ruleType` FEE and COMMISSION) are NOT renamed because the live app uses them. Mapping: FEE rule = Technical Fee; COMMISSION rule = Service Fee.

Launch values (Italy, France, Monaco, Spain, US; changeable by admin per country and category):
- Technical Fee: 5% of the eligible paid subtotal plus the local-currency equivalent of EUR 0.50 once per order. EUR 20 ticket costs EUR 21.50; two cost EUR 42.50. Free tickets and guest lists: the guest pays zero.
- Service Fee: 10% tickets and passes; 15% tables, sunbeds and extras. Partner pays zero on free admissions unless admin sets an agreed fixed amount.

Changes to the structure (migration 6 and the resolver):
1. **A rule can carry a percent part and a fixed part** (`percentValue`, `fixedValue`, `fixedCurrency`) instead of one `valueType`. The fixed part is charged **once per order, on the first online payment**; later online payments (deposit then balance) carry only the percent part; a balance paid at the venue carries no Technical Fee.
2. **Fixed amount per currency** (no live FX conversion): admin stores the amount for each currency; EUR 0.50 is the reference. The USD amount is a client input.
3. **New scopes and precedence:** COUNTRY and category defaults, then client (club/partner), VENUE, EVENT, and finally an individual TABLE_QUOTE override. Winner order: TABLE_QUOTE > EVENT > VENUE > CLIENT > COUNTRY > GLOBAL, then `priority`, then later `effectiveFrom`. Admin may lower either fee or set it to zero.
4. **Display mode** per market and category (`ITEMIZED` | `INCLUDED`), returned by the server preview (ADR-012).
5. **Rates used are saved on each sale** (order and each `OrderPayment`), later changes apply to new orders only; in mixed baskets the fixed part is charged once and its **allocation per item** is recorded for partial refunds.
6. **Processor cost** (actual Stripe cost per payment, and provider cost per issued ticket where relevant) is stored separately from the partner Service Fee and the platform margin.
7. **Partner-side fixed charge on free admissions:** optional, admin-enabled, never charged to the free guest.
8. **Preview before saving:** the admin sees the resulting price and sample orders per market (Gap 2, the pricing-rule preview, is now required: task T-096 and the admin calculator).
9. **Commission shortfall** when less is paid online than the commission due is a receivable from the partner (ADR-005, ADR-006, ADR-007).
10. Refund treatment of the Technical Fee follows ADR-007 (retained on customer-initiated cancellation; partner-funded refund on partner cancellation with admin waiver). `Refund.returnServiceFee` is superseded by `RefundItem` fields in migration 17.

Backward compatibility: v1 `/admin/commission`, `/admin/service-charge` and `/service-charge` keep working and write through to the rules; the live app total comes from the legacy flat fee until the force-update gate and the preview endpoint ship together (ADR-012).
The earlier test figure 1.5% + EUR 0.26 is not a price and is not used.
