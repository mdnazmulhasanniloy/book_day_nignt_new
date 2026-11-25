# Bookdia Night — Product & Development
 
*Updated 24 November 2026*
 
---
 
## 1. Pricing and table bookings
 
Bookdia Night development decisions, including the 23 November follow-up. Proceed with agreed work and report dependencies by question ID.
 
### Q1 · Fees and launch defaults
 
Technical Fee is the customer booking fee. Service Fee is the partner commission included in the base price.
 
Launch defaults for Italy, France, Monaco, Spain and the US: 5% of the eligible paid subtotal plus the local-currency equivalent of EUR 0.50 once per order. Partner commission: 10% for tickets and passes, 15% for tables, sunbeds and extras. Admin can change these by country and category. A EUR 20 ticket costs EUR 21.50; two cost EUR 42.50 together. Free tickets and guest lists cost the guest zero; the partner pays zero unless admin sets an agreed fixed amount.
 
### Q1 · Admin control
 
Apply country and category defaults, then the partner/club rate, event override and finally an individual table/quote override. Admin can reduce either fee or set it to zero. Show a preview of the resulting price and save the rates used on each sale. Later changes apply to new orders. In mixed baskets charge the fixed component once and record the allocation by item for partial refunds.
 
### Q2 · Presentation and calculation (C / A / B)
 
Show the full payable price as soon as calculable and itemize the Technical Fee discreetly. Support inclusive display by market/category. At launch apply 5% to each amount paid in app, including a later online balance. Charge the fixed EUR 0.50 (local equivalent) once per order, on the first online payment. A balance paid at the venue carries no Bookdia Technical Fee. Show each payment and fee before customer confirmation. Link to refund terms (Q10–Q12) and track actual processor cost separately. Apply the saved admin overrides from Q1.
 
### Q3 · A | Card authorization
 
Authorize an eligible card for the agreed amount and capture after venue approval. If a hold is unsupported or expires, request fresh payment after acceptance. Rejection before capture costs the customer zero. Mark the booking confirmed only after successful payment.
 
### Q4 · A | Quote validity
 
Default 48 hours, configurable by the club, capped by the booking deadline. A quote is subject to availability until paid. The club can withdraw an unpaid quote early if the table is sold elsewhere. Disclose this, notify the guest and disable payment on withdrawn quotes. Prevent simultaneous sale of the same table.
 
### Q5 · C | Hybrid settlement
 
The club selects which options to offer. Example: EUR 1,000 table, EUR 500 deposit, default rates.
 
1. **Deposit online, balance at venue:** EUR 525.50 online, then EUR 500 at the venue.
2. **Full payment online:** EUR 1,050.50 in one payment.
3. **Two online payments:** EUR 525.50 now, then EUR 525 when the customer confirms the balance.
Record attendance and both payment channels. On a completed EUR 1,000 table Bookdia earns EUR 150 partner commission on the full base price in all three cases. If only EUR 200 was paid online, allocate EUR 150 from it where settlement permits; record any shortfall as payable by the partner.
 
---
 
## 2. Booking support and settlement
 
Build on the existing Stripe account. Show the allocations, transfers to connected accounts and bank payouts as separate events.
 
### Q6 · In-app chat plus a support link
 
Booking-linked chat is the primary channel. Owners, authorized venue staff and authorized organizers can reply. For urgent tables or unanswered requests offer a link to the single Bookdia Night WhatsApp Business number. Suggested text: *"Need help with a last-minute table? Contact Bookdia Night on WhatsApp."* Flag attempts to divert a booking and show *"For your protection, please keep this booking in the app."* Allow the approved on-site balance workflow. Bookdia Night admins and specifically authorized platform managers/staff may review and intervene. Delete the chat 30 days after booking closure. When a dispute is opened, use dispute closure as the start of the 30-day period.
 
### Q7 · A | Split preview
 
Admin sets Bookdia Night's share. The owner proposes the remaining split and the organizer accepts before sales open. Show amounts privately to the parties. On a €10 ticket, €1 platform, €2 organizer and €7 club is one agreed example. Keep the Technical Fee separate.
 
Select the settlement mode before opening sales. If the organizer cannot receive payments, route its share to the eligible club under the agreed fallback and show this in the preview. Flag an ineligible club for resolution.
 
