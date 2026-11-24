# Internal map for `client-clarifications-2026-11-24.md` (NOT for the client)

Maps each question to our internal identifiers, what it unblocks, and the default we keep assuming until it is answered. Nothing here is a decision. Sources: `01-discovery/client-answers-02.md` (called "answers-02"; its question ids are Q1 to Q34 of `client-clarifications-2026-11-22.md`), `client-answers-review-2026-11-22.md`, `02-product/change-requests.md`, ADR-002, ADR-003, ADR-005 to ADR-013, `04-architecture/data-model.md`, the task manifest (task ids T-080 onward and FL-101 onward are new).

| Q | Topic (answers-02 ids) | Internal ids | Unblocks | Assumed until answered |
|---|---|---|---|---|
| 1 | Target or fixed dates (Q32) | Phases in `completion-plan-2026-11-24.md`; decision 2 of the brief | The phase dates | Mid-December is a target, not a fixed date |
| 2 | Approval of new scope and cost (Q34, "scheduling does not approve charges") | CR-29, CR-30, CR-31 (new scope); CR-32, CR-33, CR-34 (later phases); `scope-and-timeline-2026-11-24.md` | Any task for new scope | No tasks for new scope; Phase 1 and Phase 2 items already inside the original scope go ahead |
| 3 | Technical Fee refund on partner cancellation (Q10, Q11) | CR-22; ADR-007; T-140 (partner cancellation flag per market), T-141, T-142, T-145; adviser input | Customer refund amount and the club debit | Flag per market; default refund in EU markets, kept in the US (US default also unconfirmed) |
| 4 | Partner and customer account (Q22, Q23) | CR-18; ADR-010; T-080 to T-083; FL-102; BUG-S03 | Final sign-up shape and the pending screen | One login; pending partner sees only the club-area home (423 PARTNER_APPROVAL_PENDING); the "separate customer account" wording is not built |
| 5 | Italian ticketing decision-maker (Section 7 of answers-02) | CR-29; `siae-decision-memo-2026-11-24.md` | The route decision and the date | Italian live sales off; test mode only |
| 6 | Fixed fee per currency (Q1) | CR-15, CR-26; ADR-003; T-093 (fixed amount per currency), T-096 | Prices outside EUR | EUR 0.50 and USD 0.55 table, admin-editable |
| 7 | Inclusive display per market (Q2, section 9) | CR-26; ADR-012; T-097, FL-111 | Checkout wording per market | US inclusive, other markets itemized |
| 8 | Cote d'Azur town list (Q26) | CR-24; ADR-011; T-162, T-163, T-164, T-182; FL-132 | Area boundary and seed | The proposed nine towns; Monaco separate |
| 9 | Owner and organizer age (Q31, open list) | CR-28; T-174 (age rule field only) | Partner sign-up rule | 18 (the current rule) |
| 10 | Customers under 18 (Q31) | CR-28; T-174, FL-133; `MIN_SIGNUP_AGE = 18`; T-009 (422 for under-age social sign-in) | Any change to the age rule | 18+ stays in code until the adviser confirms in writing |
| 11 | Last-minute threshold and refund window (Q11) | CR-23; T-144 (change notice and window) | Refund route and the deadline shown to guests | 48 hours; window configurable per club, default 7 days |
| 12 | Chat retention (Q6) | CR-20; ADR-009; T-168 (retention job) | The retention job | 30 days after closure deletes chat text only; payment and booking records kept |
| 13 | Second table payment deadline (Q5) | CR-07; ADR-005; T-119, FL-117 | Second-instalment screens and rules | Club sets deadline, default 48 hours before the event; deposit follows the table policy if unpaid |
| 14 | Default permission matrix (Q24) | CR-19; ADR-008; T-102, T-109, T-176, FL-121 | Default grants for the 4 platform and 5 club roles | We send a draft table; admin edits later |
| 15 | Working-day calendar (Q25) | CR-23; T-160 | The 2-working-day timer | Venue's country |
| 16 | Guest-list and access codes priority (Q19) | CR-06; T-156, T-184, FL-128 | Phase of the codes work | Soon after launch (Phase 3 candidate) |

## Checklist items mapped

| Client checklist item | Internal reference |
|---|---|
| Stripe access and test keys | answers-02 item 01; T-090, T-091, T-092 (access received; the spikes report what is missing); decision 1 of the brief |
| Apple, TestFlight, Google Play, sign-in settings | item 02; FL-101 onward builds; release approval (Q30) |
| Push access | item 03; T-171 |
| Test system and hosting | item 04; T-085, T-086 (read-only run on live data) |
| WhatsApp Business number | Q6; T-169 |
| Screen-recording link | item 10 |
| Operational admins | item 12; T-083, T-159 |
| Advisers | item 13; Q3, Q10, Q12 |
| Backup product owner | item 11 |
| Venue authorization form | item 07; T-157 |
| Terms | item 08; CR-31 (new scope) |

## Items we did NOT ask (decided by us or already clear)

- Everything answered clearly in answers-02: fee rates and override order (Q1, Q2), card hold (Q3), 48-hour quote (Q4), settlement 3 days after event end (Q8), failed-transfer retries (Q9), per-day no-show and entry cutoff (Q17, Q18), tier progression and "Last tickets" at 20% (Q20), time zone backfill (Q21), existing owners keep access (Q23), release approval (Q30), languages EN, IT, FR, ES (Q33), launch priorities (Q34).
- Which stored facts the backend keeps for tax purposes (internal, decided in ADR-006 and ADR-007).
- The HTTP status used for a pending partner (423; ADR-010) and the version-policy gate (ADR-012): internal.
- Stripe payout eligibility per country and Monaco feasibility: our deliverable (T-092), not a client question.

## Questions merged or dropped to keep the document short

- Placement of the WhatsApp number, recording link, admins, advisers and form folded into the final checklist.
- Platform role names and the 10 test logins: no question, our deliverable (T-111).
- Date of the Italian decision folded into Q5.
