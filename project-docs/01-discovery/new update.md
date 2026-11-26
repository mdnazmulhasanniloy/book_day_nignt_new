Bookdia Night

Development Review and Completion Tracker

Consolidated review   |   6 November 2026

From Joys Rossi to the development team

Please use this document to complete and demonstrate every part of the Bookdia Night review. It brings together the original product requirements, our TestFlight observations, the later clarifications and the technical checks needed to verify the resulting behavior. Authentication must be fixed first because it currently prevents a full customer review.

Reply to each requirement separately, using its ID. For every completed item, record the completion date, exact changes, affected screens, build and evidence. A general message saying that everything has been completed will not be sufficient. I will verify the delivered behavior and record acceptance separately.
## How to read this document
Each requirement contains the observed baseline, the expected behavior and a concrete demonstration. Original requests and later product clarifications are identified. Technical recommendations explain implementation and testing details; they do not assume a specific technology stack. Open product/payment decisions are collected as Q1 to Q6 so they receive explicit answers.

The review baseline describes the supplied screenshots and reported tests. A function that was not visible or could not be accessed is not automatically classified as absent. An existing control is also not proof that its full workflow works. All acceptance fields start as Not tested for this consolidated delivery.
## Shotgun reference screenshots
The reference screenshots have already been shared twice. Use them for the ticket-section hierarchy, passes and day tickets, city discovery, filters and the purchase experience. They are functional and UX references for the reviewed requirements. Please inspect the complete set even where the images are not grouped by feature, and map the relevant examples to the IDs in this document.

