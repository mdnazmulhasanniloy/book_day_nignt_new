# Bookdia Night: questions from the first build round

Prepared 23 November 2026.

We have built the first group of features that did not depend on your answers (ticket types, discovery, search, cities, artists, bookings). While building them we hit a few points where the rules were not clear, and we chose a safe default for each. Some of these defaults change what customers or clubs experience, so we need your decision. **For every question below, the feature keeps working with our safe default until you answer.** Please answer the High-priority questions first.

**How to answer:** write your choice on the "Answer:" line, or reply with the question number and letter, for example "Q3: A". Where we marked an option "(Recommended)", "Q3: recommended" is enough. Numbers in square brackets, such as [Q28], point to the earlier list we sent you.

---

## Summary

| # | Topic | What it blocks | Priority | Answer needed by |
|---|---|---|---|---|
| 1 | Discount codes that work on every event | Who may create club-wide or platform-wide codes | High | [date] |
| 2 | Payment confirmed after the hold expired | What happens to a late payment when the tickets are gone | High | [date] |
| 3 | Sold ticket types | Whether a club can remove a ticket type that has sales | Medium | [date] |
| 4 | Who maintains an artist profile | Which club or organizer may edit an artist | Medium | [date] |
| 5 | Côte d'Azur and region cities | How a region such as Côte d'Azur appears in the city list | Medium | [date] |
| 6 | Italian names for music styles and moods | Italian labels in the filters | Medium | [date] |
| 7 | Rules we proposed | Weekend, trending, code attempts, event time zones | Medium | [date] |
| 8 | Check of the live sales numbers | Correct "tickets sold" numbers | Medium | [date] |
| 9 | Map link on the event page | What the "open in maps" button shows | Low | [date] |

**Total: 9 questions** (2 High, 6 Medium, 1 Low).

---

## 1. Discount codes

**Q1. Discount codes that work on every event** High
Today a club owner can create a discount code that is not tied to one event or one club. Such a code works on any event on the platform. Our first plan was to allow only Bookdia Night admins to create these codes, but the app's "Add promo" screen lets owners submit one, so we kept it working as it is.
*Why it matters:* a code that works everywhere can give discounts on events the owner does not run, and the club's commission and payout are affected.
- A. Only Bookdia Night admins can create codes that work on every event. Club owners can only create codes for their own events or their own club. **(Recommended)**
- B. Club owners can still create them, as today.

Until you answer, nothing changes: owners can still create these codes, and only the owner who made one (or an admin) can edit or delete it.
Answer:

---

## 2. Payments

**Q2. A payment that is confirmed after the hold expired** High
A customer has 15 minutes to pay. If the card payment is confirmed after the 15 minutes, the places may already have been given to someone else. If the ticket type is full, we cannot issue the ticket, and the customer may already have been charged.
*Why it matters:* the customer's money is involved, and today nobody is told.
- A. Refund the customer automatically and tell them by email and in the app. **(Recommended)**
- B. A Bookdia Night admin reviews each case and decides (refund, or add the place if the club agrees).
- C. Keep the places for a few minutes longer (tell us how many) so late payments are rarer, and refund the rest automatically.

Until you answer, nothing is refunded automatically. The case is recorded for manual review and the ticket is not issued.
Answer:

---

## 3. Ticket types

**Q3. A ticket type that already has sales** Medium
When tickets of a type have been bought, we keep that type and mark it inactive instead of deleting it, so past orders keep their ticket type.
*Why it matters:* a club may expect to delete the ticket type and cannot.
- A. Keep it as it is: the club can hide the ticket type, but not delete it. **(Recommended)**
- B. Allow deleting it. Past orders keep the ticket type name, but the link to the type is lost.

Answer:

---

## 4. Artists

**Q4. Who may edit an artist profile** Medium
Artist profiles are shared: the same artist can appear in many clubs' line-ups. We now let a club owner edit an artist only when the artist is in the line-up of one of that owner's events. We do not record who first added an artist, so we cannot also allow "the club that created the artist".
*Why it matters:* it decides who can change the photo, bio and links that every club's event page shows.
- A. Record who created each artist. The creator and Bookdia Night admins can edit it. Other clubs can add the artist to a line-up but cannot change the profile. **(Recommended)**
- B. Any club that has the artist in a line-up can edit it (what we have now).
- C. Only Bookdia Night admins can edit artists.

Also: may a club owner **rename** an artist or mark it **verified**? We suggest only Bookdia Night admins can (today only admins can).
- Yes, owners may. / No, only admins. **(Recommended)**

We have already fixed one related problem on our side: sending a line-up without choosing an existing artist no longer changes a shared artist's photo, links or verified mark.
Answer:

---

## 5. Cities and regions

**Q5. How Côte d'Azur appears in the city list** Medium
Cities are shown with one centre point. Côte d'Azur is a region of several towns, so it does not fit a single point well. We suggested earlier [Q26] covering about 50 km around Nice, with Monaco as its own destination.
*Why it matters:* it decides what a customer sees when they pick Côte d'Azur, and what we need to build.
- A. Treat Côte d'Azur like a city: one centre point (Nice) and the 50 km search. **(Recommended for launch, no extra build.)**
- B. Build a real "region" that groups several towns (Nice, Cannes, Antibes, Menton, ...). You tell us the towns.
- C. List the main towns as separate cities instead of one region.

All 11 destinations are loaded but switched off. Please also confirm which ones go live on day one [Q27].
Answer:

---

## 6. Italian and English names

**Q6. Italian names for music styles and moods** Medium
You sent the 15 music styles and 8 moods in English and Italian. We store the English name. The Italian name is kept in a file but is not shown yet.
*Why it matters:* customers using the Italian app would see English names in the filters.
- A. Show the Italian name when the app language is Italian, English otherwise. **(Recommended)**
- B. Always show the English name.
- C. Show both names together.

Answer:

---

## 7. Rules we proposed

**Q7. Please confirm our proposed rules** Medium
You asked us to propose these. Please say "agree" or tell us what to change.
- **This Weekend:** Friday 18:00 to the end of Sunday, in the time zone of the city or event.
- **Trending:** in the last 7 days, an event scores one point for each view and one point for each "Interested" tap. Most Viewed counts views over the last 30 days. Ties are broken by the earlier start date.
- **Discount code attempts:** a person can try a code up to 20 times per minute. After that they must wait.
- **Event time zones:** events that existed before this update have no saved time zone, so they are treated as UTC until the club sets one. (Please also answer how existing events should get a time zone [Q21].)
- A. Agree to all four. **(Recommended)**
- B. Change some (tell us which and how).

Answer:

---

## 8. Live data

**Q8. Check of the live sales numbers** [Q28] Medium
Some events may show more tickets sold than were really paid, because unpaid checkouts used to keep places reserved.
(a) May we read, without changing anything, the live sales data to prepare the list you asked for?
- A. Yes, read-only. We send you the list before any change. **(Recommended)**
- B. No. We give you a report that your team runs.

(b) After you review the list, should we correct the sold numbers?
- A. Yes, event by event, only after your written OK. **(Recommended)**
- B. No. Keep the history as it is.

We also need this check for one more reason: we added a rule that a ticket section that already has sales cannot be saved together with sub-types. We want to confirm that no live event is in that situation before we release.
Answer:

---

## 9. Event page

**Q9. The map link on the event page** Low
The event page can open the event in a map. We have two ways to build the link.
- A. Search for the event name together with its position. It shows the place name but can sometimes show a different place with a similar name.
- B. Open the exact position only (an exact pin, no name). **(Recommended)**

Answer:
