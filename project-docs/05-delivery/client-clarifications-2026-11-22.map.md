# Internal map for `client-clarifications-2026-11-22.md` (NOT for the client)

Maps each client question number to our internal identifiers, the work it unblocks, and the default we keep assuming until it is answered. Nothing here is a decision. Sources: `client-answers-review-2026-11-22.md` (the "ambiguities" and "conflicts" sections), `blockers.md`, `02-product/change-requests.md`, ADR-001 to ADR-004, `implementation-plan.md` (flags), `04-architecture/data-model.md` section 8.6, `known-issues.md`, `tasks/README.md`.

"New task" means a task that does not exist yet (to be written after the plan is approved). Ranges such as "M3" are milestones from `implementation-plan.md`.

| Q | Client topic and client IDs | Internal IDs | Unblocks | Assumed until answered |
|---|---|---|---|---|
| 1 | Fee and commission amounts, term "technical fee" vs "service fee" (Q2) | CR-15, CR-16; ADR-003 (rule values); review ambiguities 3, 4 | T-022 to T-028 values (REL-M3 note), T-057 (EXTRA fee rule), admin pages T-075, T-076 | Seeded rules reproduce today's values; naming "service fee" |
| 2 | Fee display, fee base, free-admission partner charge (Q2) | CR-15; **ADR-003 amendment** (display mode, processing-cost field, partner fixed charge, VENUE scope); review ambiguities 3, 4 | T-022 (migration 6 must be amended before it is written), T-024, T-025, T-026 | Itemized fee, on product price, no partner charge on free admissions |
| 3 | Card hold for tables (Q1) | CR-07, CR-16; new Stripe spike; review ambiguity 1 | T-056, T-058, new table payment task; REL-M5 note | No table payment flow; `QUOTE_REQUIRED` stays (T-056) |
| 4 | Quote acceptance time (Q1) | CR-07; review ambiguity (Q1 clocks) | T-058 (quote expiry), new table payment task | Configurable, capped at booking deadline; value 48 h as a placeholder only |
| 5 | Deposits (Q1) | CR-07, CR-16; review ambiguity 2 | New deposit/balance logic, T-056/T-058 follow-up | Full payment only until answered |
| 6 | Chat or WhatsApp (Q1) | CR-07; review ambiguity 12 (assigned conversations); new ADR (chat); T-055, T-058 | New chat module (if A or C), admin review pages | No messaging built; existing v1 quote and host contact stay |
| 7 | Who sets shares (Q3) | CR-02, CR-16; review ambiguity 5 | New settlement-configuration task; T-051 stays agreement-only | No split built |
| 8 | Payout timing (Q3, our proposal) | CR-16; Q3 deliverable "payout timing"; Stripe spike | New Connect transfer task, reports; REL-M5 | Not built |
| 9 | Failed payouts (Q3, our proposal) | CR-16; Q3 deliverable "failed-transfer handling, retry protection" | Same as Q8 | Not built |
| 10 | Venue-cancelled event refund (Q8) | CR-16, Q8; existing event-cancel behaviour keeps the service fee (`Refund.returnServiceFee` default); review "pending" list | New refund-engine ADR; T-063 to T-066, T-078 redesign; REL-M6 | Today's behaviour (fee kept) |
| 11 | Reschedule or venue change after sale (T4) | CR-17 T4; **implementation-plan flag 3** (no design exists); T-015, T-017 (timezone) | New design task and CR update; notices | Nothing built; only the timezone field |
| 12 | Admin role in refunds (Q8) | CR-16; review ambiguity 9; **conflict 3** (T-065, T-066, T-078 assume admin decides) | Un-holds or redesigns T-065, T-066, T-078, T-069, REL-M6 | T-063 to T-066, T-078 stay on hold |
| 13 | Refund of an amount (Q8) | CR-16; review ambiguity 9 | T-065 amount refund (`requestedAmount`) | Keep amount refunds in the redesign |
| 14 | Deposit on cancelled table (Q1, Q8) | CR-07, CR-16 | Table cancellation rules | Follows Q8 default: no automatic full refund for tables |
| 15 | Which cancelled tickets return to sale (Q9) | CR-04, CR-16; review ambiguity 10; T-007 (stock release for failed payments only) | New restock task, manual restock action | No restock on refund (old default A) until the redesign |
| 16 | Purchase limits (Q9, our proposal) | CR-16; existing limit of 5 per order | New limits task | Existing limit only |
| 17 | No-show timing on multi-day passes (Q5) | CR-05, CR-08 (A1.3, A1.4); review ambiguity 6; data-model 8.6 item 5 | New scan and no-show tasks; analytics A1.3/A1.4 | CR-05 deferral stays; `verify-ticket` unchanged |
| 18 | Entry hours and guest-list hold control (Q5) | CR-05, CR-06; review ambiguities 7, 8; T-020 (pending-hold rule) | T-020 follow-up, scan window | Hold 24 h; entry closes at event end |
| 19 | Guest-list access codes (A2.3) | CR-06; T-018, T-019 (promo fixes only); T-020 | Codes feature (not written) | Not built |
| 20 | Auto progression, starting price, badges (A2.9, A2.10, A2.17, D5) | CR-04 (Q5 part not covered); v2 `startingPrice` shape | New CR-04 tasks (not written) | Not built; public stock counts unchanged |
| 21 | Time zone of existing events | CR-17 T4; data-model 8.6 item 4 (all existing events UTC); T-015, T-017, T-035, T-060 | Time-zone backfill step in T-015/T-017 | UTC until set |
| 22 | State of a new owner/organizer account (D1) | CR-01 gate; BUG-S03 / known-issues S-03; data-model 8.6 item 6 (`OwnerApplication`, `OwnerApprovalStatus`); review ambiguity 13; Flutter signup | New approval-gate task; Flutter signup change; T-009 unaffected | Signup behaves as today |
| 23 | Existing owners (D1) | CR-01; data-model 8.6 item 6 (backfill existing owners APPROVED) | Migration plan of the approval gate | Grandfather as approved |
| 24 | Team roles and permissions (D1 matrix) | CR-02; **ADR-002 amendment / new ADR** (team permissions); review ambiguity 12; T-049 to T-053; T-069 cross-account suite; media ownership scope (`feat/media-ownership`) | New team-roles tasks, T-069 scope, REL-M5 | Matrix treated as proposed; no staff roles built |
| 25 | Venue dispute (Q4) | CR-02, Q4; review ambiguity 11 | New unregistered-venue workflow task | Nothing built |
| 26 | Côte d'Azur coverage (C3) | CR-09; T-029 to T-034, T-071, T-032 | City/region seed | Region proposal to be drawn by us |
| 27 | Launch-day destinations (C3) | CR-09; T-032 (activation flag) | City list go-live | All listed prepared; activation off until confirmed |
| 28 | Stalled-checkout sales counts (evidence request) | T-007; `reports/stock-leak.sql`; data-model 8.6 item 3; blockers notice 3 | The read-only report on live data; any correction | Local restored dump only (T-001); no production access |
| 29 | Stripe account (Q1, Q3) | CR-07, CR-15, CR-16; Stripe spike; existing Connect module | The spike, table payments, splits, payouts | No spike possible without access |
| 30 | Who publishes releases | Repo rules (no deploy without approval); REL-HF, REL-M* checklists | Release process | We never deploy without written approval |
| 31 | Minimum age (P0.1) | CR-01; `MIN_SIGNUP_AGE = 18`, `assertSignupDob`; T-009 open question (under-age social sign-in); FL-P01 open question (club owners) | Closes two open decisions (T-009, FL-P01) | 18 for all; under-age social sign-in gets 422 (as built) |
| 32 | Dates | `implementation-plan.md` milestones; CR-05 target dates (client asked); roadmap | Delivery plan and milestone order | No dates promised |
| 33 | App languages | Flutter language module; M8; client content C1/C2 labels (EN/IT) | Translation and legal text work | English and Italian |
| 34 | Priority of new scope | New CRs/ADRs: table payments (CR-07, CR-16), chat, team roles (ADR-002 amend), approval gate (CR-01), unregistered venues (CR-02), settlement (CR-02/16), multi-day and scanning (CR-05), per-ticket refunds (CR-16), referrals, resale, purchase limits, attendee messaging | Estimates and the milestone order; detailed referral and resale questions | Nothing estimated or built |

