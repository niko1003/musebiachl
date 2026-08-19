# Changelog

Notable changes to musebiachl, the Flutter app that displays sheet music to
individual musicians. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the `version`
field in `pubspec.yaml` (`<semver>+<build number>`).

Dates before 1.7.0 are reconstructed from git history, so older entries summarise what
the commits show rather than what was released as a formal changelog at the time.

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
