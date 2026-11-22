# Bookdia Night: questions we still need answered

Prepared 22 November 2026, after your written answers of the same date.

Thank you for your detailed answers. They let us plan most of the work. The questions below are what we still need before we can build or finish the features named next to each one. **Work on those features is paused until we have your answer.** Everything else continues.

**How to answer:** write your choice on the "Answer:" line, or reply with the question number and letter, for example "Q3: A". Where we marked an option "(Recommended)", "Q3: recommended" is enough. Numbers in square brackets, such as [Q5], are your own requirement numbers.

---

## Summary

| # | Topic | What it blocks | Priority | Answer needed by |
|---|---|---|---|---|
| 1 | Fee and commission amounts | Prices customers see and what clubs receive | High | [date] |
| 3 | Card hold for table bookings | How tables are booked and paid | High | [date] |
| 4 | Time to accept a quote | Table quotes and their expiry | High | [date] |
| 6 | Chat or WhatsApp for tables | Table requests and quotes | High | [date] |
| 8 | When clubs and organizers are paid | Payouts and organizer events | High | [date] |
| 10 | Event cancelled by the venue or organizer | Refunds | High | [date] |
| 12 | Who approves refunds | Refunds and cancellations | High | [date] |
| 17 | No-shows on multi-day passes | Multi-day passes and entry reports | High | [date] |
| 22 | New owner and organizer accounts | Sign-up for owners and organizers | High | [date] |
| 23 | Existing club owners | Sign-up change, live clubs | High | [date] |
| 24 | Team roles and permissions | Staff accounts, organizers | High | [date] |
| 29 | Stripe account | Table holds, split payments, payouts | High | [date] |
| 32 | Dates you need | Our delivery plan | High | [date] |
| 34 | Priority of new features | Estimates and schedule | High | [date] |
| 2 | How the fee is shown | Checkout screens and receipts | Medium | [date] |
| 5 | Deposits | Table payment screens | Medium | [date] |
| 7 | Who sets organizer and club shares | Split payments | Medium | [date] |
| 9 | Failed payouts | Payouts | Medium | [date] |
| 11 | Event rescheduled or moved | Notices and refunds | Medium | [date] |
| 13 | Refunding an amount | Refund options for clubs | Medium | [date] |
| 14 | Deposit on a cancelled table | Table cancellations | Medium | [date] |
| 15 | Cancelled tickets back on sale | Availability after cancellation | Medium | [date] |
| 16 | Purchase limits | Protection against mass booking | Medium | [date] |
| 18 | Entry hours and guest-list waiting time | Door entry, guest lists | Medium | [date] |
| 20 | Ticket progression, "from" price, low-stock labels | Event page and ticket button | Medium | [date] |
| 21 | Time zone of existing events | Event times shown to customers | Medium | [date] |
| 25 | Venue dispute | Events at venues not on the app | Medium | [date] |
| 26 | Côte d'Azur area | City list | Medium | [date] |
| 27 | Destinations live on day one | City list and launch | Medium | [date] |
| 28 | Sold numbers affected by unpaid checkouts | Correct ticket counts | Medium | [date] |
| 31 | Minimum age | Sign-up | Medium | [date] |
| 33 | App languages | Texts and legal documents | Medium | [date] |
| 19 | Guest-list access codes | Codes for guest lists | Low | [date] |
| 30 | Who puts new versions live | Releases | Low | [date] |

**Total: 34 questions** (14 High, 18 Medium, 2 Low), plus a checklist of things to send (section 10).

---

## 1. Payments and fees

**Q1. Fee and commission amounts** [Q2] **High**
Please send the amounts to use at launch for each product: the service fee the customer pays, and Bookdia Night's commission (a percentage or a fixed amount). The 1.5% + €0.26 figure in your answer is for testing only, so we will not use it as a live price. Please also tell us if "technical fee" and "service fee" mean the same thing.
*Why it matters:* it sets the price customers see and what clubs receive.
- A. Launch with today's amounts until you send new ones. **(Recommended)**
- B. Send the amounts now, using the table below.

| Product | Customer service fee | Bookdia commission | Paid by club or organizer |
|---|---|---|---|
| Tickets and passes | | | |
| Free tickets and guest lists | | | |
| Tables | | | |
| Sunbeds and extras | | | |

