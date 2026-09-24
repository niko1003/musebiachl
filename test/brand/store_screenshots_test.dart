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

  /// Play wants 16:9 at most; Apple wants exactly 1290x2796 for the 6.7" iPhone set and
  /// 2048x2732 for the 13" iPad - and it wants the iPad set because the Runner targets
  /// device family "1,2", so the app is universal whether or not anyone plays off one.
  const Map<String, ({Size size, double ratio})> devices = {
    'android-1080x1920': (size: Size(1080, 1920), ratio: 2.75),
    'ios-1290x2796': (size: Size(1290, 2796), ratio: 3.0),
    'ipad-2048x2732': (size: Size(2048, 2732), ratio: 2.0),
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

    // The pages themselves: score 1565 on klenig.at, Mozart's Allegro, fetched once
    // through the public /file/image/{id} and kept here so the harness needs no server.
    final Map<int, MemoryImage> pages = {
      9001: MemoryImage(File('test/brand/fixtures/nachtmusik-1.png').readAsBytesSync()),
      9002: MemoryImage(File('test/brand/fixtures/nachtmusik-2.png').readAsBytesSync()),
    };
    ScorePage.debugImageFor =
        (int imageId, int revision) => pages[imageId] ?? pages[9001]!;

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
            const CollectionSelectionPage(id: 1, name: 'Frühjahrskonzert 2026'));
      });

      testWidgets('03 die Mappe', (tester) async {
        await shoot(
          tester,
          '03-mappe',
          CollectionPage(
            id: 1,
            name: 'Frühjahrskonzert 2026',
            selection: CollectionSelection(
              kind: SelectionKind.instrument,
              id: 'floete-1',
              label: '1. Flöte C',
              pieceCount: 10,
              registerId: 'reg-floete',
              registerLabel: 'Flöte',
              registerOrder: 10,
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
            title: 'Eine kleine Nachtmusik',
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
  // Everything in this Mappe is public domain - every composer has been dead well over
  // seventy years - and nothing is a Heft, so no publication is named. These screenshots
  // go on a store page, and a fixture is the one place where that costs nothing.
  final List<Map<String, Object?>> mappe = [
    _piece('Eine kleine Nachtmusik', 1, 9001, notes: 'W. A. Mozart · Allegro'),
    _piece('Eine kleine Nachtmusik', 1, 9002, page: 2, notes: 'W. A. Mozart · Allegro'),
    _piece('Ouvertüre zu »Die Zauberflöte«', 2, 9003, notes: 'W. A. Mozart'),
    _piece('Air aus der Suite Nr. 3', 3, 9004, notes: 'J. S. Bach'),
    _piece('Ave Maria', 4, 9005, notes: 'Franz Schubert'),
    _piece('Halleluja aus »Der Messias«', 5, 9006, notes: 'G. F. Händel'),
    _piece('Hochzeitsmarsch', 6, 9007, notes: 'Felix Mendelssohn Bartholdy'),
    _piece('An der schönen blauen Donau', 7, 9008, notes: 'Johann Strauß (Sohn)'),
    _piece('Radetzky-Marsch', 8, 9009, notes: 'Johann Strauß (Vater)'),
    _piece('Alte Kameraden', 9, 9010, notes: 'Carl Teike'),
    _piece('Florentiner Marsch', 10, 9011, notes: 'Julius Fučík'),
  ];

  final List<String> offlineKeys = [
    for (final Map<String, Object?> row in mappe) _key(row['imageId'] as int)
  ];

  return <String, Object>{
    'token': 'screenshot',
    'username': username,
    'muse-pages-replaced-default': true,

    'collections': json.encode([
      {'id': 1, 'name': 'Frühjahrskonzert 2026', 'type': 'CONCERT_FOLDER'},
      {'id': 3, 'name': 'Kirchliche Anlässe', 'type': 'CONCERT_FOLDER'},
      {'id': 2, 'name': 'Marschbuch 2026', 'type': 'MARCH_BOOK'},
      {'id': 4, 'name': 'Ständchen', 'type': 'ANTHOLOGY'},
    ]),

    'selections-1': json.encode([
      _line('INSTRUMENT', 'floete-1', '1. Flöte C', 10,
          registerId: 'reg-floete', registerLabel: 'Flöte', registerOrder: 10),
      _line('INSTRUMENT', 'floete-2', '2. Flöte C', 10,
          registerId: 'reg-floete', registerLabel: 'Flöte', registerOrder: 10),
      _line('NOTATION', 'stimme-1', '1. in B', 10),
      _line('NOTATION', 'stimme-2', '2. in B', 10),
      _line('NOTATION', 'stimme-3', '3. in B', 9),
      _line('REGISTER', 'reg-klarinette', 'Klarinette', 10,
          registerId: 'reg-klarinette', registerLabel: 'Klarinette', registerOrder: 20),
      _line('INSTRUMENT', 'tuba', 'Tuba in C', 8,
          registerId: 'reg-tiefes-blech', registerLabel: 'Tiefes Blech', registerOrder: 80),
    ]),

    'collection-1-INSTRUMENT-floete-1': json.encode(mappe),

    'last-selection-1': json.encode(_line('NOTATION', 'stimme-2', '2. in B', 10)),

    'profile': json.encode({
      'username': username,
      'registerId': 'reg-floete',
      'registerLabel': 'Flöte',
      'instrumentId': 'floete-1',
      'instrumentLabel': '1. Flöte C',
      'pending': false,
    }),

    'instrument-groups': json.encode([
      _group('reg-floete', 'Flöte', ['1. Flöte C', '2. Flöte C', 'Piccolo']),
      _group('reg-klarinette', 'Klarinette', ['1. Klarinette in B', '2. Klarinette in B']),
      _group('reg-fluegel', 'Flügelhorn', ['1. Flügelhorn in B', '2. Flügelhorn in B']),
      _group('reg-tiefes-blech', 'Tiefes Blech', ['Tenorhorn', 'Bariton', 'Tuba in C']),
    ]),

    // Two Mappen taken along, so the lists show what "offline" looks like.
    'offline-selections': json.encode([
      {
        'collectionId': 1,
        'collectionName': 'Frühjahrskonzert 2026',
        'kind': 'INSTRUMENT',
        'selectionId': 'floete-1',
        'label': '1. Flöte C',
        'pieceCount': 10,
        'pages': offlineKeys.length,
        'keys': offlineKeys,
        'bytes': 38 * 1024 * 1024 + 640 * 1024,
        'savedAt': DateTime(2026, 9, 21).millisecondsSinceEpoch,
      },
      {
        'collectionId': 2,
        'collectionName': 'Marschbuch 2026',
        'kind': 'NOTATION',
        'selectionId': 'stimme-1',
        'label': '1. in B',
        'pieceCount': 24,
        'pages': 31,
        'keys': [for (int i = 0; i < 31; i++) 'x$i-1'],
        'bytes': 61 * 1024 * 1024,
        'savedAt': DateTime(2026, 9, 18).millisecondsSinceEpoch,
      },
    ]),

    'cached-files': <String>['9001', '9004', '9007'],

    // What somebody actually puts on that page: a breath, a bar circled, and two words.
    'drawing-$username-9001': json.encode({
      'imageId': 9001,
      'imageRevision': _revision,
      'strokes': json.encode({
        'v': 2,
        'strokes': [
          [0.281, 0.2045, 0.343, 0.2032, 0.408, 0.2048, 0.463, 0.2041],
          [0.517, 0.1735, 0.529, 0.1562],
          [
            0.702, 0.3258, 0.7295, 0.3181, 0.7515, 0.3288, 0.7508, 0.3454,
            0.7261, 0.3528, 0.7002, 0.3462, 0.6952, 0.3311, 0.7055, 0.3242,
          ],
        ],
        'texts': [
          {'x': 0.607, 'y': 0.1272, 's': 0.0305, 't': '2x'},
          {'x': 0.178, 'y': 0.2288, 's': 0.0285, 't': 'leise!'},
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
      'instrumentId': 'floete-1',
      'instrumentLabel': '1. Flöte C',
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
