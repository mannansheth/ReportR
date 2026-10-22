# Community reports: API and algorithms

Run `npm run migrate:community` once (idempotent, preserving reports/users), then `npm run start:local` (port 5002 unless PORT is provided). New community routes also ensure their additive tables are present. Run `npm run test:all` for database-backed HTTP, concurrency, and isolated external-verification checks. Tests remove their reports, accounts, community rows and private PDF fixtures. They never send real notifications or upload test assets to the cloud.

## Privacy and endpoint contract

All new routes below use `/api/reports` and require Bearer authentication. Owner report/PDF/audio routes stay private; public DTOs deliberately omit account IDs, reporter names/phone numbers, tokens, PDFs, recordings, resolution author IDs and notes. Public photos, issue descriptions and reported civic locations remain visible. `getAllReports` now requires authentication and exposes `isOwner`, never `userID`. `getUserName` is authenticated and returns only the current account.

- `POST /nearbyMatches`: `{category,location:{lat,lng}}` returns `{reports:[publicDTO]}`. This advisory preflight accepts the reported/photo location; it does not confirm anything.
- `GET /community?lat=&lng=&sort=priority|nearby&page=1&limit=20&category=&status=` returns `{reports,total,page,hasMore}`. Limit is capped at 50. Distance sorting is available when both coordinates are present; default sorting is priority, distance, then newest. Invalid reports are excluded.
- `GET /community/:id` returns `{report}`. Invalid reports are visible only to their owner.
- `POST /:id/confirm`: `{location:{lat,lng,accuracy,timestamp}}` returns `{success,alreadyConfirmed,report}`.
- `POST /:id/resolution`: multipart `location` JSON, optional `note` up to 2000 characters and optional `image` (JPEG/PNG/WebP) returns `{success,alreadyVoted,report,resolution}`. Existing text/pending/unverified contributions may be upgraded with a new photo, replacing their prior contribution. Verified contributions and repeats are idempotent.
- `GET /analytics?scope=community|mine` returns real totals, resolved/active/pending/invalid counts, resolutionRate (percentage 0..100), confirmationCount, resolvedWithEvidence, averageResolutionHours (nullable), byStatus, byCategory, byPriority and chronological monthly `{month,count,resolved}`. Community includes all reports, including invalid counts. Feed and analytics batch votes, confirmations and metadata in three queries, rather than querying each report separately.

`publicDTO` fields: `Rid, issue, description, location:{lat,lng,loc}, imageURL, status, createdAt, resolvedAt, priority, baselinePriority, confirmationCount, confirmedByMe, isOwner, distanceMeters, resolutionWeight, resolutionVoters, resolutionOriginalReporterVoted, resolutionVerifiedPhoto, resolutionVotedByMe, myEvidenceState`. Distance is null without a reference position; evidence states are none, pending, not_verified, verified. No other participant identities are exposed.

## Nearby deduplication and consent

Distances use the server's Haversine calculation (Earth radius 6,371,000 m). Active statuses are Issue Raised, Verification pending, In Progress. Common English category synonyms normalize into pothole, garbage, drainage, streetlight, water leak and flooding; unknown category labels normalize deterministically. Multiple comma-separated categories become a sorted unique set.

An existing active report within 100 m is a duplicate when it contains an **exact matching issue keyword** (case and punctuation are ignored; category synonyms are not inferred). For a multi-issue submission, any exact keyword match can surface the existing report. Resolved/invalid reports do not block new reports.

The creation endpoint repeats matching under a connection-owned MySQL advisory lock before verification or any cloud upload. The lock spans the report+metadata+history transaction. This conservative global submission lock prevents simultaneous submissions at geographically different coordinates from creating overlapping duplicates; it trades throughput for consistency. Lock acquisition is bounded to 20 seconds; retryable busy requests return 503. Network uploads currently serialize while that submission lock is held. Confirm/resolution operations use separate short row-locked transactions. The winner uses the same connection for creation, avoiding pool exhaustion from lock waiters.

A duplicate returns HTTP 409 `{success:false,code:'NEARBY_DUPLICATE',message,report:publicDTO}`. No cloud/PDF work is performed for that duplicate and no automatic confirmation occurs. The client asks the person to view/confirm the existing report. An existing same-owner report ID is an idempotent successful retry, not another confirmation. Best-effort cloud rollback cleans newly uploaded assets when a new report fails before commit.

## Unique nearby confirmations and priority

A fresh position is required for confirmations and resolution contributions: accuracy 0..100 m, captured within the preceding five minutes, at most 30 seconds into the future. Timestamp accepts ISO-8601 or epoch milliseconds. The server rechecks positions/radius; coordinates remain client-provided and do not provide GPS anti-spoof guarantees. Deduplication itself uses the reported issue location, independently of this fresh voter position.

Confirmations require a position within 500 m. The original reporter counts as the first confirmation without a separate action; their repeated calls cannot increase it. A composite primary key `(Rid,userID)` ensures each other account counts once, including concurrent/repeated requests. Resolved and invalid reports cannot receive new confirmations.

