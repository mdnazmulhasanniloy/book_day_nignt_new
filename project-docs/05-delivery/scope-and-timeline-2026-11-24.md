# Bookdia Night: scope and timeline

Prepared 24 November 2026, after your answers of the same date.

This document replaces the target dates we had so far. It says what is already built, what is still to build, what is new, how long each piece takes, and when we propose to deliver. The dates are proposals for your review. Nothing in sections 3 and 4 starts until you confirm it (see section 6).

**In one paragraph.** A usable build for your testing is realistic around **21 December 2026**. It will contain the work that is already finished, the security fixes, the new discovery screens in the app, and the approval step for new club owners and organizers. The full launch scope you asked for needs about 115 days of work in total. Our team is one developer for the server and the admin dashboard and one developer for the app, each working with Claude. With that team, the fees and the price calculated by the server are ready around **10 February 2027**, the whole launch scope is ready for your final testing around **27 April 2027**, and a launch candidate is realistic around **7 May 2027**. An early-January launch is not realistic for this scope. With a second server developer the launch candidate moves to about the end of February 2027, and with a second app developer as well to about the beginning of February; every 5 days of work you move out of the launch list brings the date forward by about a week. The Italian ticketing question and the market-by-market tax setup are separate pieces of work that we cannot date until you decide (section 4).

Days below are working days of one person. The figures include a 30% allowance for fixing and retesting. They cover the server, the admin dashboard and the app together. All estimates in this document are our own rough estimates; the ones in section 4 are not fixed until you decide and, where a provider is involved, until the provider confirms.

---

## 1. What is already built (original scope)

These items from your review tracker of 6 November are finished and tested on our side. They are not yet live: they go out in the releases of section 5, each only after your written approval.

- Security fixes: password and reset protection, protected media upload, safe webhook handling.
- Clear error messages for the door scanner, admin and owner screens.
- Ticket types with presets, free tickets, promo-code protections, guest-list duplicate protection.
- Sold-ticket counts that no longer grow with unpaid checkouts, and the 15-minute checkout hold.
- Discovery: city list, search distance from 10 to 50 km (30 km first), day grouping, date ranges, genre and mood filters with your lists, map, Interested count, recently viewed, most viewed, trending, artist pages, and the extra event-page details.
- My tickets split into future, pending and past.
- Automated tests and a continuous check that runs on every change.

## 2. Original scope still to build

| Item | Days |
|---|---|
| Customer fee and club commission rules with start dates, admin screens, financial report | 5 |
| Organizer profile, following, collaboration requests, extra items, quotes with sign-in | 8 |
| Owner analytics (club and per event), earnings with tables, refund notifications, admin orders | 5 |
| Admin dashboard pages for cities, genres and moods, artists, organizers, pricing, orders, refunds | 6 |
| **Subtotal** | **about 24** |

## 3. Added by your answers, planned for launch

You asked for these in your answers of 22 and 24 November and marked them "Launch". They go beyond the first tracker, so we give an estimate for each. As you asked, scheduling a feature is not approval of extra charges: please confirm the list below before we commission it.

| Feature | Days | What it covers |
|---|---|---|
| Approval of new club owners and organizers | 4 | New owners wait for approval and see only the club area; existing clubs keep access; admin approval queue |
| Price calculated by the server, fee display, update gate | 8 | 5% plus 0.50 booking fee and the club commission rates by country and category; one correct total in every checkout; the app asks users to update when needed |
| Team roles and permissions | 10 | Owner, General Manager, Event Manager, Reservations Staff, Organizer, plus Platform Admin, Manager, Country Manager and Staff, with an editable permissions page |
| Table requests, card holds, quotes and deposits | 11 | Quote with expiry, card hold, deposit or full payment, second payment, table policy |
| Chat for bookings and the WhatsApp support link | 6 | In-app chat linked to the booking, protection against taking the deal elsewhere, admin review, deletion after 30 days |
| Split payments, payouts and statements | 10 | Share between platform, organizer and club; transfer 3 days after the event ends; failed transfer retries; statements |
| Ticket cancellation, refunds and recovery from clubs | 10 | Single-ticket cancellation, automatic refunds under the club policy, goodwill refunds, club cost recovery, date and venue change notices |
| Multi-day passes, per-day entry, no-shows | 11 | One place per day, one QR per day, scanner per day, no-show reports, next tier opening, "Last tickets" label, access codes |
| Unregistered venues, venue disputes, destination areas | 8 | Authorization form and review, sales hold on dispute, Côte d'Azur as an area, activation of the eleven destinations |
| Purchase limits | 1 | 5 per order, 10 per customer per event |
| Four languages and the age display | 4.5 | English, Italian, French and Spanish across the app, emails and notifications; event age rule shown |
| Stabilising the built work | 2 | Time zones for existing events; the read-only list of affected sold counts |
| App updates for what is already built | 5 | New discovery screens, sign-in fixes, ticket and event page changes in the Flutter app |
| Acceptance and the five demonstrations | 1.5 | Test accounts for the ten roles, evidence for each item you will sign off |
| **Subtotal** | **about 92** | |

