# ADR-005: Table booking payments (manual-capture hold, quotes, deposit modes)

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. The card-hold route is conditional on the Stripe spike (task T-090).
- **Requirements:** CR-07, CR-16, CR-21. Client answers-02 Q3 (card authorization), Q4 (quote validity), Q5 (hybrid settlement), Q14 (table deposit policy), Q15, Q16. Client answers-01 Q1.
- **Related:** `data-model.md` migration 15 (`TableRequest`, `TableQuote`, `OrderPayment`), `api-spec.yaml` `/v2/table-requests/*`, ADR-003 (fees), ADR-006 (settlement), ADR-007 (refunds), ADR-012 (server total)

## Context
Today a table (event module) with a fixed price is bought with `POST /purchase/module`; a "starting from" table is a public `Quote` with no payment. The client now wants one flow for both: a request, a quote when the price is not fixed, an authorization hold on the customer card for a known amount, acceptance by the venue, capture, and three ways to settle (deposit online plus balance at the venue, full payment online, or two online payments). The Technical Fee (5% of each amount paid in the app plus the fixed EUR 0.50 once, on the first online payment) and the Service Fee (15% for tables) follow ADR-003. A balance paid at the venue carries no Technical Fee, but the partner commission is due on the full base price.

## Decision
1. **State machine on `TableRequest`:** `REQUESTED` -> `QUOTED` (only for starting-from tables) -> `AUTHORIZED` (hold placed, pending venue) -> `ACCEPTED` -> `CAPTURED`/`CONFIRMED`; exits: `REJECTED`, `WITHDRAWN` (quote), `EXPIRED`, `CANCELED`, `CAPTURE_FAILED`. The booking is `CONFIRMED` only after a successful payment (Q3).
2. **Card hold (Q3 = A).** For a known amount, create a PaymentIntent with `capture_method=manual` on eligible payment methods. Venue accepts: reserve the table atomically (ADR-005 point 5) and capture before the real Stripe `capture_before` deadline. Venue rejects, quote withdrawn or hold expires: cancel the authorization, the customer pays zero including fees, the UI shows the release status. Capture fails: release the table and invite a retry.
3. **Fresh-payment fallback.** If manual capture is unsupported for the method or the hold expired, the customer is asked to pay after acceptance (normal PaymentIntent). No saved card, no off-session charge (a card guarantee needs separate terms, answers-01 Q1).
4. **Quote validity (Q4 = A).** Default 48 hours, configurable by the club, capped by the booking deadline. A quote is subject to availability until paid. The club may withdraw an unpaid quote early (table sold elsewhere); this is disclosed to the customer, the customer is notified and payment is disabled on a withdrawn quote. Three clocks stay separate: quote acceptance, the accepted-table inventory hold, and the Stripe `capture_before`. The standard checkout hold stays 15 minutes.
5. **No simultaneous sale.** A table is reserved by an atomic update (row lock or unique constraint on table, date and active request) when the venue accepts or when a fresh payment is created; availability is rechecked at acceptance and payment.
6. **Deposit modes (Q5 = C, club chooses what to offer):** (a) deposit online, balance at the venue (EUR 525.50 online then EUR 500 at the venue in the client example); (b) full payment online (EUR 1,050.50); (c) two online payments (EUR 525.50, then EUR 525 when the customer confirms the balance, fixed fee only on the first). Each online payment is an `OrderPayment` row with its own fee snapshot. Attendance and both payment channels are recorded.
7. **Commission shortfall.** On a completed table the Service Fee is due on the full base price in all three modes (EUR 150 on EUR 1,000). If less was paid online, the commission is allocated from the online amount where settlement permits and the shortfall is recorded as a receivable from the partner (ADR-006, ADR-007 recovery order).
8. **Policy per table (Q14 = C).** The club sets the deposit and cancellation policy per table (non-refundable or expressly refundable terms), shown before payment; the terms accepted are stored with the booking and applied; the venue can grant exceptions.
9. **Party size** and admitted attendees are recorded on the booking; table guests are counted once in capacity.
10. Existing v1 behaviour stays: fixed-price tables via `POST /purchase/module`, `QUOTE_REQUIRED` 409 for starting-from tables (T-056), public `POST /quotes` (deprecated, rate-limited). The new flow is `/v2/table-requests` only.

## Consequences
- The live Flutter app keeps working on v1; it cannot use holds, deposits or the second payment until the Flutter tasks (FL-115 to FL-118) ship. v1 fixed tables keep full-payment-at-purchase.
- The Technical Fee amounts shown to the customer come from `POST /v2/checkout/preview` (ADR-012), including for each payment of a plan.
- Webhooks must handle `amount_capturable_updated`, `payment_intent.canceled` and capture failure.
- New admin and owner screens for quotes and policies (tasks T-112 to T-122).

## Alternatives considered
- **Always pay after acceptance (no holds):** simpler, but loses the "declined costs zero" guarantee being card-based and delays confirmation. Kept only as the fallback.
- **Saved card guarantee:** needs separate terms. Rejected (answers-01).
- **WhatsApp-only quotes:** no payment link and weak tracking. Rejected (ADR-009).

## Open points
- Deadline for the second online payment and what happens if it is not paid (asked in the client clarification document).
- Holding limits, authorization cost and supported methods per country are confirmed only by the Stripe spike (T-090); until then holds are "proposed" (answers-01 Q1).