[Open the Shotgun screenshot package](https://www.swisstransfer.com/dl/01a1b1f5-9c63-716a-8353-9d48fbd22dbe)

If the transfer is no longer accessible, report the access problem promptly and request the same screenshot set. Do not substitute assumptions for the referenced flow.

# Review overview


| **Section** | **Focus** | **Current review position** |
| --- | --- | --- |
| P0 | Authentication and test access | Reported defects block complete testing |
| A1 | General and event analytics | Incomplete relative to the requested reporting |
| A2 | Tickets passes tables and extras | Partially implemented; several flows unverified |
| B1 | City selection and discovery | Required controls missing from reviewed screens |
| B2 | Filters and map | Partially implemented |
| B3 | Homepage and artists | Partially implemented |
| C | Organizer access and collaboration | Not verified; role demonstration required |
| D | Public event page | Partially implemented |
| E | Checkout fees and commissions | Not verified; customer and admin access required |
| T | Technical implementation checks | To demonstrate with the completed workflows |
| Q1 to Q6 | Open decisions | Written answers and owner decisions required |
## Decisions already established
Provide both general club analytics and statistics for each event. Keep separate sections for day tickets, multi-day passes and tables. Offer preset ticket/pass tier names and a Custom option. Use real availability for low-stock badges. Make city selection and chronological Explore navigation explicit. Launch the Interested counter immediately with genuine user actions.

Offer fixed-price tables and a Starting from option. Present the payment and contact alternatives before choosing the variable-price table flow. Automatic organizer/club splits are preferred, with the club-receives-all alternative also to be addressed. The technical fee and commercial commission must remain distinct.
## Delivery order
First restore login and test roles. Then demonstrate inventory, admission and purchase flows, including the associated fee/payout rules. Complete discovery and public-page behavior, and reconcile analytics against the same sample records. This is an order for implementation and testing, not a division into separate paid phases or a waiver of any requirement.
## Identifier continuity
A1 and A2 follow the detailed checklist discussed during the review. B1, B2 and B3 cover discovery, C organizers, D the public event page and E checkout. The original PDF placed discovery inside A and used B/C/D for organizers/event page/checkout. The earlier Word combined several requirements into broader items; the crosswalk at the end links those items to the expanded IDs here.

# How the development team must update each item


| **Developer status** | **Meaning** |
| --- | --- |
| Pending | Work or the detailed developer response is outstanding. |
| In progress | Implementation is underway; record the remaining work. |
| Completed | Implemented in the named build and supported by the requested evidence. |
| Blocked | State the specific dependency, responsible person and next action. |
| Clarification required | State the exact question and the affected requirement or decision ID. |
The initial Pending fields mean that an item-by-item delivery response is requested. They are not a claim that all underlying code is absent. The baseline above each item records what was actually seen or reported.

Use completion dates in YYYY-MM-DD format. Record the person responsible and a build/version reference. In Implementation and evidence, explain what changed, where it appears, how it was tested and link the screenshot, recording or test record. Include any remaining limitation. Expand the editable response lines as needed.

Owner verification is separate: Not tested, Passed or Failed. Only the product owner records acceptance. If verification fails, retain the history, describe the defect and reopen the developer status. Do not mark the whole section complete while child items remain unresolved.
## Example of a useful response
A2.10 — Completed on [date], build [version], developer [name]. The event page and sticky ticket button now read the cheapest purchasable tier. I sold out the first tier in the sample event and both surfaces changed to the next price. Evidence: [recording and test order references]. Remaining limitation: [none or explanation].

This is a response example, not a statement that A2.10 has already been implemented.
## Evidence expectations
Use short recordings for flows involving several screens and screenshots for static layouts. Show test data that demonstrates sold-out, free/paid, pending/approved, multi-day and no-result states. Include sample order and event identifiers so the displayed numbers can be reconciled. Avoid real customer data in shared evidence.

For anything blocked by access, provide the required role and a working demonstration. For anything dependent on Q1 to Q6, record the question and proposed solution rather than silently selecting an option. Keep this document as the shared record; reply against the same IDs in later deliveries.

# P0 Access and test readiness
Restore authentication first so we can test every customer journey. Please investigate application defects and TestFlight configuration separately, then supply a build in which each access method works.
## P0 1 Registration and date of birth
ID P0.1  |  Review clarification

**Review baseline:** Reported defect. Registration and the birthday picker do not work reliably.

**Required behavior:** Fix date selection, validation and completion of account creation. Preserve valid entered data when an error occurs and show a useful error message. Clearly distinguish completed registration from an incomplete attempt.

**Demonstrate:** Create a fresh customer account, enter and revise a birth date, trigger an invalid input, correct it and complete registration. Show the saved profile after reopening the app.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## P0 2 Google and Apple sign in
ID P0.2  |  Review clarification

**Review baseline:** Reported defect. Both social sign-in methods failed during the review.

**Required behavior:** Verify Google and Apple sign-in in the distributed TestFlight build, including new users, returning users, cancellation and provider errors. Explain whether the cause was app logic, provider configuration or the test environment.

**Demonstrate:** Record a successful new-account and returning-account flow for each provider, plus cancellation and retry. Confirm that login returns to the intended screen without losing the booking context.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## P0 3 OTP and session recovery
ID P0.3  |  Review clarification

**Review baseline:** Reported defect. OTP verification and access completion were unreliable.

**Required behavior:** Fix OTP delivery, code entry, resend and error handling. Show expiration and retry behavior clearly. Verify session persistence, logout and reauthentication using the supported account recovery flow.

Implementation detail: apply server-side expiry and retry limits; avoid duplicate account or booking creation when users retry.

**Demonstrate:** Demonstrate a valid code, an invalid or expired code, resend, app restart, logout and login. Supply diagnostic evidence without exposing live codes or credentials.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## P0 4 Working roles and demonstration access
ID P0.4  |  Verification requirement

**Review baseline:** Customer checkout is blocked by authentication. Organizer and admin access have not been supplied.

**Required behavior:** Provide working test access for customer, club manager, organizer and admin, with exact navigation paths, build/version and a populated test event. Send credentials through an appropriate private channel rather than embedding them in this document.

Recommended access check: verify that a manager or organizer cannot access another account’s bookings, revenue or admin commission settings by changing a record identifier.

**Demonstrate:** Demonstrate each role and its relevant screens. A missing menu or missing permission must not be used as evidence that an inaccessible feature is complete.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# A1 Manager analytics
The reviewed dashboard showed revenue indicators, table reservations, tickets sold, a Monthly Earning chart and recent bookings/payments. That is only a partial foundation. We need booking and attendance analysis at club level and for each individual event.
## A1 1 Confirmed booking chart
ID A1.1  |  Original request

**Review baseline:** Partial. A monthly revenue chart was visible, but the requested booking chart was not.

**Required behavior:** Show confirmed bookings over time, independently of the revenue chart. Distinguish bookings/orders, admission tickets, reserved tables and extra product units so their totals are understandable.

**Demonstrate:** Use sample bookings across several dates and show the chart and totals matching the underlying records. Pending, failed and cancelled bookings must not silently count as confirmed.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 2 Temporal filters
ID A1.2  |  Original request

**Review baseline:** Not visible in the reviewed analytics screens.

**Required behavior:** Provide Today, Yesterday, Last Week and Month views. Make the selected date range explicit. Define whether Month means this calendar month or a rolling period; a custom range is a useful technical extension. Apply the selection consistently to cards and charts.

Implementation detail: use the event or venue timezone and label it. Separate booking-created dates from event dates where both reports are available.

**Demonstrate:** Switch between all four required periods and confirm that charts, totals and lists update together. Demonstrate records around midnight and at the start/end of the period.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 3 Scanned and used tickets
ID A1.3  |  Original request

**Review baseline:** Not visible in the reviewed analytics screens.

**Required behavior:** Display confirmed admission tickets and those actually used through a valid check-in scan. Track attendance for paid and free admission. The manager must be able to inspect an event’s attendance without mixing it with other events.

**Demonstrate:** Show a confirmed ticket before and after scanning. Scan the same entitlement again and show that attendance does not increase twice. For passes, demonstrate separate valid attendance for each included day.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 4 No shows
ID A1.4  |  Original request

**Review baseline:** Not visible in the reviewed analytics screens.

**Required behavior:** Show confirmed admission entitlements that were not used within their valid admission window. Before that window closes, label them Not Yet Scanned rather than final no-shows. Exclude cancelled, refunded or invalidated entitlements according to a documented rule.

Implementation detail: calculate no-shows per admission day/session. Do not subtract raw scan events from order totals; one order can contain several tickets.

**Demonstrate:** Close a sample admission window and reconcile used tickets plus eligible unused tickets to the confirmed eligible total. Show how a multi-day pass used on only one day is reported.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 5 Free and paid filters
ID A1.5  |  Original request

**Review baseline:** No free/paid analytics filter was visible.

**Required behavior:** Add All, Free and Paid filters. Free tickets and approved guest-list admissions must remain visible even though they generate no ticket revenue. Explain the classification of a paid product discounted to zero.

**Demonstrate:** Create paid, free and mixed-event data. Verify All equals the appropriate combined totals and that free attendance remains measurable after check-in.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 6 Tables and extras filters
ID A1.6  |  Original request

**Review baseline:** No product-category analytics filter was visible.

**Required behavior:** Allow All, Tickets, Tables and Extras views. For a pool party, 150 admissions, 12 VIP tables and 20 two-person sunbeds must be inspectable separately. Label product units, bookings and included people distinctly rather than adding them into an unexplained attendance total.

**Demonstrate:** Demonstrate category-specific booking quantities, revenue and attendance where an attendance method exists. Explain whether tables/extras are checked in separately or through the associated admission.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 7 Analytics for each event
ID A1.7  |  Review clarification

**Review baseline:** Not demonstrated. The current view appears too general.

**Required behavior:** Provide both a club overview across events and an event-specific analytics screen. Each event must show ticket quantities, scans, no-shows, free/paid breakdown, tables, extras and related receipts, using the same definitions as the overview.

**Demonstrate:** Open two different events, verify their separate data, then reconcile the club totals for the same period. Show how multi-day events can be inspected day by day.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A1 8 Attendance rates and reconciliation
ID A1.8  |  Technical recommendation

**Review baseline:** Not verified. This is an implementation recommendation supporting the requested analytics.

**Required behavior:** Add an attendance rate with its denominator clearly stated: attended eligible admissions divided by confirmed eligible admissions for the selected period/session. Keep gross sales, refunds, technical fees, commercial commissions and recipient proceeds distinguishable.

**Demonstrate:** Supply a small labelled sample dataset and expected totals. A zero denominator should display a meaningful empty value, and a refund or duplicate scan must not distort the report.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# A2 Ticket creation and booking products
The current ticket-tier form provides a name, group, price and capacity. VIP Modules also provide useful product fields. Complete the hierarchy and the purchase flow, and explain how each manager setting appears to customers. Use the Shotgun references for functional structure.
## A2 1 Multiple ticket types in one event
ID A2.1  |  Original request

**Review baseline:** Present in the reviewed form. End-to-end purchase remains unverified.

**Required behavior:** Retain multiple ticket types under one event and support paid tickets, free admission/guest list, multi-day passes, tables and other products as applicable. A manager must not need duplicate events just to offer these choices.

**Demonstrate:** Create and edit an event with multiple products; save, reopen and verify each product in the customer view and its corresponding booking record.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 2 Free tickets and guest lists
ID A2.2  |  Original request and review clarification

**Review baseline:** Partial. A Guest List management screen exists, but creating a bookable free list is unclear; a zero-price tier was rejected.

**Required behavior:** Provide an explicit Free Ticket or Guest List setup with its own quantity, availability and optional cutoff. Show Free or Free Guest List to customers. Distinguish instant confirmed free admission from a guest-list request requiring approval. Free and paid options must coexist, and closing the free list must not stop paid ticket sales.

**Demonstrate:** Configure both modes, submit an approval request, approve and reject separate requests, and verify that only confirmed admissions receive valid entry rights. Demonstrate continued paid sales after the free list closes.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 3 Discount codes and guest list access codes
ID A2.3  |  Original coupon request and review clarification

**Review baseline:** Not verified. Customer ticket selection and checkout were inaccessible.

**Required behavior:** Place promo-code entry clearly above ticket selection. Support discount use cases and define a separate guest-list invitation/access-code use case. Where approval is required, a valid code should create an inquiry for the club to accept or reject, rather than silently bypass approval.

Implementation detail: define eligible events/products, validity dates, usage limits, capacity effects and whether codes may be combined. Enforce limits on the server.

**Demonstrate:** Show a discount, an invalid/expired code and a guest-list code leading to Pending, Approved and Rejected outcomes. Confirm manager visibility of code usage.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 4 Passes valid across multiple days
ID A2.4  |  Original request

**Review baseline:** Not verified. No working multi-day entitlement was demonstrated.

**Required behavior:** For an event covering Friday and Saturday, offer a 2-Day Pass alongside Friday-only and Saturday-only admission. The pass must grant access on its stated days, not merely be a ticket with Pass in its name. Display valid dates in selection, confirmation and the ticket itself.

**Demonstrate:** Purchase all three options and verify admission on the correct days. Reject a Friday-only ticket on Saturday and allow the same multi-day pass once on each included day under the agreed re-entry rules.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 5 Separate sections for days and passes
ID A2.5  |  Original request

**Review baseline:** Not demonstrated. The section/tier hierarchy is unclear.

**Required behavior:** Use a parent section such as Friday, Saturday or 2-Day Pass, containing its own price tiers. For example, Friday may contain Super Early, Early and Regular; 2-Day Pass may contain Blind Pass, Early Pass, Standard Pass and Late Pass. Keep Tables as a separate customer section.

**Demonstrate:** Show the hierarchy in both event creation/editing and customer selection. A single-day ticket inside a multi-day event must clearly state the day it covers.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 6 Custom section names
ID A2.6  |  Original request

**Review baseline:** Partial. Group Name exists, but its purpose is unclear.

**Required behavior:** Allow managers to name the parent sections. Use clear field labels and helper text: a section groups products for a day or access type, while a tier is a priced quantity within that section. If Group Name and Tier Name already implement this, demonstrate their behavior and improve their wording.

**Demonstrate:** Create Friday, Saturday and 2-Day Pass sections; rename one without losing tiers, sales or the relationship between purchased tickets and valid dates.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 7 Preset and custom tier names
ID A2.7  |  Latest product clarification

**Review baseline:** Custom entry exists; preset lists were not visible.

**Required behavior:** Provide separate presets for tickets and passes plus a Custom option. Suggested ticket presets include Super Early, Early, Advance, Regular, Late and Super Late. Pass presets include Blind Pass, Early Pass, Standard Pass and Late Pass. The final vocabulary can be aligned consistently across the app.

**Demonstrate:** Create a ticket and a pass using presets, then a custom tier. Verify clear section names and consistent customer labels. The later review explicitly allows custom names; they are not deferred to a later phase.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 8 Price and quantity per tier
ID A2.8  |  Original request

**Review baseline:** Present in the reviewed tier form; inventory behavior is not yet verified.

**Required behavior:** Retain an independent price and quantity for every tier. Show managers the allocation, sold/reserved quantity and remaining quantity. Define what can be edited after sales start and preserve the price and terms of already purchased tickets.

**Demonstrate:** Configure 10 passes at EUR 33 and 40 at EUR 44 as an illustrative example. Save and reopen them, buy from a tier and confirm the inventory and original purchase price remain accurate.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 9 Automatic progression between tiers
ID A2.9  |  Original request

**Review baseline:** Not verified.

**Required behavior:** When the active tier sells out, make the next eligible tier purchasable automatically, up to the final tier. Clearly define the order and any start/end sale dates. Do not sell a later tier prematurely unless the manager deliberately selected a supported sales mode.

**Demonstrate:** Exhaust the first tier, verify the next tier becomes available, and show the all-sold-out state. Confirm that expired or manually closed tiers are not selected as the next available price.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 10 Dynamic starting price
ID A2.10  |  Original request and review clarification

**Review baseline:** Partial. From EUR 20 was visible on an event page, but the bottom Get A Ticket button lacked the starting price.

**Required behavior:** Calculate each section’s starting price from its lowest currently purchasable tier. Apply the correct event-level starting price to cards, the event page and the sticky ticket button, and update it after sell-out. Make it clear whether free admission is available and whether it requires approval; avoid presenting an unconfirmed guest-list request as guaranteed entry.

**Demonstrate:** Sell out the cheapest tier and confirm prices update across all customer surfaces. Verify free-and-paid events, temporarily unavailable tiers and the final Sold Out state.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 11 Residual capacity and venue limits
ID A2.11  |  Original request and product clarification

**Review baseline:** Not verified. No clear residual-capacity setting was shown.

**Required behavior:** Use the maximum capacity declared when the club is created as the ceiling. Allow manual tier allocations or a final tier based on the remaining capacity. For multi-day events, calculate availability for each day/session and ensure passes, day tickets, guest lists and tables cannot overbook the same admission capacity.

Implementation detail: specify whether a table/sunbed includes admission and how many people it reserves. Avoid double-counting those guests when they also have linked admission tickets.

**Demonstrate:** Demonstrate both allocation modes and a pass that consumes capacity on both days. Attempt to buy beyond the remaining capacity and show a controlled rejection.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 12 Tables with fixed prices
ID A2.12  |  Original request

**Review baseline:** Partial. VIP Modules expose starting price, guest capacity, quantity, area and extras, but customer purchase is unverified.

**Required behavior:** Expose Tables as a distinct section and allow named fixed-price table types with guest capacity, quantity, location/area and inclusions. Make the chosen table and total price clear before confirmation. Direct online payment is a proposed flow; confirm the selected payment approach in Q1.

**Demonstrate:** Create two table types, view them as a customer and complete the agreed reservation/payment flow. Verify table inventory, included guests, manager records and confirmation.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 13 Tables with starting prices
ID A2.13  |  Original request and open product decision

**Review baseline:** Partial. A starting-price field exists; the quote-to-booking journey is unclear.

**Required behavior:** Support generic table requests labelled Starting from when the final price depends on the request. Propose a tracked quote flow that records party size, offered price, inclusions, acceptance and the resulting booking. A reference price must not be mistaken for a confirmed final total.

**Demonstrate:** Demonstrate a request, quote, customer acceptance and confirmation, including a rejected or expired request. Address all payment/contact alternatives in Q1 before treating the flow as accepted.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 14 Special products and purchasable extras
ID A2.14  |  Original request

**Review baseline:** Partial. VIP Modules have extra fields, but their effect is unclear.

**Required behavior:** Support products such as a sunbed for two people without forcing them to appear as VIP tables. Distinguish included benefits from optional paid add-ons. Each purchasable extra needs a clear price, quantity/availability and association with a booking; descriptive text alone is not a purchasable extra.

**Demonstrate:** Create normal entry plus a two-person sunbed with an included bottle and an optional paid extra. Verify customer selection, total, inventory and the manager’s product breakdown.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 15 Optional ticket descriptions and terms
ID A2.15  |  Original request

**Review baseline:** Partial or not verified for ordinary tickets. Module descriptions exist.

**Required behavior:** Allow an optional description for every ticket/product explaining inclusions, exclusions, number of people and relevant admission conditions. Show it before booking. Managers must be able to leave it blank; this must not prevent creation.

**Demonstrate:** Show a two-person product with a bottle included, a normal ticket with conditions and a ticket without a description. Confirm the purchased terms remain available with the booking.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 16 Clear event pricing mode
ID A2.16  |  Review clarification

**Review baseline:** Partial. Event Price and Ticket Tiers coexist; help text says tiers override the event price.

**Required behavior:** Make the pricing choice explicit: single price, ticket sections/tiers, free admission, or a mixed configuration. Hide or disable irrelevant price fields and explain the active source of the checkout price. Free admission must remain compatible with paid products.

**Demonstrate:** Switch between supported modes, save and reopen the event, and verify that the customer is charged the intended price with no ambiguous fallback. Protect existing orders when configuration changes.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 17 Availability badges
ID A2.17  |  Review clarification

**Review baseline:** Exact remaining counts such as 100 left or 2000 left were displayed prominently.

**Required behavior:** Replace permanently exposed public stock counts with automatic availability badges where appropriate: Almost Sold Out, Last Tickets and Sold Out. Use configured thresholds and real inventory. Normal availability can show no badge. Managers should retain precise internal counts.

**Demonstrate:** Demonstrate normal availability, low stock and sold out. Show the thresholds and their behavior after inventory changes. Use Selling Fast only if it is supported by an actual sales-rate rule, not merely low stock.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 18 Optional modules during event creation
ID A2.18  |  Review clarification

**Review baseline:** VIP Modules, Guest List, Hosts and Quotes appear after creation; some add/edit paths were unclear or unusable.

**Required behavior:** Make optional modules accessible during event setup or clearly signpost them with wording such as You can configure this after creating the event. Explain required versus optional settings. Verify creation, editing, saving and reopening for every exposed module.

**Demonstrate:** Create an event with optional products and another without them. Add a module afterward, edit it and confirm the customer result. Explain the distinct purposes and expected sizes of Thumbnail Image and Event Image.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 19 Hosts and Quotes workflow
ID A2.19  |  Review clarification

**Review baseline:** Screens exist, but their roles and editable actions are unclear.

**Required behavior:** Explain who Hosts are, what permissions they have and how they relate to inquiries, guest lists, tables or event management. Explain how Quotes are created, delivered, accepted/rejected and converted into reservations or payments. Do not leave visible screens with unusable actions.

**Demonstrate:** Supply a short navigation demonstration for each module, including create, edit and status changes. If a module does not belong in this flow, explain its purpose and present a clear proposed treatment rather than silently removing it.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## A2 20 Club association during creation
ID A2.20  |  Earlier review finding

**Review baseline:** An associated club was displayed while the form still instructed the user to create a club first.

**Required behavior:** Resolve inconsistent associated-club validation and messaging. Show the selected club and its relevant capacity. Distinguish manager-owned venue selection from organizer collaboration and manually entered unregistered venues.

**Demonstrate:** Create and edit an event with an existing club, then test a manager without a club. Verify that messages and available actions match the actual account state.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# B1 City selection and event discovery
The location selector must drive discovery consistently. A location filter alone does not replace a visible city selector on Home and Explore, or a chronological event feed.
## B1 1 Visible searchable city selector
ID B1.1  |  Original request

**Review baseline:** Not visible at the top of Home or Explore during the review.

**Required behavior:** Place a searchable city/location selector in the top navigation of Home and Explore. Persist the selected city while moving between screens. Selecting a city must not depend on granting GPS permission.

**Demonstrate:** Search and select two supported cities, move between Home and Explore, then reopen the app and verify the intended persistence behavior.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B1 2 Adjustable search radius
ID B1.2  |  Original request and review clarification

**Review baseline:** No distance slider was visible.

**Required behavior:** Add a distance radius slider around the selected city, adjustable up to approximately 40–50 km. Show the current value clearly; 10, 20, 30, 40 and 50 km are suitable illustrative steps. Apply it consistently to event results and the map.

**Demonstrate:** Reduce the radius from 50 to 20 km and verify that results and counts change correctly. Include events just inside and just outside the selected boundary.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B1 3 Empty results and city availability
ID B1.3  |  Original request

**Review baseline:** Not verified.

**Required behavior:** When no events match the city, distance or filters, show a meaningful empty state and ways to change the search. Distinguish no matching events from a loading/network error. Make the handling of cities not yet launched explicit.

**Demonstrate:** Select a city with no events, apply an over-restrictive filter and trigger a network error. Confirm each state is clear and does not silently replace the chosen city with unrelated events.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B1 4 Chronological Explore sections
ID B1.4  |  Original request and review clarification

**Review baseline:** Tonight Near You exists, but the requested Explore grouping was not evident.

**Required behavior:** Organize Explore into visible chronological sections such as Today, Tomorrow, This Weekend and Upcoming. Users should see day/date groups while scrolling without first opening filters. Keep the Tonight Near You homepage module as a complementary view.

**Demonstrate:** Show events across multiple days in chronological order. Define how overlapping labels such as Tomorrow and This Weekend avoid confusing duplication, and how overnight events are assigned to a date.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B1 5 Customer ticket categories
ID B1.5  |  Original request

**Review baseline:** Reported to exist in principle, but blocked by login and not tested.

**Required behavior:** Provide Future, Pending and Past ticket/booking lists. Distinguish a pending guest-list request from confirmed admission and from a payment still processing. Multi-day passes should remain findable while they are valid.

**Demonstrate:** After authentication is fixed, show a future paid ticket, a pending guest-list request, a current pass and a past ticket. Verify transitions and access to the relevant confirmation or entry code.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# B2 Contextual filters and map
The reviewed filters include Event/Club selection, date, location, price and rating. Preserve the useful controls while making categories relevant to the selected result type and completing map navigation.
## B2 1 Different filters for events and clubs
ID B2.1  |  Review clarification

**Review baseline:** Partial. The category list does not meaningfully adapt when Clubs is selected.

**Required behavior:** When Events is selected, show relevant event categories such as concert, festival, open air or warehouse. When Clubs is selected, show venue attributes and relevant proximity/style choices. Clear or translate filters that are incompatible with the new mode.

**Demonstrate:** Select event-specific filters, switch to Clubs and verify that irrelevant choices disappear without leaving hidden active restrictions. Switch back and confirm predictable behavior.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B2 2 Music and mood choices
ID B2.2  |  Original request and review clarification

**Review baseline:** Mood appeared to be optional free text; music quick filters need verification.

**Required behavior:** Offer understandable predefined mood choices and music genres through selectable controls and quick filter chips. Avoid requiring users to invent mood text. Keep manager tags and customer filters aligned so selecting a mood produces meaningful matches.

**Demonstrate:** Create tagged events, filter by their music and mood, and show relevant results. Demonstrate multiple selections and reset. Propose the initial shared vocabulary for review.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B2 3 Date shortcuts and ranges
ID B2.3  |  Original request

**Review baseline:** Date selection was reported to work well; the full set of shortcuts remains unverified.

**Required behavior:** Retain working date controls and include This Week, Next Weekend, a single date and a from–to range. Use consistent local dates between filters, Explore groups and event details.

**Demonstrate:** Test each shortcut and a date range crossing a month boundary. Confirm inclusion/exclusion of an overnight event and a multi-day event according to the documented rule.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B2 4 Price location rating and results count
ID B2.4  |  Original request and review clarification

**Review baseline:** Location, price and rating controls were reported as useful. A live matching-results count was not verified.

**Required behavior:** Keep these controls and show the count of matching events/clubs as filters change. Make active filters visible and easy to clear. Define how price filters handle free entry, paid admission, tables and starting prices.

**Demonstrate:** Combine filters and verify the displayed count matches the returned results, including zero results. Check free events and events whose cheapest tier sells out.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B2 5 Map quick filter chips
ID B2.5  |  Review clarification

**Review baseline:** Map exists; quick filters were missing.

**Required behavior:** Add a visible row of quick filter chips to the map and keep their state synchronized with list search. Use the same result type, city, radius, dates and category logic in both views.

**Demonstrate:** Apply a filter in the map and switch to the list, then reverse the sequence. Verify matching event/club sets, counts and active chips.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B2 6 Recenter and location accuracy
ID B2.6  |  Review clarification

**Review baseline:** Recenter was missing. A screenshot showed a result thousands of kilometres away, requiring investigation.

**Required behavior:** Provide Recenter to my location. Explain whether it changes only the map camera or also the search center; if it changes the search, update the visible location state. Handle permission denied/unavailable without breaking manual city search.

**Demonstrate:** Test allowed and denied location permission, recentering, manual city selection and distance display. Investigate the distant result without assuming the screenshot alone proves a calculation defect.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# B3 Homepage and artist discovery
The current Home includes trending events, Tonight Near You, popular clubs and VIP table deals. Complete location-based behavior and the requested discovery modules.
## B3 1 Homepage based on the selected city
ID B3.1  |  Original request

**Review baseline:** Not verifiable because the city selector was unavailable.

**Required behavior:** Make local homepage modules respond to the chosen city and radius. Preserve useful existing sections and ensure their labels reflect the location actually used. Changing cities should not leave stale cards from the previous city.

**Demonstrate:** Switch between two cities and verify trending events, nearby events, clubs and table offers update consistently, including loading and empty states.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B3 2 City specific trending sections
ID B3.2  |  Original request

**Review baseline:** A section such as Blowing Up in Paris was not visible.

**Required behavior:** Add a city-labelled trending module in the spirit of the Shotgun reference. Document the ranking signal and time window used so trending has a consistent meaning. The city name must come from the current location context.

**Demonstrate:** Show the section in two cities and explain the ranking with sample data. Where activity is insufficient, use a meaningful alternative or empty state rather than inventing popularity.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B3 3 Recently viewed and most viewed
ID B3.3  |  Original request

**Review baseline:** Neither requested module was visible.

**Required behavior:** Add compact Recently Viewed and/or Your Most Viewed modules as requested, without taking excessive space. Distinguish personal viewing history from a city-wide Most Viewed ranking if both are shown. Keep labels accurate and preserve the expected link back to each event.

**Demonstrate:** View several events, revisit one and return Home. Show the intended history/order, the behavior after a city change and the no-history state.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B3 4 Artist section photos and profiles
ID B3.4  |  Original request and review clarification

**Review baseline:** Lineup names can be entered, but photo upload and clickable profiles were not demonstrated.

**Required behavior:** Provide an Artists discovery section and let managers associate artists with an event, including a photo. Make artist names/photos clickable and show a profile with upcoming linked events. A profile can initially be generated and managed through manager/event data.

**Demonstrate:** Add an artist photo and link the same artist to two events. Open the artist from a lineup and verify both upcoming events appear without creating unnecessary duplicate profiles.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## B3 5 Follow artists and account ownership
ID B3.5  |  Original request with open implementation detail

**Review baseline:** Following was not available in the reviewed flow; artist login is unclear.

**Required behavior:** Allow users to follow/unfollow artists and persist that state. Confirm whether separate artist accounts exist or are planned and who can edit a profile. An independent artist account is not a prerequisite for the initial manager-maintained profile and follow flow.

**Demonstrate:** Follow an artist, reopen the app, verify the state and unfollow. Supply the profile-edit permission rule and proposed ownership/claim approach if artist accounts are supported.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# C Event organizers
Organizer access and flows have not been demonstrated. Mark these items Not Verified until working access and evidence are provided. They cannot be accepted through a general statement that the project is complete.
## C1 Organizer role and event management
ID C1  |  Original request

**Review baseline:** Not verified. No organizer test account or walkthrough was supplied.

**Required behavior:** Provide an organizer role with manager-like event creation and management. Organizers must be able to configure their events and inspect ticket sales/attendance relevant to their own events, with permissions appropriate to their relationship with the venue.

**Demonstrate:** Provide an organizer account, create/edit an event and show organizer analytics. Explain which settings require venue approval and verify that other organizers’ records are inaccessible.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## C2 Registered venue collaboration
ID C2  |  Original request

**Review baseline:** Not verified.

**Required behavior:** Let an organizer search/select a registered club and send a hosting/collaboration request. The club can accept or reject it. Show the request status and define when the event can be published or sold. After approval, associate the event with both organizer and club profiles.

**Demonstrate:** Show submission, Pending, acceptance and rejection. Confirm that an unapproved collaboration is not displayed as venue-approved, and that acceptance produces the intended event association and permissions.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## C3 Organizer profile and attribution
ID C3  |  Original request

**Review baseline:** Not verified.

**Required behavior:** Provide organizer name, follow button and follower count, description, base city, website, tags and social links such as Instagram, Facebook and SoundCloud. Event pages must show Organized by with a clickable organizer identity and the venue/club identity.

**Demonstrate:** Open the event from both profiles, follow/unfollow the organizer and test the website/social links. Verify that the correct organizer and venue are shown throughout the booking journey.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## C4 Unregistered venues and authorization
ID C4  |  Original request with open implementation decision

**Review baseline:** Not verified.

**Required behavior:** Allow manual venue entry when a club is not on the platform. Explain that the organizer must be authorized to hold the event there. Capture the agreed declaration/authorization process and distinguish the manually entered venue from a verified registered club. For this flow, the proposed recipient is the organizer only, subject to the selected payment setup.

Recommended recordkeeping: retain the accepted text/version, account, timestamp and review result. A disclaimer alone must not be treated as evidence that the venue granted permission.

**Demonstrate:** Demonstrate manual entry, required acknowledgement/evidence, event review and organizer payout setup. Answer Q4 about the exact permission evidence, acceptance wording and review procedure.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## C5 Organizer and venue payout modes
ID C5  |  Original request and product preference

**Review baseline:** Not verified.

**Required behavior:** Prefer automatic allocation between organizer and club when the provider and account setup support it. Also address the alternative in which the club receives payment and settles with the organizer under their agreement. For an unregistered venue, use the organizer-only route described in C4.

Implementation detail: no provider, custody model, split capability or payout timing is assumed by this document. State restrictions and the treatment of failed payouts, cancellations and refunds.

**Demonstrate:** Present the supported modes and demonstrate one sample order for each supported route, with gross amount, fees, commissions and recipient proceeds. Answer Q3 before fixing the production payout model.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## C6 Organizer inquiries and operational statuses
ID C6  |  Review clarification and implementation detail

**Review baseline:** Not verified. Club-side inquiry screens exist but their relationship to other flows is unclear.

**Required behavior:** Document where guest-list requests, collaboration requests and table quotes appear, which role can act on them and which state changes notify the customer or partner. Distinguish these request types even if they share an Inquiries area.

**Demonstrate:** Show one request of each supported type through its complete lifecycle. Confirm that approve/reject actions are permission-controlled and do not create duplicate bookings or payouts.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# D Public event page
Several public-page elements were visible, including the cover, event name, date, description, lineup, share and favorite controls. Retain them and complete the missing interactions and location block.
## D1 Event identity and essential content
ID D1  |  Original request

**Review baseline:** Partially visible; organizer links, full address and complete dates need verification.

**Required behavior:** Show cover, title, organizer/club, start and end dates/times, city and street address, description and lineup. Add clear mood tags. For multi-day events, display the overall dates and distinguish the dates covered by each ticket.

**Demonstrate:** Review a club event, an organizer collaboration and a multi-day event. Verify that all links and labels identify the right venue, organizer and local event times.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## D2 Share and favorites
ID D2  |  Original request

**Review baseline:** Share and the lower-left favorite control were visible; behavior still needs testing.

**Required behavior:** Retain sharing and adding/removing favorites. Ensure shared links resolve to the correct event and returning from authentication preserves the intended action.

**Demonstrate:** Share an event, open its link, save it as a favorite, reopen the app and remove it. Show appropriate behavior for a cancelled or unavailable event.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## D3 Interested button and counter
ID D3  |  Original request with confirmed launch decision

**Review baseline:** Not visible in the reviewed screen.

**Required behavior:** Launch Interested and the interested-person count immediately. Count real user actions and prevent the same user from inflating the total through repeated taps. The earlier idea of seeded/random counts is not used in this specification. The visibility of a named interested-users list is addressed in Q6.

**Demonstrate:** Mark and unmark interest with test accounts. Confirm the counter updates accurately, survives reopening and does not double-count retries or repeated taps.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## D4 Location block and Google Maps
ID D4  |  Original request

**Review baseline:** Bottom location block and external map action were missing.

**Required behavior:** Add a location section near the bottom of the event page with venue name and full address. Tapping it should open the correct destination in Google Maps, with a usable browser fallback if the app is unavailable.

**Demonstrate:** Test a registered venue and a manually entered venue. Confirm the destination matches the displayed address and does not merely open a generic city search.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## D5 Ticket button and selection continuity
ID D5  |  Original request and review clarification

**Review baseline:** Get A Ticket was visible, but lacked the starting price; the next screen could not be fully tested.

**Required behavior:** Show a clear bottom purchase action with the current starting price and connect it to the event’s sections and tiers. Preserve the chosen event and products through login. Use clear actions for free requests, paid purchases, table inquiries and sold-out events.

**Demonstrate:** Open the same event before and after the cheapest tier sells out; verify the button and selection screen agree. Log in during purchase and confirm the selection remains correct.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# E Checkout technical fees and commercial commissions
Customer checkout and admin commission configuration could not be tested. These are core delivery items. Provide working access and transaction examples instead of treating lack of visibility as completion.
## E1 Complete customer checkout
ID E1  |  Original request and verification requirement

**Review baseline:** Not verified because login blocked the customer journey.

**Required behavior:** Demonstrate booking for paid admission, confirmed free entry, approval-based guest lists, multi-day passes, fixed-price tables and the agreed quote/deposit flow. Present the selected product, dates, people/quantity, price, applicable charges and final total before confirmation.

**Demonstrate:** Supply end-to-end recordings and test records for each supported product. Show pending, successful and failed outcomes, confirmation and access to the booked ticket/product. A failed payment must not issue a valid paid admission.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## E2 Customer technical fees
ID E2  |  Original request and latest clarification

**Review baseline:** Not verified. Calculation and cost coverage are unresolved.

**Required behavior:** Show the customer the ticket price, clearly disclosed technical/service fees and final total. The intended technical fee covers payment/transaction costs rather than being the platform’s commercial earnings. The latest clarification places technical fees on tickets. Specify the formula, payer, rounding, payment-method variation and refund behavior in Q2.

Implementation detail: do not promise exact cost recovery without a defined formula. Decide explicitly whether any technical charge applies to tables/extras; do not silently generalize the ticket rule.

**Demonstrate:** Provide worked examples for the supported payment methods and order sizes, including a free ticket. Reconcile the displayed fee with the configured rule and demonstrate how provider-cost differences are handled.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## E3 Admin commission configuration
ID E3  |  Original request with an open applicability decision

**Review baseline:** Not verified. Admin access and settings location were not supplied.

**Required behavior:** Give authorized admins configurable commercial commissions as a percentage or fixed amount, by client/client type, event/event type and product category. The system must support tickets, tables and extras as described in the original PDF. The latest discussion emphasizes tables, sunbeds and extras; confirm ticket applicability in Q2 rather than removing it silently.

**Demonstrate:** Provide admin navigation and demonstrate a percentage rule, a fixed rule and a specific override. Show the commission impact in internal reporting without exposing the internal commercial split to the customer.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## E4 Separate fees and financial reporting
ID E4  |  Original request and implementation detail

**Review baseline:** Not verified.

**Required behavior:** Keep technical fees and Bookdia Night commercial commissions as separate accounting/reporting components. Internal commissions must not be labelled as technical transaction costs. Customer-facing prices and charges must remain transparent, while the internal division between platform, organizer and club stays in authorized reporting.

**Demonstrate:** Show an order-level breakdown of product value, discounts, customer charges, provider costs, refunds, commercial commission and recipient proceeds. Identify any tax treatment still awaiting a decision rather than inventing rates.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## E5 Rule changes and order history
ID E5  |  Original request and technical recommendation

**Review baseline:** Not verified. The owner requires the ability to change commission settings.

**Required behavior:** Allow commission changes with effective dates and clear precedence between general rules and client/event/product overrides. Preserve the applied rule and amounts on an existing order. New settings must not silently rewrite completed orders or settled payouts.

**Demonstrate:** Create an order, change the commission and create another. Demonstrate correct before/after treatment and a record of who changed the rule and when. Confirm the commission base, payer and settlement timing through Q2.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## E6 Payment refunds and payout reconciliation
ID E6  |  Verification requirement and technical recommendation

**Review baseline:** Not verified.

**Required behavior:** Demonstrate cancellations and full/partial refunds for the supported product and payout flows. Define whether fees and commissions are returned, how admission is invalidated and how inventory is released. Handle payment notifications/retries without issuing duplicate tickets or duplicate financial entries.

Implementation detail: validate provider notifications server-side and make repeated operations safe. Store provider references with the order; use the provider’s supported payment components rather than storing raw card data.

**Demonstrate:** Repeat a payment notification, interrupt a payment, refund a booking and simulate a payout problem. Show one consistent order history and explain the remaining obligations of each recipient.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
# T Implementation checks across the app
These technical recommendations make the requested behavior testable. They do not prescribe a framework or payment provider. Explain the implementation used, or propose an equivalent that meets the acceptance outcome.
## T1 Inventory reservations and concurrent purchase
ID T1  |  Technical recommendation

**Review baseline:** Not tested.

**Required behavior:** Use a consistent server-side inventory source for tiers, day capacity, passes and reservable products. If checkout temporarily holds stock, define expiry and release rules. Recheck availability during confirmation so simultaneous buyers cannot both consume the final unit.

**Demonstrate:** Run two purchases against the final available entitlement and show that only one confirms. Test expiry, cancellation and refund release, including passes that consume multiple day allocations.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## T2 Entry validation and pass scanning
ID T2  |  Technical recommendation

**Review baseline:** Not tested.

**Required behavior:** Associate entry credentials with valid confirmed entitlements. Validate event, day/session, cancellation/refund status and previous use. Record who scanned and when. Define re-entry policy explicitly. If offline scanning is supported, document synchronization and duplicate-use limitations.

**Demonstrate:** Test a valid ticket, wrong day, wrong event, duplicate scan, refunded ticket and multi-day pass. Show the resulting attendance counts and a clear operator message for each outcome.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## T3 Consistent entities and permissions
ID T3  |  Technical recommendation

**Review baseline:** Not tested.

**Required behavior:** Keep explicit relationships between venue, event, day/session, section, tier, product, order, attendee/entitlement, scan and payout. Reuse stable artist and organizer identities. Apply authorization on the server for viewing or changing these records.

**Demonstrate:** Provide a concise data relationship explanation and test cross-account access attempts. Confirm that changing a display name does not break existing tickets, linked profiles or financial history.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## T4 Timezones and lifecycle changes
ID T4  |  Technical recommendation

**Review baseline:** Not tested.

**Required behavior:** Use consistent event-local dates and unambiguous stored timestamps across discovery, checkout, ticket validity, analytics and payouts. Define how cancellation, rescheduling and venue changes affect sold tickets, customer notices, counters and linked profiles.

**Demonstrate:** Test an overnight event and a daylight-saving boundary where relevant. Reschedule or cancel a test event and show the resulting customer and manager states without losing the original transaction history.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]
## T5 Release evidence and recoverable errors
ID T5  |  Verification requirement

