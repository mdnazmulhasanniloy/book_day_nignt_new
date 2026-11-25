# ADR-013: Multi-day passes, per-day credentials, scanning and no-show

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. The CR-05 deferral is lifted.
- **Requirements:** CR-05, CR-04, CR-06, CR-08. Client answers-02 Q17-18, Q19, Q20-21, Section 8 (admission and inventory). Client answers-01 Q5.
- **Related:** `data-model.md` migrations 18 and 22 (`EventDay`, `PassDayEntitlement`, `TicketCredential`, `EntryScan`); `api-spec.yaml` `POST /v2/owner/scan`, `GET /v2/events/{eventId}/days`; ADR-004, ADR-007

## Context
Today `POST /owner/verify-ticket` marks one `Order.checkedInAt`: one check-in per order, no day, tier or attendee. A multi-day pass must give one valid admission per covered day, reserve one place on each included date, and record no-shows per day. The client's rules: no-show recorded at each day's entry cutoff, next day stays valid; the club sets the entry cutoff (default event end) and the guest-list approval hold (default 24 h, 1 to 72 h, capped by the entry cutoff); the next tier opens on sellout; the lowest available price is shown; "Last tickets" at 20% or less of a tier; venue staff may reduce online inventory for offline sales; checkout hold stays 15 minutes.

## Decision
1. **Model.** `EventDay` (eventId, date, capacity, entryCutoff), tier validity per day, `PassDayEntitlement` (attendee, day), and one `TicketCredential` per covered day under the same pass (single-use). `EntryScan (credentialId, doorId, result, scannedAt, scannedBy)` records every scan.
2. **Capacity per day** = declared venue capacity minus confirmed admissions, offline allocations and active holds, each counted once; a pass needs a place on every covered day; if one day is full only eligible options remain on sale. Reductions below commitments are rejected (T-004 rule extended).
3. **Scan endpoint v2** `POST /v2/owner/scan`: one successful scan per credential; repeated scans, cancelled or wrong-day or wrong-event credentials are rejected with 404/409/422, never 401/403 (live Flutter treats 403 like 401); two doors at once resolve by a conditional update on the credential. v1 `verify-ticket` stays unchanged and deprecated (ADR-001).
4. **No-show.** A scheduler job marks unused credentials of a day as no-show at that day's entry cutoff; the next covered day stays valid. A group with zero arrivals is reported separately from a partly attended group.
5. **Guest list.** A pending request holds a place until the approval hold ends (default 24 h, 1 to 72 h, capped by the entry cutoff); on expiry the pending place is released and the guest is told.
6. **Progression and display.** When a tier sells out the next opens automatically; `startingPrice` is the lowest tier currently on sale; availability badge `LAST_TICKETS` at 20% or less of that tier while stock remains; exact counts are hidden from public responses (v2 shape; v1 `soldCount` stays).
7. **Tables.** A table with N guests records party size and admitted attendees; eight guests are counted once in capacity.
8. **Codes (Q19).** One code model: purpose (discount or guest-list request), event or list, expiry, use limit (1 = single-use, 100 = shared). Guest-list codes submit a request; the ticket is issued after approval where required. Identity-bound invitations come later.
9. **Time zone.** All day logic uses `Event.timezone`; a backfill sets it from venue or city for existing events (ambiguous ones are flagged, organizers can correct).

## Consequences
- New tables and jobs; Flutter scanner and ticket screens change (FL-124 to FL-126). The old app keeps scanning with v1 per-order check-in.
- Analytics (CR-08) gains scans, no-shows and attendance rate.
- Italian fiscal admission may add constraints (do not deliver an active QR before issue is confirmed); that is new scope (CR-29) and not part of this ADR.

## Alternatives considered
- **One credential per pass:** cannot record per-day entry or no-shows. Rejected.
- **No-show only after the whole event:** the client chose per day (Q17 = A).
- **Extend `Order.checkedInAt`:** per-order, not per attendee or day. Rejected.

## Open points
- Whether guest-list access codes are Launch (priority not stated).
- Door identification and offline scanning rules.
