# Decisions needed from the client

Project: Bookdia Night. Date prepared: 2026-11-21. Based on the review tracker of 6 Nov 2026 (open decisions Q1 to Q6) plus three extra questions (D1, Q8, Q9). There is no Q7: Q8 keeps the number we agreed.

**How to answer:** for each question below, reply with the question number and either "Option A/B/C" or your own rule. If you agree with our recommendation, just write "Q3: recommended". Nothing in the "Blocks" line can be finished until that question is answered; everything else carries on meanwhile.

"CR-xx" numbers are our internal change-request numbers (see `02-product/change-requests.md`).

## Status after the client response (2026-11-24)

Source: `01-discovery/client-answers-02.md` (answers to `client-clarifications-2026-11-22.md`, questions Q1 to Q34; mapping in `client-clarifications-2026-11-22.map.md`). Recorded by Claude for product owner confirmation. "Resolved" means we can build on the answer; the points still open are in the next two tables. Under-18 (Q31) is resolved on the client side but NOT implemented (product owner decision, see below).

| Q | Topic | Status | Answer (short) | CR / ADR |
|---|---|---|---|---|
| Q1 | Fee and commission amounts | Resolved (values); two details open | Technical Fee (customer) 5% of the eligible paid subtotal plus EUR 0.50 local equivalent once per order; Service Fee (partner commission) 10% tickets and passes, 15% tables, sunbeds, extras; Italy, France, Monaco, Spain, US; admin overrides by country, category, club, event, table or quote | CR-15, CR-26; ADR-003 amended |
| Q2 | Fee display and base | Resolved; one detail open | Full price shown as soon as calculable, fee itemized discreetly, inclusive display by market and category; 5% on each in-app payment, fixed fee once on the first online payment; no fee on a balance paid at the venue; partner fixed charge only if admin sets it | CR-15, CR-26; ADR-012 |
| Q3 | Card hold for tables | Resolved (A); proof needs Stripe | Authorize, capture after venue approval, fresh payment if unsupported or expired, zero cost on rejection | CR-07; ADR-005 |
| Q4 | Quote validity | Resolved (A) | 48 h default, club-configurable, capped by the booking deadline, club may withdraw an unpaid quote, no simultaneous sale | CR-07; ADR-005 |
| Q5 | Deposits | Resolved (C) | Club chooses: deposit online plus venue balance, full online, or two online payments; commission on the full base price | CR-07; ADR-005 |
| Q6 | Chat or WhatsApp | Resolved (in-app primary plus WhatsApp support link) | Booking-linked chat, one Bookdia WhatsApp number as support link, diversion flagged, delete 30 days after closure | CR-20; ADR-009 |
| Q7 | Who sets shares | Resolved (A) | Admin sets Bookdia share; owner proposes; organizer accepts before sales open; fallback to the eligible club | CR-21; ADR-006 |
| Q8 | When partners are paid | Resolved (A, 3 days) | Transfer 3 calendar days after event end; Pending then Confirmed; holds for open refund or dispute | CR-21; ADR-006 |
| Q9 | Failed payouts | Resolved (agree) | Retry up to 3 times in 3 days; immediate notice; we explain where funds sit | CR-21; ADR-006 |
| Q10 | Venue or organizer cancels | Partly | Admission refunded, Service Fee reversed, Technical Fee refunded where law or terms require; club repays it by default; admin may waive; admin-only Charge to club. Default for the Technical Fee depends on terms and adviser | CR-22; ADR-007 |
| Q11 | Event rescheduled or moved | Resolved (A); two details open | Notify at once; tickets stay valid; refund within 7 days of notice; immediate route for a last-minute change | CR-23; ADR-007 |
| Q12 | Who approves refunds | Resolved | Automatic under policy; club decides exceptions; organizers only with owner permission; staff forward; admins handle disputes | CR-22; ADR-007 |
| Q13 | Refund of an amount | Resolved (A) | Documented partial goodwill refund with admission kept (Italy needs adviser) | CR-22; ADR-007 |
| Q14 | Deposit on a cancelled table | Resolved (C) | Club sets the policy per table, shown before payment | CR-07; ADR-005 |
| Q15 | Cancelled tickets back on sale | Resolved | Unused invalidated tickets, including an approved late cancellation, return while sales are open; not on a cancelled event | CR-22; ADR-007 |
| Q16 | Purchase limits | Resolved (A) | 5 per order, 10 per customer per event, configurable; repeat cancellations flagged | CR-25 |
| Q17 | No-shows on multi-day passes | Resolved (A) | Recorded at each day's entry cutoff; next day stays valid | CR-05; ADR-013 |
| Q18 | Entry hours and guest-list wait | Resolved (A) | Club sets entry cutoff (default event end) and guest-list hold (24 h default, 1 to 72 h, capped by the cutoff) | CR-05, CR-06; ADR-013 |
| Q19 | Guest-list access codes | Resolved (design); priority open | One code screen: purpose, event or list, expiry, use limit | CR-06; ADR-013 |
| Q20 | Progression, from price, low stock | Resolved (A) | Next tier opens on sellout; lowest price shown; Last tickets at 20% or less | CR-04; ADR-013 |
| Q21 | Time zone of existing events | Resolved (A) | Backfill from venue or city, organizer can correct, ambiguous flagged | CR-17, CR-05 |
| Q22 | New owner and organizer accounts | Resolved (own rule) | Pending: club-area home only, partner tools locked, enforced on the server; customer use needs a separate customer account | CR-18; ADR-010 |
| Q23 | Existing club owners | Resolved (A) | Keep full access, no reapproval | CR-18; ADR-010 |
| Q24 | Team roles and permissions | Resolved on roles; matrix open | Club roles (General Manager is the former Primary Manager; Event Manager is separate), platform roles, editable permissions page; owner invites; organizer permissions off until granted | CR-19; ADR-008 |
| Q25 | Venue dispute | Resolved (A) | Sales suspended, sold tickets stay valid, admin decides within 2 working days; unregistered venues need form and admin approval | CR-23 |
| Q26 | Cote d Azur area | Partly | Saint-Tropez to Menton as an area independent of the radius; Monaco separate; towns not listed | CR-24; ADR-011 |
| Q27 | Destinations on day one | Resolved (A) | All eleven prepared and enabled; activation still needs events and checks | CR-24; ADR-011 |
| Q28 | Sold numbers and unpaid checkouts | Resolved (A, A) | Read-only inspection allowed; differences listed first; change data only after written approval for each event | T-007 follow-up |
| Q29 | Stripe account | Resolved (existing account); access received | Use the existing account with limited team access and Connect; payout countries Italy, France, Monaco, Spain, US (eligibility to verify, Monaco specially) | CR-07, CR-21; ADR-006 |
| Q30 | Who puts versions live | Resolved (A) | We prepare releases; publish only after written Bookdia approval | release process |
| Q31 | Minimum age | Answered, NOT implemented | Client: declared date of birth, under-18 may sign in and buy with a warning; event age rule shown; owner and organizer age to confirm separately. Product owner decision: signup stays 18+ until the client's adviser confirms in writing | CR-28 |
| Q32 | Dates | Partly | Target mid-December 2026 usable build and early January 2027 launch; no fixed event date. Mid-December is NOT a hard date; the plan is in `completion-plan-2026-11-24.md` | plan |
| Q33 | Languages | Resolved | English, Italian, French, Spanish complete at launch; other agreed languages shortly after; language inventory wanted | CR-27 |
| Q34 | Priority of features | Resolved | Launch: tables, chat, team roles, partner approval, unregistered venues, splits, multi-day passes, ticket cancellation and refunds, purchase limits, Interested count. Soon after: referral, resale and waitlist. Later: attendee messaging, avatar preview. Scheduling does not approve extra charges | CR-18 to CR-34 |