Are "technical fee" and "service fee" the same thing? Yes, we call it "Service fee" in the app **(Recommended)** / No (please explain).
Answer:

**Q2. How the fee is shown and calculated** [Q2] Medium
*Why it matters:* customers must see the right total before they pay.
(a) How is the fee shown?
- A. A separate "Service fee" line on every purchase. **(Recommended)**
- B. Included in the price and labelled "Service fee included".
- C. A for some products or countries and B for others (tell us which).

(b) What is the fee calculated on?
- A. The product price only. **(Recommended)**
- B. The total the customer pays, so the card cost is covered exactly.

(c) Free tickets and guest lists carry no fee for the guest and no commission. Do you also want an optional fixed charge for the club or organizer that Bookdia Night can switch on?
- A. No, not at launch. **(Recommended)**
- B. Yes.

Answer:

**Q3. Card hold for table bookings** [Q1] **High**
For a table with a known price, you proposed holding the amount on the customer's card when they ask, and charging it only if the venue accepts. We will test this with your Stripe account before we promise it. If a hold is not possible (some payment methods, or the hold has expired), do you agree that the customer pays after the venue accepts?
*Why it matters:* it decides how tables are booked and paid. A declined request costs the customer nothing.
- A. Yes. Use a card hold where possible, otherwise ask the customer to pay after acceptance. **(Recommended)**
- B. Never hold. Always ask the customer to pay after the venue accepts.
- C. Something else (please explain).

Answer:

**Q4. Time to accept a quote** [Q1] **High**
How long does a customer have to accept a quoted price?
*Why it matters:* quotes expire, and customers see how much time is left.
- A. 48 hours. The club can shorten or extend it, but never past the booking deadline. **(Recommended)**
- B. 24 hours.
- C. 72 hours.
- D. Other (please say).

Answer:

**Q5. Deposits** [Q1] Medium
You said clubs may offer a deposit, full payment or both. After a deposit, how does the customer pay the rest? (Saving a card to charge later would need separate terms, so we will not build that.)
*Why it matters:* it changes what customers are told at booking and what you can see in reports.
- A. In the app, by a deadline the club sets. **(Recommended)**
- B. At the venue, outside the app. Bookdia Night would not see or track that payment.
- C. The club chooses for each table.

Answer:

**Q6. Chat or WhatsApp for table requests** [Q1] **High**
How should customers and clubs talk about a table request?
*Why it matters:* the two routes differ a lot in build time, and the choice affects how well bookings are protected.
- A. Chat inside the app, linked to the booking. The club, authorized staff and authorized organizers can reply, Bookdia Night can review, and attempts to move the deal elsewhere are flagged. **(Recommended)**
- B. WhatsApp through a Bookdia Night number (never a personal number).
- C. Both.

If you choose A or C, we will ask separately how long chat records are kept and who at Bookdia Night reviews chats.
Answer:

**Q7. Who sets the organizer and club shares** [Q3] Medium
In your example, €2 goes to the organizer, €7 to the club and €1 to Bookdia Night. Who decides these shares for an event?
*Why it matters:* it decides who sees and agrees the split before tickets go on sale.
- A. The club owner proposes, the organizer accepts in the app, and a Bookdia Night admin can step in. **(Recommended)**
- B. A Bookdia Night admin only.
- C. The same fixed shares for every event, set by Bookdia Night.

Answer:

**Q8. When clubs and organizers are paid** [Q3] **High**
You asked us to propose payout timing.
*Why it matters:* it decides when clubs and organizers get their money, and whether refunds can be settled first.
- A. A few days after the event ends (for example 3 days), so refunds and disputes are settled first. **(Recommended)**
- B. As soon as each sale is paid, where Stripe allows it.
- C. Other (please say).

Stripe's own timing rules may add delay. We will confirm after testing with your account.
Answer:

**Q9. Failed payouts** [Q3] Medium
We propose: if a payout fails, we retry up to 3 times over 3 days, then tell the Bookdia Night admin and the club or organizer. The money stays in Bookdia Night's Stripe balance until it is fixed, and sales continue.
*Why it matters:* it decides what happens when a bank account or Stripe account has a problem.
- A. Agree. **(Recommended)**
- B. Retry once, then notify.
- C. Other (please say).

