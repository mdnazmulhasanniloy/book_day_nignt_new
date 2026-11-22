# ADR-001: API versioning and deprecation

- **Status:** Accepted (spec diff approved 2026-11-21)
- **Requirements:** all approved CRs; CR-07 (`POST /v2/quotes`) and CR-15 (`/v2/admin/pricing-rules`, `/v2/admin/financials`) are the first v2 endpoints
- **Related:** `api-spec.yaml` (`info.description`), `api-spec-changelog.md`

## Context
A production Flutter app uses `/api/v1` and cannot be force-updated on our schedule (no update gate is documented; ⚠️ UNVERIFIED). `backend/CLAUDE.md` forbids removing or renaming response fields. Several approved changes would break that rule if done in place (for example authenticated-only quotes, new fee/commission model).

## Decision
1. **Additive changes stay in v1.** Allowed: new endpoints, new optional query parameters and body fields, new response fields, new enum values on response fields clients ignore, new error codes on already-failing paths.
2. **Anything else is breaking and goes to `/api/v2`.** Breaking = removing or renaming a field, changing a type or meaning, making an optional request field required, adding auth to a public endpoint, changing a success status code or shape.
3. **Mechanics.** v2 is a separate Express router mounted at `/api/v2`, containing only the changed endpoints; everything else keeps being served from v1 (no copy of unchanged endpoints). In the spec, v2 operations use path keys that start with `/v2` plus a path-level `servers` override, and carry `x-api-version: v2`.
4. **Deprecation.** When v2 replaces a v1 operation, v1 keeps working with identical behaviour and gets `deprecated: true` and `x-change: deprecated` in the spec. At runtime, v1 responses add `Deprecation: true` and `Link: <v2 url>; rel="successor-version"` (headers are additive). **No sunset date is set** until we can measure which app versions still call v1 (milestone M8 or later).
5. **Status-code corrections** (500 to 4xx) are treated as non-breaking: the Flutter client shows the real message for any 4xx and a generic one for 5xx (`api_expection.dart:29-43`). Exception rule: business failures must not use 401/403, because the client maps both to `UnauthorizedException` (`base_client.dart:492`) and will log the user out once BUG-B07 is fixed.
6. **One accepted breaking removal inside v1:** the leaked bcrypt hash in `GET /admin/users` (BUG-S17). It is a security fix and only the Admin client calls the endpoint.

## Alternatives considered
- **Header or media-type versioning:** invisible in logs and Swagger, harder for Flutter and curl. Rejected.
- **No versioning, fix in place:** breaks the live app. Rejected.
- **Full v2 copy of the API:** doubles maintenance for endpoints that did not change. Rejected.

## Consequences
- Two routers and two sets of tests; v2 handlers should reuse v1 services, not copy them.
- The spec carries both worlds; `x-status: planned` marks TO-BE items until they ship, then the tag is removed.
- v1 deprecation without a sunset date can last indefinitely; revisit when app-version telemetry exists.
