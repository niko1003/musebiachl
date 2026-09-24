import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:musebiachl/model/api/collection_composition.dart';
import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/service/offline_files_stub.dart'
    if (dart.library.io) 'package:musebiachl/service/offline_files_io.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';

/// The pages themselves, on this device.
///
/// A singleton, as flutter_cache_manager requires: two managers over one key are two
/// sqlite handles on the same database.
///
/// It replaces `DefaultCacheManager`, which ScorePage used to get by default, for two
/// reasons. Its ceiling is 200 files and its expiry 30 days, so a 96-page Marschbuch made
/// available offline in September would be half gone by the concert - the oldest files are
/// dropped as soon as the next Mappe is opened. And it keeps them in the temporary
/// directory (see offline_files_io.dart). Neither is wrong for a picture that can be
/// fetched again; both are wrong for the copy a player is relying on.
class MusePages extends CacheManager with ImageCacheManager {
  static const String key = 'muse-pages';

  /// High enough that nothing a wind orchestra owns reaches it, and long enough that
  /// expiry never removes a page: what is here was asked for, and goes when it is
  /// removed.
  static const Duration _stalePeriod = Duration(days: 3650);
  static const int _maxObjects = 20000;

  static final MusePages _instance = MusePages._();

  factory MusePages() => _instance;

  MusePages._()
      : super(offlinePagesConfig(
          key,
          stalePeriod: _stalePeriod,
          maxNrOfCacheObjects: _maxObjects,
        ));
}

/// One line of one Sammlung, as it sits on this device.
class OfflineSelection {
  OfflineSelection({
    required this.collectionId,
    required this.collectionName,
    required this.kind,
    required this.selectionId,
    required this.label,
    required this.pieceCount,
    required this.pages,
    required this.keys,
    required this.bytes,
    required this.savedAt,
  });

  final int collectionId;
  final String collectionName;
  final SelectionKind kind;
  final String selectionId;
  final String label;

  /// The Stückzahl the pick screen showed when this was saved.
  ///
  /// The cheap staleness signal: that screen knows every line's Stückzahl without loading
  /// a single page, so a piece added to the Mappe since can be pointed out there.
  final int pieceCount;

  /// How many pages this line has, and which of them are really on the device. They differ
  /// when a download was stopped or a page would not come - "8 von 12 Seiten" is the only
  /// honest thing to show then.
  final int pages;
  final List<String> keys;

  final int bytes;
  final int savedAt;

  late final Set<String> _keys = keys.toSet();

  String get id => OfflineStore.idFor(collectionId, kind, selectionId);

  bool get complete => pages > 0 && keys.length >= pages;

  /// Whether the page with this cache key is one of the ones lying here.
  bool holds(String key) => _keys.contains(key);

  /// Pages were added to or taken out of this line since it was saved.
  bool outdatedFor(CollectionSelection selection) => selection.pieceCount != pieceCount;

  /// Pages of this line the device does not have - what CollectionPage can work out, and
  /// the pick screen cannot, because only here is the piece list at hand.
  bool missesAnyOf(Iterable<String> currentKeys) =>
      currentKeys.any((String key) => !_keys.contains(key));

  String get sizeLabel => formatBytes(bytes);

  String get savedLabel {
    final DateTime when = DateTime.fromMillisecondsSinceEpoch(savedAt);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(when.day)}.${two(when.month)}.${when.year}';
  }

  factory OfflineSelection.fromJson(Map<String, dynamic> json) => OfflineSelection(
        collectionId: json["collectionId"],
        collectionName: json["collectionName"] ?? '',
        kind: SelectionKind.fromKey(json["kind"]),
        selectionId: json["selectionId"],
        label: json["label"] ?? '',
        pieceCount: json["pieceCount"] ?? 0,
        pages: json["pages"] ?? 0,
        keys: List<String>.from(json["keys"] ?? const <String>[]),
        bytes: json["bytes"] ?? 0,
        savedAt: json["savedAt"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "collectionId": collectionId,
        "collectionName": collectionName,
        "kind": kind.key,
        "selectionId": selectionId,
        "label": label,
        "pieceCount": pieceCount,
        "pages": pages,
        "keys": keys,
        "bytes": bytes,
        "savedAt": savedAt,
      };
}

/// A download in flight.
class OfflineProgress {
  const OfflineProgress({this.done = 0, this.failed = 0, this.total = 0});

  final int done;
  final int failed;
  final int total;

  int get handled => done + failed;

  /// Null while the piece list is still being asked for - there is no total yet, and an
  /// indeterminate spinner says exactly that.
  double? get fraction => total == 0 ? null : handled / total;
}