**Review baseline:** No consolidated evidence for every requirement has been supplied.

**Required behavior:** Identify the test build, environment and roles used in every demonstration. Provide clear loading, empty, error and retry states for critical flows. Record enough diagnostic detail to reproduce failures while keeping sensitive credentials and personal data out of evidence shared in this document.

**Demonstrate:** Run the acceptance scenarios in the final section, link each result to its requirement IDs and reopen failed items with reproduction steps. Resolve critical access, purchase, inventory and payout defects before sign-off.

Developer status: Pending   |   Completed: [YYYY-MM-DD]   |   Developer: [name]

Implementation and evidence: [Describe changes, screens, build and proof; expand as needed.]

Owner verification: Not tested   |   Verified on: [date]   |   Result notes: [enter here]

# Open decisions and required answers
These points must be answered explicitly. Keep the confirmed direction in place while the development team explains feasibility and the owner selects any unresolved commercial or product rule. A proposal is not an approved configuration.
## Q1 Table payment and partner contact
Linked items: A2.12, A2.13, A2.19 and E1.

**Confirmed direction and options:** Fixed-price tables should have a clear bookable total; generic tables should show Starting from and use a tracked request. Present the following alternatives and recommend a practical default: full online payment; deposit with clear balance/cancellation terms; card guarantee or authorization where supported; a quote/request handled by an in-app intermediary or an assigned platform partner. If WhatsApp is used, explain who owns the number, how the partner is assigned, how the request and confirmed sale are tracked, and how the platform’s commercial attribution is retained. Direct untracked venue contact does not address the concern about losing table bookings.