### Still open or waiting on the client

| # | Item | Waiting on | Blocks |
|---|---|---|---|
| O1 | Fixed fee amount in each currency (USD at least) and what "eligible paid subtotal" excludes | Client | Fee rules (T-022, fee tasks) |
| O2 | Which markets and categories use the inclusive price display (the US upfront rule is known) | Client, advisers | Display mode |
| O3 | Default for refunding the Technical Fee when the partner cancels | Client, adviser, terms | Refund engine partner path |
| O4 | How one person gets both a partner account and a customer account (same email) | Client | Pending-owner flow |
| O5 | Cote d Azur towns or boundary | Client | Destination area seed |
| O6 | Age requirement for owners and organizers; written adviser confirmation for under-18 | Client adviser | CR-28 |
| O7 | "Last-minute" threshold for event changes; whether the 7-day window is configurable | Client | Event change task |
| O8 | Whether deleting chats 30 days after closure is acceptable for disputes and fiscal records | Client adviser | Chat retention job (built but disabled until answered) |
| O9 | Deadline for the second online payment and the result if unpaid | Client | Table second payment |
| O10 | Default permission matrix per role and page | Client | Roles defaults |
| O11 | Priority of guest-list access codes (not in the Q34 table) | Client | Codes task |
| O12 | Working-day calendar for the 2-working-day venue decision | Client | Venue dispute task |
| O13 | Delivery dates per delivery incl. passes and scanning (the client asks us; our proposal is in the plan) | Us, then client | Plan |
| O14 | Approved Italian ticketing route and provider quote (new scope CR-29) | Client | Italian live sales (none until approved) |
| O15 | Stripe holding limits and Monaco payout eligibility | Us (spike) | Settlement design |

