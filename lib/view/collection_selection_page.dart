import 'package:flutter/material.dart';

import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/model/api/player_profile.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/arg/collection_arguments.dart';
import 'package:musebiachl/service/offline_store.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/collection_page.dart';
import 'package:musebiachl/view/offline_button.dart';

/// One section of the pick list: a register, or the Stimmen, which belong to none.
class _Section {
  final String label;
  final bool mine;

  _Section(this.label, {this.mine = false});
}

/// Which line of this Sammlung to read.
///
/// The screen exists because a Sammlung says what it is assigned by and nothing else can:
/// a Marschbuch whose pages carry "1. in B" offers Stimmen, a Mappe assigned the old way
/// offers instruments, and one that has had both over the years offers both. Nothing is
/// guessed and nothing is invented - the list is the pages that are really in it.
///
/// The player's own register is on top, with their instrument first inside it. That is as
/// far as a favorite can go: no register says whether somebody plays the 1. or the 3., so
/// a Stimme is always a decision, and the screen asks for it every time. What it does
/// remember is the line picked here last time, as a mark rather than as an answer.
class CollectionSelectionPage extends StatefulWidget {
  static const routeName = '/collection/selection';

  final int id;
  final String name;

  const CollectionSelectionPage({
    Key? key,
    required this.id,
    required this.name,
  }) : super(key: key);

  @override
  State<CollectionSelectionPage> createState() => _CollectionSelectionPageState();
}

class _CollectionSelectionPageState extends State<CollectionSelectionPage> {
  List<CollectionSelection>? selections;
  PlayerProfile? profile;
  CollectionSelection? last;