Answer:

---

## 2. Refunds and cancellations

**Q10. Event cancelled by the venue or organizer** [Q8] **High**
What do customers get back if the venue or organizer cancels an event? Today the ticket price is refunded and the service fee is kept.
*Why it matters:* it decides how much customers get back and what we show them.
- A. Everything, including the service fee. **(Recommended. Many markets expect this, so please check with your adviser.)**
- B. The ticket price only. The service fee is kept (how it works today).
- C. It depends on the country (please explain).

Answer:

**Q11. Event rescheduled or moved after tickets are sold** [T4] Medium
What happens if an event changes date or moves to another venue?
*Why it matters:* customers need clear notices and a clear choice.
- A. Tickets stay valid, customers are told, and they may ask for a full refund within a window the club sets (we suggest 7 days). **(Recommended)**
- B. Tickets stay valid. No refund.
- C. Everyone is refunded automatically.

Answer:

**Q12. Who approves refunds** [Q8] **High**
Your answer gives refund decisions to the club, and to organizers only with the owner's permission. Should a Bookdia Night admin approve any refunds? Today an admin approves every refund.
*Why it matters:* it decides who customers wait for.
- A. No. The club decides under its policy. Bookdia Night admins handle disputes only. **(Recommended)**
- B. An admin approves exceptions after the cancellation deadline only.
- C. An admin approves every refund.

Answer:

**Q13. Refunding an amount** [Q8] Medium
Besides cancelling tickets, should a club be able to refund part of the money (for example €10 as a goodwill gesture) without cancelling the tickets?
*Why it matters:* it decides whether clubs have this option.
- A. Yes, as a club exception. **(Recommended)**
- B. No. Only whole tickets or orders.

Answer:

**Q14. Deposit on a cancelled table** [Q1, Q8] Medium
A customer cancels a confirmed table after paying a deposit. What happens to the deposit?
*Why it matters:* customers see this before they pay.
- A. Not refunded unless the venue agrees. **(Recommended)**
- B. Refunded if cancelled before the club's deadline.
- C. The club decides for each table.

Answer:

**Q15. Cancelled tickets back on sale** [Q9] Medium
You said eligible cancelled capacity returns to sale automatically while sales are open.
*Why it matters:* it decides how many tickets are available after cancellations.
(a) Which cancelled tickets count as eligible?
- A. Only tickets cancelled in time under the club's policy and not yet scanned. **(Recommended)**
- B. Any cancelled ticket.

(b) "While sales remain open" means until:
- A. The club's sales end time, normally the event start. **(Recommended)**
- B. Another time (please say).

Answer:

**Q16. Purchase limits** [Q9] Medium
You asked us to propose limits against mass booking and repeated cancelling. We propose: keep the limit of 5 tickets per order, add a limit of 10 tickets per customer per event, and flag accounts that cancel repeatedly for admin review.
*Why it matters:* it protects real customers from people who block tickets.
- A. Agree. **(Recommended)**
- B. Use other numbers (please say).

Answer:

---

## 3. Tickets and entry

**Q17. No-shows on multi-day passes** [Q5] **High**
For a pass that covers Friday and Saturday, when is an unused day counted as a no-show?
*Why it matters:* it decides what your attendance and no-show reports show.
- A. At the end of each day's entry hours. Missing Friday is a no-show for Friday, and the pass stays valid for Saturday. **(Recommended)**
- B. Only after the whole event ends.

Answer:

**Q18. Entry hours and guest-list waiting time** [Q5] Medium
Who sets (a) the time each day when entry closes, and (b) how long a guest-list request can wait for approval before the place is released?
*Why it matters:* the door team and guests need clear times.
- A. The club sets both for each event. Entry closes at the event end time unless the club changes it. The waiting time starts at 24 hours and can be set between 1 and 72 hours. **(Recommended)**
- B. Bookdia Night sets fixed values for everyone.

Answer:

**Q19. Guest-list access codes** [A2.3] Low
Your list asks for guest-list codes, but your answers do not say how they should work.
*Why it matters:* we do not want to guess how guests get in.
- A. Not at launch. Discount codes keep working. **(Recommended)**
- B. One shared code for each event or guest list.
- C. A unique code for each guest.

