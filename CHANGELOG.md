# Changelog

Notable changes to musebiachl, the Flutter app that displays sheet music to
individual musicians. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the `version`
field in `pubspec.yaml` (`<semver>+<build number>`).

Dates before 1.7.0 are reconstructed from git history, so older entries summarise what
the commits show rather than what was released as a formal changelog at the time.

## [1.12.0+29] — 2026-09-24

Needs muse-server 4.37.0.

### Changed
- **The Mappe comes first, and the Stimme second.** The app used to open on an instrument
  picker and show no music until one was chosen; now it opens on the Sammlungen, and
  tapping one asks which line of *that* Mappe to read.

  That is the order the question actually has. Which Mappe is on the stand is what a player
  knows; which Stimme they read is a question only that Mappe can pose — a Marschbuch whose
  pages carry "1. in B" has no opinion about instruments at all, and somebody who reads the
  1. in one Mappe is routinely handed the 3. in the next.

  The pick screen offers **what the Sammlung really holds** (`/app/collection/{id}/selections`):
  its Stimmen, its instruments, its registers, each with the number of pages carrying that
  assignment. Nothing is guessed and nothing is invented.

- **A player says what they play, once, and it belongs to their account.** The second tab
  is **Mein Instrument**: a register — Flügelhorn, Klarinette, Schlagwerk — and optionally
  the exact instrument. It is stored on the account (`/app/profile`), not on the phone, so
  a new device finds it again and the admin can set it over the telephone.

  In every Sammlung that register is listed **first**, with that instrument at the top of
  it. It deliberately does not pick a Stimme: no register says whether somebody plays the
  1. or the 3., so a Stimmen-assigned Mappe is a decision every time. What the app does
  remember is the line picked in that Mappe last time, marked *zuletzt* — a hint, not an
  answer.

  An `instrumentId` left behind by 1.11.0 is adopted as the favorite on first start, so
  upgrading does not lose what somebody picked.

- **The whole UI has been reworked.** Material 3 in brass rather than the framework's blue,
  a dark theme that follows the device — a phone on a music stand in a darkened hall is the
  normal case — section headers, icons per Sammlungsart, a search box on the Sammlungen and
  on the pieces of a Mappe, and real empty states instead of a blank list. ScorePage is
  untouched: it paints its own black viewer and always did.

- **A Heft in a Sammlung is its pieces, not 80 pages.** A Sammlung holds a Heft by holding
  its scan, so Kirchenblech used to be *one* row: opening it put you on page 1 and the
  Deutsche Messe was six swipes away, during the piece. Its pieces are now listed under it
  as a collapsible row — and when the Sammlung is nothing but that one Heft, the Heft is
  skipped and its pieces *are* the list. Each is numbered by its place in the printed index
  and opens at its own pages. Pages nobody has cut into a piece yet come last as
  *Weitere Seiten*; a Heft nothing has been cut out of stays the single row it was.

- **The pick screen counts Stücke, not Seiten.** "15 Seiten" was the wrong question — a part
  runs over two sheets often enough that counting paper says nothing, and for a Heft the
  number that means something is how many pieces are printed in it.

- **⇄ in the Mappe swaps Stimme** without walking back through the Sammlungen.

### Removed
- The Instrumente tab, and with it the rule that nothing could be opened before an
  instrument was chosen.

## [1.11.0+25] — 2026-08-25

### Added
- **A pencil and an eraser on a page.** `ScorePage` can be marked up the way paper
  always could — a breath, a cut, the repeat that catches you out. The marks are
  private to the player, belong to the *page*, and are stored per user by the backend
  (`/app/drawing`), so a new phone finds them again.

  The pencil freezes the view exactly as the Lock button does; you cannot zoom and
  draw at once, or every line would drag the page too. The eraser lifts whole strokes
  rather than rubbing holes in them.

  Every stroke writes the device copy immediately and the server copy goes up when the
  pencil is put down, on a page turn and on leaving. Anything drawn offline goes **up**
  before anything comes down, so the server cannot overwrite marks it has not seen.
  Marks drawn against an older revision of a page — rotate, crop and tile all rewrite a
  page while keeping its id — are hidden rather than laid over music they no longer fit.

- **A way out.** A logout button in both Home tabs, asking first and naming who the
  device is logged in as, because logging back in needs a signal.

### Fixed
- **A rejected token stranded the app.** There was no path back to the login screen:
  `LoginPage` jumped straight to `HomePage` on any stored token, and a rejected one
  produced an error bar for ever. A 401/403 now ends the session and returns to the
  login screen with a line saying why — and *only* a 401/403 or the logout button does.
  A timeout, a 500 or no signal at all leave the session alone, because being thrown
  out to a login screen you cannot get past without reception is worse than any error.

  The status code matters: an invalid token on `/app/**` answers **401**, not the 403
  the security config configures — `AbstractAuthenticationProcessingFilter`'s failure
  handler replies first.

