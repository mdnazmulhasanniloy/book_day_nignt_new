# ADR-007: Refund engine and partner cost recovery

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. Supersedes the refund-request design of CR-16 (T-063 to T-066, T-078) where it conflicts.
- **Requirements:** CR-22, CR-23, CR-16. Client answers-02 Q10 (partner cancellation and fee recovery), Q11 (date or venue change), Q12-13 (authority, goodwill), Q14, Q15 (restock), Q25.
- **Related:** `data-model.md` migration 17 (`RefundItem`, `PartnerDebit`, per-ticket status); `api-spec.yaml` `/v2/bookings/{id}/tickets/{ticketId}/cancel`, `/v2/owner/orders/{orderId}/refunds`, `/v2/admin/refunds`, `/v2/admin/partner-debits/{id}/waive`, `/v2/admin/charge-to-club`, `/v2/owner/events/{eventId}/restock`; ADR-003, ADR-006, ADR-008

## Context
The built model allows one refund per order (`Refund.orderId` unique), refunds only on formal event cancellation (service fee kept), and `verify-ticket` rejects any order with a refund. The CR-16 design had the owner request and the admin approve every refund, with whole order or one amount, no per-attendee refund and no stock release. The client replaced that: per-ticket cancellation, automatic refunds under the club's published terms, club (or owner-permissioned organizer) authority for exceptions, partial goodwill refunds with admission kept, automatic restock while sales are open, and recovery of the customer Technical Fee refund from the responsible partner.

## Decision
1. **Per-ticket status.** Each admitted attendee ticket has a status (`VALID`, `USED`, `CANCELED`, `REFUNDED`) and credential. Cancelling one ticket invalidates that credential and keeps the others. Refunds become one-to-many (`Refund` 1:N per order, `RefundItem` per ticket or amount); the old unique constraint is relaxed in migration 17 and every `order.refund` check in code is revisited.
2. **Authority (Q12-13).** Eligible voluntary cancellations are refunded automatically under the published policy (cutoff in hours or non-refundable, shown before purchase). After the cutoff the club decides exceptions; organizers need explicit owner permission (ADR-008); reservations staff forward requests; platform admins handle disputes only. Admin approval of every refund is removed.
3. **Customer-initiated cancellation.** Refund the admission price, reverse the Service Fee, retain the Technical Fee, including inside the free window, subject to mandatory local rules; this is shown before purchase. Example: EUR 20 ticket plus EUR 1.50 Technical Fee refunds EUR 20.
4. **Goodwill (Q13 = A).** A club may approve a documented partial refund while admission continues. Italy: a partial goodwill adjustment keeping admission needs separate fiscal treatment (answers-02 Section 8); blocked for Italy until the adviser confirms.
5. **Partner cancellation (Q10).** Refund the cancelled admission and reverse its Service Fee. The Technical Fee is non-refundable by default; it is refunded whenever law or the booking terms require it, and an admin may authorize a full or partial discretionary refund. A per-market flag decides the default for partner-cancelled events until the terms and the adviser fix it.
6. **Recovery.** By default the responsible club (or the organizer under its agreement) is debited the full Technical Fee actually refunded (`PartnerDebit`). Only a Bookdia admin can waive part or all of its margin, case by case, down to the documented unrecovered Stripe cost. The approval screen shows original fee, actual cost, waiver and partner debit; approver and reason are logged. The cost is never charged twice. Recovery order: eligible partner balance, then future settlements, then an invoice for the shortfall under the partner agreement. The customer receives the refund independently of recovery.
7. **Admin-only "Charge to club".** For chargebacks arising from event cancellation or change; records customer refund, platform contribution and the remaining debit separately with amount, reason and approver; bank credits are reconciled to prevent double reimbursement.
8. **Date or venue change (Q11).** Notify guests immediately; unused tickets stay valid; guests who decline may refund within 7 days of notice and before use (exact deadline shown); an immediate refund route for a last-minute change; Technical Fee per point 5 and 6.
9. **Restock (Q15).** Unused invalidated tickets, including an approved late cancellation, return to sale automatically while sales are open and before the club's closing time; none on a cancelled event; manual restock action with a double-release guard; the owner or authorized organizer is notified when manual release is needed.
10. **Processor confirmation.** A refund stays `PENDING` until the processor confirms; refund webhooks (T-067) update status.
11. **History.** Keep a history of ticket changes; a closed event can still have a support case, bank dispute or accounting adjustment.

## Consequences
- Breaking for built code only (not the live app): `Refund` uniqueness, `verify-ticket` rule "any refund blocks entry" (replaced by per-ticket status in the v2 scan endpoint, ADR-013; v1 keeps its behaviour). Event-cancel refunds keep their current behaviour on v1 until the new engine ships.
- T-063 to T-066 and T-078 are superseded; T-067 (webhooks), T-068 (admin orders) stay.
- Settlement holds and reversals depend on ADR-006.

## Alternatives considered
- **Keep admin approval and add per-ticket status:** contradicts Q12. Rejected.
- **Always refund the Technical Fee:** contradicts "non-refundable by default" (Q10, Q12-13). Rejected.
- **Charge the partner the whole refund:** contradicts commission reversal rules. Rejected.

## Open points
- Default for refunding the Technical Fee when the partner cancels (depends on terms and adviser; clarification document).
- What counts as a "last-minute" change and whether the 7-day window is configurable.
- Fiscal treatment of Italian goodwill and refunds (CR-29, new scope).
