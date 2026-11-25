# SmartEvents mobile (Flutter)

The SmartEvents app for Android, iOS and the web. It uses the same backend as
the web app (Express API in `../server`, MongoDB Atlas, Socket.IO) and adds
Firebase for analytics, crash reports and push notifications.

## What is in the app

| Tab / screen | What it does |
| --- | --- |
| Welcome, sign in, sign up | **Continue with Google**, email and password, organizer / vendor / admin accounts (admin signup and access codes), forgot password and reset, email verification and resend, live password checklist (same rules as the server), session kept in secure storage with automatic token refresh |
| Explore | Search, category chips, top vendors, upcoming events with infinite scroll |
| Event | Details, vendor, **Make an offer** (opens a negotiation), **Get pass** (QR ticket) |
| Vendors | Search and filter by category; vendor profile with stats, events, packages and AI designs; **Request a quote**, make an offer on a package, book a design; save to favorites |
| Bookings / Offers | Grouped into open, agreed and closed; "your turn" badges and banner; updates live |
| Negotiation | Deal panel (offer on the table, whose turn, price trail), accept / decline / counter, **change my offer** while waiting, chat at any time with quick replies, live over Socket.IO; after a deal: mark as delivered (releases escrow), cancel, report a problem (dispute), leave a review |
| Smartie | AI assistant that answers from your own bookings; proposed actions run only after **Confirm** |
| Passes | QR entry passes, full-screen for the gate |
| Notifications | Unread badge, mark all read, tap to open the booking |
| Profile | Account, trust score, light / dark / system theme, Firebase status, sign out |
| Settings | Name and email, change password, country and region (sets the currency), contact us |
| Organizer extras | My events (plans with checklists), favorite vendors, event reviews |
| Vendor tools | Business profile, event listings (create / edit / delete), services, availability calendar, revenue, reviews, **check in guests** (QR scanner), design studio |
| Admin | Platform numbers, people (restrict, verify vendors, change roles), disputes (refund or pay out) |

Prices show in the user's own currency (from their country), and every form
checks the same rules as the server (`server/utils/validation.js`).

## Run

```bash
cd mobile
flutter pub get
flutter run                 # Android / iOS device or emulator
flutter run -d chrome       # web
```

By default the app talks to the live API (`lib/config/api_config.dart`). For a
local server:

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1 --dart-define=SOCKET_URL=http://10.0.2.2:5000
# Web (the server must allow the page's origin in ALLOWED_ORIGINS)
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:5000/api/v1 --dart-define=SOCKET_URL=http://localhost:5000
```

## Google sign-in (one time)

The app sends Google's ID token to `POST /auth/google`, which checks it against
the website's OAuth client (`GOOGLE_CLIENT_ID` on the server). The app uses
that same web client ID (`GOOGLE_SERVER_CLIENT_ID`, set in
`lib/config/api_config.dart`). Android also needs the app registered in the
same Google Cloud project:

1. Google Cloud console, the project that owns the web client
   (`334746400767-...`), APIs and Services, Credentials, Create credentials,
   OAuth client ID, type **Android**.
2. Package name `com.smartevents.smartevents`, and the SHA-1 of the signing key.
   For debug builds on this PC:
   `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`
   (add the release key's SHA-1 too before publishing).
3. No code change is needed; the sign-in sheet works once Google has the app.

## Connect Firebase (one time)

The app runs without Firebase; these steps switch on analytics, Crashlytics and
push notifications.

1. Create a project at https://console.firebase.google.com (add Android app
   `com.smartevents.smartevents` and iOS app with the same bundle id).
2. Install the tools and generate the config (from `mobile/`):

   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   This replaces `lib/firebase_options.dart` and adds
   `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
3. Push notifications from the server: in Firebase console go to Project
   settings, Service accounts, Generate new private key, and put the JSON (or its
   base64) in the server's environment as `FIREBASE_SERVICE_ACCOUNT`. Every
   in-app notification (new offer, counter-offer, message, pass) is then also
   sent as a push to the user's phones.
4. iOS only: enable Push Notifications and Background Modes > Remote
   notifications in Xcode, and upload an APNs key in Firebase.

Profile shows "Firebase: Connected" once it works.

## Build for release

```bash
flutter build apk --release        # Android APK (build/app/outputs/flutter-apk/)
flutter build appbundle --release  # Play Store
flutter build ios --release        # needs a Mac with Xcode
flutter build web --release        # static site in build/web
```

## Code layout

```
lib/
  main.dart                start-up: Firebase, saved session, router
  router.dart              routes and the bottom navigation
  config/api_config.dart   API and socket addresses
  core/                    theme, API client, session store, socket, Firebase, formatting, password rules
  models/models.dart       Event, Vendor, Booking, Offer, Chat, Ticket, Notification, Design
  state/app_state.dart     signed-in user, theme, unread count
  screens/                 auth, explore, vendors, bookings + negotiation, smartie, tickets, notifications, profile
  widgets/common.dart      images, loading shimmer, empty and error states, chips, dialogs
```

## API used

All routes are under `/api/v1`.

| Area | Routes |
| --- | --- |
| Session | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`, `POST /auth/logout`, `GET /auth/socket-token` |
| Push | `POST /auth/push-token`, `DELETE /auth/push-token` |
| Events | `GET /events`, `GET /events/:id` |
| Vendors | `GET /vendor/list`, `GET /vendor/profile/:id`, `GET /designs?vendor=` |
| Bookings | `POST /bookings`, `GET /bookings/my`, `GET /bookings/organizer`, `GET /bookings/:id`, `POST /bookings/:id/negotiate`, `PUT /bookings/:id/offer`, `POST /bookings/:id/messages`, `PUT /bookings/:id/accept`, `PUT /bookings/:id/reject` |
| Tickets | `GET /tickets/my`, `POST /tickets/purchase` |
| Notifications | `GET /notifications`, `PUT /notifications/read-all`, `PUT /notifications/:id/read` |
| Smartie | `POST /ai/agent`, `POST /ai/agent/execute` |

Live events on the socket: `offer-countered`, `offer-revised`, `offer-accepted`,
`offer-rejected`, `negotiation-message`, `notification`.

## Keeping in step with the web app

This repository is a fork of `Umar-Qureshi-16/SmartEvents`:

```bash
git fetch upstream
git merge upstream/master
```