- **Non-200 responses could crash on being read.** `ServerException.fromJson` called
  `json.decode` straight out and assigned `message` to a non-nullable String. A rejected
  token gets Boot's own error JSON, which has no `message` at all, so the one response
  the app most needed to understand threw a `TypeError`. Replaced by
  `messageForResponse`, which also survives Apache's HTML and an empty body.

- The username field said "Username" with a mail icon and autocapitalised the first
  letter of a case-sensitive username. It is a username; there is no e-mail anywhere in
  the model.

## [1.9.0+23] — 2026-08-19

### Changed
- **Konzertmappe → Collection**, following muse-server 4.0.0: `/app/folder/` →
  `/app/collection/`, and every `folder*.dart` renamed to `collection*.dart`. The
  SharedPreferences cache keys change with them (`folders` → `collections`), so the
  first launch after the update refetches instead of reading a stale cache.
- **The collection list is grouped by type** — Konzertmappen, Marschbücher, Sammlungen,
  Hefte — from the new `type` field. An unknown or missing type falls back to
  Konzertmappe, so the app still works against an older server.

### Removed
- The folder `version` field; the list label is now just the name.


## [1.8.0+22] — 2026-08-18

### Changed
- **You now pick an instrument, not a musician.** The first tab lists instruments
  grouped by instrument group as expandable sections, with the group holding the current
  selection opened automatically. Musicians changed too often to be a useful selector.
- The selection is persisted as `instrumentId` (a UUID string) instead of `musicianId`
  (an int), and folder data is cached per instrument.
- Reads `GET /app/instrument` and
  `GET /app/folder/{id}/find-for-instrument?instrumentId=…`.

### Removed
- `users_page.dart` and the `Musician` model, replaced by `instruments_page.dart` and
  `InstrumentGroup` / `Instrument`.
- `musicianId` and `optionalInstrument` from `FolderComposition`. "Optional" instruments
  were a property of a musician, so the concept no longer exists.

### Breaking
- Requires muse-server 3.3.0; this version cannot talk to 3.2.0 or earlier.
- On upgrade nothing is selected until the player picks an instrument once. The old
  cached folder entries keyed by musician are simply never read again.

## [1.7.0+21] — 2026-08-18

### Changed
- **Migrated from Dart 2 to Dart 3.** The SDK constraint moved from
  `">=2.16.2 <3.0.0"` to `^3.11.0` (plus `flutter: ">=3.41.0"`), which every current
  package version requires. No source changes were needed — the code was already
  null-safe.
- http 1.1.2 → 1.6.0, shared_preferences 2.0.15 → 2.5.5, wakelock_plus 1.2.0 → 1.7.0,
  cached_network_image 3.2.1 → 3.4.1, photo_view 0.14.0 → 0.15.0,
  cupertino_icons 1.0.2 → 1.0.9, flutter_lints 3.0.1 → 6.0.0,
  flutter_launcher_icons 0.13.1 → 0.14.4. 58 packages changed in total.

### Removed
- `elastic_drawer` — never imported, and hard-capped at Dart `<3.0.0`, so it alone
  blocked the Dart 3 migration.
- `accordion` — never imported. Dropping both also removed `get` and `scroll_to_index`
  as transitive dependencies.

### Known issues
- `assets/images/` is declared in `pubspec.yaml` but does not exist, so every build
  logs an error about the missing directory. Pre-existing.
- `flutter analyze` reports 20 `info`-level lints (`use_super_parameters`,
  `strict_top_level_inference`) newly surfaced by flutter_lints 6. No errors.

## [1.6.2+20] — 2026-01-17

### Fixed
- Deprecated API usages and lint warnings.

### Added
- Back button on the score page.

## [1.5.0+17] — 2025-12-11

### Changed
- Dependency upgrade; replaced the deprecated `wakelock` package with `wakelock_plus`.

### Added
- Podfile with an explicit iOS platform specification.

## [1.4.0+16] — 2023-11-28

### Changed
- Dependency update.

## [1.3.0+15] — 2023-04-12

### Added
- Offline support with data caching.

### Changed
- Removed logging.

## [1.2.0+14] — 2023-03-30

Release.

## [1.1.2+13] — 2022-09-04

### Added
- Timeout and server exception handling.

## [1.1.0+11] — 2022-09-01

### Added
- Keep the screen awake on the score page; lock button.
- iPad rotation support; portrait lock elsewhere.
- Android signing key.

### Changed
- Simplified the login page.

### Fixed
- Login.
