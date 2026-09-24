import 'package:flutter_test/flutter_test.dart';

import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/service/offline_store.dart';
import 'package:musebiachl/service/remote_service.dart';

/// The bookkeeping behind "offline verfügbar".
///
/// The download itself needs a server and a device to be worth testing; what is worth
/// testing without either is the part that decides what the player is shown - and the
/// cache key, which is the whole contract between this store and ScorePage.
void main() {
  OfflineSelection saved({
    int pieceCount = 3,
    int pages = 4,
    List<String>? keys,
  }) =>
      OfflineSelection(
        collectionId: 7,
        collectionName: 'Marschbuch 2026',
        kind: SelectionKind.notation,
        selectionId: 'c0ffee',
        label: '1. in B',
        pieceCount: pieceCount,
        pages: pages,
        keys: keys ?? const ['11-100', '12-100', '13-100', '14-100'],
        bytes: 4 * 1024 * 1024,
        savedAt: DateTime(2026, 9, 24).millisecondsSinceEpoch,
      );

  CollectionSelection line({int pieceCount = 3}) => CollectionSelection(
        kind: SelectionKind.notation,
        id: 'c0ffee',
        label: '1. in B',
        pieceCount: pieceCount,
      );

  test('the key is the id and the revision, as ScorePage builds it', () {
    expect(OfflineStore.imageKey(4711, 1758700000000), '4711-1758700000000');
    expect(
      OfflineStore.imageUrl(4711, 1758700000000),
      '${RemoteServices.baseUrl}/file/image/4711?v=1758700000000',
    );
  });

  test('a record survives the index it is written to', () {
    final OfflineSelection read = OfflineSelection.fromJson(saved().toJson());

    expect(read.id, saved().id);
    expect(read.collectionName, 'Marschbuch 2026');
    expect(read.kind, SelectionKind.notation);
    expect(read.keys, hasLength(4));
    expect(read.savedLabel, '24.09.2026');
    expect(read.sizeLabel, '4,0 MB');
  });

  test('a stopped download is not a Stimme that is here', () {
    expect(saved().complete, isTrue);
    expect(saved(keys: const ['11-100', '12-100']).complete, isFalse);
  });

  test('a page is only held under the revision it was downloaded with', () {
    expect(saved().holds('12-100'), isTrue);

    // Rotated on the server since: same page, new picture, and the device has the old one.
    expect(saved().holds('12-200'), isFalse);
    expect(saved().missesAnyOf(const ['11-100', '12-200']), isTrue);
    expect(saved().missesAnyOf(const ['11-100', '12-100']), isFalse);
  });

  test('a piece added to the Mappe makes the copy outdated', () {
    expect(saved().outdatedFor(line()), isFalse);
    expect(saved().outdatedFor(line(pieceCount: 4)), isTrue);
  });

  test('sizes are German and never say 0,0 MB for half a megabyte', () {
    expect(formatBytes(512 * 1024), '512 KB');
    expect(formatBytes(1024 * 1024 * 3 + 100 * 1024), '3,1 MB');
    expect(formatBytes(1024 * 1024 * 1024 * 2), '2,0 GB');
  });
}
