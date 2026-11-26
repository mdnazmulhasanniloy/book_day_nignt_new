# Migration rehearsal 20261122-011750

Database `bookdia_rehearsal` on localhost:5441 (container bookdia-rehearsal-pg). Dump: `bookdianight.dump`.

## 1. Recreate database
- recreated with postgis, btree_gist

## 2. Restore dump
- restore took 2s (exit 0, errors other than 'already exists': 0)

## 3. prisma migrate deploy
```
25 migrations found in prisma/migrations
Applying migration `20261027211302_add_promo_created_by_user`
Applying migration `20261101040000_add_event_modules_and_quotes`
Applying migration `20261101051000_allow_event_module_purchase`
Applying migration `20261101053000_add_event_guest_list`
Applying migration `20261101054500_add_vip_hosts`
Applying migration `20261101055500_add_bookings_closed`
Applying migration `20261101061000_phase6_mood_artists_nested_tiers`
Applying migration `20261101163000_waiting_list_slot_context`
Applying migration `20261102104500_guest_list_entry_notifications`
Applying migration `20261102154500_guest_list_entry_other_count`
Applying migration `20261103101500_host_inquiry_notifications`
Applying migration `20261111120000_oauth_identity`
The following migration(s) have been applied:
migrations/
  └─ 20261027211302_add_promo_created_by_user/
    └─ migration.sql
  └─ 20261101040000_add_event_modules_and_quotes/
    └─ migration.sql
  └─ 20261101051000_allow_event_module_purchase/
    └─ migration.sql
  └─ 20261101053000_add_event_guest_list/
    └─ migration.sql
  └─ 20261101054500_add_vip_hosts/
    └─ migration.sql
  └─ 20261101055500_add_bookings_closed/
    └─ migration.sql
  └─ 20261101061000_phase6_mood_artists_nested_tiers/
    └─ migration.sql
  └─ 20261101163000_waiting_list_slot_context/
    └─ migration.sql
  └─ 20261102104500_guest_list_entry_notifications/
    └─ migration.sql
  └─ 20261102154500_guest_list_entry_other_count/
    └─ migration.sql
  └─ 20261103101500_host_inquiry_notifications/
    └─ migration.sql
  └─ 20261111120000_oauth_identity/
    └─ migration.sql
All migrations have been successfully applied.
```
- migrate deploy took 2s

Last 15 migrations with duration (the dump was behind the repo, so the newest ones ran in this rehearsal):
```
20261111120000_oauth_identity | 0.016
20261103101500_host_inquiry_notifications | 0.006
20261102154500_guest_list_entry_other_count | 0.004
20261102104500_guest_list_entry_notifications | 0.004
20261101163000_waiting_list_slot_context | 0.006
20261101061000_phase6_mood_artists_nested_tiers | 0.032
20261101055500_add_bookings_closed | 0.004
20261101054500_add_vip_hosts | 0.037
20261101053000_add_event_guest_list | 0.028
20261101051000_allow_event_module_purchase | 0.006
20261101040000_add_event_modules_and_quotes | 0.046
20261027211302_add_promo_created_by_user | 0.011
20261024094524_add_waiting_list_and_club_events | 0.014
20261024083922_add_shotgun_features | 0.041
20261003091258_add_checked_in_at_to_order | 0.007
```

## 3b. Schema drift vs schema.prisma
- no drift beyond the known btree_gist item (BUG-B04)

## 4. Violation checks (GATE rows must be 0)
```
GATE|Order.serviceChargeAmount < 0|0
GATE|Order.commissionAmount outside 0..grossAmount|0
GATE|Order.sellerEarnings <> grossAmount - commissionAmount|0
GATE|Order.buyerTotal <> grossAmount + serviceChargeAmount|0
GATE|ServiceCharge.amount <= 0|0
GATE|ApplicationCharge.chargePercentage outside 0..100|0
INFO|PromoCode with neither or both of eventId / clubId|2
INFO|duplicate (eventId, groupName, tierName) tier groups|0
```

## 5. Stock-leak report (read-only, informational, first 60 lines)
```
               event_id               |    event_name    |               tier_id                | groupName  |  tierName   | price | capacity | isActive | sold_count_now | paid_persons | diff | unpaid_pending_persons | pending_last_15min | ambiguous_same_price 
--------------------------------------+------------------+--------------------------------------+------------+-------------+-------+----------+----------+----------------+--------------+------+------------------------+--------------------+----------------------
 003a6ddf-ca5b-44a1-8faa-fe11c93c5908 | updated test     | 7cea0cdf-e4ce-4b49-9610-8b68f1d0826b | test group | Test ticket | 15.00 |        5 | t        |              0 |            0 |    0 |                      0 |                  0 | f
 563c4428-2f6f-4fd9-89a8-e0d148cfd963 | Sample team sync | 21714c54-ad55-46f3-95eb-6acf1260a3ba |            | test        | 50.00 |       50 | t        |              0 |            0 |    0 |                      0 |                  0 | f
(2 rows)

               event_id               |    eventName     |               tier_id                |  tierName   | price | capacity | sold_count_now | corrected_sold_count | diff | impossible_value_check 
--------------------------------------+------------------+--------------------------------------+-------------+-------+----------+----------------+----------------------+------+------------------------
 003a6ddf-ca5b-44a1-8faa-fe11c93c5908 | updated test     | 7cea0cdf-e4ce-4b49-9610-8b68f1d0826b | Test ticket | 15.00 |        5 |              0 |                    0 |    0 | f
 563c4428-2f6f-4fd9-89a8-e0d148cfd963 | Sample team sync | 21714c54-ad55-46f3-95eb-6acf1260a3ba | test        | 50.00 |       50 |              0 |                    0 |    0 | f
(2 rows)

 events_with_leak | leaked_persons | events_with_lower_count_than_sales 
------------------+----------------+------------------------------------
                0 |              0 |                                  0
(1 row)

```

## 6. Migration 4 review query
- n/a: migration 4 (TO-BE) does not exist in the repo yet.

## Summary
RESULT: PASS
