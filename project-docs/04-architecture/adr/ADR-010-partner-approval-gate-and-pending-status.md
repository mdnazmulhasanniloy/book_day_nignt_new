# ADR-010: Partner approval gate and the 423 pending status

- **Status:** Proposed (client answers 2026-11-24, product owner decisions of the same day), awaiting confirmation. Lifts the CR-01 deferral.
- **Requirements:** CR-18, CR-01, CR-02, BUG-S03. Client answers-02 Q22, Q23. Client answers-01 D1.
- **Related:** `data-model.md` migration 1 (`PartnerApplication`, status backfill); `api-spec.yaml` `/admin/partner-applications`, `partnerStatus` on auth responses; known-issues S-03; ADR-002, ADR-008

## Context
Today `POST /auth/signup` accepts `role: CLUB_OWNER` from any client (S-03), and the live Flutter signup lets the user pick it (`sign_up_model.dart`, `sign_in_controller.dart` routes owners to the payout flow). The client requires admin approval before partner dashboards, sensitive information or sales. Existing clubs keep access without reapproval (Q23). Pending owners and organizers see only the club-area home with partner tools locked; customer use requires a separate customer account (Q22). The server must enforce this.

## Decision
1. **Status model.** `PartnerApplication (userId unique, status PENDING | APPROVED | REJECTED, decidedAt, decidedByAdminId, decisionNote)`. Auth responses (login, check, social, signup) gain an additive `partnerStatus` (`PENDING | APPROVED | REJECTED`, absent for customers).
2. **Backfill.** Migration 1 sets every existing `CLUB_OWNER` to `APPROVED` (Q23); only new owners and organizers start `PENDING`. New signups with `role: CLUB_OWNER` are accepted (the live app still sends it) but create a `PENDING` application.
3. **Gate.** A middleware on partner endpoints (club, event, module, quote, owner, organizer, connect, media for partners) answers a `PENDING` or `REJECTED` account with **HTTP 423** and `errorType: PARTNER_APPROVAL_PENDING` (or `PARTNER_REJECTED`) and a plain message. An allow-list keeps the club-area home endpoints (profile, check, logout, application status) working.
4. **Never 401 or 403 for "pending".** Evidence: the live Flutter app treats both 401 and 403 as a dead session (`flutter_app/lib/app/core/network/api_error_handler.dart:68` and `base_client.dart:492` both test `statusCode == 401 || statusCode == 403`), so a 403 would log a waiting owner out in a loop; ADR-001 already forbids business failures on 401/403. Other 4xx are shown as a message (`ValidationException`), so 423 shows the server text on old builds and a proper pending screen on new builds that read `partnerStatus`.
5. **Admin.** `GET /admin/partner-applications`, `POST .../{id}/approve`, `POST .../{id}/reject`; notification to the applicant; named approvers (checklist item 12) are a client input.
6. **Customer account.** The same email cannot be both. A pending partner who wants to buy tickets needs a separate customer account; how that account is created (second email) is an open client question. Invitations are verified before an invited owner or organizer is approved.
7. **Organizers** follow the same gate (an organizer is a `CLUB_OWNER` account with a profile, ADR-002).

## Consequences
- Closes S-03 once shipped: new accounts cannot act as owners before approval.
- Old app builds: a pending owner sees an error message on partner screens instead of being logged out; existing owners are unaffected.
- Flutter needs the signup change and a pending screen (FL-102); the admin app needs the approvals page.
- Support load: approval SLA is a client process, not a technical limit.

## Alternatives considered
- **403 with a custom errorType:** logs the owner out in the live app. Rejected.
- **200 with empty data:** hides the cause and risks old screens crashing on empty bodies. Rejected.
- **Create pending owners as customers (option A in the clarification):** the client chose a club-area home with locked tools (answers-02 Q22).

## Open points
- How one person gets both a customer and a partner account (email uniqueness).
- Age requirement for owners and organizers (clarification document); the 18+ signup rule stays.