**Total for sections 2 and 3: about 116 working days.**

## 4. New scope that needs your decision (no work until approved)

We cannot honestly give dates for these, because they depend on outside parties. The ranges are first estimates and will be firmed up after your decision and after quotes from the providers.

| Item | Estimate (days) | Why it needs your decision first |
|---|---|---|
| Italian ticket issuing and access control (fiscal tickets) | 15 to 30 if we connect an approved provider; 80 to 150 or more if we build our own system (rough estimate, to be confirmed with the provider) | No provider is chosen. A separate short memo explains the options. Real Italian sales stay off until an approved route exists. Provider fees are not included. |
| Market setup for France, Monaco, Spain and the United States (including Nevada tax) | 15 to 25 | Each market needs a worked sale, refund, scan and report, and confirmation from your tax adviser. |
| Drafting of booking, refund and venue terms | 3 to 5 for the publishing and versioning work | The legal text itself must come from your legal adviser. We cannot supply legal advice. |
| Referral programme | 10 to 15 | "Soon after launch"; needs the holiday calendar and fee rules you will send. |
| Ticket resale and waitlist alerts | 20 to 30 | "Soon after launch"; priced separately as you asked; needs detailed questions first. |
| Messaging between attendees and Interested avatars | 15 to 25 | "Later"; estimate on request. |

## 5. Proposed phases and dates

| Phase | Contents | Proposed date |
|---|---|---|
| **1. Stable build for your testing** | Release of the finished work and the security fixes (each with your written approval); new discovery screens and sign-in fixes in the app; approval step for new owners; the app can ask for an update; time zones for existing events; purchase limits; first look at stalled-checkout counts (read only, needs hosting access) | **21 December 2026** (the last development task is planned for 9 December; the rest is release approval and app store review) |
| **2. Launch scope** | Everything in section 3, released in steps | Fees, price calculated by the server and the update gate: **10 February 2027**. Roles, tables, splits and payouts, refunds, passes and scanning, venues and areas, chat, languages and admin pages: March to April 2027. Ready for your final testing **27 April 2027**; launch candidate **7 May 2027** |
| **3. Soon after launch** | Referral programme, resale and waitlist, the remaining app languages already listed | Starts after launch; dates once section 4 is decided and detailed questions are answered |

We assume no work from 24 December to 1 January. Each release goes live only after your written approval. App store review adds 2 to 4 days for each app release.

**Assumptions behind the dates.**
- Team: one developer for the server and the admin dashboard, and one developer for the app, each working with Claude. Larger team, in one line: a second server and admin developer brings the launch candidate to about the end of February 2027, and a second app developer as well to about the beginning of February.
- You answer the high-priority questions by **4 December 2026**. Stripe, Apple, Google and push access are received, thank you. Where a Stripe setting is still missing (for example Connect for a country), we report it as soon as we test it and the payment items wait for it.
- The wording of terms, the venue authorization form and the adviser answers arrive before the matching screens are tested.
- The 30% allowance is enough. Scope changes during the build are estimated separately.

## 6. What we need from you

By **4 December 2026**:
1. Written confirmation of the features in section 3 and their estimates, or your changes.
2. Answers to the high-priority questions in our separate question list of 24 November.
3. Access to the test system and hosting (DigitalOcean), or the name of the person who manages it. Without it we cannot run the read-only list of sold counts.

By **11 December 2026**:
4. The names of the administrators who approve owners, organizers and venues.
5. The names of your tax, accounting and legal advisers for each launch market.
6. The WhatsApp number and the screen-recording link.

Later:
7. Your decision on the Italian ticketing route and on each item in section 4.
8. The venue authorization form in English and Italian, and the legal terms, before the matching screens are tested.
9. Your holiday calendar and fee rules, before referral work starts.

## 7. How dates can move

Dates move day for day if the hosting access, the written approvals or the adviser answers arrive late. They also move if the scope in section 3 grows, or if you change the order of priorities. We will tell you the new date as soon as we know.