### Checklist items from the client (section 10 of the clarifications)

Access received (product owner, 2026-11-24): Stripe yes, Apple and Google yes, push yes. Hosting / DigitalOcean: received (product owner, 2026-11-24), so the read-only stalled-checkout run is no longer blocked. Received means we have access; what each account still lacks (Connect permissions, per-country coverage, sign-in settings) is verified by the spike and release tasks and reported to the client.

| # | Item | Status | Owner of the next step |
|---|---|---|---|
| 01 | Stripe: existing account, limited team access, test keys, Connect permissions, test coverage by country; verify Monaco | Received (product owner, 2026-11-24); Connect permissions and per-country coverage still to verify | Us: spike report listing exactly what is missing |
| 02 | Apple Developer, TestFlight, Google Play Console, Apple and Google sign-in settings | Received (product owner, 2026-11-24) | Us: list what is missing |
| 03 | Push notifications platform and account | Received (product owner, 2026-11-24); we still owe the client the answer on which platform, account and permissions we use | Us |
| 04 | Hosting and test environment, or the infrastructure contact (also needed to run the read-only stalled-checkout list) | Received 2026-11-24 | Us |
| 05 | Testers: Joys Rossi (contact and TestFlight Apple ID received in answers-02); ten labelled test logins | Contact received; logins are ours to create (task `rb_seed`) | Us |
| 06 | Pricing | Received (Q1, Q2) | none |
| 07 | Venue authorization form (EN, IT, legal review) | Missing; we owe the proposed download, upload and review flow | Client (form), us (flow) |
| 08 | Terms: booking, cancellation and refund, venue authorization (incl. partner recovery) | Missing; client asks us to prepare them (new scope CR-31, needs an adviser) | Client, us |
| 09 | Referral inputs (holiday calendars, fees a complimentary event waives) | Missing; needed before referral development only | Client |
| 10 | Design references | Screenshot link received; the screen-recording link is not in the text; ask which link is current and to keep it active | Client |
| 11 | Product acceptance: Joys Rossi is the sole contact | Received | none |
| 12 | Operational admins who approve owners, organizers, venues and handle disputes | Missing | Client |
| 13 | Tax, accounting and legal advisers per launch market | Missing | Client |