### Q8 · Event end plus three days (A)
 
Charge the customer when the booking is confirmed and issue a valid ticket. Show each partner's share as **Pending** until event end, then **Confirmed — scheduled for transfer** with the expected date. Initiate the transfer of eligible funds three calendar days after event end, subject to Stripe availability. Keep withdrawal disabled before release. Admission and scan status are separate from settlement status. A no-show alone does not suspend settlement.
 
Hold the amount affected by an open refund or dispute and release undisputed amounts. Before transfer, reverse the affected internal shares, including the applicable Service Fee. After transfer, support full or partial transfer reversals and show any unrecovered amount. Demonstrate one partially refunded order and one insufficient partner balance. Confirm holding limits for advance sales and how the platform keeps sufficient available funds on its actual account.
 
### Q9 · Failed payouts
 
Prefer an immediate notice to admin and partner. Retry transient failures up to three times in three days. For an invalid IBAN or missing document, notify immediately with the required action. Explain where funds actually sit and when sales can continue under the account restrictions.
 
### Q10 · Partner cancellation and fee recovery
 
Refund the cancelled admission and reverse its internal Service Fee. Refund the customer Technical Fee whenever required by law or the applicable booking terms. For tickets and confirmed tables, charge the responsible club (or organizer under its agreement) the full amount of the Technical Fee actually refunded by default. Bookdia admin alone can waive part or all of its margin case by case, down to the documented unrecovered Stripe cost. Show the original fee, actual cost, waiver and partner debit before approval. Log approver and reason. Never charge the cost twice. Recover from eligible partner balance, future settlements, then invoice the shortfall under the partner agreement. The customer receives any amount due independently of recovery.
 
The Technical Fee is non-refundable by default. Admin may authorize a full or partial discretionary refund; process any legally required refund in full. Provide an Admin-only **"Charge to club"** action for chargebacks arising from event cancellation or change. Record the customer refund, any platform contribution and the remaining debit to the responsible club separately, with amount, reason and approver. Reconcile any bank credit to prevent double reimbursement.
 
---
 
## 3. Refunds, entry and inventory
 
Keep a history of ticket changes. A closed event can still have an open support case, bank dispute or accounting adjustment.
 
### Q11 · Date or venue change
 
Notify guests immediately. Keep unused tickets valid and offer a refund to guests who decline the change. Proposed window: seven days from notice, before use, with an immediate refund route for a last-minute change. Show the exact deadline. Refund the applicable admission price. Where law or booking terms require refunding the Technical Fee, apply Q10 in full, including partner funding and the discretionary admin waiver.
 
### Q12–13 · Authority and partial refunds
 
Close ordinary self-service cancellation at the published cutoff. For an eligible voluntary cancellation, follow the published refund terms. Bookdia retains the Technical Fee on customer-initiated cancellations, including within the free cancellation window, subject to mandatory local rules. Display this before purchase. Example: a refundable €20 ticket plus €1.50 Technical Fee gives a €20 refund. Allow case handling and bank disputes after event end.
 
### Q14 · C | Table deposit
 
Club sets the policy per table and displays it before payment. Allow non-refundable deposits and expressly published refundable terms. Apply the terms accepted by the guest; the venue can grant additional exceptions.
 
### Q15 · Release capacity
 
Restock unused invalidated tickets while sales are open, including an approved late cancellation. Respect the club's sales closing time. Stop sales on cancelled events. Notify the owner or authorized organizer if manual release is required.
 
### Q16 · A | Purchase limits
 
Default five tickets per order and ten per customer per event, configurable by event. Flag repeated cancellations for review. Count a table booking as its own product.
 
### Q17–18 · Attendance and guest lists
 
