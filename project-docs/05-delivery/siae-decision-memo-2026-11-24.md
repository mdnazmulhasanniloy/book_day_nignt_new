# Decision memo: admission tickets for events in Italy

Prepared 24 November 2026. Source: `01-discovery/client-answers-02.md`, sections 5, 7 and 8. This is a decision memo, not legal advice. Facts about SIAE rules, certification and fiscal systems are **not verified by us** and must be confirmed with the client's adviser and the ticketing provider. We assert no legal conclusion here.

## The question

For covered Italian events, a QR code generated from a Bookdia booking ID alone does not establish that a fiscal admission ticket was issued (answers-02, section 7). Stripe records the payment only. We need to know who issues the admission on behalf of the organizer, which approved system does it, and how the door validates it. The music licence and royalties are a separate organizer and adviser workstream. No fiscal ticketing partner has been selected. The client wants a decision memo before any paid work, and says development may proceed in test mode, with real Italian admission sales enabled only on the approved route.

## What we know from the client's answers

- One QR per guest journey is wanted. The app shows the admission, and the door scan is validated in the appropriate system.
- Payment, fiscal issue, admission and partner payout are independent states. A payout pending until event end plus three days must never leave a paid admission pending.
- Do not deliver an active QR until issue is confirmed. One stable request key per ticket. After a timeout, query the issuer before retrying. A duplicate payment notification must never issue two tickets. Unresolved paid orders go to a reconciliation queue and end in delivery or refund.
- Refunds: fiscal cancellation, QR invalidation, Stripe refund, inventory release and commission reversal must be linked and tracked, with the original IDs and reasons kept.
- Evidence the client expects: sample ticket, duplicate-scan result, cancellation receipt, event-end report and reconciled settlement for a pilot venue, plus a failed issuance after payment, a refunded ticket in a two-ticket order and a multi-day pass.
- Preferred partner model: zero fixed or minimum fees.

## Options

| | A. Integrate an approved partner | B. Build a Bookdia fiscal system | C. Keep Italian sales off for now |
|---|---|---|---|
| What it needs | Approval reference and supported system version; sandbox, technical specifications, sample fiscal ticket and event report; mapping of organizer, venue, event, date, sector and ticket category to the partner's IDs; written confirmation that the Bookdia scanner may act as a client of the approved access-control system, or use of the approved reader on the same credential | A fiscal issuance and access-control module with ticket generation and fiscal seal, smart-card integration, protected records, signed reports, cancellation records; a test card; a certification scope agreed with an eligible assessor; technical documentation; a conformity certificate; application to the Italian Revenue Agency; production activation | Nothing for Italy. Other markets proceed. Italian events can be listed, but admissions are not sold in the app |
| Engineering days (rough estimate, to be confirmed with the provider; not a fact until the provider confirms) | 15 to 30 (rough estimate, to be confirmed with the provider), depending on the partner's interface | 80 to 150 or more (rough estimate, to be confirmed with the provider), plus assessor and certification work we cannot size | 0 |
| Calendar dependencies | Partner choice, contract, sandbox access, pilot venue; start to first real sale likely months | Certification, test card, Revenue Agency application; likely the longest | None |
| External fees | Unknown, to be quoted: setup, minimums, recurring charges, charges per paid ticket, per complimentary ticket and per cancellation | Unknown: assessor, certification, card, ongoing operation | None |
| Maintenance | Partner interface changes, outage and offline rules, event reports | Ongoing compliance, reporting, certificate renewals | None |
| Responsible party | Partner issues; organizer remains the party of record unless the adviser says otherwise (unverified) | Whoever owns and operates the approved system (to be confirmed: Bookdia or another entity) | Client |
| Main risks | Partner cannot support Bookdia's own payments, tables with several guests, guest-list reservations or multi-day passes; scanner not accepted; fees above the client's preference | Time, cost and regulatory risk; hard to finish before launch | Lost Italian revenue; the client must accept that Italian cities launch without ticket sales |

## Recommendation

Start with **C for real sales and A for test mode**: keep Italian sales off until a route is approved, ask two or three providers for sandbox, specifications and a quote, and do not start B before a cost and responsibility decision. B is a separate project of its own and cannot be sized responsibly yet.

## What we can do now in test mode, without approval

All of this is generic and does not depend on the route: separate states for payment, issue, admission and payout; one request key per ticket; query-before-retry on timeout; the reconciliation queue for paid orders without a confirmed issue; QR delivery only after confirmed issue; fiscal cancellation as a step of the refund flow. These sit inside the refund and scanning work already planned and add no new task until the route is chosen. We cannot test against a real issuer without a sandbox.

## What we need from the client

1. The decision-maker and the date for the decision (question 5 of the clarification document).
2. Which provider or providers to approach, or permission for us to contact them.
3. The adviser's answers on: who is the issuer and the organizer of record for each Italian sales route; whether the Technical Fee falls within the advance-booking rights of the applicable permit; who holds the music licence; which receipts enter the calculation; how complimentary admissions at a paid event, free-entry events, table guests and guest-list QR codes are treated.
4. Written confirmation of cost responsibility for non-recoverable issuance costs on cancellation, and whether the issuance cost is included in the customer Technical Fee (answers-02, section 8 allows it).

## Status of work

There are **no build tasks** for Italian fiscal ticketing and none will be created until the client approves scope and cost in writing. The estimate for option A is a rough range only and is listed in the scope and timeline document as "to be confirmed after provider answers". No SIAE rule in this memo has been checked by us.