### Items we owe the client (from answers-02)

Stripe feasibility and holding-limit report and the Monaco check; demonstrations (partially refunded order, insufficient partner balance, the five end-to-end runs); accounting and tax note; language inventory; push platform answer; venue authorization flow proposal; decision memo for the Italian ticketing route (`siae-decision-memo-2026-11-24.md`); estimates for the new-scope items (`scope-and-timeline-2026-11-24.md`); tracker evidence per ID with build, date and changes; the delivery dates. The 1.5% + EUR 0.26 test figure is retired.

---

## Status after the client response (2026-11-22)

The client answered in `01-discovery/client-answers-01.md`. Full mapping, ambiguities and impact: `05-delivery/client-answers-review-2026-11-22.md`. The question text below is kept as sent. All of Q1 to Q6, Q8, Q9 and D1 are now resolved or narrowed by the 2026-11-24 section above (`client-answers-02.md`); only the points listed there as open remain.

| # | Status | What is settled | What is still open |
|---|---|---|---|
| Q1 | Direction | Fixed and starting-from tables, quotes by club or authorized organizer, deposit/full/both, approval before collection (manual capture proposed) | Stripe feasibility and cost demonstration; quote acceptance duration; deposit balance terms; messaging channel |
| Q2 | Partly | Fee on every paid product, zero by admin, itemized or included, commission borne by club or organizer, overrides by client/venue/event/product, versioned | Rule values; per-market validation; fee base |
| Q3 | Answered | Automatic percentage splits with fallbacks | Payout timing, failed transfers, retries, reversal on refund, reporting, tax (requested from us) |
| Q4 | Answered | Upload evidence, admin approval before sales, dispute suspends sales | Form wording (supplied on request); refunds on dispute |
| Q5 | Answered | Capacity, passes, holds (24 h configurable), one scan per ticket, no-show at event end | No-show timing for multi-day; entry-window time; who configures the hold |
| Q6 | Answered | 30 km initial radius, lists C1/C2, trending 7 d, most viewed 30 d, count (optional avatars), artist profiles, hosts | Optional avatar preview scope |
| Q8 | Answered | Per-ticket cancellation, club cutoff, automatic in-time refund, exceptions | Venue-cancelled events; market requirements |
| Q9 | Answered | Automatic capacity restore while sales open, manual restock | "Eligible" definition; purchase-limit values; resale is a separate estimate |
| D1 | Answered | Admin approval before partner access; invitations verified | Confirm account stays a customer until approved; access matrix is "proposed"; referral conditions |
| C1 to C3 | Answered | Genre, mood and city lists | Cote d'Azur coverage; activation status per destination |

| # | Topic | Blocks | Answer needed |
|---|---|---|---|
| Q1 | How are tables paid for? | CR-07, CR-16 | Choose A, B, C or D |
| Q2 | Customer fees and Bookdia commission | CR-15, CR-16 | Fill the table |
| Q3 | How money is split with organizers | CR-02, CR-16 | Choose A or B |
| Q4 | Events at venues not on the app | CR-02 | Confirm proof needed |
| Q5 | Capacity, entry and no-show rules | CR-04, CR-05, CR-06, CR-08 | Confirm 6 rules |
| Q6 | Smaller discovery and profile choices | CR-07, CR-09, CR-10, CR-11, CR-12 | Confirm 6 defaults |
| Q8 | Partial refunds, for example one person out of a group order? | CR-16 | Choose A, B or C |
| Q9 | When we refund an order, do the tickets go back on sale? | CR-16 | Choose A, B or C (default A: no) |
| D1 | Can anyone sign up as a club owner? | CR-01 (owner check only), CR-02 | Choose A, B or C |

---

## Q1. How should customers pay for a table?

**The question:** When someone books a VIP table or a sunbed, when and how do they pay? Tables with a fixed price are simple. Tables where the price depends on the request ("starting from") are harder, because the final price is not known when the customer asks.

