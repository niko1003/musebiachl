import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:musebiachl/theme.dart';

/// Not a test so much as a way of *looking* at the corporate design without a phone.
///
/// `flutter test --update-goldens test/brand` writes the two PNGs in test/brand/goldens,
/// which is the only rendering of the real fonts and the real palette available on a
/// machine with no Android SDK and no browser. Run it after touching theme.dart.
void main() {
  setUpAll(() async {
    // Declared fonts are not loaded into a widget test, so the sampler would otherwise
    // render in the test framework's blank placeholder face - which is exactly the thing
    // being checked here.
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
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('the corporate design, ${brightness.name}', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: museTheme(brightness),
        home: const _Sampler(),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_Sampler),
        matchesGoldenFile('goldens/brand-${brightness.name}.png'),
      );
    });
  }
}

class _Sampler extends StatelessWidget {
  const _Sampler();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    Widget swatch(String name, Color colour, Color on) => Container(
          width: 150,
          height: 62,
          color: colour,
          alignment: Alignment.center,
          child: Text(name, style: TextStyle(color: on, fontSize: 12)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Marschbuch 2026'),
            Text('1. Flügelhorn in B',
                style: TextStyle(
                    fontFamily: bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          Icon(Icons.offline_pin, color: scheme.primary),
          const SizedBox(width: 12),
          const Icon(Icons.search),
          const SizedBox(width: 12),
          const Icon(Icons.swap_horiz),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              swatch('primary', scheme.primary, scheme.onPrimary),
              swatch('secondary', scheme.secondary, scheme.onSecondary),
              swatch('surface', scheme.surface, scheme.onSurface),
              swatch('primaryCont.', scheme.primaryContainer, scheme.onPrimaryContainer),
              swatch('surfaceCont.', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
              swatch('error', scheme.error, scheme.onError),
            ]),
          ),
          const SectionHeader('Konzertmappen', trailing: 'mein Register'),
          ListTile(
            leading: Icon(Icons.folder_special_outlined, color: scheme.primary),
            title: Text('Frühjahrskonzert 2026', style: text.titleMedium),
            subtitle: Row(children: [
              Icon(Icons.offline_pin, size: 15, color: scheme.primary),
              const SizedBox(width: 4),
              Text('1. in B',
                  style: TextStyle(
                      color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            trailing: Icon(Icons.chevron_right, color: scheme.outline),
          ),
          const Divider(indent: 68, endIndent: 16),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Text('7'),
            ),
            title: Text('Böhmischer Traum', style: text.titleMedium),
            subtitle: const Text('Polka · 2 Seiten'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('2', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 2),
              Icon(Icons.auto_stories, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Icon(Icons.offline_pin, size: 18, color: scheme.primary),
            ]),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurfaceVariant,
              child: const Text('8'),
            ),
            title: Text('Dem Land Tirol die Treue', style: text.titleMedium),
            subtitle: const Text('noch nicht geöffnet'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Überschrift in Noto Serif', style: text.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Fließtext in Fira Sans. Die Trachtenkapelle Mörtschach wurde 1925 als '
                'Feuerwehrkapelle gegründet.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text('Zweite Textfarbe, für die zweite Zeile.', style: text.bodySmall),
              const SizedBox(height: 16),
              Row(children: [
                FilledButton(onPressed: () {}, child: const Text('Anmelden')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: () {}, child: const Text('Aktualisieren')),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {},
                  child: Text('Entfernen', style: TextStyle(color: scheme.error)),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('8 von 96 Seiten fehlen — nochmal versuchen.',
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