**Answer required:** State provider support and limits, authorization duration if relevant, when money is collected, expiry/cancellation/no-show rules, customer consent, commission treatment and conversion from quote to confirmed booking. Do not assume that entering a card automatically authorizes an arbitrary future charge.

Developer proposal and evidence: [enter response]

Owner decision: Pending   |   Decision date: [date]   |   Approved rule: [enter here]
## Q2 Technical fee and commission policy
Linked items: E2 to E6.

**Confirmed direction and options:** Technical fees are intended for ticket transaction costs. Commercial commissions are configurable and were originally requested on tickets, tables and extras; the latest clarification specifically emphasizes tables, sunbeds and extras. Confirm whether commercial commission also applies to tickets. Keep the configuration capable of the original product categories while this point is decided.

**Answer required:** Provide a product-by-product matrix stating the customer technical fee, commercial commission, payer, percentage/fixed formula, calculation base, discount/tax/refund treatment, minimums/rounding, rule precedence and effective date. Supply worked examples and identify who validates accounting/tax treatment. Explain whether non-ticket transactions have a technical charge, how free bookings are handled and how actual provider costs are reconciled.

Developer proposal and evidence: [enter response]

Owner decision: Pending   |   Decision date: [date]   |   Approved rule: [enter here]
## Q3 Organizer payout architecture
Linked items: C4, C5 and E6.