**Why it matters:** It decides whether the customer pays inside the app, whether Bookdia Night earns its commission on every table, and whether bookings can be lost to private WhatsApp deals. Card payment rules also limit how long we can reserve money on a card for a later charge.

**Options:**
- **A. Pay in full online (fixed-price tables).** Simple, money collected immediately, commission is certain.
- **B. Pay a deposit online, balance later.** Customer pays part now. We need clear rules for the balance and for cancellations.
- **C. Request first, then pay (starting-from tables).** The customer sends a request in the app, the club replies with a price, the customer accepts and pays online. The whole conversation is tracked inside the app.
- **D. Request handled by a Bookdia Night partner on WhatsApp.** Works, but we need to know who owns the number and how we prove the sale came from the app. Not recommended because it is hard to track.

**Our recommendation:** A for fixed-price tables, plus C for "starting from" tables. Use B (deposit) only if the clubs ask for it. Avoid D.

**Also tell us:** how long a quote stays valid (suggested: 48 hours), the cancellation and no-show rule for tables, and whether commission applies to the full table price.

---

## Q2. What fees does the customer pay, and what does Bookdia Night earn?

**The question:** There are two separate amounts: (1) a **service fee** the customer pays to cover card-processing costs, and (2) Bookdia Night's own **commission**, taken from the club or organizer's sales. Please tell us, for each product, which of these apply.

**Why it matters:** This sets the price the customer sees and what the club receives. We must not call the commission a "technical fee". Today the app charges one flat fee per order and one commission percentage for events and one for clubs; it cannot yet do different rules per product.

**Please fill in:**

| Product | Service fee for customer? | Commission? | Percentage or fixed amount? | Who pays the commission (club or customer)? |
|---|---|---|---|---|
| Tickets / passes | | | | |
| Free tickets / guest list | | | | |
| Tables | | | | |
| Sunbeds / extras | | | | |

**Also tell us:** what happens to the fee and commission when a customer is refunded; whether rules can differ by club or by event; the date a new rule starts (old orders always keep the rule they were sold under); who checks tax and accounting.

**Our recommendation:** keep a service fee for tickets only, flat per order as today; commission as a percentage on all paid products, with the ability to override per club or event. On refunds, return the commission but keep the service fee (this matches how event-cancellation refunds already work: the service fee is kept).

---

## Q3. How is money shared between an organizer and a club?

**The question:** When an organizer holds an event at a registered club, who receives the customer's payment?

**Why it matters:** It decides how organizers and clubs are paid, what each must set up before they can sell, and who handles refunds and disputes. We use Stripe today; whether the split option is available for your accounts must be confirmed with Stripe before we promise it.