If you choose B or C, please describe the idea in one sentence.
Answer:

**Q20. Ticket progression, "from" price and low-stock labels** [A2.9, A2.10, A2.17, D5] Medium
Your answers do not cover these. We propose:
1. When a ticket type sells out, the next one opens automatically.
2. "From €X" shows the lowest ticket currently on sale on event cards, the event page and the ticket button.
3. Show "Last tickets" when 20% or fewer remain, instead of exact numbers.

*Why it matters:* it changes what customers see on every event page.
- A. Agree to all three. **(Recommended)**
- B. Change something (tell us what).

Answer:

**Q21. Time zone of existing events** Medium
Existing events do not have a saved time zone, so their times could show wrongly to people in other time zones.
*Why it matters:* customers must see the correct start time.
- A. We set each event's time zone from its city and location. Organizers can correct it. **(Recommended)**
- B. Every organizer sets it for each event.

Answer:

---

## 4. Venues and organizers

**Q22. New owner and organizer accounts** [D1] **High**
While a new club owner or organizer waits for Bookdia Night's approval, what can they do?
*Why it matters:* it changes the sign-up screen in the app.
- A. Use the app as a normal customer only. Partner screens, sales and payouts unlock after approval. **(Recommended)**
- B. See the partner screens but not publish or sell until approved.

Answer:

**Q23. Existing club owners** [D1] **High**
What happens to the club owners already using the app?
*Why it matters:* live clubs must not lose access by accident.
- A. They keep full access. Approval applies to new accounts only. **(Recommended)**
- B. All existing owners must be approved again, and lose access until they are.

Answer:

**Q24. Team roles and permissions** [D1] **High**
Is the access table in your answer final? It has Platform Admin, Club Owner, Primary Manager, Event Manager (General Manager), Reservations Staff and Organizer.
*Why it matters:* each role needs its own screens and limits. Changes later are costly.
(a) Is the table final?
- A. Yes, build it as written. **(Recommended)**
- B. It needs changes (please list them).

(b) Is "Event Manager" the same role as "General Manager"? Yes / No.
(c) How are managers and staff added?
- A. The club owner adds them directly. Bookdia Night can suspend any account. **(Recommended)**
- B. Bookdia Night approves each one.

(d) When an owner lets an organizer handle quotes, chat or refunds:
- A. All three are off until the owner switches each one on. **(Recommended)**
- B. All three are on.

Answer:

**Q25. A venue disputes an event** [Q4] Medium
If sales are suspended after a venue disputes an event, what happens to tickets already sold?
*Why it matters:* customers need to know where they stand.
- A. They stay valid and a Bookdia Night admin decides within 2 working days. **(Recommended)**
- B. They are refunded automatically.

Answer:

---

## 5. Discovery and launch locations

**Q26. Côte d'Azur area** [C3] Medium
You asked us to propose the area. Which do you prefer?
*Why it matters:* it decides which events appear when a customer picks Côte d'Azur.
- A. Within about 50 km of Nice: Nice, Cannes, Antibes, Menton and nearby towns. Monaco stays its own destination. **(Recommended, matches the 50 km maximum search distance.)**
- B. The whole coast from Saint-Tropez to Menton.
- C. A list of towns that you send.

Answer:

**Q27. Destinations live on day one** [C3] Medium
Which destinations must be live on launch day?
*Why it matters:* a live destination needs events and a confirmed activation before we switch it on.
- A. All of them: Rome, Milan, Turin, Bologna, Paris, Côte d'Azur, Barcelona, Madrid, New York, Las Vegas, Monaco. **(Recommended, you asked us to prepare all of them.)**
- B. Only these first: ______

Answer:

---

## 6. Admin and data

**Q28. Sold numbers affected by unpaid checkouts** [Evidence] Medium
Some events may show more tickets sold than were really paid, because unpaid checkouts used to keep places reserved.
*Why it matters:* ticket counts and reports should be correct.
(a) May we read, without changing anything, the live sales data to prepare the list you asked for?
- A. Yes, read-only. We send you the list before any change. **(Recommended)**
- B. No. We give you a report that your team runs.

(b) After you review the list, should we correct the sold numbers?
- A. Yes, event by event, only after your written OK. **(Recommended)**
- B. No. Keep the history as it is.