Priority is an integer 1..100. Type baselines are pothole55, garbage40, drainage60, streetlight45, water leak60, flooding70, other35. The highest category baseline applies to mixed reports. When a valid AI visual severity 1..10 is available, add `round((severity-5)*3)` and clamp baseline to 10..85. This uses visual severity independently of the language of the person's description. If AI is unavailable, use the type baseline without a fabricated severity. Legacy 1..10 priorities are treated as prior visual severity during additive metadata migration.

`priority = min(100, round(baseline + min(40,12*log2(uniqueConfirmationCount))))`.

The original count1 adds zero, growth saturates at40, repeat accounts add nothing. Private owner/authority report views also receive the normalized score.

## Community resolution

A fresh position within **200 m** is required for each contribution. Original reporter text weight=3; each other account text weight=1. A verified repair photo adds3 to that same account's text weight. File presence alone adds **zero**. A unique `(Rid,userID)` vote row prevents replay or repeated photos from multiplying weight.

Verification compares the ORIGINAL report photo and the NEW evidence photo using a repair-specific Gemini prompt. It requires `sameScene=true`, `allIssuesResolved=true`, and confidence at least80 for every issue in a mixed report. An unrelated scene or any remaining defect fails. Original images are downloaded only from the configured own Cloudinary image-upload report folder, over HTTPS, without redirects, with a 10-second timeout and 8 MB bound. New photo verification is bounded to35 seconds. Missing/unavailable originals or AI failures save the contribution as pending with no photo bonus; explicit failed comparisons are not_verified. Images are uploaded outside database transactions. Freshness/status/proximity/uniqueness are rechecked under the row lock afterward. Unused race-losing uploaded images are cleaned up best-effort.

A report becomes Resolved when either:

1. the original reporter has contributed **and** at least one verified photo contribution exists; or
2. total contribution weight is at least5 from at least2 distinct nearby accounts.

Examples: original reporter alone text3 stays open; original3 + two other text1 votes resolves; verified independent photo4 + another text1 resolves; original reporter verified photo6 resolves alone through the first rule. Pending/unverified photos do not qualify for the first rule and contribute only ordinary account text weight. Contributions need not be endorsements first. These are account-based weights, not a claim that accounts uniquely identify human beings.

Resolution updates status, resolvedAt, resolvedBy and history atomically. History source is community; authority resolution workflows remain available. The numerical thresholds are deliberately explicit constants here and in communityRoutes.js rather than hidden AI judgments. They should be changed together with client explanations/tests if product policy changes.

## Known limits

Client positions can be spoofed. Account creation currently uses a device-notification OTP rather than telecom-verified phone ownership, so account uniqueness is not strong identity verification. Photo comparisons are probabilistic and fail closed for bonuses. Public feeds currently load matching report rows before in-memory ranking/pagination; batching avoids N+1 queries but large installations should add geospatial indexes/materialized counters before scaling. The global submit lock is suitable for this prototype's consistency requirements, not high-volume city-wide ingestion.

## Private recordings and PDF assets

Public report photos remain public. Audio uses Cloudinary video/authenticated; PDFs use raw/authenticated with a .pdf public-ID extension. Delivery signatures returned by Cloudinary are stripped before database storage. Signed URLs remain inside the server.

`GET /api/reports/:id/audio` requires Bearer owner/Authority/Admin access, returns audio/mp4 for m4a (or the corresponding actual audio MIME), supports single byte ranges (206/416), bounds downloads to25 MB and sends Cache-Control private,no-store. Flutter downloads it to its private app directory and plays a device file. PDF recovery likewise supports authenticated/private originals and local archival copies.

Existing assets were migrated with Cloudinary rename to_type=authenticated,invalidate=true, preserving bytes and moving to randomized IDs under the same report folder. Official semantics: https://cloudinary.com/documentation/image_upload_api_reference#rename_method and https://cloudinary.com/documentation/control_access_to_media .

- `npm run migrate:private-media`: read-only scoped migration plan.
- `npm run migrate:private-media -- --apply`: apply/resume migration.
- `npm run verify:private-media`: read-only live CDN denial and actual owner-proxy checks, without creating users or sending notifications.
- `npm run test:private-media`: isolated external media plus real MySQL/HTTP tests of upload options, trusted URL parsing, owner/authority privacy and audio ranges.

Original backup bytes and the resumable journal are under gitignored backend/data/private-media-backups/. Originals are backed up before rename; SHA256 equality is checked against signed downloads afterward. Database URLs update only after unsigned authenticated delivery is denied. Destination IDs enter the journal before mutations, allowing interrupted renames to resume. Keep these private backups until normal backup policy covers them; never commit them.

Completed live migration:13 preserved assets (3 recordings,10 PDFs),13/13 unsigned CDN requests denied; old public URLs also denied401/404. Actual owner audio206 and PDF200 worked, anonymous401 and other-account404. An idempotent rerun found0 public assets and13 already authenticated. CDN invalidation cannot retract bytes previously downloaded by someone else.

Additional actual Cloudinary round-trip check (`node scripts/check-live-private-upload.js`, opt-in because it creates then cleans two QA-only assets) verified new authenticated rawPDF and video/audio uploads: unsigned401 and byte-identical signed original downloads. QA assets were removed afterward.
