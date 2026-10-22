# Community reporting

## Using the app

- **Reports → All reports** opens the community feed, including for new accounts. Choose highest priority or nearest first. Reading public reports does not require location permission.
- Tap an issue for its photo, category, description, civic location, status, priority, confirmation count and resolution progress. Reporter identities, PDFs and voice recordings are private. **My reports** retains the owner's full details and PDF/audio actions; authorized authorities retain access.
- **I see this too** on a card or detail page confirms the issue once per account. A fresh position within **500 metres** is required. The original reporter already counts as one person. Repeated taps cannot inflate counts.
- **Report as resolved** requires a fresh position within **200 metres**. Add an optional note and take/select a repair photo, or submit without a photo. Pending or unsuccessful photo evidence can be replaced with a clearer photo.
- Submission checks active issues within 100 metres before generating a PDF or uploading. It offers an existing issue only when an issue keyword matches exactly (ignoring case and punctuation); category synonyms are not inferred. The backend repeats the check under a concurrency lock.
- **Analytics → Community impact** shows real totals across the app. **My impact** shows personal statistics. Community information remains available when you have no personal submissions.

Public descriptions and photos should contain civic information; the app does not automatically redact personal information within user-authored content.

## Priority and resolution

Priority starts from issue type and available visual severity. Distinct nearby confirmations add `min(40, 12 × log2(people))`, rounded with the baseline and capped at 100. Each account contributes once. The baseline and community contribution are explained on the issue page.

For resolution, the original reporter contributes 3 points and another nearby account contributes 1. A verified repair photo adds 3 points to that person's contribution. Verification compares the original and new scene, requires every reported issue to be repaired, and requires at least 80% model confidence. File presence alone receives no photo bonus. Unavailable verification remains pending.

An issue resolves for everyone when the original reporter contributes and a verified repair photo exists, or when at least two distinct nearby accounts contribute at least 5 total points. For example, the original reporter's verified repair photo can resolve it; their text alone cannot. Five independent nearby text contributions can also resolve it. Status and history update atomically. Authority resolutions retain their own provenance.

These are account-based signals. GPS can be spoofed and image verification is probabilistic. Pending verification is shown honestly and does not earn photo points.

## Branding and languages

Flutter uses the unmodified `frontend/assets/logo.png`, copied into `flutter/assets/branding/`. Startup uses the original thin green progress indicator style; Android launch artwork and launcher icons use the original mark. No artificial startup delay is added. Notification initialization has an eight-second startup limit, and push-token retrieval has a twelve-second limit so unavailable push services cannot indefinitely block startup or sign-in feedback.

Community reports, evidence controls, duplicate prompts, analytics and explanations support English, Hindi and Marathi. User-authored descriptions remain in their original language. Canonical categories remain stable for matching across UI languages.

## Setup and maintenance

See [Flutter startup and Maps setup](../flutter/README.md) and [backend API, migration and algorithm reference](../backend/COMMUNITY.md).

Run `npm.cmd run migrate:community` from `backend` before deployment. For existing media, run `npm.cmd run migrate:private-media` to preview, then `npm.cmd run migrate:private-media -- --apply` to migrate. The migration preserves originals and hashes in the gitignored backup/journal directory and can resume. Keep archives/backups outside public hosting.

PDF/audio access is checked at the API and Cloudinary origin. New uploads use authenticated delivery. The local database's 13 legacy PDF/audio assets were migrated with byte-integrity checks, and unsigned direct delivery was denied. Owner/authority access uses authenticated backend endpoints; signed cloud URLs are not handed to the app. Public issue photos remain visible.

## Validation

From `flutter`: `flutter analyze`, `flutter test`, and `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/community_flow_test.dart -d DEVICE_ID`.

From `backend`: `npm.cmd run test:all`. Database-backed tests cover simultaneous duplicate submissions, account uniqueness, GPS/radius rejection, priority, photo verification states/upgrades, resolution, public field privacy, private media authorization and analytics. External AI/cloud boundaries are controlled in automated tests; fixtures are cleaned up.

Android integration uses deterministic UI/location fixtures and saves screenshots to `flutter/build/phone-validation/`. This separates repeatable UI validation from database-backed HTTP tests. The available device during this change was an Android emulator; a physical phone was not connected. Live Google map tiles still require the placeholder API key to be replaced. iOS permission descriptions are included, but an iOS build was not run on Windows.

Validation on 15 October 2026: Flutter analyzer clean; all 88 Flutter tests passed; all four backend suites passed; Android community integration passed all cases (five including teardown). English/Hindi/Marathi feed and analytics screenshots were reviewed. Existing 13 private media assets denied unsigned delivery; owner PDF/audio delivery and new authenticated Cloudinary upload round trips were verified. Test logs are in `flutter/build/phone-validation/`.