See [page 10](#10-questionnaire-clarifications-and-remaining-inputs) for daily cutoffs and approval holds.
 
### Q19 · One code management screen
 
Choose purpose (discount or guest-list request), event/list, expiry and use limit. One use makes a single-use code; e.g. 100 uses makes a shared code. Guest-list codes submit a request; issue the ticket after approval where required. Identity-bound individual invitations can follow later.
 
### Q20–21 · Discovery and inventory
 
For multi-day passes, reserve one place on each included date. Allow one valid admission per covered day. Venue staff can reduce remaining inventory for offline sales. Use a 15-minute checkout hold.
 
---
 
## 4. Partners, permissions and release
 
Commercial launch coverage and Stripe payout eligibility must be verified separately.
 
### Q22–23 · Pending and existing partners
 
Existing clubs retain access without reapproval. Pending new owners and organizers see only the club-area home, with partner tools locked. Customer use requires a separate customer account.
 
### Q24 · Distinct managers and simple permissions
 
**Club roles**
 
- **Club Owner** — controls payout destination and team.
- **General Manager** (the former Primary Manager) — runs club-wide operations and reporting, without ownership transfer or payout destination access.
- **Event Manager** — handles assigned events, pricing within permissions, capacity, bookings and event revenue.
- **Reservations Staff** — manage guest lists, bookings, check-in and forward refunds.
- **Organizer** — permissions for quotes, chat and refunds start off and are granted independently.
Owner invites staff; platform can suspend accounts. Use simple page-level view/manage checkboxes and explicit sensitive actions for both platform and club staff. Only platform admin controls Bookdia commercial rates.
 
**Platform roles**
 
- **Platform Admin** — full access.
- **Platform Manager** — admin-like operational access, excluding payouts, payout destinations, Stripe settings, commercial rates, Technical Fee refunds, club debits and admin management.
- **Country Manager** — same permissions as Platform Manager within the assigned country or region only.
- **Platform Staff** — can handle ordinary refunds within policy, tickets, chat, reports and disputes; excludes rates, payouts, roles and event publishing.
Reserve Technical Fee refunds and club debits for Admin. Give Joys an editable role-permissions page with per-page and sensitive-action toggles. Enforce permissions and geographic limits server-side.
 
### Q25 · A | Disputed venue
 
Suspend sales and keep the booking record pending the admin decision within two working days. Escalate immediately for an imminent event. Inform ticket holders promptly. If cancelled, apply Q10.
 
> For Q25, previously sold tickets stay valid pending the admin decision. For unregistered venues require the completed authorization form and admin approval before publication or sales.
 
### Q26–27 · B / A | Launch coverage
 
Côte d'Azur extends from Saint-Tropez to Menton. Model this as a destination area independent of the 50 km search radius. Monaco remains its own destination. Enable all eleven destinations:
 
Rome, Milan, Turin, Bologna, Paris, Côte d'Azur, Barcelona, Madrid, New York, Las Vegas and Monaco.
 
For a city without a club use *"Your city's first party is on its way."* For active cities with no matching results offer date/radius changes.
 
### Q28–30 · Data and accounts
 
See [page 10](#10-questionnaire-clarifications-and-remaining-inputs) for production-data access, Stripe and release approvals.
 
### Q31 · Age
 
Use declared date of birth, including Google and Apple sign-in. Under-18 customers can sign in and purchase. Show the warning: *"Many events are 18+. Check the age requirement before you book. Continue?"* Display the event age rule before purchase. General registration uses self-declaration. Confirm the age requirement for owners and organizers separately.
 
---
 
## 5. Delivery and Italian ticketing
 
Proceed with development. The Italian production flow requires confirmation of the issuer, access-control system and contractual responsibilities.
 
### Q32 · Target schedule
 
Target mid-December 2026 for a usable build and early January 2027 for launch, subject to your realistic schedule and owner testing. Provide dates for each delivery, including multiday passes/scanning. No fixed event date has been supplied. Notify Joys whenever a group of tracker IDs is ready with build, date, changes and evidence. Joys retests and closes each ID individually.
 
### Q33 · Languages
 
English, Italian, French and Spanish must be complete at launch across app flows and customer documents, with appropriate review of terms. Deliver the remaining previously agreed languages already listed in the app shortly afterwards. Return the current language inventory for reconciliation.
 
### Q34 · Complete features and priorities
 
- **Launch:** table quotes/holds/deposits, booking chat with support link, team permissions, partner approvals, authorization for unregistered venues, splits, multiday passes and scanning, ticket-level cancellation/refunds, purchase limits and Interested count.
- **Soon after:** complete referral programme and complete resale/waitlist flow.
- **Later:** attendee messaging and optional avatar preview.
Give each deliverable an owner, date and end-to-end test. Schedule distinct features as whole units. Cross-reference original scope; scheduling a feature does not approve extra charges. Submit any separate estimate before work is commissioned.
 
### Italy · Keep the guest journey to one QR
 
Identify the event organizer, ticket seller, issuer and certified ticketing/access-control provider for each Italian sales route. Show how the Bookdia app presents the admission, how a door scan validates it in the appropriate system, and how a repeated or cancelled admission is rejected. Demonstrate a paid ticket, a complimentary admission at a paid event, a free-entry event and a table with multiple guests. Identify whether each guest-list QR records a reservation or is the fiscal admission itself, and how it is validated. Obtain a provider quote covering setup, recurring charges, issue and cancellation.
 
### Italy · Reconcile a refunded sale
 
Demonstrate an issued ticket followed by a customer refund or event cancellation. Link the original ticket, fiscal cancellation record and reason, QR invalidation, Stripe refund, commission reversal and updated partner statement. Mark the refund pending until the processor confirms its outcome. Identify the responsible party and time limit for each step. Please provide evidence from the issuer's test system.
 
Bookdia will confirm with its adviser and the ticketing provider who obtains the music licence and which receipts enter the calculation. For each event, name the organizer holding the music licence and provide an export of gross sales, fees, cancellations and refunds for reconciliation with box-office sales. Confirm whether the Technical Fee falls within advance-booking rights under the applicable permit. Keep the payout schedule separate.
 
**Official references:** SIAE, "Biglietterie automatizzate e controllo accessi" and "Permesso per utilizzazione di musica per trattenimenti danzanti"; Italian Ministry of Finance, decree of 13 July 2000, article 7.
 
---
 
## 6. Section 10 · Items to supply
 
Please mark each item **Received**, **Missing** or **Needs updating**. Identify the person who needs it and the first delivery it affects. Access details belong in a private channel.
 
| # | Item | Details |
|---|------|---------|
| 01 | **Stripe** | Use the existing account. Team to confirm limited team access, test keys, Connect permissions and test coverage by country. Report exactly what is missing. Mark previously supplied access Received; list each missing permission. Specifically verify Monaco Connect payout eligibility on the actual account and report feasibility. |
| 02 | **App distribution and sign-in** | Confirm invitations to Apple Developer, TestFlight and Google Play Console, plus access to Apple and Google sign-in configuration. Mark access already sent as Received and identify exactly what is missing. |
| 03 | **Push notifications** | Tell Joys which push notification platform, account and permissions are needed. Joys is the contact. |
| 04 | **Hosting and testing environment** | Confirm access to the test environment and hosting or identify the infrastructure contact. Written release approval applies under Q30. |
| 05 | **Testers** | Joys Rossi tests the first build. TestFlight Apple ID: Segreteria@beverlyvacanze.it. Contact: Joysrossi@gmail.com. Supply ten separate test logins: Customer, Club Owner, Club General Manager, Event Manager, Reservations Staff, Organizer, Bookdia Admin, Platform Manager, Country Manager and Platform Staff. Send credentials privately and use test payments. |
| 06 | **Pricing** | Launch rates and the confirmed second-instalment rule are specified in Q1–Q2. Test all three Q5 payment options. |
| 07 | **Venue authorization form** | Team to send the proposed download, completion, upload and admin review flow. Joys will supply the form in English and Italian for legal review and arrange the required launch translations under Q33. |
| 08 | **Terms** | Prepare booking, cancellation/refund and venue authorization terms for review, including partner recovery. Resale and referral terms are due with those releases. |
| 09 | **Referral inputs** | Before referral development, confirm holiday calendars per market and exactly which fees a complimentary event waives. |
| 10 | **Design references** | Screenshot package supplied: <https://www.swisstransfer.com/dl/01a20284-aa6f-733b-ab5b-7e0ba209e1b2>. Both the screenshot and screen-recording links have been sent. Download both before expiry and confirm receipt. Use the references with original visuals. |
| 11 | **Product acceptance** | Joys Rossi is the sole product acceptance and sign-off contact for now. Use item 05. |
| 12 | **Operational admins** | Bookdia to identify admins authorized to approve owners, organizers and venues and handle disputes. |
| 13 | **Market advisers** | Bookdia to identify the tax/accounting and legal review contacts for each launch market. Team to flag country-specific dependencies. |
 
---
 
## 7. Italian admission tickets: two implementation options
 
### Decision requested from engineering
 
No fiscal ticketing partner has been selected. For covered Italian events a QR generated from a Bookdia booking ID alone does not establish that a fiscal admission ticket was issued. Stripe records the payment. Identify the party issuing the admission on behalf of the organizer, the approved system and the access-control route. Treat the music licence and royalties as a separate organizer/adviser workstream.
 
### A. Integrate an approved partner
 
Obtain the approval reference and supported system version. Request a sandbox, technical specifications, sample fiscal ticket and event report. Map our organizer, venue, event, date, sector and ticket categories to their IDs. Confirm how new venues are onboarded and how inventory is allocated when the club sells elsewhere. Ask whether Bookdia can use its own Stripe Connect checkout and receive issuance, cancellation and scan results.
 
#### At the door
 
Ask for written confirmation that the Bookdia scanner may act as a client of the approved access-control system in this configuration. Show the issuer-provided credential in the app. Send the scan for validation against the official valid-ticket list and record its result. If unsupported, propose using the approved reader on the same customer credential. Document outage and offline reconciliation rules before allowing offline entry.
 
### B. Build a Bookdia fiscal system
 
Estimate a dedicated fiscal issuance and access-control module. Implement compliant ticket generation and fiscal seal, test smart-card integration, protected records, signed reports and transmission, cancellation records and access-control reporting. Request a test card, agree the certification scope with an eligible assessor, prepare technical documentation and test evidence, obtain the conformity certificate, submit the application to the Italian Revenue Agency and complete required tests and production activation. Confirm which entity owns and operates the approved system.
 
### Return a decision memo before paid work
 
For each option show engineering days, calendar dependencies, external fees, maintenance and responsible party. Quote pilot and multi-club terms, setup, minimums and charges for paid tickets, complimentary tickets and cancellations. Our preferred partner model is zero fixed or minimum fees. Development may proceed in test mode. Enable real Italian admission sales only on the approved route.
 
---
 
## 8. Order, refund and scanner acceptance tests
 
### One order, multiple records
 
Store order ID, payment ID, seller, organizer, venue jurisdiction, issuer, issued ticket ID, seal/reference, admission date and status, scan result, refund ID and payout allocation. Keep payment, fiscal issue, admission and partner payout as independent states. A partner payout pending until event end plus three days must not leave a paid admission pending.
 
### Successful sale and recovery
 
Reserve inventory for 15 minutes. Coordinate payment and fiscal issue using the issuer-supported sequence. Use one stable request key per ticket. On timeout, query the issuer before retrying. Do not deliver an active QR until issue is confirmed. Queue unresolved paid orders for reconciliation, notify support and resolve by delivery or refund. A duplicate payment notification must never issue two tickets.
 
### Admission and inventory
 
Test concurrent scans at two doors, wrong event/day, cancelled and previously used tickets. For a multi-day pass keep admission rights per covered day. For a table of eight verify how eight admissions are recorded, including staggered arrival. The issuer must confirm the supported model for included admission, complimentary places and guest-list reservations versus truly free events.
 
### Refunds
 
For an unused cancelled ticket coordinate fiscal cancellation, QR invalidation, refund and inventory release. Keep original IDs and reasons. Track failures until resolved. A partial goodwill payment adjustment may preserve admission only through a separate authorized process with the correct fiscal treatment. Reconcile the issuer report, Stripe and Bookdia amounts per event.
 
### Technical Fee and accounting
 
Admin may include agreed issuance cost in the configurable customer Technical Fee. Preserve the once-per-order fixed charge. Store the actual provider cost per issued ticket and actual processing cost separately from partner Service Fee and platform margin. In a two-ticket order test two issuance costs and one fixed customer charge. Show the full payable price as required in each market. Do not add a second undisclosed charge. Confirm who absorbs non-recoverable issuance costs on cancellation; Q10 already covers processor cost.
 
### Evidence for sign-off
 
Return a sample ticket, duplicate-scan result, cancellation receipt, event-end report and reconciled settlement for a pilot venue. Include evidence for failed issuance after payment, one refunded ticket in a two-ticket order and a multi-day pass. Joys signs off the tracker IDs against the test build.
 
---
 
## 9. Market configuration before live sales
 
### France | Paris and the French Riviera
 
For paid shows provide admission issuance or compliant digital recording before entry. Nightclubs using the cash-register route have specific receipt obligations. Identify which system is authoritative for each club. For computerized ticketing support unique issue records, retained and exportable data, daily receipts and the operator declaration by first use. Confirm current requirements for the chosen system and venue before activation.
 
**References:** French tax administration, BOI-TVA-DECLA-20-30-20-30 and -40.
 
### Principality of Monaco
 
Configure Monaco separately from France. Article 76 of the local turnover tax code provides for tickets or digital admission records before entry and a cash-register route for discotheques in the specified circumstances. Check Annex A-173 to A-179 with the operator. Provide legible records, inspector access via the operator and sales reconciliation. Obtain local confirmation for the proposed digital flow.
 
### Spain | Barcelona and Madrid
 
Record organizer authorization for primary sales. In Catalonia, Law 11/2009, article 21, expressly permits authorized technological sales platforms. Madrid has separate event and refund rules. Configure organizer identity, venue, date/time, prices, complaint information and cancellation/change handling. Establish who issues invoices or receipts and whether Spanish billing software rules apply to that entity and software. Keep invoice identifiers distinct from entry credentials.
 
### United States | New York and Las Vegas
 
For covered live-event tickets show mandatory fees in the prominent upfront total, including in listings; disclose the final payable amount before payment. Assess club admission by event type. New York admission tax treatment depends on the venue and entertainment. Nevada generally applies 9% Live Entertainment Tax to admissions to qualifying live entertainment at venues with capacity of 200 or more, subject to exceptions. Record jurisdiction, taxable base, capacity, collector and exemption rationale. Review primary sales and future resale separately.
 
### Deliverable per market
 
Provide one worked sale, a refund, a scan and an event report; identify the seller, issuer, tax collector and applicable local rules. Confirm provider coverage, fiscal software requirements and treatment of mixed table/admission packages with the local adviser. A country flag alone cannot determine tax or authorize sales. Open destination discovery independently of live ticket sales.
 
---
 
## 10. Questionnaire clarifications and remaining inputs
 
### Q12–13 | Refund authority and goodwill
 
Eligible voluntary refunds are automatic under the policy. The club decides exceptions; organizers need explicit owner permission, reservations staff forward requests, platform admins handle disputes. Full cancellation invalidates the ticket. The club may approve a documented partial goodwill refund with continued admission.
 
### Q17–21 | Attendance, inventory and time
 
Record a no-show at each covered day's entry cutoff; the next covered day stays valid. Club sets entry cutoff (default event end) and guest-list approval hold (default 24 hours, configurable 1–72 hours, capped by entry cutoff). On expiry release the pending place. Open the next tier on sellout. Show the lowest available price on cards, event page and purchase button. Show **Last tickets** at 20% or less of that tier while stock remains. Backfill missing time zones from venue/city and allow organizer correction; flag ambiguous records.
 
### Q22–23 | Approval and existing accounts
 
Existing clubs keep access with no new approval. New owners and organizers awaiting approval can see only the club-area home. Lock all partner tools and enforce this on the server. Customer access requires a customer account.
 
### Q28–30 | Production data, Stripe and release
 
Read-only inspection is authorized for the affected sales counts. Return the event-by-event differences first. Change live data only after written approval for each event. Use the existing Stripe account with limited permissions; confirm eligibility for partner payouts in Italy, France, Monaco, Spain and the US. Developers prepare releases; publish only after written Bookdia approval.
 
### What remains open after Q34
 
Track the 13 handover items on page 6 ([Section 10 · Items to supply](#6-section-10--items-to-supply)). Open items include:
 
- Owner/organizer age requirement
- Stripe holding limits
- Monaco payout eligibility
- Local terms and tax review
- Venue authorization form
- Operational admin assignments
- Approved ticketing route
- Delivery dates, including pass scanning
Confirm both reference downloads. Referral and resale follow-ups are due when scheduled.
 