# Decisions needed from the client

Project: Bookdia Night. Date prepared: 2026-11-21. Based on the review tracker of 6 Nov 2026 (open decisions Q1 to Q6) plus one extra question (D1).

**How to answer:** for each question below, reply with the question number and either "Option A/B/C" or your own rule. If you agree with our recommendation, just write "Q3: recommended". Nothing in the "Blocks" line can be finished until that question is answered; everything else carries on meanwhile.

"CR-xx" numbers are our internal change-request numbers (see `02-product/change-requests.md`).

| # | Topic | Blocks | Answer needed |
|---|---|---|---|
| Q1 | How are tables paid for? | CR-07, CR-16 | Choose A, B, C or D |
| Q2 | Customer fees and Bookdia commission | CR-15, CR-16 | Fill the table |
| Q3 | How money is split with organizers | CR-02, CR-16 | Choose A or B |
| Q4 | Events at venues not on the app | CR-02 | Confirm proof needed |
| Q5 | Capacity, entry and no-show rules | CR-04, CR-05, CR-06, CR-08 | Confirm 6 rules |
| Q6 | Smaller discovery and profile choices | CR-07, CR-09, CR-10, CR-11, CR-12 | Confirm 6 defaults |
| D1 | Can anyone sign up as a club owner? | CR-01, CR-02 | Choose A, B or C |

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

## D1. Can anyone sign up as a club owner?

**The question:** Today, anyone can register in the app and choose "club owner" themselves, with no check. Should this stay?

**Why it matters:** A club owner can create clubs and events, sell tickets and receive payouts. Without a check, anyone can appear as a venue. This is also a security risk. Removing it will change the signup screen in the mobile app.

**Options:**
- **A. Keep as is.** Fast, no protection.
- **B. Anyone can apply, but an admin must approve before they can sell.** Account is created as a normal customer until approved.
- **C. Club owners and organizers are created only by an admin (invitation).** Most control, more manual work.

**Our recommendation:** B. It keeps signup simple and adds control before any money is involved. This question also decides how the new "organizer" role is created.