**Confirmed direction and options:** The preferred route is an automatic organizer/club allocation. Also present the alternative where all proceeds go to the club and the club settles with the organizer. When the venue is unregistered, the proposed route pays the organizer only.

**Answer required:** Name the payment provider and supported account arrangement, identify who sells to the customer and receives each payment, list onboarding requirements, define split rules and payout timing, and explain refunds, failed payouts and disputes. Clarify whether both registered-venue modes can be configured and how their reporting differs. Do not assume Bookdia Night can hold funds or that split payments are available without checking the provider arrangement.

Developer proposal and evidence: [enter response]

Owner decision: Pending   |   Decision date: [date]   |   Approved rule: [enter here]
## Q4 Authorization for manually entered venues
Linked items: C4 and C6.

**Confirmed direction and options:** Organizers must be authorized to hold the event at an unregistered venue. The app should capture a clear acknowledgement and an appropriate permission/review process rather than relying on an unexplained disclaimer.

**Answer required:** Propose the evidence required, exact acceptance text for legal review, the person responsible for checking it, publication conditions and the handling of rejection or a venue dispute. Specify stored evidence/version/timestamp and how a manual venue is distinguished from a registered/verified club. Final legal wording requires the appropriate business/legal review.

Developer proposal and evidence: [enter response]

