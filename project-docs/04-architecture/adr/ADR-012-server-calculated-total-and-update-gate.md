# ADR-012: Server-calculated checkout total, fee display mode and the force-update gate

- **Status:** Proposed (client answers 2026-11-24, product owner decision 7 of the same day), awaiting confirmation. All parts ship in one release.
- **Requirements:** CR-26, CR-15, CR-16. Client answers-02 Q1 (launch defaults and admin control), Q2 (presentation and calculation), Section 9 (US upfront total).
- **Related:** `api-spec.yaml` `POST /v2/checkout/preview`, `GET /v2/app/version-policy`; ADR-001, ADR-003, ADR-005; data-model migration 22 (`AppVersionPolicy`)

## Context
The live Flutter app loads the flat amount from `GET /service-charge` (`flutter_app/lib/app/core/network/end_point.dart:51`) and calculates the checkout total itself (`buy_ticker_controller.dart:88-96`, `loadServiceCharge`); booking details show `serviceChargeAmount` from the order. The client's launch fee is 5% of the eligible paid subtotal plus EUR 0.50 (local equivalent) once per order, with admin overrides by country, category, club, event and table or quote. A percentage plus a fixed part cannot be expressed as one flat number. If the server charges the new fee while the old app still shows the old total, the customer sees a total different from the charge, which breaks the rule to show the full payable price before payment (all markets, US upfront-fee rule).

## Decision
1. **Preview endpoint.** `POST /v2/checkout/preview` takes the basket (event tickets, tables, extras, payment step, promo) and returns line amounts, the Technical Fee lines, the payable total per payment, the applicable display mode (`ITEMIZED` or `INCLUDED`, per market and category) and the rule ids used. It is the only place the total is calculated; the same code runs at order creation, and the order stores the rates used (ADR-003).
2. **Display mode** is returned by the preview, so the app only renders what it receives: show the full payable price as soon as it is calculable and itemize the Technical Fee discreetly, or label "Service fee included" where the market or category requires an inclusive price (US).
3. **Flutter change.** The checkout screens call the preview and drop the client-side fee calculation (tasks FL-111, FL-112; backend T-089, T-096).
4. **Legacy path.** `GET /service-charge`, `GET /admin/service-charge`, the old purchase request and response shapes keep working unchanged for old app versions (ADR-001). While the gate is off, charges for old builds follow the legacy flat fee so what the old app shows equals what is charged.
5. **Force-update gate.** `GET /v2/app/version-policy` returns the minimum supported build per platform and an update message; a setting (`AppVersionPolicy`) holds it. New builds read it at launch and show an update-required screen below the minimum. The new fee model is switched on only when the gate minimum is a build that uses the preview. Old builds below the minimum are blocked from purchase endpoints on the server with HTTP 426 `UPGRADE_REQUIRED` once the switch is on (a status the live app shows as a message).
6. **Release together.** Backend preview and gate, Flutter build, and the switch go out as one coordinated release with the store release first; the client publishes only after written approval (Q30).
7. **Processor cost** is recorded per payment separately from commission and margin (Q2); tax and fee wording per market is reviewed by the client's advisers.

## Consequences
- Old builds that are never updated stop being able to buy once the gate is on; the client must accept that and the store review lead time.
- The fee model v2 must not be switched on in production before the Flutter build is live. A rollback is "gate off", which restores the legacy flat fee.
- Tests: preview equals the order total for every product mix; legacy endpoints byte-compatible; 426 only after the switch.

## Alternatives considered
- **Change `/service-charge` to return a percentage:** changes a field's meaning; breaks the live total. Rejected.
- **Charge the new fee silently to old builds:** displayed total differs from the charge. Rejected.
- **No gate, rely on voluntary updates:** leaves two prices on the market. Rejected.

## Open points
- The app-side rollout date and the minimum build number (depends on the store release).
- Fixed fee amount per currency other than EUR and which markets show the inclusive price (clarification document).
