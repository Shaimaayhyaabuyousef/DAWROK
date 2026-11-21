# Reports for citizens, facilities and employees

The shared `ReportScreen` matches the supplied initial, facility and app-report layouts. Settings for all roles use the `report` route; `citizen_report` remains an alias used by points/restriction review.

## Account permissions

- Citizens choose app or facility reports. A facility report requires a real active facility selected from Firestore (including facilities currently offline).
- Active facility owners and approved active staff can send app reports only. Role and workplace are resolved from the signed-in user's profile or staff membership, never accepted from navigation arguments.
- Firestore independently enforces the same role/type/target relationship. A target facility cannot read reports about it.
- The anonymous toggle hides identity from the target facility. It is not anonymous authentication: reports remain linked to their author for administration and follow-up, as explained in the form. All reports and attachments are private to their author and administrators.

## Data and attachments

`reports/{id}` stores `uid`, `reporterRole`, `reporterFacilityId`, `type` (`app` or `facility`), `facilityId`, `facilityName`, `message` (10–500 characters), `anonymous`, `hasPhoto`, `status` (`open` initially), and server `createdAt`.

An optional single JPEG is saved to `reports/{id}/attachments/photo` with `bytes`, `contentType` and server `createdAt`. It is resized/re-encoded, stripped of source metadata, and limited to 200,000 bytes. This uses Firestore on Spark without Firebase Storage. Attachment bytes are excluded from indexing in `firestore.indexes.json`. Firestore free-plan quotas still apply.

Report and photo commit atomically. Failed sends keep the form; retries reuse the same report ID, so a lost acknowledgement cannot create duplicate reports. Reports/attachments are immutable to ordinary clients. Administration may resolve and respond.

The microphone dictates text into the description; it does not attach an audio recording. Recognition uses the device's speech service and language, may need connectivity, and depends on microphone/speech permissions. Unsupported or denied devices show an error and retain typing. Photo and speech permissions are configured for Android, iOS and macOS. Actual device permission flows require device testing.

## Administration

The existing trusted helper supports all report roles:

```sh
# Set GOOGLE_APPLICATION_CREDENTIALS to a private service-account file.
cd scripts
npm install
node review_citizen_report.mjs REPORT_ID resolve 'Your report has been reviewed.'
```

`restore` and `retain` remain available for citizen restriction reviews only. `resolve` is the ordinary response action for any role. Responses are stored on the report; citizen notifications use `citizen_accounts/{uid}/events`, and facility/employee notifications use `users/{uid}/notifications` for their future notification interfaces. The helper is not run automatically by the application.

## Validation and activation

```sh
flutter pub get
flutter test test/report_screen_test.dart test/widget_test.dart test/reliability_policy_test.dart
cd scripts
npm install
npm run test:rules
```

From the repository root, with authorized Firebase CLI credentials:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project dawrok-f908e
flutter run -t lib/pages/main.dart
```

No production deployment is performed by the tests. Existing reports remain readable, but new reports must use the new schema. Update clients and rules together.

Validation on 2026-11-18: all 11 retained Flutter unit/widget tests passed. A temporary visual test also captured the three supplied report states at 393×852. Firestore emulator suites passed for role restrictions, facility identity, private reads, report length/status validation, atomic bounded photos, report responses and existing booking/staff flows. Flutter analysis found no errors; pre-existing warnings and SDK/style notices remain. Camera and speech permissions have not been exercised on a physical device. Firebase CLI reported no authorized account, so production rules/indexes have not been deployed.