## Checklist items (section 10) mapped

| Client checklist item | Internal reference |
|---|---|
| Stripe access incl. test keys | Stripe spike; CR-15, CR-16 |
| Apple, TestFlight, Google Play, sign-in settings | P0.2 (provider configuration), implementation-plan flag 2 |
| Notification account access | Push notification service (environment) |
| Test system and hosting | Environment / release process; REL checklists |
| Tester names and roles | P0.4, implementation-plan flag 1 (test accounts per role) |
| Fee/commission amounts | Q1 above; ADR-003 values |
| Venue authorization form wording | blockers content item C4; Q4; CR-02 |
| Updated terms | Legal documents module (admin) |
| Holiday calendar and referral details | D1 referral incentives (review ambiguity 14) |
| Screenshot package (two different links) | `01-discovery/new update.md` link vs `client-answers-01.md` link; client item C6 |
| Product owner, admins, advisers | Acceptance rules in the tracker; D1 approvals; Q2 market validation |

## Items we did NOT ask (already answered clearly, or only an internal choice)

- Radius 30 km, genre and mood lists, city list, Trending 7 days, Most Viewed 30 days, artist fields, count-only Interested at launch (Q6, C1 to C3).
- Percentage splits chosen per event with fallbacks (Q3); unregistered-venue workflow and label suggestion (Q4); capacity rules, one scan per ticket, multi-day credential per day, 15-minute checkout hold (Q5, Q1).
- Per-ticket cancellation, automatic in-time refund with commission reversed and technical fee kept, tables no automatic full refund, no-show forfeits (Q8).
- Staff-visible label choices: "Presented by [Organizer] at [Venue]" is the client's own suggestion (not asked again). Language of label where only one is shown (C1): we assume the user's app language.
- Internal-only decisions (not for the client): release shape and merge order, T-004 error codes (404/409 vs 422), T-004 omitted-field and reactivation behaviour, legacy media backfill, media delete ownership scope.
- Interested avatar preview: optional per the client; count-only at launch is our default (also listed in the priority table, Q34).
- Security items (no client question): refresh-token storage, TLS certificate checks, session revocation on account deletion, logout revocation scope.

## Questions merged or dropped to keep the client document short

- "Technical fee" vs "service fee" folded into Q1; fee display, fee base and the free-admission partner charge folded into Q2.
- Chat record retention and chat moderation owner folded into a follow-up line in Q6.
- Guest-list hold control folded into Q18; permission defaults, staff approval and the "General Manager" alias folded into Q24.
- Optional Interested preview, label language and ranking weights: assumed (see above) or delivered by us for review, not asked.
