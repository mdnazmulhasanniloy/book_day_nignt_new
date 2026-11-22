# Bookdia Night — Client Response

*Bookdia Night / Client Response / 22 November 2026 — prepared for the Development Team*

---

## 1. Table reservations and quotes

### Q1. What the customer can book

Offer fixed-price tables and tables advertised as "Starting from". The club or an organizer authorized by the club owner may issue a quote. Show the final price, party size, inclusions, expiry and cancellation policy before the customer commits. The club can offer a deposit, full payment, or both. Where both are offered, let the customer choose. Show the amount due now, balance and settlement terms.

### Approval before collection

A request alone reserves no table. For a known amount, Stripe manual capture is the proposed route on eligible payment methods. Authorize the customer-approved amount, mark the request pending, and let the authorized operator accept or reject. On acceptance, reserve the table atomically and capture before the authorization expires. Confirm only on successful capture. On rejection cancel the authorization, release the whole hold and charge the customer zero, including service fees. Display the release status. If capture fails, release inventory and invite a payment retry.

### When the final price is still unknown

Send the approved quote first, then collect the customer's consent and payment for that exact amount. Recheck availability at acceptance/payment. If manual capture is unavailable or the hold has expired, request a fresh payment after venue approval. Please demonstrate both routes and verify authorization costs under our own Stripe contract. A card guarantee would require separate terms for any later charge.

### Three different clocks

Your proposed 48 hours means the time the customer has to accept the quoted price. The duration remains open. Make it configurable and cap it at the booking deadline. Set any accepted-table inventory hold separately. For Stripe authorizations use the actual `capture_before` deadline. The standard active checkout hold is 15 minutes.

### Messaging

WhatsApp may be an additional channel routed through Bookdia Night. Owners cannot enter a personal WhatsApp number. Alternatively propose an in-app conversation linked to the booking, available to owner, authorized staff and owner-authorized organizers. Platform admins can review and intervene. Flag or block attempts to move the transaction elsewhere, explain chat moderation to participants and retain the quote and payment record.

---

## 2. Fees, commission and settlement

*Payments / Q2–Q3*

### Q2. Customer service fee

Support a platform service fee on every paid product: tickets, passes, tables, sunbeds and extras. Admin may set it to zero by product or agreement, including for tables and sunbeds. Route the fee to Bookdia Night and record actual processing costs separately. Support an itemized fee or an all-inclusive price labelled "Service fee included". Always display the payable total before purchase. Validate the presentation and refund policy per launch market.

### Pricing recommendation for testing only

For standard EEA cards, Stripe's public Italian price is 1.5% + €0.25 per successful charge. On a €10 order this is about €0.40, versus €4.75 on €300. For an initial cost-coverage simulation, test 1.5% + €0.26 per order, then compare against actual charges including fees on the collected total, Connect, card mix and currency conversion. This is a benchmark, not an approved consumer rate. Show sample orders for each market and product before activation.

### Internal technology-partner commission

Bookdia Night earns a percentage of the paid product price, borne by the club or organizer and embedded in the price. Set an admin-controlled base and overrides by client, venue, event and product. Allow lower or higher negotiated deals for large tables and sunbeds. Retain support for fixed amounts from the original brief. Default free admissions to zero. A percentage of zero yields zero: support a separately agreed partner-side fixed charge if admin enables one for free admissions. Never charge the free guest for it. Version rates by effective date and preserve the original order terms.

### Q3. Split the proceeds

Apply percentage splits automatically. Select the settlement arrangement when configuring the event. In the owner's €10 example, €2 goes to the organizer, €7 to the club and €1 to Bookdia Night. These illustrative percentages apply to the ticket base and total 100%. Account for any technical fee separately. If organizer payments are inactive, route the seller proceeds to the eligible club after Bookdia Night deductions. If the club itself cannot receive funds, flag the issue and request resolution. For approved unregistered venues, the onboarded organizer receives seller proceeds.

### Developer response requested

Confirm Stripe Connect feasibility on our account and in the launch markets. Propose payout timing, failed-transfer handling, retry protection, reversal of splits after refunds and reporting. Provide examples for a deposit, an included fee, a zero-fee table and an event cancelled by its organizer. Submit accounting and tax treatment for business review.

---

## 3. Capacity, cancellations and resale

*Admission / Q5, Q8, Q9*

### Q5. Capacity and sales outside the app

