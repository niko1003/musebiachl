import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/model/arg/collection_arguments.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/model/arg/selection_arguments.dart';
import 'package:musebiachl/service/offline_store.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/auth/login_page.dart';
import 'package:musebiachl/view/collection_page.dart';
import 'package:musebiachl/view/collection_selection_page.dart';
import 'package:musebiachl/view/home_page.dart';
import 'package:musebiachl/view/score_page.dart';

/// The store screenshots, rendered from the real screens.
///
///     flutter test --update-goldens test/brand/store_screenshots_test.dart
///
/// writes `test/brand/goldens/store/<device>/…png`. Every pixel is the app's own widgets
/// in the app's own theme with the app's own fonts; only the *data* is a fixture, and
/// only because there is no account on the production server to take real screenshots
/// with - and no Android SDK on this machine to run the app on a device at all.
///
/// Two things make that possible without a server. The app is cache-first, so seeding
/// SharedPreferences is the same as having opened those screens before; and `baseUrl`
/// points at a port nothing listens on, so every request fails at once and each page
/// takes the offline path it was built for.
void main() {
  const String username = 'anna';

  /// Play wants 16:9 at most; Apple wants exactly 1290x2796 for the 6.7" set.
  const Map<String, ({Size size, double ratio})> devices = {
    'android-1080x1920': (size: Size(1080, 1920), ratio: 2.75),
    'ios-1290x2796': (size: Size(1290, 2796), ratio: 3.0),
  };

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // ScorePage keeps the screen awake, which is a platform channel and therefore not
    // there in a test. Answering it is cheaper than making the page care.
    const String wakelock =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi';
    for (final MapEntry<String, List<Object?>> channel in const {
      '$wakelock.toggle': [null],
      '$wakelock.isEnabled': [false],
    }.entries) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        channel.key,
        (ByteData? message) async =>
            const StandardMessageCodec().encodeMessage(channel.value),
      );
    }

    // Material's own icon font is not loaded in a widget test either, and a screenshot
    // full of empty boxes where the icons should be is no screenshot at all. It ships
    // with the SDK rather than with the app, so it is found through the SDK's own path.
    // dart lives at $FLUTTER/bin/cache/dart-sdk/bin/dart, so the font is four directories
    // up and two back down. Walked rather than hardcoded, because a different SDK
    // checkout would otherwise silently give a screenshot full of empty boxes.
    Directory dir = File(Platform.resolvedExecutable).parent;
    File? icons;
    for (int up = 0; up < 6 && icons == null; up++) {
      final File candidate = File(
          '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (candidate.existsSync()) icons = candidate;
      dir = dir.parent;
    }
    if (icons == null) {
      fail('MaterialIcons-Regular.otf not found under the Flutter SDK - the screenshots '
          'would have a box where every icon belongs.');
    }

    final Uint8List iconBytes = icons.readAsBytesSync();
    await (FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(ByteData.view(iconBytes.buffer))))
        .load();

    for (final MapEntry<String, List<String>> family in const {
      bodyFont: [
        'assets/fonts/FiraSans-Regular.ttf',
        'assets/fonts/FiraSans-Medium.ttf',
        'assets/fonts/FiraSans-SemiBold.ttf',
      ],
      headingFont: ['assets/fonts/NotoSerif-SemiBold.ttf'],
    }.entries) {
      final FontLoader loader = FontLoader(family.key);
      for (final String path in family.value) {
        final Uint8List bytes = File(path).readAsBytesSync();
        loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }

    // Nothing listens on port 9, so every request is refused immediately. That is the
    // path the app is built for, and it is what keeps these screenshots off the network.
    RemoteServices.baseUrl = 'http://127.0.0.1:9';
    RemoteServices.localToken = 'screenshot';

    SharedPreferences.setMockInitialValues(_fixture(username));

    // The page itself, from a booklet rather than from the server.
    final Uint8List page = File('test/brand/fixtures/score-page.png').readAsBytesSync();
    ScorePage.debugImageFor = (int imageId, int revision) => MemoryImage(page);

    await OfflineStore.load();
  });

  for (final MapEntry<String, ({Size size, double ratio})> device in devices.entries) {
    Future<void> shoot(
      WidgetTester tester,
      String name,
      Widget home, {
      Future<void> Function(WidgetTester tester)? then,
    }) async {
      tester.view.physicalSize = device.value.size;
      tester.view.devicePixelRatio = device.value.ratio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: museTheme(Brightness.light),
        onGenerateRoute: (settings) => _route(settings),
        home: home,
      ));

      // Reading the cache, having the request refused and decoding the page are all real
      // asynchronous work, and a widget test's clock is fake - pump() alone never gets to
      // any of it. runAsync lets the real ones happen; the pump after each shows them.
      await _settle(tester);
      if (then != null) {
        await then(tester);
        await _settle(tester);
      }

      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/store/${device.key}/$name.png'));
    }

    group(device.key, () {
      testWidgets('01 Sammlungen', (tester) async {
        await shoot(tester, '01-sammlungen', const HomePage(authToken: 'x'));
      });

      testWidgets('02 Stimme wählen', (tester) async {
        await shoot(tester, '02-stimme-waehlen',
            const CollectionSelectionPage(id: 1, name: 'Marschbuch 2026'));
      });

      testWidgets('03 die Mappe', (tester) async {
        await shoot(
          tester,
          '03-mappe',
          CollectionPage(
            id: 1,
            name: 'Marschbuch 2026',
            selection: CollectionSelection(
              kind: SelectionKind.notation,
              id: 'stimme-1',
              label: '1. in B',
              pieceCount: 9,
            ),
          ),
        );
      });

      testWidgets('04 die Noten', (tester) async {
        await shoot(
          tester,
          '04-noten',
          const ScorePage(
            imageIds: [9001, 9002],
            imageRevisions: [1758000000000, 1758000000000],
            title: 'Air aus der Suite Nr. 3',
          ),
        );
      });

      testWidgets('05 mein Instrument', (tester) async {
        await shoot(
          tester,
          '05-mein-instrument',
          const HomePage(authToken: 'x'),
          then: (tester) async {
            await tester.tap(find.text('Mein Instrument'));
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
          },
        );
      });

      testWidgets('06 Anmelden', (tester) async {
        SharedPreferences.setMockInitialValues(
            Map<String, Object>.from(_fixture(username))..remove('token'));
        await shoot(tester, '06-anmelden', const LoginPage());
      });
    });
  }
}

