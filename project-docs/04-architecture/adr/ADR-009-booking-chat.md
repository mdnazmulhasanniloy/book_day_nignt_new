# ADR-009: Booking chat and support link

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. Retention rule needs legal review.
- **Requirements:** CR-20, CR-07. Client answers-02 Q6. Client answers-01 Q1 (Messaging).
- **Related:** `data-model.md` migration 21 (`Conversation`, `Message`, `ChatFlag`); `api-spec.yaml` `/v2/bookings/{id}/chat`, `/v2/admin/chats`, `/v2/admin/chats/{id}/intervene`; ADR-005, ADR-008

## Context
Table requests and quotes need a channel between customer and club. The client chose booking-linked chat as the primary channel, plus a link to one Bookdia Night WhatsApp Business number for urgent tables or unanswered requests (suggested text: "Need help with a last-minute table? Contact Bookdia Night on WhatsApp."). Owners may not enter personal WhatsApp numbers. Attempts to divert a booking must be flagged ("For your protection, please keep this booking in the app."), while the approved on-site balance workflow is allowed.

## Decision
1. **One `Conversation` per table request or booking** with participants: customer, club owner, authorized venue staff, authorized organizers (permission from ADR-008). Platform admins and specifically authorized platform managers or staff can review and intervene (intervention messages are labelled).
2. **Flagging.** Messages are scanned for diversion patterns (phone numbers, messenger links, "pay outside", etc.); a hit creates a `ChatFlag`, shows the protection message and notifies the admin queue. No automatic blocking at launch; rules are configurable and logged.
3. **Support link.** One setting holds the Bookdia WhatsApp Business number and text; the app shows the link for urgent tables or when a request has no reply after a configurable time.
4. **Retention.** Delete the chat 30 days after booking closure. When a dispute is opened, dispute closure starts the 30 days. A scheduled job deletes messages and attachments; the quote and payment records are kept (they are order data, not chat).
5. **Notifications.** New messages and flags send push notifications (needs the push account, checklist item 03).
6. **Access.** Chat endpoints are v2 only, authenticated, rate limited; read states per participant.

## Consequences
- New module, tables and worker job; admin review page; Flutter chat screens.
- Deleting chat after 30 days removes evidence that disputes, chargebacks or tax and fiscal records might need. The client must confirm with the adviser (clarification document); until then the job is built but disabled by a setting.
- No change for the live app: v1 quote and host contact endpoints stay.

## Alternatives considered
- **WhatsApp-only:** weak tracking, personal numbers, hard to protect bookings. Rejected as the primary channel.
- **Both channels equal:** the client chose in-app primary plus a support link.
- **Third-party chat SDK:** extra cost and data location questions. Not chosen for now.

## Open points
- The WhatsApp number (client to supply).
- Whether 30-day deletion is acceptable for legal and fiscal reasons.
- Who reviews chats first (named admins, checklist item 12).