Use the declared venue capacity as the ceiling for each day. Deduct confirmed admissions, offline allocations and active holds once each. Owner or authorized organizer can reduce online availability as offline sales occur. Prevent reductions below existing commitments. A multiday pass needs a place on every included day. If Friday is full, only eligible options such as Saturday-only remain on sale.

### Guest lists, tables and entry

The proposed 24-hour guest-list hold concerns a request awaiting approval. It is a configurable inventory timeout, separate from the cancellation deadline for a confirmed free ticket. Release expired pending holds and tell the guest. Tables reserve on acceptance, with payment confirmation as described in Q1. Publish named table bookings and capacity ranges, e.g. 5–8 guests for €300, 4–6 for €150, or a two-person sunbed for €100. Include the associated guests in entry capacity once. Record party size and attendees admitted against the booking.

### Scans and no-shows

Publish the venue's entry hours. Each ticket allows one successful scan for its entitlement. Reject repeat scans. Proposed multiday implementation: issue a single-use credential for each included day under the same pass. At event end, an unused admission is a no-show. Report a group with zero arrivals separately from one partially attended. The venue manages on-site admission and its published cutoff.

### Q8. Refund authority and policy

The club sets a cancellation cutoff in hours or marks a booking non-refundable. Display the policy before payment. For eligible tickets cancelled in time, automatically refund the full product amount, reverse the associated platform commission and retain the disclosed technical fee. After cutoff or on a non-refundable booking, a refund requires a club exception. An organizer may approve refunds only with explicit owner permission. For confirmed tables, venue approval governs discretionary refunds. Retain the technical fee on an approved post-capture refund. For a confirmed table the default is no automatic full refund; the venue may authorize an exception. A customer may cancel a single eligible ticket in a group order: invalidate that ticket and preserve the remaining admissions. A no-show forfeits the amount paid under the disclosed terms. A declined pending table request costs the customer zero. Confirm separately the policy for venue-cancelled events and applicable market requirements.

### Q9. Inventory and resale

Invalidate every cancelled credential immediately. Automatically restore eligible unused capacity while sales remain open. If manual restocking is needed, notify the owner or authorized organizer and provide a manual restock action that prevents double release. Propose purchase limits to reduce mass booking and cancellation abuse. As an additional flow, scope ticket resale on both open and sold-out events. A seller is repaid on successful resale. Offer waitlist alerts and optional pre-authorized automatic purchase with a disclosed price limit and expiry. Transfer entry rights once, invalidate the original code and issue a new one. Please estimate this feature separately in the delivery schedule.

---

## 4. Venue verification and team access

*Partners / Q4, D1*

### Q4 / C4. Events at unregistered venues

Provide a draft workflow. Bookdia Night will supply the downloadable authorization form when requested. The organizer completes it, obtains evidence of venue permission and uploads it. A Bookdia Night admin approves or rejects before publication or sales. On dispute, suspend sales and refer to admin. Public label suggestion: **"Presented by [Organizer] at [Venue]"**. This attributes the event accurately without implying a club partnership or contractual exclusivity.

### D1. Approval and invitations

Club owners and organizers may apply or be invited. Require platform admin approval before access to partner dashboards, sensitive information or sales. Invitations also require verification. Track inviter, invitee, qualifying event or purchase and reward redemption.

### Proposed access matrix for implementation

| Role | Responsibilities and limits |
|---|---|
| **Platform Admin** | Approve accounts and venues, configure fees and commissions, oversee disputes, review booking chat and audit changes. |
| **Club Owner** | Manage club-wide operations and financial reports, authorize organizers and staff, manage payout destination through verified controls, and set policies. |
| **Primary Manager** | Manage club operations, events, bookings, reporting and authorized refunds. Reserve payout destination changes and ownership transfer for the owner. Prevent self-escalation of privileges. |
| **Event Manager (General Manager)** | Operate current assigned events, update information and capacity, manage tables, see ticket counts and revenue per assigned event. Restrict club-wide financial history, payout settings and role grants. |
| **Reservations Staff** | Manage guest names, reservations, check-in, basic event information and assigned conversations. Submit refund requests to an approver. Restrict financial reports, payment details and refund approval. |
| **Organizer** | Operate assigned events and offline inventory within venue limits. Separate owner-granted permissions for quotes, chat and refunds. Record who granted or revoked each permission. Enforce access on the server as well as in the interface. |

### Referral incentives

Proposed partner reward: when a referred owner or organizer completes their first paid event, the inviter earns one complimentary event on a non-holiday. Define the eligible fee waiver, holiday calendar and redemption conditions before release. For customers, the invitee gets 10% off their first eligible ticket and the inviter earns a 10% discount after that purchase succeeds. The stated minimum event commission for this incentive is 10%. Fund discounts from Bookdia Night's commercial commission; exclude complimentary referral events. Model deals below 10%, reversals and overlapping discounts before activation so partner proceeds remain protected.

