# SmartEvents mobile (Flutter)

The Flutter app for SmartEvents. It uses the same backend as the web app in
`../client` (Express API in `../server`, MongoDB Atlas, Socket.IO).

## Run

```bash
cd mobile
flutter pub get
flutter run
```

By default the app talks to the live API (`lib/config/api_config.dart`).
To use a local server instead (Android emulator):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1 --dart-define=SOCKET_URL=http://10.0.2.2:5000
```

## API the app will use

All routes are under `/api/v1` and documented at `/api-docs` on the server.

| Area | Routes |
| --- | --- |
| Sign-in | `POST /auth/register`, `POST /auth/login`, `POST /auth/google`, `GET /auth/me` (send `Authorization: Bearer <token>`) |
| Events | `GET /events`, `GET /events/:id` |
| Vendors | `GET /vendors`, `GET /vendors/:id` |
| Bookings and negotiation | `POST /bookings`, `GET /bookings/my`, `GET /bookings/:id`, `POST /bookings/:id/negotiate`, `PUT /bookings/:id/offer`, `POST /bookings/:id/messages`, `PUT /bookings/:id/accept`, `PUT /bookings/:id/reject` |
| Designs | `GET /designs`, `GET /bookings/:id/design` |
| Tickets | `GET /tickets/my` |

Live updates: connect to `SOCKET_URL` with `auth: { token }` from
`GET /auth/socket-token`, emit `join-negotiation` with the booking id, and listen
for `offer-countered`, `offer-revised`, `offer-accepted`, `offer-rejected` and
`negotiation-message`.

## Keeping in step with the web app

This repository is a fork of `Umar-Qureshi-16/SmartEvents`. To bring in backend
or web changes made there:

```bash
git fetch upstream
git merge upstream/master
```