Answer:

---

## 7. Access and accounts

**Q29. Stripe account** [Q1, Q3] **High**
Which Stripe account will we use for testing and live payments?
*Why it matters:* we cannot test card holds or split payments without it, and your answers ask us to confirm that they work for your account and countries.
- A. Your existing account. You add us as a team member with limited rights and make sure split payments (Connect) are enabled for the launch countries. **(Recommended)**
- B. A new account set up for Bookdia Night.

Please also tell us the countries where clubs and organizers will be paid at launch.
Answer:

**Q30. Who puts new versions live** Low
We will not change your live app or servers without your written approval.
- A. We prepare each version and publish it only after your written approval. **(Recommended)**
- B. You publish, and we hand over each version.

Answer:

**Q31. Minimum age** [P0.1] Medium
Customers must be 18 or older to sign up today.
*Why it matters:* it decides who can create an account.
(a) Does 18 also apply to club owners and organizers?
- A. Yes, 18 for everyone. **(Recommended)**
- B. A different age for owners (please say which).

(b) What happens if someone under 18 signs in with Google or Apple?
- A. No account is created and a clear message is shown. **(Recommended)**
- B. They can browse but not buy.

Answer:

**Q32. Dates you need** **High**
Please tell us:
- your launch date;
- the date you need multi-day passes and scanning (you asked for our target dates, so we need yours too);
- any events with fixed dates that we must support;
- the dates of your own demonstrations and sign-offs.

*Why it matters:* it sets our delivery plan. We will reply with our target date for each item.
Answer:

---

## 8. Content we need

**Q33. App languages at launch** Medium
Your lists are in English and Italian. Which languages do the app and the legal documents need at launch?
*Why it matters:* every text and document has to be written and checked in each language.
- A. English and Italian. **(Recommended)**
- B. Also French.
- C. Also Spanish.

Answer:

---

## 9. New features to prioritize

**Q34. Priority of new features** **High**
Your answers add features that were not in the first plan. Please mark each one: **Launch** (needed on launch day), **Soon after** (right after launch) or **Later**. Each feature will get its own time estimate before we build it. For referral rewards and resale, we will send a few detailed questions once you have chosen their priority.

| Feature | Launch / Soon after / Later |
|---|---|
| Table requests with card hold, quotes and deposits | |
| Chat for bookings (or WhatsApp) | |
| Team roles and permissions for managers, staff and organizers | |
| Approval of new club owners and organizers | |
| Events at venues that are not on the app (authorization form and review) | |
| Automatic split payments to organizers and clubs | |
| Multi-day passes, per-day entry and no-show reports | |
| Cancelling single tickets, with automatic refunds under the club's policy | |
| Referral rewards for partners and customers | |
| Ticket resale and waitlist alerts (priced separately) | |
| Purchase limits | |
| Messaging between attendees, and Interested avatars (future direction) | |

Answer:

---

## 10. Things we need you to send

**Access (please send privately, never by email in plain text)**
- [ ] Stripe account access (see Q29), including the test keys.
- [ ] Apple Developer, TestFlight and Google Play Console access, and the Google and Apple sign-in settings.
- [ ] Access to the account used for app notifications.
- [ ] Access to the test system and the hosting accounts, or the name of the person who manages them (see Q30).
- [ ] Names and emails of the people who will test, with the role each needs: customer, club manager, organizer, admin and each staff role. We will create labelled test accounts and use test payments.

**Content**
- [ ] The amounts for fees and commissions (Q1).
- [ ] The final wording of the venue authorization form, in English and Italian, reviewed by your legal adviser.
- [ ] Updated terms for booking, refunds and venue authorization (and for resale and referral, if you choose them).
- [ ] If referral rewards are a priority: the holiday calendar for each market and what "one complimentary event" covers.
- [ ] The screenshot package. Your tracker and your latest answers contain two different download links. Please tell us which one is current and keep it active. Please send the screen recording when it is ready.

**People**
- [ ] The name and contact of the product owner who accepts our work, and a backup.
- [ ] The Bookdia Night admins who will approve owners, organizers and venues, and handle disputes.
- [ ] The adviser who will review tax, accounting and the wording of fees and refund terms in each launch market.
