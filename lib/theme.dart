import 'package:flutter/material.dart';

/// The app's look, in one place: the Trachtenkapelle Mörtschach corporate design.
///
/// Three colours and two typefaces, all of them from the Grafikerin's guide
/// (*Corporate Design/PNG/Hauptfarben.txt*) rather than from Material's defaults:
///
/// | | |
/// | --- | --- |
/// | Grün `#0A8B31` | the primary - the flower in the Vereinslogo is this green |
/// | Braun `#493936` | *Textfarbe 1*: what writing is, not a decoration |
/// | Braun 80% `#72615E` | *Textfarbe 2*, for the second line of anything |
/// | Rot `#FF0000` | a Nebenfarbe, and the only thing errors are allowed to be |
///
/// Headings are **Noto Serif SemiBold**, running text **Fira Sans** - the guide's two.
/// Both are bundled (assets/fonts) rather than asked of the device, which has neither.
///
/// Both brightnesses are built from the green, and the app follows the system: a phone on
/// a music stand in a darkened hall is the normal case. The dark theme's ground is a
/// near-black brown out of the same family rather than Material's grey-violet, and its
/// green is the tonal palette's lighter step - the brand green at 3.9:1 against black is
/// not something to read a Stimme by.
///
/// ScorePage is the exception and always was: it paints its own black viewer with explicit
/// colours, because a page of music is black ink on white paper and no theme has an
/// opinion about that.
const Color brandGreen = Color(0xFF0A8B31);
const Color brandBrown = Color(0xFF493936);
const Color brandBrownSoft = Color(0xFF72615E);
const Color brandRed = Color(0xFFFF0000);

/// Warm neutrals, mixed from the brown rather than picked: a grey that is not on the
/// brown's hue reads as dirt next to the logo.
const Color _paper = Color(0xFFFFFFFF);
const Color _paperShade = Color(0xFFF4F1F0);
const Color _paperEdge = Color(0xFFE7E1DF);
const Color _night = Color(0xFF1C1716);
const Color _nightShade = Color(0xFF272020);
const Color _nightInk = Color(0xFFF0EBE9);

const String headingFont = 'Noto Serif';
const String bodyFont = 'Fira Sans';

ThemeData museTheme(final Brightness brightness) {
  final bool light = brightness == Brightness.light;

  final ColorScheme base =
      ColorScheme.fromSeed(seedColor: brandGreen, brightness: brightness);

  final ColorScheme scheme = light
      ? base.copyWith(
          primary: brandGreen,
          onPrimary: Colors.white,
          secondary: brandBrown,
          onSecondary: Colors.white,
          secondaryContainer: _paperEdge,
          onSecondaryContainer: brandBrown,
          surface: _paper,
          onSurface: brandBrown,
          onSurfaceVariant: brandBrownSoft,
          surfaceContainer: _paperShade,
          surfaceContainerHighest: _paperEdge,
          outline: brandBrownSoft,
          outlineVariant: _paperEdge,
          error: brandRed,
          onError: Colors.white,
        )
      : base.copyWith(
          // The green is left as the tonal palette made it - lighter than the logo's, and
          // it has to be, or nothing on this ground could be read.
          onPrimary: const Color(0xFF00210A),
          surface: _night,
          onSurface: _nightInk,
          onSurfaceVariant: const Color(0xFFBFB3AF),
          surfaceContainer: _nightShade,
          surfaceContainerHighest: const Color(0xFF332A29),
          outline: const Color(0xFF8C7E7A),
          outlineVariant: const Color(0xFF3A3130),
        );

  final TextTheme text = _textTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: bodyFont,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    listTileTheme: const ListTileThemeData(
      // A rehearsal room is not a place for precision tapping.
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: scheme.outlineVariant,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: scheme.surfaceContainer,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
    ),
  );
}

/// Noto Serif for anything that names something, Fira Sans for anything that is read.
///
/// The split follows the guide rather than Material's own scale: what it calls a heading
/// is a title here - a Sammlung's name, a Stück's name, the empty-state line that says
/// what is missing.
TextTheme _textTheme(final ColorScheme scheme) {
  TextStyle heading(double size, {double? height}) => TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w600,
        fontSize: size,
        height: height,
        color: scheme.onSurface,
      );

  TextStyle body(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: bodyFont,
        fontWeight: weight,
        fontSize: size,
        color: color,
      );

  return TextTheme(
    displaySmall: heading(30),
    headlineMedium: heading(24),
    headlineSmall: heading(21),
    titleLarge: heading(19),
    titleMedium: heading(16),
    titleSmall: body(14, FontWeight.w600, scheme.onSurface),
    bodyLarge: body(16, FontWeight.w400, scheme.onSurface),
    bodyMedium: body(14, FontWeight.w400, scheme.onSurface),
    bodySmall: body(12.5, FontWeight.w400, scheme.onSurfaceVariant),
    labelLarge: body(14, FontWeight.w600, scheme.onSurface),
    labelMedium: body(12, FontWeight.w500, scheme.onSurface),
    labelSmall: body(11, FontWeight.w500, scheme.onSurfaceVariant),
  );
}

/// The one way this app says something went wrong.
///
/// The guide's Rot is a Nebenfarbe and this is the only thing it is for. As a container
/// rather than a flat fill, because pure #FF0000 behind white text is a road sign, not a
/// message - and because every other surface in the app comes out of the scheme too.
void showError(BuildContext context, String message) {
  final ColorScheme scheme = Theme.of(context).colorScheme;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    backgroundColor: scheme.errorContainer,
  ));
}

/// The Vereinslogo, in whichever version the brightness calls for.
///
/// Two files rather than one tinted image: the negative version keeps the flower green
/// and turns only the writing white, which is what the guide shows on a dark ground - a
/// logo recoloured in code would be neither version.
class BrandLogo extends StatelessWidget {
  final double width;

  const BrandLogo({Key? key, this.width = 220}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      dark ? 'assets/images/tkm-logo-dark.png' : 'assets/images/tkm-logo.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Trachtenkapelle Mörtschach',
    );
  }
}

/// The small caps line above a group of entries - a Sammlungsart, a register, "Stimmen".
class SectionHeader extends StatelessWidget {
  final String label;
  final String? trailing;

  const SectionHeader(this.label, {Key? key, this.trailing}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: headingFont,
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// What every list in this app shows while it has nothing yet, and when it stays empty.
///
/// The loading text is English like the rest of the debug-ish strings; everything a player
/// reads once the app is working is German.
class LoadingBody extends StatelessWidget {
  final String label;

  const LoadingBody(this.label, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class EmptyBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;

  const EmptyBody({Key? key, required this.icon, required this.title, this.hint}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListView(
      // A ListView rather than a Column, so pull-to-refresh still works on an empty list.
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Icon(icon, size: 48, color: scheme.outline),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