/// Which Stimmen have been taken along, and the downloading of them.
///
/// All of it is static on purpose: one index, one set of downloads running, for the whole
/// process. A download outlives the screen that started it - somebody who taps it and
/// walks into the Sammlung should find the pages arriving, not a cancelled request - so it
/// cannot live in a State.
///
/// [changes] fires on every step of that: a page arriving, a download finishing, a Stimme
/// being removed. Every screen that shows offline state rebuilds on it.
class OfflineStore {
  OfflineStore._();

  static const String _indexKey = 'offline-selections';
  static const String _flushedKey = 'muse-pages-replaced-default';

  static final Map<String, OfflineSelection> _saved = <String, OfflineSelection>{};
  static final Map<String, OfflineProgress> _running = <String, OfflineProgress>{};
  static final Set<String> _cancelled = <String>{};

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<void>? _loading;

  /// How many pages are fetched at once. A Marschbuch is 90 of them and each is a whole
  /// round trip; one at a time makes a player watch a progress bar for a minute, and all
  /// of them at once is a denial of service against our own little server.
  static const int _atOnce = 3;

  static String idFor(int collectionId, SelectionKind kind, String selectionId) =>
      '$collectionId/${kind.key}/$selectionId';

  static String imageUrl(int imageId, int revision) =>
      '${RemoteServices.baseUrl}/file/image/$imageId?v=$revision';

  /// The same key ScorePage puts on the image provider, which is the whole point: a page
  /// downloaded here is a page that screen then finds without a network.
  static String imageKey(int imageId, int revision) => '$imageId-$revision';

  /// Reads the index once. Idempotent, and safe to await from several pages at once.
  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String stored = prefs.getString(_indexKey) ?? '';
    if (stored.isNotEmpty) {
      try {
        for (final dynamic entry in json.decode(stored) as List<dynamic>) {
          final OfflineSelection saved = OfflineSelection.fromJson(entry);
          _saved[saved.id] = saved;
        }
      } catch (_) {
        // An index this version cannot read is not worth taking the app down for. The
        // pages are still on disk and making the Stimme available again rewrites it.
      }
    }

