# Citizen home, notifications and reliability

The home screen follows the supplied design and displays only the newest ticket whose status is `waiting` or `called`. Loading and errors are not treated as an empty booking list. Search opens the existing facility directory. The original facility details design is retained.

Accounts start with zero points. `citizen_accounts/{uid}` stores the balance and restriction state. Its `events` subcollection contains one deterministic welcome event and subsequent booking, attendance and review events. No sample notifications or balances are seeded. Negative balances are allowed, so a missed first appointment still deducts five points.

## Attendance and restrictions

- Authorized facility staff close a called ticket. Serving also requires an existing check-in.
- Serving adds five points and resets the consecutive absence counter. Absence deducts five points.
- The third consecutive absence starts a seven-day booking suspension. Attendance does not erase suspension history.
- Any further absence after that suspension expires requires administrative review. A restored account starts a fresh restriction cycle, with its points preserved.
- Results are ordered by when staff finalize tickets, not by their original booking dates.
- Ticket finalization, balance change and notification are one transaction. The rules independently validate arithmetic, prior ticket state and server timestamps, preventing duplicate scoring and client balance edits.
- Restrictions block regular and reward bookings. Notifications, existing tickets and reports remain available.

## Rewards

Every successful redemption costs 100 points. Citizens choose:

1. **Extra place:** normal daily capacity must be exhausted, and the facility must have an unused `rewardCapacity` place. This separate quota defaults to zero and is set in the facility queue editor. It never reopens a closed or archived queue.
2. **Priority:** requires normal capacity. Within the same queue and time slot, priority tickets precede regular tickets; earlier slots retain precedence. Creation time, then ticket ID, break ties. A currently called ticket is not displaced.

The daily counter stores total `reserved` and `rewardReserved`. Counter changes, booking, points debit and notification commit together. An unsuccessful attempt consumes neither a place nor points. Daily queue and time-slot duplication guards still apply.

## Reports and review

The report screen writes `reports/{id}`. Trusted administrators can resolve a report with the helper below; it preserves points, records the response, and sends a notification. Keep service-account credentials outside the repository. The helper is not automatically run by the app.

```sh
cd scripts
npm install
# Set GOOGLE_APPLICATION_CREDENTIALS to a private service-account file.
node review_citizen_report.mjs REPORT_ID restore 'Your booking access has been restored.'
# Or retain the restriction:
node review_citizen_report.mjs REPORT_ID retain 'Please provide more information.'
```

## Run and deploy

```sh
flutter pub get
flutter analyze
flutter test test/reliability_policy_test.dart test/widget_test.dart
cd scripts
npm install
npm run test:rules
```

Rules tests run exclusively against the local `demo-dawrok` emulator. To activate the feature on the existing Firebase project, publish the bundled rules using an authorized Firebase CLI login:

```sh
firebase deploy --only firestore:rules --project dawrok-f908e
flutter run -t lib/pages/main.dart
```

Deploy rules and updated clients together: older facility clients cannot finalize tickets without the required atomic points update. Existing balances are not fabricated and historical completed tickets are not rescored. The implementation uses Firestore transactions and rules and does not require Cloud Functions. Device-clock skew can cause a transaction at a suspension boundary to be rejected by the server; retry after correcting the clock.

## Validation (2026-11-17)

Firestore emulator checks passed for normal bookings, welcome persistence, first-time balance creation, duplicate-score denial, suspension/review, report submission, fraudulent redemptions, concurrent last reward place, employee scoring and existing staff/facility permissions. Five retained Flutter unit/widget tests passed; a temporary sixth test captured both home states for visual inspection at 393×1066. Queue schedule regression checks also passed. Flutter analysis found no errors in the application; existing warnings and SDK deprecation/style notices remain. No production Firebase rules deployment or physical-device test was performed in this workspace.
