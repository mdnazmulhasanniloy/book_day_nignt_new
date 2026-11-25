# ADR-008: Team roles and permissions (club and platform)

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. Amends ADR-002 (which has no staff model).
- **Requirements:** CR-19, CR-02. Client answers-02 Q24 (roles), Q12-13 (organizer permissions), Section 6 item 05 (ten test logins). Client answers-01 D1 access matrix.
- **Related:** `data-model.md` migration 14 (`ClubTeamMember`, `PlatformStaff`, `RolePermission`, `PermissionGrant`, `PermissionAuditLog`); `api-spec.yaml` `/v2/clubs/{clubId}/team`, `/v2/team/invitations/{token}/accept`, `/v2/admin/platform-staff`, `/v2/admin/role-permissions`, `/v2/owner/organizers/{organizerId}/permissions`; ADR-002, ADR-010

## Context
`AccountRole` is `USER | ADMIN | CLUB_OWNER`. The client defines club roles (Club Owner, General Manager (the former Primary Manager), Event Manager, Reservations Staff, Organizer) and platform roles (Platform Admin, Platform Manager, Country Manager, Platform Staff), page-level view/manage checkboxes, explicit sensitive actions, an editable permissions page, and server-side enforcement including geographic limits. In answers-01 the alias "Event Manager (General Manager)" was used; answers-02 makes them two roles.

## Decision
1. **`AccountRole` is not changed.** The live Flutter app reads the role as a string and routes by `CLUB_OWNER`; unknown values could break it. Staff are ordinary accounts (`USER` or `CLUB_OWNER` as today) with rows in separate tables.
2. **Club team.** `ClubTeamMember (clubId, userId, role: GENERAL_MANAGER | EVENT_MANAGER | RESERVATIONS_STAFF, status, invitedBy, assignedEventIds?)`. Owner invites directly (Q24 c = A); the platform can suspend any account. Self-escalation is blocked. Owner keeps payout destination and team control; General Manager runs club operations and reporting without ownership transfer or payout destination access; Event Manager works on assigned events only (pricing within permissions, capacity, bookings, event revenue); Reservations Staff manage guest lists, bookings, check-in and forward refund requests.
3. **Organizer** keeps ADR-002 (a profile on a `CLUB_OWNER` account). Permissions for quotes, chat and refunds start OFF and are granted independently by the owner (`PermissionGrant`, grantor and time kept, revocations kept) (Q24 d = A).
4. **Platform roles.** `PlatformStaff (userId, role: PLATFORM_MANAGER | COUNTRY_MANAGER | PLATFORM_STAFF, countryCodes[])`. Platform Admin remains `AccountRole.ADMIN`. Platform Manager has admin-like operational access except payouts, payout destinations, Stripe settings, commercial rates, Technical Fee refunds, club debits and admin management. Country Manager is the same inside the assigned country or region only. Platform Staff handle ordinary refunds within policy, tickets, chat, reports and disputes, never rates, payouts, roles or event publishing. Technical Fee refunds and club debits are Admin only.
5. **Permission model.** A catalogue of pages (view / manage) and sensitive actions; `RolePermission` stores the defaults per role, editable by Admin on a page (`/v2/admin/role-permissions`). A resolver returns the effective permissions for (user, club or country); one middleware checks them on the server. Every grant, revoke and role change is written to `PermissionAuditLog`.
6. **Additive session data.** Login and check responses gain `teamRole`, `permissions` and `clubIds` (additive; absent for normal accounts). Old app builds ignore them.
7. **Geographic limits** use the country of the club or event (via `City.countryCode`); records without a country are visible only to Admin.
8. **Test accounts.** A seed script creates ten labelled accounts (customer, club owner, general manager, event manager, reservations staff, organizer, Bookdia admin, platform manager, country manager, platform staff) with test payments only.

## Consequences
- Every owner endpoint that uses `req.user.id` as club owner needs a membership-aware check; the cross-account test suite (T-069) is extended.
- Flutter needs role-aware navigation (FL-121). The admin app gets roles, team and audit pages.
- Media ownership (`feat/media-ownership`, not in main) should use club scope when it is built, so a manager can delete a colleague's file.

## Alternatives considered
- **New `AccountRole` values:** irreversible in Postgres and may mis-route the live app. Rejected (product owner decision, 2026-11-24).
- **One account per role with separate login:** rejected (ADR-002).
- **Hard-coded permission matrix:** the client asked for an editable page. Rejected.

## Open points
- The default permission matrix per page (the client gave roles and principles, not a full table).
- Whether "assigned events" are chosen per event or per organizer relationship.