Owner decision: Pending   |   Decision date: [date]   |   Approved rule: [enter here]
## Q5 Capacity and admission rules
Linked items: A1.3 to A1.8, A2.2, A2.11, T1 and T2.

**Confirmed direction and options:** Managers may allocate tier capacities manually or use residual venue capacity. A pass consumes the applicable admission capacity on each included day. Free admission, table guests and product bookings need consistent treatment.

**Answer required:** Document the event/day capacity formula, when pending guest-list requests or quotes reserve stock, checkout hold expiry, included versus additional admissions for tables/sunbeds, re-entry and duplicate-scan policy, cancellation/refund release, and when a no-show becomes final. Provide a numerical multi-day example showing that no category double-counts or overbooks the same people.

Developer proposal and evidence: [enter response]

Owner decision: Pending   |   Decision date: [date]   |   Approved rule: [enter here]
## Q6 Remaining profile and discovery choices
Linked items: B1 to B3, D3 and A2.19.

**Confirmed direction and options:** The city selector, artist profiles/following and Interested counter are required. The review also mentions an interested-people list, while the precise visibility and profile behavior have not been defined. Artist account ownership and the roles of Hosts/Quotes need a clear explanation.

**Answer required:** Confirm the maximum radius and available steps; initial music/mood vocabulary; meaning/ranking of Most Viewed and trending; whether and to whom an interested-people list is visible; artist editing/account ownership; and the operating roles of Hosts and Quotes. Recommend a clear default for each unresolved choice and identify any dependencies without delaying already-defined behavior.

