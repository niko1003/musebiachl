import 'package:flutter/material.dart';

/// The app's look, in one place.
///
/// Brass rather than the framework's blue: this is a wind orchestra's Biachl, and the
/// chrome is the only place any colour lives - a page of music is black ink on white
/// paper, and ScorePage paints its own black viewer regardless of the theme.
///
/// Both brightnesses are built from the same seed and the app follows the system, because
/// a phone on a music stand in a dark hall is the normal case.
const Color _seed = Color(0xFF8A5A2B);

ThemeData museTheme(final Brightness brightness) {

  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      // A rehearsal room is not a place for precision tapping.
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
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
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: scheme.onSurface),
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
