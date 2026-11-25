# Client answers review (2026-11-22)

Source of truth: `01-discovery/client-answers-01.md` ("Client Response", 22 November 2026). Reviewed against `05-delivery/blockers.md` (the questions we sent), `02-product/change-requests.md`, ADR-001 to ADR-004, `roadmap.md`, the task files and the branches listed in section 5. No code was changed. Nothing was pushed, merged, rebased or deployed.

How to read the status words: **Answered** = the client gave a rule we can build on. **Direction** = the client set the direction but the mechanism is marked "proposed" or needs our demonstration first. **Partly** = some parts answered, some parts open. **Pending** = not answered. Nothing was inferred where the text is silent.

The client document is written as a response to our blockers, but it does not use our A/B/C option letters. Where an answer clearly matches one of our options this report says "matches option X" and flags it for confirmation, it does not rewrite the client's words.

---

## 1. Question-by-question mapping

| Q | Our question | Client answer (intent, from the document) | Status |
|---|---|---|---|
| Q1 | How are tables paid for? | Fixed-price tables and "Starting from" tables. A quote may be issued by the club or by an organizer authorized by the owner. Before commit show final price, party size, inclusions, expiry, cancellation policy. Club may offer deposit, full payment or both; if both, the customer chooses; show amount due now, balance and settlement terms. A request alone reserves no table. For a known amount, Stripe manual capture is the **proposed** route on eligible methods: authorize, mark pending, the authorized operator accepts or rejects; on accept reserve atomically and capture before expiry, confirm only on successful capture; on reject cancel the authorization and charge zero including fees; if capture fails release inventory and invite a retry. Unknown final price: send the approved quote first, then collect consent and payment for that exact amount; recheck availability; if manual capture is unavailable or the hold expired, request a fresh payment after venue approval. A card guarantee would need separate terms. Quote acceptance window: duration "remains open", configurable, capped at the booking deadline. Inventory hold after acceptance is a separate setting; Stripe uses the real `capture_before`; standard checkout hold is 15 minutes. | **Direction** (flow confirmed; mechanism proposed, we must demonstrate both routes and verify authorization cost under the client's Stripe contract) |
| Q1 (messaging) | WhatsApp or in-app | WhatsApp "may be an additional channel routed through Bookdia Night" (owners cannot enter a personal number). Alternatively "propose an in-app conversation" linked to the booking, available to owner, authorized staff and owner-authorized organizers; admins can review and intervene; flag or block attempts to move the deal elsewhere; explain moderation; retain quote and payment record. | **Pending** (the client asks us to propose; no choice made) |
| Q2 | Customer fee and commission | Service fee supported on every paid product (tickets, passes, tables, sunbeds, extras); admin can set it to zero by product or agreement; fee goes to Bookdia Night; actual processing cost recorded separately; itemized fee or all-inclusive "Service fee included"; always show the payable total; validate presentation and refund policy per launch market. Commission: percentage of the paid product price, borne by the club or organizer, embedded in the price; admin base plus overrides by client, venue, event and product; negotiated lower or higher deals for large tables and sunbeds; fixed amounts from the original brief still supported; free admissions default to zero; 0% yields zero; optional separately agreed partner-side fixed charge for free admissions if admin enables it, never charged to the free guest; rates versioned by effective date, original order terms preserved. The 1.5% + EUR 0.25 Stripe price and the 1.5% + EUR 0.26 test figure are "for testing only, not an approved consumer rate". | **Partly** (structure answered; **values not given**; per-market validation pending) |
| Q3 | Split between organizer and club | Percentage splits applied automatically (matches our option A). Settlement arrangement chosen when the event is configured. Example EUR 10: EUR 2 organizer, EUR 7 club, EUR 1 Bookdia Night, "illustrative", applied to the ticket base, totalling 100%; technical fee accounted separately. Organizer payments inactive: seller proceeds go to the eligible club after Bookdia deductions. Club cannot receive funds: flag and request resolution. Approved unregistered venue: the onboarded organizer receives seller proceeds. | **Answered** for the rule; payout timing, failed transfers, retry protection, reversal after refunds and reporting are **requested from us** (see section 4) |
| Q4 / C4 | Unregistered venues | Draft workflow; Bookdia Night supplies the downloadable authorization form when requested; organizer completes it, obtains evidence of venue permission and uploads it; a Bookdia admin approves or rejects before publication or sales; on dispute suspend sales and refer to admin. Public label **suggestion**: "Presented by [Organizer] at [Venue]". (Matches our option B.) | **Answered** for the workflow; form wording not supplied yet |
| Q5 | Capacity, entry, no-show | Declared venue capacity is the per-day ceiling; deduct confirmed admissions, offline allocations and active holds once each; owner or authorized organizer can reduce online availability as offline sales happen, never below existing commitments; a multi-day pass needs a place on every included day; if Friday is full only eligible options (for example Saturday-only) stay on sale. Guest-list pending hold of 24 h is a **configurable** inventory timeout, separate from the cancellation deadline of a confirmed free ticket; expired pending holds are released and the guest told. Tables reserve on acceptance (payment per Q1). Publish named table bookings with capacity ranges (for example 5-8 guests for EUR 300, 4-6 for EUR 150, two-person sunbed EUR 100); associated guests counted once in entry capacity; record party size and attendees admitted. Publish venue entry hours; each ticket allows one successful scan; repeats rejected; multi-day: a single-use credential per included day (proposed); at event end an unused admission is a no-show; report zero-arrival groups separately from partly attended; the venue manages on-site admission and its published cutoff. | **Answered** (matches our six defaults, with the 24 h hold made configurable; see ambiguities for no-show timing) |
| Q6a | Search radius | 10, 20, 30, 40, 50 km, **initially 30 km** (our default was 20 km). | **Answered** (changes our default) |
| Q6b | Music and mood lists | Editable lists; the lists are given in C1 and C2. | **Answered** |
| Q6c | Trending, Most Viewed | Trending by city from views and Interested signals over 7 days; Most Viewed = city event opens over 30 days; personal searches and recently viewed kept separate; document ranking weights and duplicate handling. (Matches our default.) | **Answered** |
| Q6d | Interested | Launch with a genuine count. **Optional** preview: three or four small, non-clickable, non-zoomable avatars or initial circles with +N. If identities are shown, first name only, with visibility controls. Event-based messaging between attendees (one contact per event on the free plan, VIP members may contact all) is a **future direction**; consent, blocking and reporting to be scoped first. | **Answered** for launch (count); preview optional; messaging out of scope now |
| Q6e | Artists | Clubs and organizers maintain artist profiles: photo, Spotify link, upcoming events, follow. (No artist logins mentioned; our default stands.) | **Answered** |
| Q6f | Hosts, Quotes | Hosts are named event participants such as promoters; "demonstrate current permissions". Quotes follow the Q1 table workflow. | **Answered** (hosts description); permissions demo requested from us |
| Q8 | Refunds | Club sets a cancellation cutoff in hours or marks a booking non-refundable; policy shown before payment. Eligible ticket cancelled in time: automatic full product refund, reverse the associated platform commission, retain the disclosed technical fee. After cutoff or non-refundable: needs a club exception. An organizer approves refunds only with explicit owner permission. Confirmed tables: venue approval governs discretionary refunds; default no automatic full refund. Technical fee retained on an approved post-capture refund. **A customer may cancel a single eligible ticket in a group order**: invalidate that ticket, keep the rest. No-show forfeits the amount paid. Declined pending table request costs zero. Venue-cancelled events and market requirements to be confirmed separately. | **Answered** (matches our option C, plus automatic in-time refunds); venue-cancelled events **pending** |
| Q9 | Stock on refund, resale | Invalidate every cancelled credential immediately. Automatically restore eligible unused capacity while sales remain open; manual restock action (with notification to the owner or authorized organizer) that prevents double release. "Propose purchase limits" against mass booking and cancellation abuse. Ticket resale on open and sold-out events is an **additional flow** to scope and **estimate separately** (seller repaid on successful resale, waitlist alerts, optional pre-authorized auto-purchase with price limit and expiry, one-time transfer that invalidates the original code). | **Answered** for restock (differs from our default A "no"); purchase limits and resale are **proposals/estimates requested from us**, not approved scope |
| D1 | Who may be a club owner | Club owners and organizers may apply or be invited. Platform admin approval is required before access to partner dashboards, sensitive information or sales. Invitations also require verification. Track inviter, invitee, qualifying event or purchase, and reward redemption. (Matches our option B for applying, with invitations from option C.) | **Answered** (gate required); confirm "account stays a normal customer until approved" |
| D1 (matrix) | Roles | Proposed access matrix: Platform Admin, Club Owner, Primary Manager, Event Manager (General Manager), Reservations Staff, Organizer (with owner-granted permissions for quotes, chat, refunds; record who granted or revoked; enforce on the server). | **Direction** (marked "proposed access matrix for implementation") |
| D1 (referrals) | Incentives | Partner: first paid event of a referred owner or organizer earns the inviter one complimentary event on a non-holiday. Customer: invitee 10% off first eligible ticket, inviter 10% after that purchase succeeds. Minimum event commission for the incentive 10%; funded from Bookdia Night's commission. Define waiver, holiday calendar and redemption conditions and model sub-10% deals, reversals and overlaps before activation. | **Pending** (proposed; conditions to be defined) |
| C1 | Genres | 15 genres in display order, EN/IT labels. | **Answered** |
| C2 | Moods | 8 moods, EN/IT labels. | **Answered** |
| C3 | Launch locations | Italy: Rome, Milan, Turin, Bologna. France: Paris and Cote d'Azur (a region). Spain: Barcelona, Madrid. US: New York, Las Vegas. Monaco. We must propose the Cote d'Azur geographic coverage and confirm activation status per destination before production. | **Answered** (list); coverage proposal and activation status **pending** |
| C5 | Test accounts | Client asks us to create labelled test accounts (customer, club manager, organizer, admin, staff roles) with test payments; Apple and Google configuration sent privately. | **Request to us** |
| C6 | References | Shotgun screenshot package to be downloaded and access confirmed; a recording will follow; build an original visual design. The package is an external link; it was not opened for this review. | **Request to us** |
| Evidence | Tracker and demos | Continue the tracker with status, completion date, notes and evidence per ID; target dates for multi-day passes and scanning; table revenue in owner earnings; preserve historical tier sales; label ticket-type analytics from the first reliable date; send a read-only list of sales counts affected by stalled checkouts before any historical correction; five end-to-end demonstrations. | **Request to us** |

---

## 2. Confirmed decisions (safe to plan against)

1. Tables: fixed and "Starting from" are both offered; quotes from the club or an owner-authorized organizer; deposit, full or customer choice when both offered; a request alone reserves nothing; declined request costs the customer zero including service fee; checkout hold 15 min; quote acceptance window configurable and capped at the booking deadline.
2. Service fee may apply to every paid product and is admin-configurable to zero per product or agreement; free admissions carry no customer fee and default to zero commission.
3. Commission: percentage of the product price, borne by the club or organizer, embedded in the price; admin base with overrides by client, venue, event, product; fixed amounts still supported; versioned by effective date; old orders keep their terms.
4. Settlement: automatic percentage splits chosen per event; fallbacks as stated (organizer inactive to club; club cannot receive: flag; unregistered venue to the organizer).
5. Unregistered venues: organizer uploads evidence of venue permission; admin approves before publication or sales; dispute suspends sales.
6. Capacity and entry rules of Q5 (one scan per ticket per entitlement; multi-day = place on every day; table guests counted once; pending guest-list hold timeout configurable; offline allocations may reduce online availability but never below commitments).
7. Refund policy of Q8 (club cutoff in hours or non-refundable; automatic in-time refund of the product amount with commission reversed and technical fee kept; per-ticket cancellation in a group order; confirmed tables no automatic full refund).
8. Cancelled credentials are invalidated immediately; eligible capacity is restored automatically while sales are open; manual restock action exists and cannot double-release.
9. Discovery: radius steps 10 to 50 km starting at 30 km; Trending 7 days, Most Viewed 30 days; genuine Interested count; artist profiles maintained by clubs and organizers; the genre, mood and location lists in C1 to C3.
10. Owner and organizer access requires platform admin approval (D1); invitations require verification.

## 3. Still pending (explicitly not decided by the client)

- Rule VALUES for fees and commissions (the 1.5% + EUR 0.26 figure is a test benchmark only) and per-market presentation and refund validation (Q2).
- Quote acceptance duration (Q1: "remains open").
- Choice of messaging channel (Q1) and its moderation scope.
- Stripe manual-capture feasibility and cost under the client's own contract (Q1); Connect feasibility in the launch markets (Q3).
- Payout timing, failed-transfer handling, retry protection, reversal of splits on refund, reporting (Q3), accounting and tax treatment (client wants a submission for business review).
- Refund policy for venue-cancelled events and per-market requirements (Q8).
- Purchase limits (values) and the entire resale feature (Q9; to be estimated separately).
- Referral incentive conditions (waiver, holiday calendar, redemption; D1).
- Final access matrix (marked "proposed").
- Activation status per destination and the Cote d'Azur coverage (C3).
- Authorization form wording for unregistered venues (supplied by Bookdia Night when requested).
- Not addressed by the client at all: minimum age rule for club owners; behaviour for an under-age social sign-in; whether a money-amount (non per-ticket) goodwill refund is still wanted.

## 4. Ambiguities requiring clarification

1. **Manual capture is "proposed".** Is it approved as the route if it proves feasible, and which payment methods count as "eligible"? What happens for methods that cannot do manual capture besides the "fresh payment after venue approval" route? The validity window of an authorization must be verified against Stripe and the client's contract; we have not assumed it.
2. **Deposit settlement.** "Show amount due now, balance and settlement terms": how and when is the balance collected (in app, on site, later charge)? A card guarantee "would require separate terms", so a later automatic charge is not approved.
3. **Fee base.** "Compare against actual charges including fees on the collected total": is the service fee computed on the total (grossed up) or on the product price? Does it apply to the deposit amount only or to the full price of a table?
4. **Partner-side fixed charge on free admissions.** Who sets and who pays it (club or organizer), and is it shown anywhere to the customer? The text says never charge the free guest.
5. **Settlement example.** The EUR 2 / 7 / 1 split is "illustrative"; confirm the percentages are per-event configuration and not platform defaults, and whether Bookdia's EUR 1 is the commission or part of the technical fee ("account for any technical fee separately").
6. **No-show timing.** "At event end an unused admission is a no-show" versus "the venue manages ... its published cutoff". For a multi-day pass is the no-show decided per day (when that day's entry hours end) or at the end of the event? Our earlier default said per day at the end of the entry window.
7. **Entry window time.** We asked for the closing time of each day's entry window; the answer only says "publish the venue's entry hours". Is it a per-day field set by the club, with no platform default?
8. **Guest-list hold.** 24 h is "configurable": by whom (admin, owner, per event) and with what bounds?
9. **Refund authority versus admin.** The matrix gives refund authority to club roles and requires explicit owner permission for organizers; the platform admin "oversees disputes". Is admin approval still required for anything (our built design: owner requests, admin decides)? Is the money-amount refund (our earlier option B) still wanted next to per-ticket cancellation?
10. **"Eligible" capacity restore.** What makes capacity eligible (cancelled before cutoff only?) and what does "while sales remain open" mean (until event start or the sales end time)?
11. **Dispute on unregistered venue.** If sales are suspended, are existing buyers refunded, and by whom?
12. **Access matrix.** Described as "proposed". Are Primary Manager, Event Manager and Reservations Staff approved by admin like owners, or only added by the owner? Is "General Manager" an alias of Event Manager? The matrix assumes a chat feature ("assigned conversations") that is not decided (Q1 messaging).
13. **D1 account state.** Our option B said the account is a normal customer until approved. The client wording ("approval before access to partner dashboards, sensitive information or sales") is consistent with that; please confirm, because it decides whether existing owners keep access (see section 6, migration impact).
14. **Referrals.** "Minimum event commission 10%" together with a 10% customer discount funded from commission: confirm that no discount may be given when the commission is below 10%, and who owns the holiday calendar.
15. **C1 labels.** "Use the same label in both languages where only one is shown": which screens show a single language, and does the user's app language pick the label?
16. **Interested preview.** Optional: is it in the first release or a later one? Visibility controls need a user setting that does not exist yet.

---

## 5. Affected tasks and branches

### Branches (existing work compared with the answers)

| Branch | Effect of the answers | Action |
|---|---|---|
| `release/hotfix` (HF-002 to HF-005) | None. Security fixes; no client answer touches them. | None |
| `feat/media-ownership` | The rule "uploader owns, admin may delete anything" is correct for today. The new team model (staff roles, organizers granted by an owner) means several people act for one club, so uploader-only ownership will block a manager deleting a colleague's file. Admin "with appropriate permissions" is only the platform admin today. | Keep as is. Revisit ownership scope (club or event scope) when the staff-role work is designed. Not a blocker. |
| `feat/t-004-tier-update` | Compatible. Q5 says capacity must not go below "existing commitments" (confirmed, offline allocations and active holds); T-004 guards only `soldCount`, which is the subset that exists today. T-004 never writes `soldCount`, so Q9's automatic restore does not conflict. Multi-day passes and per-day capacity (CR-05) will extend the tier model and are not covered by ADR-004. The 404/409 versus 422 error-code question is internal and unaffected. | Merge as planned. Add a follow-up note: when offline allocations and holds exist, the capacity check must include them. |
| `feat/t-009-social-dob` | Social sign-in always creates a `USER` (`AccountRole.USER`), so it is not a path to self-selecting `CLUB_OWNER`. D1 is now answered, but T-009 deliberately leaves signup role handling alone. DOB and age rules: the client did not answer. | Merge as planned. The D1 gate becomes its own task (section 6). Age rule for club owners and under-age social sign-in remain internal open decisions. |
| `fix/flutter-auth-refresh`, `fix/flutter-dob-picker` | No client answer changes them. The DOB picker keeps the existing 18-year rule, which the client has not addressed. | None. |
| `ci/backend-tests`, `feat/t-002-migration-rehearsal`, `feat/t-003-test-harness` | None. | None |

### Tasks (existing task files)

| Task | Previously | Now |
|---|---|---|
| T-007 stock release | Estimate report only; correction a manual client decision | Client wants a read-only list of sales counts affected by stalled checkouts before any correction. `reports/stock-leak.sql` is that list; running it against production needs approval. |
| T-008 checkout hold | 15 min, client answer pending | **Confirmed** 15 minutes. |
| T-009 | Signup role waits for D1 | D1 answered; role gate is a separate task; T-009 unchanged. |
| T-020 | Pending-hold rule not part of it (Q5) | Pending-hold rule now answered (24 h, configurable); access codes are **still not answered**. |
| T-022 to T-025 (pricing rules) | Structure accepted; values wait for Q2 | Structure needs amendments before migration 6 is written (ADR-003 conflicts, section 7). Values still pending. |
| T-026 free checkout | Fee waiver provisional until Q2 | Fee only on paid products is confirmed; commission default zero confirmed; an optional partner-side fixed charge on free admissions is new. |
| T-049, T-050, T-051 organizer | No approval step (D1 deferred); no payout split or unregistered venues | D1 answered, Q3 and Q4 answered; those parts are new tasks, T-049 to T-051 stay scoped as written. |
| T-056, T-057, T-058 tables, extras, quotes | Quote-to-payment not approved | Q1 direction given; implementation waits for the Stripe feasibility demonstration. Extras: the FEE rule now applies (Q2). |
| T-063 to T-066, T-078 refunds (T-067 and T-068 stay valid) | Whole order or an amount once; admin approves; no stock release | **Conflict.** Q8 and Q9 replace these assumptions (section 7). Do not implement as written. |
| T-029 to T-034, T-071 cities, radius | Radius default 20 km; city list awaited | Radius 30 km initial; city list received (C3). |
| T-031, T-032 vocabularies | Waited for lists | **Unblocked**: lists C1 and C2 received. |
| T-041, T-042 trending and views | Count only, no names | Count confirmed; optional avatar preview is new and optional. |
| T-043, T-044 artists | Fields assumed | Photo, Spotify link, upcoming events, follow confirmed. |
| CR-05 and its tasks (not yet written) | Deferred, waiting Q5 | Q5 answered; the product owner can lift the deferral. Tasks still have to be written. |
| REL-M3, REL-M5, REL-M6 | Notes about Q2, Q1/Q3/Q4, Q8/Q9 | Release notes updated (see the task edits). |

---

## 6. Required changes by component (analysis only; nothing implemented)

### Backend
- **Table payments (Q1):** Stripe PaymentIntent with `capture_method=manual` (authorize, pending, accept, capture, release), the "fresh payment" fallback route, deposit and full payment options with balance terms, quote acceptance window (configurable, capped), accepted-table inventory hold separate from the Stripe `capture_before`, capture-failure release, a pending-request release status. Messaging (in-app conversation linked to a booking with moderation, retention, admin review) if chosen.
- **Fees and commission (Q2):** rules for FEE and COMMISSION on every product with scopes including venue; a display mode (itemized or "Service fee included"); recording of actual processing cost separately; partner-side fixed charge for free admissions (admin switch); sample orders per market.
- **Settlement (Q3):** per-event settlement arrangement; automatic percentage splits with Stripe Connect transfers; fallbacks; flags for payee problems; failed-transfer retry with idempotency; split reversal on refund; ledger and reporting.
- **Unregistered venues (Q4):** venue-authorization record with uploaded evidence and admin decision, status that blocks publication and sales, dispute suspension, public label.
- **Capacity and entry (Q5, CR-04, CR-05):** per-day capacity from venue capacity; offline allocations; multi-day passes with a single-use credential per included day; scan rejection of repeats; party size and admitted attendees per table booking; no-show derivation and reporting; guest-list hold timeout setting and release notification.
- **Refunds (Q8, Q9):** per-ticket status and credential invalidation; cancellation cutoff per booking (hours or non-refundable) shown before payment; automatic in-time refund with commission reversal and fee retention; exception and permission model (club, owner-granted organizer, venue approval for tables); automatic capacity restore while sales are open; manual restock action with double-release protection; purchase limits (to be proposed).
- **Access (D1, matrix):** approval status for owners and organizers and a gate on partner endpoints (this also closes S-03 for the live signup), invitation and verification, per-club team roles with permission grants, who granted or revoked, server-side enforcement, audit; referral tracking.
- **Discovery (Q6, C1 to C3):** city and region configuration including the Cote d'Azur region and per-destination activation flag; seed vocabularies from C1 and C2 with EN/IT labels; radius steps and default 30 km; ranking windows 7 and 30 days; optional Interested preview with first-name and visibility controls.
- **Evidence and data:** read-only stock-leak list before any historical correction; table revenue in owner earnings (already a planned notice); analytics labelled from the first reliable date.

### Admin dashboard
Approval queues for owners, organizers and venue authorizations; fee and commission rules with overrides and a sample-order calculator; split and payout monitoring with retry; refund and exception oversight; chat review and intervention (if chat is built); city, region, genre and mood management; audit views; referral tracking.

### Flutter
Signup and sign-in changes for the owner approval gate (the live app currently lets a user choose `CLUB_OWNER` itself); table request, quote, deposit and payment screens with the amounts due, balance and cancellation policy; per-ticket cancellation and refund-policy display; multi-day pass and per-day availability; scan and credential screens; role-aware navigation for staff roles; city and 30 km radius, genre and mood pickers (EN/IT), trending and most viewed; optional Interested preview; artist profile; social DOB screen (T-009 contract); unregistered-venue flow for organizers. Flutter work stays last (M8).

### Cross-cutting requests to us
Stripe feasibility and cost report; Connect examples (deposit, included fee, zero-fee table, event cancelled by organizer); payout timing proposal; accounting and tax note; purchase-limit proposal; resale estimate; target dates for multi-day passes and scanning; tracker with evidence; five end-to-end demonstrations; labelled test accounts; the screenshot package download.

---

## 7. Conflicts with existing ADRs and technical decisions

No ADR was changed. Each item states the conflict and a recommended resolution for approval.

| # | Existing decision | Conflict with the client answers | Recommended resolution |
|---|---|---|---|
| 1 | **ADR-002** organizer = a profile on a `CLUB_OWNER` account; no new role; authorization by profile | Organizer identity stays compatible. But the client's matrix adds club-level team roles (Primary Manager, Event Manager, Reservations Staff) and per-permission grants to organizers (quotes, chat, refunds) with grant history. ADR-002 has no staff or per-club permission model, and "assigned events" scoping does not exist. D1 also now requires admin approval, which ADR-002 only anticipated. | Keep ADR-002 for organizer identity. Write a new ADR (club team membership and permission grants, stored per club, not as `AccountRole` values) and amend ADR-002's consequences to reference it and the D1 gate. |
| 2 | **ADR-003** pricing rules: scopes GLOBAL, CLIENT, EVENT; categories TICKET, TABLE, EXTRA, CLUB_BOOKING; FEE and COMMISSION; free-order fee waiver provisional | Client asks overrides by client, venue, event **and product**: a VENUE scope is missing. Client also asks a fee display mode ("Service fee included"), separate recording of actual processing cost, and an optional partner-side fixed charge on free admissions. "Who pays commission" and "fee on tables and extras" were open in ADR-003 and are now answered (club or organizer; yes, admin-configurable). | Amend ADR-003 before migration 6 is written (it is not written yet, so this is cheap): add the VENUE scope, a display mode field, a processing-cost field on the order ledger, and the free-admission partner charge. Structure otherwise unchanged. |
| 3 | **CR-16 / T-063 to T-066, T-078** refunds: owner requests, admin approves, whole order or an amount once, no per-attendee refunds, no stock release | Client chose per-ticket cancellation, automatic in-time refunds, club cutoff and exceptions, owner-permissioned organizers, venue approval for tables, and automatic capacity restore. Admin approval as the authority conflicts; per-ticket status did not exist. | Pause T-063 to T-066 and T-078 as written (T-067 refund webhooks and T-068 admin order views do not depend on the refund policy and stay valid). Redesign as a policy-driven refund engine (new ADR) after the Stripe and Connect spike. Keep the migration plan flexible (per-ticket status). Ask the product owner whether admin approval remains for anything. |
| 4 | **Q9 default (no restock)** written into T-065, T-066, T-078 and REL-M6 | Replaced by automatic restore of eligible capacity plus a manual restock action. | Update those tasks together with item 3. |
| 5 | **CR-09 / roadmap** radius default 20 km | Client: initially 30 km. | Change the default to 30 km (docs updated in this change). |
| 6 | **CR-11 Q6d default**: count only, no names | Count only remains the launch default; the client adds an optional avatar or initials preview with first names and visibility controls. | Keep count-only for launch; treat the preview as an optional later task. |
| 7 | **CR-01 decision note**: owner-approval gate deferred until D1 | D1 is answered. The gate is required (admin approval before partner dashboards, data or sales). It changes the live signup for `CLUB_OWNER` (S-03) and may affect existing owners. | Product owner lifts the deferral; write a task with a migration plan (existing owners grandfathered as approved, new ones pending) and a Flutter signup change. Not part of T-009. |
| 8 | **CR-05 Deferred** (multi-day passes, scanning) | Q5 is answered. | Product owner may re-approve CR-05; tasks to be written. The existing `verify-ticket` and per-order `checkedInAt` stay until then. |
| 9 | **Original recommendation for Q1** (A for fixed tables, C for starting-from, B only if asked) | Client wants deposit, full or both, plus manual-capture approval. Larger than the recommendation. | Plan around the client's description, subject to the feasibility demonstration. |
| 10 | **Q2 recommendation** (service fee tickets only) | Client wants the fee supported on every paid product. | Follow the client (ADR-003 already supports it structurally). |
| 11 | **ADR-001** (versioning) and **ADR-004** (tier matching) | No conflict. ADR-004 does not cover multi-day pass tiers or per-day capacity. | Extend when CR-05 is designed. |

---

## 8. Recommended implementation and merge order

No code starts until you approve. Suggested order:

1. **Decisions first (documentation only):** confirm the ambiguities in section 4 with the client; product owner lifts the deferrals (CR-01 gate, CR-05); approve the ADR amendments (items 1 to 3 in section 7).
2. **Existing branches (unchanged by the answers):** release the hotfix track first as already planned; merge `feat/t-003-test-harness`, `feat/t-002-migration-rehearsal`, `ci/backend-tests`, then `feat/media-ownership`, `feat/t-004-tier-update`, `feat/t-009-social-dob`, then the Flutter branches (with the review conditions already met), then the docs branches in sequence. Merge approval is still yours.
3. **Remaining M1 (T-005 to T-014):** unchanged. T-008's 15 min hold is now confirmed.
4. **Spike (new, small):** Stripe manual capture and Connect feasibility and cost in the launch markets, with the demonstrations the client requested. This gates Q1, Q3 and Q8 design.
5. **ADR work:** amend ADR-003, add the team-permissions ADR and the refund-engine ADR.
6. **M3 pricing rules** (T-022 onward) with the amended ADR-003; values stay pending the client.
7. **M4 discovery:** seed vocabularies and cities from C1 to C3 (30 km default), then the rest of M4.
8. **Owner and organizer approval gate** (S-03 fix) with the grandfathering migration, before partner features that handle money.
9. **M5 organizer, tables and quotes** after the spike; then unregistered venues and settlement.
10. **Refund engine and capacity restore** (replacing T-063 to T-066 and T-078), then **CR-05** multi-day passes and scanning.
11. **Admin pages (M7)** for each new endpoint, then **Flutter (M8)** last.
12. Resale, referrals, purchase limits and attendee messaging: estimate and schedule separately after the above.

Dependencies that matter: (4) gates (6 table payments, 9, 10); (5) gates the migrations in (6) and (10); (8) gates anything that exposes sensitive data or sales to new roles.

---

## Documents updated by this review
`roadmap.md`, `blockers.md` (status table at the top; the original text is kept), `02-product/change-requests.md` (client-answers section and decision-log entry; **CR statuses were not changed**, they remain the product owner's decision), and the task files listed in section 5 (a dated "Client answer" note under each; plan text untouched). `01-discovery/client-answers-01.md` is committed unchanged as the source.
