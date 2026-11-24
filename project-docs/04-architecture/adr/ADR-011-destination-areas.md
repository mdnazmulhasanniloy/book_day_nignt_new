# ADR-011: Destination areas independent of the search radius

- **Status:** Proposed (client answers 2026-11-24), awaiting product owner confirmation. The town list is not yet defined.
- **Requirements:** CR-24, CR-09. Client answers-02 Q26-27. Client answers-01 C3, 6a.
- **Related:** `data-model.md` migration 20 (`DestinationArea`, `DestinationAreaMember`); `api-spec.yaml` `GET /cities` (additive fields), `/v2/admin/destination-areas`; built T-031, T-033, T-034, T-032

## Context
Built discovery models a `City` as a point with `timezone` and `isLaunched`, searched with `radiusKm` 10 to 50. The client says the Cote d'Azur extends from Saint-Tropez to Menton (well over 50 km), must be modelled as a destination area independent of the 50 km search radius, and Monaco remains its own destination. All eleven destinations are to be enabled: Rome, Milan, Turin, Bologna, Paris, Cote d'Azur, Barcelona, Madrid, New York, Las Vegas, Monaco. Destination discovery opens independently of live ticket sales; commercial coverage and Stripe payout eligibility are verified separately. T-032 seeded the Cote d'Azur as an inactive placeholder city.

## Decision
1. **`DestinationArea (id, name, countryCode, kind: AREA, timezone, isLaunched, boundary?)`** with `DestinationAreaMember (areaId, cityId or town name, lat, lng)`. A city row may point to its area. Events belong to an area when their coordinates fall inside the boundary or inside a member town radius; the choice (polygon versus member list) is made by the town-list answer, member list first.
2. **Explore and map** accept `cityId` of an area and match by membership instead of `radiusKm`; the radius still applies to ordinary cities and to the GPS search. `GET /cities` adds `kind` and `areaId` (additive); the existing fields and the seeded Cote d'Azur row stay.
3. **Activation per destination.** `isLaunched` remains the switch; all eleven are prepared, activation needs events plus the client's confirmation; Monaco stays a separate destination from France in data, tax and payouts.
4. **Texts.** A city with no club shows "Your city's first party is on its way."; an active city with no matching result offers date or radius changes (response carries an `emptyReason` field, additive).
5. Time zone comes from the area or the member city; the time zone backfill (Q21) uses the same data.

## Consequences
- The seeded placeholder (Nice centre, no members) is replaced by a real area once the client confirms the towns.
- Old app builds only know cities and radius; they see the area as a city row and keep working.
- Admin Cities page gains area management.

## Alternatives considered
- **Make the radius larger for this city only:** breaks the 50 km cap and gives overlapping Monaco results. Rejected.
- **Polygon only:** needs a drawn boundary the client has not given; the member list is simpler to edit.

## Open points
- The towns or coastal depth that belong to the area (clarification document).
- Which destinations are live on launch day in practice.