Developer proposal and evidence: [enter response]

Owner decision: Pending   |   Decision date: [date]   |   Approved rule: [enter here]

# Acceptance scenarios
Run these scenarios against the delivery build and link the evidence to the requirement IDs. Use labelled test data. These scenarios complement the per-item demonstrations; passing one scenario does not close unrelated requirements.
## V1 Registration and access
P0.1 to P0.4

Create and recover customer access; verify date picker, Google, Apple and OTP; open all four test roles and resume a booking after login.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V2 Paid ticket and tier progression
A2.1, A2.5 to A2.10, A2.17, D5, E1

Configure two tiers; buy the final item in the cheaper tier; confirm that the next tier, starting prices, badges and final checkout total update.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V3 Free entry and guest list codes
A2.2, A2.3, B1.5, C6

Book instant free entry and request approval through a guest-list code. Approve one request and reject another; verify tickets, pending lists, capacity and continued paid sales.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V4 Multi day pass and capacity
A2.4, A2.11, T1, T2

Offer Friday, Saturday and a 2-Day Pass. Reserve capacity per day, scan the pass on both days and reject the wrong day/duplicate use. Test concurrent demand for the final entitlement.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V5 Tables sunbeds and extras
A2.12 to A2.15, A2.18, A2.19, Q1