  var isLoaded = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  /// Everything from the device first, so the screen is up before the request is made -
  /// and so it works with no signal at all, which is the normal case in a rehearsal room.
  Future<void> getData() async {
    await OfflineStore.load();
    profile = await RemoteServices().cachedProfile();
    last = await RemoteServices().lastSelection(widget.id);

    final cached = await RemoteServices().cachedSelections(widget.id);
    if (cached != null && mounted) {
      setState(() {
        selections = cached;
        isLoaded = true;
      });
    }

    try {
      final fresh = await RemoteServices().fetchSelections(widget.id);
      if (!mounted) return;
      setState(() {
        selections = fresh;
        isLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is SessionExpiredException) {
        await endSession(reason: sessionRejectedMessage);
        return;
      }
      setState(() => isLoaded = true);
      if (cached != null) return; // offline, and the list is already on screen
      showError(context, 'Error: ${e.toString()}');
      selections = [];
    }

    // A favorite set on another phone, or by the admin over the telephone. Quiet on
    // purpose: the list above is already usable without it.
    try {
      final fresh = await RemoteServices().fetchProfile();
      if (fresh != null && mounted) setState(() => profile = fresh);
    } catch (_) {
      // offline, or a rejected token the request above has already dealt with
    }
  }

  bool _isMine(CollectionSelection selection) =>
      profile?.registerId != null && selection.registerId == profile!.registerId;

  bool _isMyInstrument(CollectionSelection selection) =>
      profile?.instrumentId != null &&
      selection.kind == SelectionKind.instrument &&
      selection.id == profile!.instrumentId;

  bool _wasLast(CollectionSelection selection) =>
      last != null && last!.kind == selection.kind && last!.id == selection.id;

  /// Sections, in the order this player wants them: their own register, then the Stimmen -
  /// which no register can answer for - then everything else in Partiturordnung.
  List<Object> get _rows {
    final List<CollectionSelection> all = selections ?? <CollectionSelection>[];
    if (all.isEmpty) return const [];

    final Map<String, List<CollectionSelection>> bySection = <String, List<CollectionSelection>>{};
    for (final CollectionSelection selection in all) {
      bySection.putIfAbsent(selection.section, () => <CollectionSelection>[]).add(selection);
    }

    final List<String> sections = bySection.keys.toList();
    sections.sort((a, b) {
      final int byRank = _rank(bySection[a]!).compareTo(_rank(bySection[b]!));
      if (byRank != 0) return byRank;
      final int byOrder = _order(bySection[a]!).compareTo(_order(bySection[b]!));
      return byOrder != 0 ? byOrder : a.compareTo(b);
    });

    final rows = <Object>[];
    for (final String section in sections) {
      final List<CollectionSelection> entries = bySection[section]!;

      // The server's order is Partiturordnung and part number, which is the order a player
      // reads a list of Stimmen in; the one thing worth moving is this player's own
      // instrument, an explicit decision they made. Partitioned rather than sorted -
      // Dart's List.sort is not guaranteed to be stable, and the rest of the order matters.
      final List<CollectionSelection> mine = entries.where(_isMyInstrument).toList();
      final List<CollectionSelection> rest =
          entries.where((entry) => !_isMyInstrument(entry)).toList();

      rows.add(_Section(section, mine: _rank(entries) == 0));
      rows.addAll(mine);
      rows.addAll(rest);
    }
    return rows;
  }

  int _rank(List<CollectionSelection> entries) {
    if (entries.any(_isMine)) return 0;
    if (entries.first.registerLabel == null) return 1;
    return 2;
  }

  int _order(List<CollectionSelection> entries) => entries
      .map((entry) => entry.registerOrder ?? 9999)
      .reduce((a, b) => a < b ? a : b);

  static IconData _iconFor(SelectionKind kind) {
    switch (kind) {
      case SelectionKind.notation:
        return Icons.music_note_outlined;
      case SelectionKind.instrument:
        return Icons.queue_music_outlined;
      case SelectionKind.register:
        return Icons.groups_outlined;
    }
  }

  /// What the screen is called depends on what the Sammlung has to offer.
  String get _title {
    final List<CollectionSelection> all = selections ?? <CollectionSelection>[];
    if (all.isEmpty) return 'Stimme wählen';
    return all.any((entry) => entry.kind == SelectionKind.notation)
        ? 'Stimme wählen'
        : 'Instrument wählen';
  }

  Future<void> _open(CollectionSelection selection) async {
    await RemoteServices().rememberSelection(widget.id, selection);
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      CollectionPage.routeName,
      arguments: CollectionArguments(widget.id, widget.name, selection),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, overflow: TextOverflow.ellipsis),
            Text(
              _title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      // Rebuilt from the offline store as well: a download started on one row keeps
      // running when this screen is left, and every row says where its Stimme is.
      body: !isLoaded
          ? const LoadingBody('Loading Stimmen from API')
          : ValueListenableBuilder<int>(
              valueListenable: OfflineStore.changes,
              builder: (context, _, _) => RefreshIndicator(
                onRefresh: getData,
                child: rows.isEmpty
                    ? const EmptyBody(
                        icon: Icons.music_off_outlined,
                        title: 'Dieser Sammlung ist noch nichts zugewiesen.',
                        hint: 'Sobald die Seiten im MuseAdmin einer Stimme oder einem Instrument '
                            'zugewiesen sind, stehen sie hier.',
                      )
                    : ListView.builder(
                        itemCount: rows.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) return _hint(scheme);
                          if (index == 1) return _offlineHint(scheme);

                          final row = rows[index - 2];

                          if (row is _Section) {
                            return SectionHeader(row.label, trailing: row.mine ? 'mein Register' : null);
                          }

                          return _tile(row as CollectionSelection, scheme);
                        },
                      ),
              ),
            ),
    );
  }

  /// Only shown to somebody who has never said what they play - it is the one thing that
  /// would put their own lines on top, and nothing on this screen otherwise mentions it.
  Widget _hint(ColorScheme scheme) {
    if (profile != null && !profile!.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sag unter »Mein Instrument«, was du spielst — dann steht dein Register hier oben.',
              style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown until this Sammlung has something on the device, and then never again. The
  /// icon on every row is the whole feature, and nothing else on the screen names it.
  Widget _offlineHint(ColorScheme scheme) {
    if (OfflineStore.inCollection(widget.id).isNotEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          Icon(Icons.download_for_offline_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mit diesem Zeichen rechts nimmst du eine ganze Stimme mit — '
              'dann ist sie auch ohne Netz da.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(CollectionSelection selection, ColorScheme scheme) {
    final bool mine = _isMyInstrument(selection);
    final bool wasLast = _wasLast(selection);
    final OfflineSelection? saved = OfflineStore.forSelection(widget.id, selection);
    final OfflineProgress? progress = OfflineStore.progressOf(widget.id, selection);

    return Container(
      color: mine || wasLast ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        onTap: () => _open(selection),
        leading: Icon(_iconFor(selection.kind), color: scheme.primary),
        title: Text(
          selection.label,
          style: TextStyle(fontWeight: mine ? FontWeight.w700 : FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Stücke, not pages: a part runs over two sheets often enough that counting
                // paper would say nothing, and a Heft counts as the pieces printed in it.
                Text('${selection.pieceCount} ${selection.pieceCount == 1 ? 'Stück' : 'Stücke'}'),
                if (selection.kind == SelectionKind.register) ...[
                  const SizedBox(width: 6),
                  Text('· ganzes Register', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
                if (mine) _badge('mein Instrument', scheme.primary, scheme.onPrimary),
                if (wasLast && !mine) _badge('zuletzt', scheme.secondary, scheme.onSecondary),
              ],
            ),
            _offlineLine(selection, saved, progress, scheme),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OfflineButton(
              collectionId: widget.id,
              collectionName: widget.name,
              selection: selection,
            ),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }

  /// The second line of a row: what this Stimme's offline state actually is.
  ///
  /// A number of pages and a size, because "offline" on its own is a claim and this is
  /// the evidence - half a Marschbuch has to look different from a whole one.
  Widget _offlineLine(CollectionSelection selection, OfflineSelection? saved,
      OfflineProgress? progress, ColorScheme scheme) {
    if (progress != null) {
      final String counted =
          progress.total == 0 ? '…' : '${progress.handled} von ${progress.total} Seiten';
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('lädt · $counted',
            style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }

    if (saved == null) return const SizedBox.shrink();

    final bool outdated = saved.outdatedFor(selection);
    final String text = !saved.complete
        ? 'offline · nur ${saved.keys.length} von ${saved.pages} Seiten'
        : outdated
            ? 'offline · seither geändert'
            : 'offline · ${saved.pages} ${saved.pages == 1 ? 'Seite' : 'Seiten'} · ${saved.sizeLabel}';

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: OfflineMark(label: text, size: 15, complete: saved.complete && !outdated),
    );
  }

  Widget _badge(String label, Color background, Color foreground) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