/// Real time, then a frame, until the screen has stopped changing.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Route<dynamic>? _route(RouteSettings settings) {
  if (settings.name == CollectionSelectionPage.routeName) {
    final SelectionArguments args = settings.arguments as SelectionArguments;
    return MaterialPageRoute(
        builder: (_) => CollectionSelectionPage(id: args.id, name: args.name));
  }
  if (settings.name == CollectionPage.routeName) {
    final CollectionArguments args = settings.arguments as CollectionArguments;
    return MaterialPageRoute(
        builder: (_) =>
            CollectionPage(id: args.id, name: args.name, selection: args.selection));
  }
  if (settings.name == ScorePage.routeName) {
    final ScoreArguments args = settings.arguments as ScoreArguments;
    return MaterialPageRoute(
        builder: (_) => ScorePage(
            imageIds: args.imageIds,
            imageRevisions: args.imageRevisions,
            index: args.index,
            title: args.title));
  }
  return null;
}

// --- the fixture ---------------------------------------------------------------------
//
// Mappen and pieces a wind orchestra really has, so the screenshots show the app doing
// its job rather than "Lorem ipsum 1".

const int _revision = 1758000000000;

String _key(int imageId) => '$imageId-$_revision';

Map<String, Object> _fixture(String username) {
  final List<Map<String, Object?>> marschbuch = [
    _piece('Dem Land Tirol die Treue', 1, 9001, notes: 'Marsch'),
    _piece('Dem Land Tirol die Treue', 1, 9002, page: 2, notes: 'Marsch'),
    _piece('Mein Heimatland', 2, 9003),
    _piece('Egerländer Musikantenmarsch', 3, 9004),
    _piece('Böhmischer Traum', 4, 9005, notes: 'Polka'),
    _piece('Böhmischer Traum', 4, 9006, page: 2, notes: 'Polka'),
    _piece('Alte Kameraden', 5, 9007),
    _piece('Mühlviertler Landler', 6, 9011),
    _piece('Air aus der Suite Nr. 3', 7, 9008, booklet: 'Kirchenblech', inBooklet: 1),
    _piece('In Gedanken bin i bei dir', 8, 9009, booklet: 'Kirchenblech', inBooklet: 2),
    _piece('Großer Gott, wir loben dich', 9, 9010, booklet: 'Kirchenblech', inBooklet: 3),
  ];

  final List<String> offlineKeys = [
    for (final Map<String, Object?> row in marschbuch)
      if ((row['imageId'] as int) != 0) _key(row['imageId'] as int)
  ];

  return <String, Object>{
    'token': 'screenshot',
    'username': username,
    'muse-pages-replaced-default': true,

    'collections': json.encode([
      {'id': 1, 'name': 'Marschbuch 2026', 'type': 'MARCH_BOOK'},
      {'id': 2, 'name': 'Frühjahrskonzert 2026', 'type': 'CONCERT_FOLDER'},
      {'id': 3, 'name': 'Kirchliche Anlässe', 'type': 'CONCERT_FOLDER'},
      {'id': 4, 'name': 'Ständchen', 'type': 'ANTHOLOGY'},
      {'id': 5, 'name': 'Kirchenblech', 'type': 'BOOKLET'},
    ]),

    'selections-1': json.encode([
      _line('NOTATION', 'stimme-1', '1. in B', 9),
      _line('NOTATION', 'stimme-2', '2. in B', 9),
      _line('NOTATION', 'stimme-3', '3. in B', 8),
      _line('INSTRUMENT', 'fluegel-1', '1. Flügelhorn in B', 9,
          registerId: 'reg-fluegel', registerLabel: 'Flügelhorn', registerOrder: 3),
      _line('INSTRUMENT', 'fluegel-2', '2. Flügelhorn in B', 9,
          registerId: 'reg-fluegel', registerLabel: 'Flügelhorn', registerOrder: 3),
      _line('REGISTER', 'reg-klarinette', 'Klarinette', 9,
          registerId: 'reg-klarinette', registerLabel: 'Klarinette', registerOrder: 2),
      _line('INSTRUMENT', 'tuba', 'Tuba in C', 7,
          registerId: 'reg-tiefes-blech', registerLabel: 'Tiefes Blech', registerOrder: 8),
    ]),

    'collection-1-NOTATION-stimme-1': json.encode(marschbuch),

    'last-selection-1': json.encode(
        _line('NOTATION', 'stimme-2', '2. in B', 9)),

    'profile': json.encode({
      'username': username,
      'registerId': 'reg-fluegel',
      'registerLabel': 'Flügelhorn',
      'instrumentId': 'fluegel-1',
      'instrumentLabel': '1. Flügelhorn in B',
      'pending': false,
    }),

    'instrument-groups': json.encode([
      _group('reg-fluegel', 'Flügelhorn',
          ['1. Flügelhorn in B', '2. Flügelhorn in B', '3. Flügelhorn in B']),
      _group('reg-klarinette', 'Klarinette', ['1. Klarinette in B', '2. Klarinette in B']),
      _group('reg-tiefes-blech', 'Tiefes Blech', ['Tenorhorn', 'Bariton', 'Tuba in C']),
      _group('reg-schlagwerk', 'Schlagwerk', ['Kleine Trommel', 'Große Trommel']),
    ]),

    // Two Mappen taken along, so the lists show what "offline" looks like.
    'offline-selections': json.encode([
      {
        'collectionId': 1,
        'collectionName': 'Marschbuch 2026',
        'kind': 'NOTATION',
        'selectionId': 'stimme-1',
        'label': '1. in B',
        'pieceCount': 9,
        'pages': offlineKeys.length,
        'keys': offlineKeys,
        'bytes': 43 * 1024 * 1024 + 210 * 1024,
        'savedAt': DateTime(2026, 9, 21).millisecondsSinceEpoch,
      },
      {
        'collectionId': 2,
        'collectionName': 'Frühjahrskonzert 2026',
        'kind': 'INSTRUMENT',
        'selectionId': 'fluegel-1',
        'label': '1. Flügelhorn in B',
        'pieceCount': 14,
        'pages': 22,
        'keys': [for (int i = 0; i < 22; i++) 'x$i-1'],
        'bytes': 61 * 1024 * 1024,
        'savedAt': DateTime(2026, 9, 18).millisecondsSinceEpoch,
      },
    ]),

    'cached-files': <String>['9001', '9003', '9005'],

    // What somebody actually writes on a page.
    'drawing-$username-9001': json.encode({
      'imageId': 9001,
      'imageRevision': _revision,
      'strokes': json.encode({
        'v': 2,
        'strokes': [
          [0.115, 0.238, 0.176, 0.236, 0.236, 0.239],
          [0.62, 0.451, 0.665, 0.447, 0.706, 0.452],
          [0.148, 0.66, 0.163, 0.7, 0.2, 0.706, 0.216, 0.67, 0.183, 0.648, 0.152, 0.664],
        ],
        'texts': [
          {'x': 0.27, 'y': 0.2, 's': 0.036, 't': '2x'},
          {'x': 0.53, 'y': 0.41, 's': 0.033, 't': 'leise!'},
        ],
      }),
      'pending': false,
    }),
  };
}

Map<String, Object?> _piece(
  String title,
  int ordering,
  int imageId, {
  int page = 1,
  String? notes,
  String? booklet,
  int? inBooklet,
}) =>
    {
      'compositionLabel': title,
      'scoreId': 100 + ordering,
      'imageId': imageId,
      'imageRevision': _revision,
      'instrumentId': 'stimme-1',
      'instrumentLabel': '1. in B',
      'primaryInstrument': true,
      'collectionOrdering': ordering,
      'page': page,
      'scoreNotes': notes,
      'bookletLabel': booklet,
      'pieceOrdering': inBooklet,
    };

Map<String, Object?> _line(
  String kind,
  String id,
  String label,
  int pieceCount, {
  String? registerId,
  String? registerLabel,
  int? registerOrder,
}) =>
    {
      'kind': kind,
      'id': id,
      'label': label,
      'pieceCount': pieceCount,
      'registerId': registerId,
      'registerLabel': registerLabel,
      'registerOrder': registerOrder,
    };

Map<String, Object?> _group(String id, String label, List<String> instruments) => {
      'id': id,
      'label': label,
      'instruments': [
        for (int i = 0; i < instruments.length; i++)
          {'id': '$id-$i', 'label': instruments[i]}
      ],
    };