Purchase a fixed-price table, request a variable-price table and book a two-person sunbed with a paid extra. Verify quantities, included guests, terms and tracked quote conversion.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V6 Cities filters and map
B1.1 to B1.4, B2.1 to B2.6, B3.1, B3.2

Change city and radius; switch Events/Clubs; apply dates, music, mood and price; verify counts and map/list agreement. Deny GPS, recenter and test empty results.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V7 Profiles and public interaction
B3.3 to B3.5, C3, D1 to D4

View history; open and follow an artist/organizer; share/favorite an event; add/remove interest; open its correct Google Maps location.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V8 Organizer collaboration
C1 to C6, Q3, Q4

Request a registered venue’s approval and test acceptance/rejection. Create a manually entered venue with the agreed authorization process and demonstrate the configured payout routes.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V9 Fees payment and refunds
E1 to E6, Q2, Q3

Compare the customer total with internal fee/commission/payout records. Change an admin rule, preserve the earlier order, retry a notification and run full/partial refunds.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]
## V10 Analytics and release checks
A1.1 to A1.8, T3 to T5

Reconcile the above orders and scans at club and event level using each date/product/free-paid filter. Check no-shows after closure, role isolation and event lifecycle changes.

Test result: Not run   |   Build and date: [enter]   |   Evidence and defects: [enter]

# Crosswalk from the earlier Word
Use this mapping when carrying over developer notes from the earlier Development Review and Tracker. The broader items in that version are expanded here so each behavior can receive a separate response. A prior completion claim must be checked against every linked requirement.

| **Earlier Word item** | **Expanded requirements** |
| --- | --- |
| P0.1 Authentication | P0.1 to P0.4 |
| A1.1 Analytics | A1.1 to A1.8 |
| A2.1 Categories and templates | A2.1, A2.5, A2.6, A2.7 |
| A2.2 Multi-day passes | A2.4, A2.5, A2.11, T2 |
| A2.3 Pricing and stock | A2.8, A2.9, A2.10, A2.17, T1 |
| A2.4 Venue capacity | A2.11, Q5 |
| A2.5 Free entry and promo codes | A2.2, A2.3, C6 |
| A2.6 Tables and products | A2.12 to A2.15, Q1 |
| A2.7 Creation and management | A2.16, A2.18, A2.19, A2.20 |
| B1.1 City and radius | B1.1, B1.2, B1.3 |
| B1.2 Chronological discovery | B1.4, B1.5 |
| B2.1 Contextual filters | B2.1 to B2.4 |
| B2.2 Map | B2.5, B2.6 |
| B3.1 Dynamic homepage | B3.1 to B3.3 |
| B3.2 Artists | B3.4, B3.5 |
| C1 Organizer collaboration | C1, C2, C3, C6 |
| C2 Unregistered venues | C4, Q4 |
| C3 Payouts | C5, E6, Q3 |
| D1 Event page | D1 to D5 |
| E1 Checkout and fees | E1, E2, E4, E6, Q2 |
| E2 Admin commissions | E3, E4, E5, Q2 |
# Delivery record and owner acceptance
Please return this document with every requirement response completed, Q1 to Q6 answered, and the demonstrations attached or linked. Retain the IDs and recorded history when issuing a new build.

| **Delivery field** | **Entry** |
| --- | --- |
| Build and environment | [enter version and environment] |
| Delivery date and developer lead | [enter date and name] |
| Requirement completion summary | [enter IDs completed, still open and blocked] |
| Open decisions | [enter Q IDs awaiting owner response] |
| Test access | [enter role access instructions; share credentials privately] |
| Evidence location | [enter accessible folder or recording links] |
| Known limitations and defects | [enter exact IDs, impact and next action] |
| Owner review date | [enter date] |
| Owner result | Not tested / Passed / Failed / Accepted items only |
| Accepted requirement IDs | [list IDs verified by the owner] |
| Items reopened after review | [list IDs and reproduction details] |
## Completion rule
A developer status of Completed means the implementation is available with evidence. Owner acceptance requires a successful retest of the required behavior. Any item blocked by authentication, missing permissions, unresolved payment rules or unavailable evidence remains open until it can be verified.

Please do not return the product with a single statement that everything is done. Explain what has been delivered for each point so that the next review can resolve the remaining work without repeating the same discussions.
