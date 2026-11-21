# BookDiaNight — Flutter API & Mobile Integration Guide

> **Version:** 1.0.0  
> **Target Audience:** Flutter App Developer  
> **Backend Environment Base URL:** `https://ibady.nazmul.qzz.io`  
> **API Version Prefix:** `/api/v1`

---

## Table of Contents
1. [Overview & Recent Feature Additions](#1-overview--recent-feature-additions)
2. [Deep Linking & Universal Links (iOS & Android)](#2-deep-linking--universal-links-ios--android)
   - [Overview & Share URL Structure](#21-overview--share-url-structure)
   - [iOS Universal Links Setup](#22-ios-universal-links-setup)
   - [Android App Links Setup](#23-android-app-links-setup)
   - [Flutter Implementation & Route Handling](#24-flutter-implementation--route-handling)
3. [Club Waiting List System](#3-club-waiting-list-system)
   - [How the Waiting List Works](#31-how-the-waiting-list-works)
   - [Join Waiting List](#32-join-waiting-list)
   - [Leave Waiting List](#33-leave-waiting-list)
   - [Check Club Waiting Status & Queue Position](#34-check-club-waiting-status--queue-position)
   - [Get My Active Waiting Lists](#35-get-my-active-waiting-lists)
   - [UI / UX Flow Recommendations](#36-ui--ux-flow-recommendations)
4. [In-App Notification Center & Push Handling](#4-in-app-notification-center--push-handling)
   - [Device Registration & FCM Token Sync](#41-device-registration--fcm-token-sync)
   - [Notification Inbox Endpoints](#42-notification-inbox-endpoints)
   - [Notification Payload Structure & Action Routing](#43-notification-payload-structure--action-routing)
5. [Club Events Association & Discovery](#5-club-events-association--discovery)
   - [Club Upcoming & Past Events](#51-club-upcoming--past-events)
   - [Event Creation with Club Association](#52-event-creation-with-club-association)
6. [Error Handling & Standard Envelope](#6-error-handling--standard-envelope)

---

## 1. Overview & Recent Feature Additions

The backend has implemented and verified the following new capabilities:

1. **Native Deep Linking (iOS Universal Links & Android App Links)**: Automatic opening of the app when tapping club or event share links, with social preview cards (OpenGraph metadata) fallback on the web.
2. **Club Waiting List Engine**: Allows users to join a queue when a club's tables are sold out or held. When a table hold expires, backend workers automatically notify waiting users via push notifications and emails.
3. **In-App Notification Center**: Unread badge count, notification inbox pagination, single/all mark-as-read APIs.
4. **Club-Linked Events**: Events can now be directly linked to a `clubId`, and the club explore endpoints query events associated with the club.

---

## 2. Deep Linking & Universal Links (iOS & Android)

### 2.1 Overview & Share URL Structure

When a user in the Flutter app shares a Club or an Event, format the shared URL as:

- **Club Share URL:** `https://ibady.nazmul.qzz.io/explore/club/<clubId>`
- **Event Share URL:** `https://ibady.nazmul.qzz.io/explore/event/<eventId>`

*(Note: `/club/<id>` and `/event/<id>` are also supported).*

#### Behavior:
- **If App is Installed:** The operating system intercepts the URL and opens the Flutter app directly to the specified club/event screen without launching a web browser.
- **If App is NOT Installed:** The user lands on a responsive mobile web preview page featuring the cover image, club/event title, date/time, and a prominent **"Open in BookDiaNight App"** CTA button.

---

### 2.2 iOS Universal Links Setup

The server is already serving the required `apple-app-site-association` file at:
`https://ibady.nazmul.qzz.io/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["3Z64Z2KU2S.com.bookdianightltd.bookdianightapp"],
        "components": [
          { "/": "/club/*" },
          { "/": "/event/*" },
          { "/": "/explore/club/*" },
          { "/": "/explore/event/*" }
        ]
      }
    ]
  }
}
```

#### Steps for iOS Developer:
1. Open the Flutter project in Xcode (`ios/Runner.xcworkspace`).
2. Go to **Runner** target > **Signing & Capabilities**.
3. Click `+ Capability` and add **Associated Domains**.
4. Add the following entry (with the `applinks:` prefix):
   ```
   applinks:ibady.nazmul.qzz.io
   ```
5. Ensure your Apple Developer Team ID matches `3Z64Z2KU2S` and Bundle ID is `com.bookdianightltd.bookdianightapp`.

---

### 2.3 Android App Links Setup

The server is already serving the required `assetlinks.json` file at:
`https://ibady.nazmul.qzz.io/.well-known/assetlinks.json`

Configured with SHA-256 fingerprint:
`45:1C:1D:8D:B0:D3:AC:E9:32:D1:EC:77:31:D9:44:96:57:1E:0B:76:EF:E4:8E:64:82:D2:19:75:A4:F9:4D:87`
Package Name: `com.bookdianightltd.bookdianightapp`

#### Steps for Android Developer:
Open `android/app/src/main/AndroidManifest.xml` and add the following intent-filter inside the main `.MainActivity` `<activity>` tag:

```xml
<activity
    android:name=".MainActivity"
    ...>
    
    <!-- Deep Link & App Links Intent Filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data android:scheme="https" android:host="ibady.nazmul.qzz.io" android:pathPrefix="/explore/club/" />
        <data android:scheme="https" android:host="ibady.nazmul.qzz.io" android:pathPrefix="/explore/event/" />
        <data android:scheme="https" android:host="ibady.nazmul.qzz.io" android:pathPrefix="/club/" />
        <data android:scheme="https" android:host="ibady.nazmul.qzz.io" android:pathPrefix="/event/" />
    </intent-filter>
    
</activity>
```

---

### 2.4 Flutter Implementation & Route Handling

Using the official [app_links](https://pub.dev/packages/app_links) package (recommended) or `go_router`:

```dart
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

class DeepLinkHandler {
  static final AppLinks _appLinks = AppLinks();

  static void init(BuildContext context) {
    // 1. Handle app opened from terminated state via link
    _appLinks.getInitialAppLink().then((uri) {
      if (uri != null) _handleNavigation(context, uri);
    });

    // 2. Handle app opened from background state via link
    _appLinks.uriLinkStream.listen((uri) {
      _handleNavigation(context, uri);
    });
  }

  static void _handleNavigation(BuildContext context, Uri uri) {
    final pathSegments = uri.pathSegments;

    // Matches: /explore/club/<id> OR /club/<id>
    if ((pathSegments.length >= 3 && pathSegments[0] == 'explore' && pathSegments[1] == 'club') ||
        (pathSegments.length >= 2 && pathSegments[0] == 'club')) {
      final clubId = pathSegments.last;
      Navigator.pushNamed(context, '/club-detail', arguments: {'clubId': clubId});
      return;
    }

    // Matches: /explore/event/<id> OR /event/<id>
    if ((pathSegments.length >= 3 && pathSegments[0] == 'explore' && pathSegments[1] == 'event') ||
        (pathSegments.length >= 2 && pathSegments[0] == 'event')) {
      final eventId = pathSegments.last;
      Navigator.pushNamed(context, '/event-detail', arguments: {'eventId': eventId});
      return;
    }
  }
}
```

---

## 3. Club Waiting List System

### 3.1 How the Waiting List Works

1. If all tables are booked or on temporary checkout HOLD, a user can tap **"Join Waiting List"**.
2. The user is assigned a FIFO queue position.
3. Every 10–15 minutes, when other users abandon checkout holds without paying, the background worker automatically releases those tables and marks the top waiting users as `NOTIFIED`.
4. The user receives a push notification:
   > *"Table Available! A table just opened up at [Club Name]. Book now before it's gone!"*
5. The user can view their active queues and queue positions at any time.

---

### 3.2 Join Waiting List

Adds the authenticated user to the queue for a club. If already on the list, returns existing queue status.

- **Method:** `POST`
- **Path:** `/api/v1/waiting-list/join`
- **Headers:** `Authorization: Bearer <accessToken>`, `Content-Type: application/json`

#### Request Body:
```json
{
  "clubId": "cm1234567890abcdef"
}
```

#### Success Response (`201 Created` or `200 OK`):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Successfully joined waiting list",
  "data": {
    "id": "wl_cm7890abcdef",
    "clubId": "cm1234567890abcdef",
    "userId": "usr_987654321",
    "status": "PENDING",
    "notifiedAt": null,
    "createdAt": "2026-10-24T10:00:00.000Z",
    "updatedAt": "2026-10-24T10:00:00.000Z",
    "position": 3,
    "club": {
      "id": "cm1234567890abcdef",
      "name": "Club Luminaria",
      "location": "Mayfair, London",
      "thumbnail": "https://cdn.bookdianight.com/clubs/thumb1.jpg"
    }
  }
}
```

---

### 3.3 Leave Waiting List

Removes the user from the waiting list for a club.

- **Method:** `POST`
- **Path:** `/api/v1/waiting-list/leave`
- **Headers:** `Authorization: Bearer <accessToken>`, `Content-Type: application/json`

#### Request Body:
```json
{
  "clubId": "cm1234567890abcdef"
}
```

#### Success Response (`200 OK`):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Successfully left waiting list",
  "data": {
    "message": "Successfully left waiting list"
  }
}
```

---

### 3.4 Check Club Waiting Status & Queue Position

Call this when rendering the Club Detail screen to determine the button state for the user.

- **Method:** `GET`
- **Path:** `/api/v1/waiting-list/club/:clubId/status`
- **Headers:** `Authorization: Bearer <accessToken>`

#### Response A (User is NOT in Waiting List):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Club waiting list status retrieved successfully",
  "data": {
    "isWaiting": false,
    "position": null,
    "entry": null
  }
}
```

#### Response B (User IS in Waiting List):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Club waiting list status retrieved successfully",
  "data": {
    "isWaiting": true,
    "position": 2,
    "entry": {
      "id": "wl_cm7890abcdef",
      "clubId": "cm1234567890abcdef",
      "userId": "usr_987654321",
      "status": "PENDING",
      "createdAt": "2026-10-24T09:30:00.000Z",
      "club": {
        "id": "cm1234567890abcdef",
        "name": "Club Luminaria"
      }
    }
  }
}
```

---

### 3.5 Get My Active Waiting Lists

Fetches all clubs the user is currently waiting for (useful for a "My Waiting Lists" tab in user profile/bookings).

- **Method:** `GET`
- **Path:** `/api/v1/waiting-list/my?page=1&limit=20`
- **Headers:** `Authorization: Bearer <accessToken>`

#### Success Response (`200 OK`):
```json
{
  "success": true,
  "statusCode": 200,
  "message": "My waiting lists retrieved successfully",
  "data": [
    {
      "id": "wl_cm7890abcdef",
      "clubId": "cm1234567890abcdef",
      "userId": "usr_987654321",
      "status": "PENDING",
      "createdAt": "2026-10-24T09:30:00.000Z",
      "club": {
        "id": "cm1234567890abcdef",
        "name": "Club Luminaria",
        "location": "Mayfair, London",
        "thumbnail": "https://cdn.bookdianight.com/clubs/thumb1.jpg",
        "coverImage": "https://cdn.bookdianight.com/clubs/cover1.jpg",
        "lat": 51.5074,
        "lng": -0.1278
      }
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "totalPages": 1
  }
}
```

---

### 3.6 UI / UX Flow Recommendations

```
[Club Detail Screen Loaded]
       │
       ▼
Fetch GET /api/v1/waiting-list/club/:clubId/status
       │
       ├─► If isWaiting == true:
       │     Display: Badge "In Queue: #<position>"
       │     Action Button: "Leave Waiting List" -> calls /waiting-list/leave
       │
       └─► If isWaiting == false & All tables full:
             Action Button: "Join Waiting List" -> calls /waiting-list/join
```

---

## 4. In-App Notification Center & Push Handling

### 4.1 Device Registration & FCM Token Sync

When the user logs in, completes social auth, or refreshes their authentication token, the app sends device details to the backend:

- **Path:** `/api/v1/auth/login` (or `/api/v1/auth/refresh-token`)
- **Headers:** `Content-Type: application/json`

#### Payload fields:
```json
{
  "deviceId": "UUID-of-device-from-device_info_plus",
  "fcmToken": "FIREBASE_MESSAGING_FCM_TOKEN",
  "platform": "IOS" // or "ANDROID"
}
```

> **Important:** The backend automatically upserts the token per `(userId, deviceId)`. If a user logs into a new device or reinstalls, the backend keeps multiple active devices synced.

---

### 4.2 Notification Inbox Endpoints

#### 1. Unread Notification Count (Bell Icon Badge)
- **Method:** `GET`
- **Path:** `/api/v1/notifications/unread-count`
- **Headers:** `Authorization: Bearer <accessToken>`

```json
{
  "success": true,
  "statusCode": 200,
  "message": "Unread notification count retrieved successfully",
  "data": {
    "unreadCount": 4
  }
}
```

#### 2. Get Notifications List (Paginated)
- **Method:** `GET`
- **Path:** `/api/v1/notifications?page=1&limit=20`
- **Headers:** `Authorization: Bearer <accessToken>`

```json
{
  "success": true,
  "statusCode": 200,
  "message": "Notifications retrieved successfully",
  "data": [
    {
      "id": "notif_1001",
      "userId": "usr_987654321",
      "notificationType": "CLUB_SEAT_AVAILABLE",
      "title": "Table Available!",
      "body": "A table just opened up at Club Luminaria. Book now before it's gone!",
      "data": {
        "clubId": "cm1234567890abcdef"
      },
      "isRead": false,
      "createdAt": "2026-10-24T10:15:00.000Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "totalPages": 1
  }
}
```

#### 3. Mark Single Notification as Read
- **Method:** `PATCH`
- **Path:** `/api/v1/notifications/:id/read`
- **Headers:** `Authorization: Bearer <accessToken>`

```json
{
  "success": true,
  "statusCode": 200,
  "message": "Notification marked as read successfully",
  "data": {
    "id": "notif_1001",
    "isRead": true
  }
}
```

#### 4. Mark All Notifications as Read
- **Method:** `PATCH`
- **Path:** `/api/v1/notifications/read-all`
- **Headers:** `Authorization: Bearer <accessToken>`

```json
{
  "success": true,
  "statusCode": 200,
  "message": "All notifications marked as read successfully",
  "data": {
    "count": 4
  }
}
```

---

### 4.3 Notification Payload Structure & Action Routing

When Firebase sends a push, `data` always includes `notificationType`. Booking and ticket pushes also include `orderId` and `serviceType` (`EVENT` or `CLUB`). A club-table queue alert uses `CLUB_SEAT_AVAILABLE` and `clubId`.

```dart
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  final notificationType = message.data['notificationType'];

  switch (notificationType) {
    case 'CLUB_SEAT_AVAILABLE':
      final clubId = message.data['clubId'];
      if (clubId != null) {
        Navigator.pushNamed(context, '/club-detail', arguments: {'clubId': clubId});
      }
      break;

    case 'BOOKING_CONFIRMED':
    case 'CLUB_BOOKING_CONFIRMED':
    case 'PAYMENT_FAILED':
    case 'TICKET_AVAILABLE':
    case 'NEW_CLUB_BOOKING':
    case 'NEW_TICKET_SALE':
      final orderId = message.data['orderId'];
      final serviceType = message.data['serviceType'];
      if (orderId != null && serviceType != null) {
        Navigator.pushNamed(context, '/booking-detail', arguments: {
          'orderId': orderId,
          'serviceType': serviceType,
        });
      }
      break;

    default:
      Navigator.pushNamed(context, '/notifications');
  }
});
```

---

## 5. Club Events Association & Discovery

### 5.1 Club Upcoming & Past Events

Clubs now host both user-created events and club-linked events. Use these explore endpoints on the Club Profile:

#### 1. Upcoming Events for Club
- **Method:** `GET`
- **Path:** `/api/v1/explore/club/:clubId/events/upcoming?page=1&limit=10`
- **Headers:** Optional `Authorization: Bearer <accessToken>`

#### 2. Past Events for Club
- **Method:** `GET`
- **Path:** `/api/v1/explore/club/:clubId/events/past?page=1&limit=10`
- **Headers:** Optional `Authorization: Bearer <accessToken>`

---

### 5.2 Event Creation with Club Association

When an organizer or club manager creates an event from the app, they can associate the event directly with a club by passing `clubId`:

- **Method:** `POST`
- **Path:** `/api/v1/events`
- **Headers:** `Authorization: Bearer <accessToken>`, `Content-Type: application/json`

#### Body addition:
```json
{
  "name": "Halloween Midnight Rave",
  "description": "The biggest electronic rave of the year.",
  "clubId": "cm1234567890abcdef", // Optional: links event to this club
  "startAt": "2026-10-31T21:00:00.000Z",
  "endAt": "2026-11-01T04:00:00.000Z",
  "location": "Mayfair, London",
  "dressCode": "Costume / Smart Casual",
  "eventPrice": 25.00,
  "currency": "EUR"
}
```

---

## 6. Error Handling & Standard Envelope

All responses adhere to the standard BookDiaNight API envelope:

### Success Envelope
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Action performed successfully",
  "data": { ... },
  "meta": { ... } // optional pagination
}
```

### Error Envelope
```json
{
  "success": false,
  "statusCode": 404,
  "message": "Club not found or inactive",
  "errorDetails": null
}
```

### Common HTTP Status Codes
| Code | Meaning | Action in Flutter App |
| :--- | :--- | :--- |
| `200` / `201` | Success | Update local state / UI. |
| `400` | Bad Request / Validation Error | Check request body parameters. |
| `401` | Unauthorized | Refresh access token using `/auth/refresh-token` or redirect to Login. |
| `403` | Forbidden | User account inactive or permission denied. |
| `404` | Not Found | Resource (club, event, notification) does not exist. |
| `500` | Internal Server Error | Show friendly toast and report trace ID if present. |

---

*Document generated automatically for BookDiaNight Mobile Integration.*