    // Not awaited: the first list on screen is waiting for this method, and emptying a
    // directory full of scans is not something it should wait for.
    unawaited(_flushDefaultCache(prefs));
  }

  /// Everything ScorePage had looked at before 1.13.0 sits in DefaultCacheManager's
  /// directory, which nothing reads any more. Emptying it once gives the phone back what
  /// can be tens of megabytes of scans.
  static Future<void> _flushDefaultCache(SharedPreferences prefs) async {
    if (prefs.getBool(_flushedKey) ?? false) return;

    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Nothing here is worth a failed start.
    }
    await prefs.setBool(_flushedKey, true);
  }

  static OfflineSelection? of(int collectionId, SelectionKind kind, String selectionId) =>
      _saved[idFor(collectionId, kind, selectionId)];

  static OfflineSelection? forSelection(int collectionId, CollectionSelection selection) =>
      of(collectionId, selection.kind, selection.id);

  /// What this Sammlung has on the device, in the order it was taken along.
  static List<OfflineSelection> inCollection(int collectionId) => _saved.values
      .where((OfflineSelection saved) => saved.collectionId == collectionId)
      .toList()
    ..sort((OfflineSelection a, OfflineSelection b) => a.savedAt.compareTo(b.savedAt));

  static OfflineProgress? progressOf(int collectionId, CollectionSelection selection) =>
      _running[idFor(collectionId, selection.kind, selection.id)];

  static int get totalBytes =>
      _saved.values.fold(0, (int sum, OfflineSelection saved) => sum + saved.bytes);

  /// Stops a download. What has arrived stays: eight pages of a Marschbuch are eight pages
  /// of a Marschbuch, and the record says so rather than pretending to be whole.
  static void cancel(int collectionId, CollectionSelection selection) {
    final String id = idFor(collectionId, selection.kind, selection.id);
    if (!_running.containsKey(id)) return;

    _cancelled.add(id);
    _fire();
  }

  /// Takes a whole Stimme of a Sammlung along: its piece list and every page of it.
  ///
  /// Returns null when everything arrived, and the reason otherwise - the caller decides
  /// whether that is worth a red bar. Never throws: this is started by a button on a
  /// screen the player may well have left by the time it finishes.
  static Future<String?> download({
    required int collectionId,
    required String collectionName,
    required CollectionSelection selection,
  }) async {
    final String id = idFor(collectionId, selection.kind, selection.id);
    if (_running.containsKey(id)) return null;

    _cancelled.remove(id);
    _running[id] = const OfflineProgress();
    _fire();

    try {
      // The piece list first: it is what says which pages the Stimme has, and it is what
      // CollectionPage reads when there is no signal. Fresh from the server, because
      // making a Mappe available offline is something done *with* a signal - the cached
      // copy is only there so a retry after a lost connection still saves the pages.
      List<CollectionComposition>? listed;
      try {
        listed = await RemoteServices()
            .fetchPieces(collectionId, selection.kind, selection.id);
      } on SessionExpiredException {
        // The one failure that is not "offline". The rule is the app's oldest: a 401 from
        // the backend ends the session, wherever it arrived - and the cached piece list is
        // no use if the account behind it is gone.
        await endSession(reason: sessionRejectedMessage);
        return sessionRejectedMessage;
      } catch (e) {
        listed = await RemoteServices()
            .cachedPieces(collectionId, selection.kind, selection.id);
        if (listed == null) return e.toString();
      }
      final List<CollectionComposition> pieces = listed ?? const [];

      // One entry per page, in reading order, without the duplicates a piece listed under
      // both a Heft and its own title would otherwise produce.
      final Map<String, _Page> wanted = <String, _Page>{};
      for (final CollectionComposition row in pieces) {
        if (row.imageId == 0) continue; // the server's placeholder for "no page"
        final _Page page = _Page(row.imageId, row.imageRevision);
        wanted[page.key] = page;
      }

      if (wanted.isEmpty) {
        return 'Für ${selection.label} gibt es hier keine Seiten.';
      }

      final List<_Page> pages = wanted.values.toList();
      _running[id] = OfflineProgress(total: pages.length);
      _fire();

      int done = 0;
      int failed = 0;
      String? lastError;

      int next = 0;
      Future<void> worker() async {
        while (true) {
          if (_cancelled.contains(id)) return;

          final int index = next++;
          if (index >= pages.length) return;

          final _Page page = pages[index];
          try {
            await MusePages().downloadFile(page.url, key: page.key);
            done++;
          } catch (e) {
            failed++;
            lastError = e.toString();
          }

          _running[id] =
              OfflineProgress(done: done, failed: failed, total: pages.length);
          _fire();
        }
      }

      await Future.wait(List<Future<void>>.generate(_atOnce, (_) => worker()));

      // What is really lying here, asked of the store rather than counted from this run.
      // That is what makes a download somebody stopped and started again add up instead
      // of forgetting the pages the first attempt had already fetched.
      List<String> have = <String>[];
      int bytes = 0;
      for (final _Page page in pages) {
        final FileInfo? info = await MusePages().getFileFromCache(page.key);
        if (info == null || !await info.file.exists()) continue;
        have.add(page.key);
        bytes += await info.file.length();
      }

      // A store that cannot say what it holds is not a store that holds nothing. In the
      // browser there is no directory and no database behind MusePages, so the answer
      // above is empty however well the download went; the run's own count is then the
      // best thing there is. On a device the two agree, and if they ever did not, the
      // next download would correct the record anyway.
      if (have.isEmpty && done > 0) {
        have = [for (int i = 0; i < done && i < pages.length; i++) pages[i].key];
      }

      final OfflineSelection? previous = _saved[id];
      final OfflineSelection saved = OfflineSelection(
        collectionId: collectionId,
        collectionName: collectionName,
        kind: selection.kind,
        selectionId: selection.id,
        label: selection.label,
        pieceCount: selection.pieceCount,
        pages: pages.length,
        keys: have,
        bytes: bytes,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );

      _saved[id] = saved;
      await _persist();

      // A page that was rotated or scanned again keeps its id and changes its revision,
      // so the copy under the old key is a picture of nothing now. Nobody else would ever
      // clear it: this store has no expiry, on purpose. Keyed on what the Stimme *has*
      // and not on what this run fetched - a download that was stopped after two pages
      // must not take the other seventy-eight with it.
      if (previous != null) {
        for (final String old in previous.keys) {
          if (!wanted.containsKey(old)) {
            await MusePages().removeFile(old);
          }
        }
      }

      if (_cancelled.contains(id)) {
        return 'Abgebrochen bei ${have.length} von ${pages.length} Seiten.';
      }
      if (failed > 0) {
        return '$failed von ${pages.length} Seiten fehlen - nochmal versuchen. ($lastError)';
      }
      return null;
    } finally {
      _running.remove(id);
      _cancelled.remove(id);
      _fire();
    }
  }

  /// Gives the space back, and with it the promise: what is not here is not offline.
  static Future<void> remove(OfflineSelection saved) async {
    for (final String key in saved.keys) {
      try {
        await MusePages().removeFile(key);
      } catch (_) {
        // A file already gone is the state we were after anyway.
      }
    }

    _saved.remove(saved.id);
    await _persist();
    _fire();
  }

  static Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      json.encode(_saved.values.map((OfflineSelection e) => e.toJson()).toList()),
    );
  }

  static void _fire() => changes.value++;
}

/// One page of a scan, as it is asked for and as it is stored.
class _Page {
  _Page(this.imageId, this.revision);

  final int imageId;
  final int revision;

  String get key => OfflineStore.imageKey(imageId, revision);
  String get url => OfflineStore.imageUrl(imageId, revision);
}

/// "4,2 MB" - German decimal comma, and no intl package for one number.
String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / 1024).round()} KB';
}
