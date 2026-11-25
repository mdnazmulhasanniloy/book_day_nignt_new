# Internal map for `client-clarifications-2026-11-24.md` (NOT for the client)

Maps each question to our internal identifiers, what it unblocks, and the default we keep assuming until it is answered. Nothing here is a decision. Sources: `01-discovery/client-answers-02.md` (called "answers-02"; its question ids are Q1 to Q34 of `client-clarifications-2026-11-22.md`), `client-answers-review-2026-11-22.md`, `02-product/change-requests.md`, ADR-002, ADR-003, ADR-005 to ADR-013, `04-architecture/data-model.md`, the task manifest (task ids T-080 onward and FL-101 onward are new).

| Q | Topic (answers-02 ids; old number) | Internal ids | Unblocks | Assumed until answered |
|---|---|---|---|---|
| 1 | Option A, B or C and approval of new scope and cost (Q32, Q34; old Q1 and Q2 merged) | Section 9 of `completion-plan-2026-11-24.md`; CR-29 to CR-34 (new scope); `scope-and-timeline-2026-11-24.md` section 5A | The plan of record and any task for new scope | Option A stays the plan of record; mid-December is a target; no tasks for new scope |
| 2 | Technical Fee refund on partner cancellation (Q10, Q11; old Q3) | CR-22; ADR-007; T-140, T-141, T-142, T-145; adviser input | Refund amount and the club debit | Flag per market; default refund in EU markets, kept in the US (US default also unconfirmed) |
| 3 | Partner and customer account (Q22, Q23; old Q4) | CR-18; ADR-010; T-080 to T-083; FL-102; BUG-S03 | Sign-up shape and the pending screen | One login; pending partner sees only the club-area home (423 PARTNER_APPROVAL_PENDING) |
| 4 | Italian ticketing decision-maker (section 7 of answers-02; old Q5) | CR-29; `siae-decision-memo-2026-11-24.md` | The route decision and date | Italian live sales off; test mode only |
| 5 | Fixed fee per currency (Q1; old Q6) | CR-15, CR-26; ADR-003; T-093, T-096 | Prices outside EUR | EUR 0.50 and USD 0.55, admin-editable; an order in a currency without an amount is refused |
| 6 | Inclusive display per market (Q2, section 9; old Q7) | CR-26; ADR-012; T-097, FL-111 | Checkout wording | US inclusive, other markets itemized |
| 7 | Minimum ages: owners and organizers, and customers (Q31; old Q9 and Q10 merged) | CR-28; T-174, FL-133; `MIN_SIGNUP_AGE = 18`; T-009 | Any change to the age rules | 18+ stays in code until the adviser confirms in writing |
| 8 | Last-minute threshold and refund window (Q11; old Q11) | CR-23; T-144 | Refund route and deadline shown to guests | 48 hours; window configurable per club, default 7 days |
| 9 | Chat retention (Q6; old Q12) | CR-20; ADR-009; T-168 | The retention job | 30 days after closure deletes chat text only |
| 10 | Second table payment (Q5; old Q13) | CR-07; ADR-005; T-119, FL-117 | Second-instalment rules | Club sets deadline, default 48 hours before; deposit follows table policy if unpaid |
| 11 | Cote d'Azur town list (Q26; old Q8) | CR-24; ADR-011; T-162 to T-164, T-182; FL-132 | Area boundary and seed | The proposed nine towns; Monaco separate |

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

## Dropped from the client list in the final review (2026-11-24)

- Old Q1 (target or fixed dates): already decided by the product owner (mid-December is not fixed); folded into Q1.
- Old Q14 (default permission matrix): not a question, we send a draft (T-102, T-109). Old Q15 (working-day calendar): venue's country (T-160). Old Q16 (codes priority): soon after launch (T-156, T-184, FL-128). All three are listed under 'What we will assume' in the client document.
- The client list has 11 questions (4 High, 7 Medium). The hosting item is one line in the checklist (item 04; T-085, T-086).
