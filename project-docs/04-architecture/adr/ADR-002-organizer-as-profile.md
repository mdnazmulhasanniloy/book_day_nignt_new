# ADR-002: Organizer is a profile on a club-owner account, not a new role

- **Status:** Accepted (spec diff approved 2026-11-21)
- **Requirements:** CR-02 (approved part: organizer identity, profile, follow, collaboration request). Owner approval (CR-01 / D1) is deferred until the client answers.
- **Related:** `data-model.md` 8.2 (`OrganizerProfile`, `CollaborationRequest`), `api-spec.yaml` `/organizer/*`, `/organizers/*`, `/collaboration-requests`

## Context
The tracker (C1 to C6) asks for an organizer role that manages its own events, has a public profile and asks registered clubs to host. Today `AccountRole` is `USER | ADMIN | CLUB_OWNER`, and `auth.routes.ts:63` already states that event organizers use `CLUB_OWNER`. The live Flutter app routes by the role string stored on the device; how it handles an unknown value is ⚠️ UNVERIFIED (the splash code falls back to the user dashboard, `splash_view.dart:55-57`). Postgres cannot remove an enum value once added.

## Decision
- **Do not add `ORGANIZER` to `AccountRole`.** An organizer is a `CLUB_OWNER` account that has an `OrganizerProfile` (1:1 with `User`). If the client later asks for owner approval (D1), organizers are covered by the same gate; nothing here depends on it.
- All organizer endpoints require `CLUB_OWNER` and, where relevant, an existing profile. Authorization checks use the profile, not the role.
- `Event.organizerId` is optional. When an event has both `clubId` and `organizerId`, the event can be published and sold only if an `ACCEPTED` `CollaborationRequest` exists for that organizer and club.
- Admin moderation uses `OrganizerProfile.isVerified` and `isSuspended`; a suspended organizer cannot publish events.
- Manual (unregistered) venues and payout splitting are **not** part of this decision (Q3, Q4 unanswered).

## Alternatives considered
- **New `ORGANIZER` enum value:** cleaner naming, but irreversible in Postgres, and the live app may mis-route an unknown role. Rejected for now.
- **Separate `Organizer` account table with its own login:** a second auth stack for the same person. Rejected.

## Consequences
- Organizers and club owners share screens and the Stripe Connect onboarding path; the UI distinguishes them by profile presence, not role.
- "Club owner who is also an organizer" is natural (one account, one profile) and needs no special case.
- If the Flutter app later gets role-aware navigation, revisit: adding `ORGANIZER` then is a deliberate migration with a client release first.