---

## 5. Search, profiles and launch coverage

*Discovery / Q6, C1–C3*

### 6a–6c. Search and rankings

Use distance options of 10, 20, 30, 40 and 50 km, initially 30 km. Use editable music and mood lists. Rank **Trending** by city using views and Interested signals over seven days. **Most Viewed** ranks city event opens over 30 days. Keep each user's personal searches and recently viewed events separate. Document ranking weights and duplicate handling.

### 6d–6f. Interested, artists and hosts

Launch with a genuine Interested count. Optional preview: three or four small, non-clickable, non-zoomable avatars or initial circles with a +N remainder. If identities are shown, use first name only and offer visibility controls. Future direction: event-based messaging for meeting other attendees, with one contact per event on the free plan and the ability for paid VIP members to contact all participating attendees. Users should be able to coordinate attending together. Scope consent, blocking and reporting before enabling contact. Clubs and organizers maintain artist profiles including photo, Spotify link, upcoming events and follow. Hosts are named event participants such as promoters: demonstrate current permissions. Quotes refer to the table workflow in Q1.

### C1. Music genres in customer display order (EN / IT)

1. House
2. Techno
3. Tech House
4. Deep House
5. Melodic House & Techno
6. Afro House
7. Disco & Nu-Disco / Disco e Nu-Disco
8. Hip-Hop & Rap / Hip-Hop e Rap
9. R&B
10. Reggaeton
11. Latin / Latino
12. Pop & Commercial / Pop e Commerciale
13. EDM
14. Drum & Bass
15. Rock & Indie / Rock e Indie

Use the same label in both languages where only one is shown.

### C2. Moods (EN / IT)

| English | Italian |
|---|---|
| Party | Festa |
| Chill | Relax |
| Underground | Underground |
| Elegant | Elegante |
| Exclusive | Esclusivo |
| Social | Social |
| Romantic | Romantico |
| High Energy | Alta energia |

### C3. Launch locations

| Country | Destinations |
|---|---|
| Italy | Rome, Milan, Turin, Bologna |
| France | Paris and the Côte d'Azur |
| Spain | Barcelona and Madrid |
| United States | New York and Las Vegas |
| Monaco | Principality of Monaco |

Configure the Côte d'Azur as a region and propose its geographic coverage. Prepare these destinations for launch and confirm activation status per destination before production.

---

## 6. Access, references and delivery

*Handoff / C5–C6*

### C5. Test accounts

Please create labelled test accounts for customer, club manager, organizer and admin, plus staff-role fixtures. Use test payments. Send the required Apple and Google configuration details and minimum access needed privately. Provide build number, role and navigation path for each demonstration.

### C6. Functional references

The Shotgun screenshots have been shared three times. Please download this package promptly and confirm access. If a regional access issue prevents download, report it immediately. A screen recording will follow separately. Use the examples for ticket sections, passes, discovery and purchase behavior. Create an original Bookdia Night visual design.

[Download the screenshot package](https://www.swisstransfer.com/dl/01a20284-aa6f-733b-ab5b-7e0ba209e1b2)

### Release evidence and historical data

Continue the existing tracker and return status, completion date, implementation notes and evidence per ID. Provide target dates for multiday passes and scanning. Demonstrate table revenue in owner earnings, preserve known historical tier sales and label ticket-type analytics from the first reliable date. Send a read-only list of sales counts affected by stalled checkouts before any historical correction. Show the updated dashboard error messages.

### Required end-to-end demonstrations

1. Reject a pending table request, then accept a separate one: show the customer balance, platform ledger and inventory for each.
2. Run a €10 split, cancellation and failed payout retry. Reconcile all participants and the technical fee.
3. Sell the last Friday place while Saturday is open. Verify pass availability and duplicate-scan rejection.
4. Test a refund before and after cutoff, approval permissions and resale of released capacity.
5. Sign in as each staff role and verify exactly which event, booking, revenue and payment settings it can access.

### Stripe references

- [Separate card authorization and capture](https://docs.stripe.com/payments/place-a-hold-on-a-payment-method)
- [Italy payment pricing](https://stripe.com/it/pricing)
- [Connect pricing](https://stripe.com/it/connect/pricing)

Verify account-specific terms, supported methods, cross-border transfers and fee treatment before enabling live transactions.