**Options:**
- **A. Automatic split.** The payment is divided between organizer and club (and Bookdia Night's commission) as soon as it is made. Fully tracked, but both sides must complete payment onboarding first.
- **B. Club receives everything and pays the organizer itself.** Simpler to build, but Bookdia Night cannot see or guarantee the organizer's payout.

**For a venue that is not on the app:** the organizer receives the money alone (this is already your direction).

**Our recommendation:** A as the main route, with B available only if a club or organizer cannot complete onboarding. Please also tell us when payouts should happen (for example, after the event) and what happens if a payout fails or an event is cancelled.

---

## Q4. What proof is needed for an event at a venue that is not on the app?

**The question:** An organizer may enter a venue manually. How do we make sure they are allowed to hold the event there?

**Why it matters:** Without a check, anyone could sell tickets for a venue that does not know about the event. A checkbox alone is not proof.

**Options:**
- **A. Checkbox only.** Fast, but no protection.
- **B. Checkbox plus an uploaded document** (for example, a signed letter or email from the venue), reviewed by a Bookdia Night admin before the event can go on sale.
- **C. Admin contacts the venue directly** before approval.

**Our recommendation:** B. We keep the accepted wording, date, account and the admin's decision on record. Events at manual venues are marked "unverified venue" until approved. **Needed from you:** the exact wording (reviewed by your legal adviser), who in your team does the review, and what happens if the venue later objects (suggested: event is unpublished and sales are refunded).

---

## Q5. Capacity, entry and no-show rules

**The question:** Please confirm the rules below, or give your own.

**Why it matters:** These rules decide how many people can be sold, what the door scanner accepts, and what the analytics report. A wrong rule means double-selling or turning paid guests away.

| # | Rule | Our recommended default |
|---|---|---|
| 1 | Total capacity of an event day | The venue capacity set when the club is created, minus anything already allocated |
| 2 | A multi-day pass | Counts as one place on **each** day it covers |
| 3 | Pending guest-list requests and table requests | A pending guest-list request holds a place for 24 hours; a table quote does not hold stock until accepted |
| 4 | Checkout hold | A place is held for 15 minutes while the customer pays, then released |
| 5 | Does a table or sunbed include entry for its guests? | Yes: guests of a table are not sold separate tickets, and are counted once |
| 6 | Re-entry and a ticket scanned twice | One entry per ticket per day. A second scan is refused and shown as "already used". A no-show is final once the entry window of that day closes |

**Also tell us:** the closing time of the entry window for each day (suggested: event end time).

---

## Q6. Smaller choices for discovery and profiles

**Why it matters:** None of these block everything, but each one changes what customers see. We will use our default if you do not answer.

| # | Question | Our recommended default |
|---|---|---|
| 6a | How far can customers search from their city? | Steps of 10, 20, 30, 40, 50 km; 20 km selected first |
| 6b | Which music styles and moods are offered? | We propose a starter list and you edit it. Customers pick from the list, no free typing |
| 6c | What do "Trending" and "Most viewed" mean? | Trending: events in the city ranked by views and "Interested" taps in the last 7 days. Most viewed: most opened events in the city over 30 days |
| 6d | Can people see **who** is "Interested" in an event? | No. Show only the number. (Showing names raises privacy questions) |
| 6e | Can artists have their own login to edit their profile? | Not now. The club or organizer maintains artist profiles. Artist accounts can be added later |
| 6f | What exactly are "Hosts" and "Quotes" for clubs? | Hosts: named people (for example, promoters) the club lists on an event so customers can contact them. Quotes: table requests (see Q1). Please confirm or correct |

---

## Q8. Do you need partial refunds, for example one person out of a group order?

**The question:** A customer can buy tickets for up to 5 people in one order. If one of them cannot come, should we be able to refund just that person's ticket? Or is it enough to refund a whole order, or an amount of money?

**What your tracker says:** it asks us to show "cancellations and full/partial refunds" (item E6) and to "run full/partial refunds" in the final test (V9). It does not say whether "partial" means part of the money or one person's ticket, and it never mentions refunding an individual attendee. That is why we are asking.

**Why it matters:** today the system can refund a whole order only, once. Refunding one person means each ticket needs its own status (valid, refunded), the door scanner must reject that one ticket but accept the others, and the stock must be given back. That is a bigger change than the rest of the refund work.

**Options:**
- **A. Whole-order refunds only.** What we build now. Simple and safe.
- **B. Whole order, or a money amount once per order** (for example a goodwill refund of 10 EUR). The tickets stay valid. This is what the first release supports.
- **C. Refund one person's ticket out of a group order.** Needs the per-ticket status described above.

**Our recommendation:** B for now, and C only if clubs really need it. Please say which, so we do not build the wrong one.

**Also tell us:** whether the service fee is returned on a partial refund (see Q2) and who may request one (the club, the customer, or only your admins; we currently allow the club to ask and your admin to decide).

---

## Q9. When an order is refunded, should the tickets or places go back on sale?

**The question:** After a refund (a whole order, or an amount), should the places that order held become available to other customers again?

**Why it matters:** If yes, a refunded group of four frees four places, which helps sell out events but means the event can be resold after a refund, and it only makes sense for a full refund of the whole order. If no, the places stay counted as sold, so the number of tickets sold never goes down because of a refund. Money-only (partial) refunds should never release places, because the customer keeps their tickets.

**Options:**
- **A. No (default).** A refund returns money only. The sold count does not change. Entry is blocked only after a FULL refund of the order.
- **B. Yes, for full refunds only.** A full refund frees the places; a money-amount refund does not.
- **C. Yes, decided by the admin on each refund** (a tick box on the approval).

**Our recommendation:** A for now. It is the simplest and cannot cause double-selling. We can add B or C later as a small extra step once you tell us.

**What we do until you answer:** we use A. Nothing is built to give places back on refund. Places that were held by an unpaid or expired payment are still released automatically; that is a different case and is already approved.

**Also tell us:** whether an event cancelled by the club (which already refunds everyone) should keep its current behaviour. We assume yes.

---

## D1. Can anyone sign up as a club owner?

**The question:** Today, anyone can register in the app and choose "club owner" themselves, with no check. Should this stay?

**Why it matters:** A club owner can create clubs and events, sell tickets and receive payouts. Without a check, anyone can appear as a venue. This is also a security risk. Removing it will change the signup screen in the mobile app.

**Options:**
- **A. Keep as is.** Fast, no protection.
- **B. Anyone can apply, but an admin must approve before they can sell.** Account is created as a normal customer until approved.
- **C. Club owners and organizers are created only by an admin (invitation).** Most control, more manual work.

**Our recommendation:** B. It keeps signup simple and adds control before any money is involved. This question also decides how the new "organizer" role is created.

**Status on our side:** nothing is built for this until you answer. Signup and club creation keep working exactly as today. The rest of the account and login fixes go ahead.

---

## Client notices (not questions)

Things that will look different after the changes. No answer is needed; please tell your team.

1. **Owner earnings will include table purchases.** Today the owner earnings figure leaves table (VIP module) purchases out. After the change they are counted, so owners will see higher totals than before.
2. **Old ticket purchases have no ticket type recorded.** Purchases made before the release do not say which ticket type (tier) was bought, and this cannot be rebuilt. Reports by ticket type start from the release date. Existing ticket types keep their current sold numbers.
3. **Past sold counts may be too high.** Until now, a started but unpaid or failed checkout kept its places reserved forever. Some events therefore show more tickets sold than were actually paid. We are preparing a read-only report of the affected events; the numbers will be added here once it has been run. Nothing is changed automatically, and each correction is your decision.

---

## Content we need from you

Some features need real content from your team before they can go live. We can build and test them with placeholders, but we cannot publish them without your lists. Please send them in any simple format (a spreadsheet or a plain list is fine).

| # | What we need | Used for | Format | Needed by |
|---|---|---|---|---|
| C1 | **Music genre starter list** (for example House, Techno, Hip-Hop, Reggaeton...) in the order you want customers to see them | The genre filter on Explore and the genre choice when a club creates an event (CR-10, Q6b). You can edit the list later in the admin | One genre per line, with Italian and English names if you want both | Before the discovery release (M4) goes live |
| C2 | **Mood starter list** (for example Chill, Party, Romantic, Exclusive...) | The mood filter and the mood tags on an event page (CR-10, Q6b) | One mood per line, same format | Same |
| C3 | **City seed list**: the cities you want customers to pick from at launch, and which ones are live on day one | The city selector and the distance search (CR-09, Q6a). Today events only carry free-text locations, so we cannot build this list safely from existing data | City name, country, and "live at launch: yes/no". We add the map position and time zone | Same |
| C4 | **Venue-authorization wording** (only if you want events at venues not on the app, Q4) | CR-02, not approved yet | Text reviewed by your legal adviser | Only after Q4 is answered |

**What happens if we do not receive them:** the discovery features still work with placeholders in testing, but the production city list stays empty (customers keep using GPS and the text city as today) and the genre and mood lists are limited to the values already used on existing events. Nothing breaks; the new filters are just thinner.
