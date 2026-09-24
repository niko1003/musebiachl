import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/collection_composition.dart';
import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/offline_store.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/offline_button.dart';
import 'package:musebiachl/view/score_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One piece of a Mappe, as this player gets it: the title, and every page of their part.
///
/// The server answers one row per *page*, so a part running over three pages used to be
/// three identical-looking entries. They are folded back into one here, because what a
/// player is looking for is the piece.
class _Piece {
  final String label;
  final String instrumentLabel;
  final String? notes;
  final int ordering;

  /// Set when this is a piece inside a Heft - see [_Booklet].
  final String? bookletLabel;

  /// Its place in the Heft's printed index, or null for pages nobody has cut out yet.
  final int? pieceOrdering;

  final List<int> imageIds = [];
  final List<int> imageRevisions = [];

  _Piece(this.label, this.instrumentLabel, this.notes, this.ordering,
      this.bookletLabel, this.pieceOrdering);

  bool get playable => imageIds.isNotEmpty;
  int get pages => imageIds.length;

  /// How the pages of this piece are named in the offline store - the same key ScorePage
  /// puts on the image provider, which is what makes a downloaded page the one it shows.
  List<String> get keys => [
        for (int i = 0; i < imageIds.length; i++)
          OfflineStore.imageKey(
              imageIds[i], i < imageRevisions.length ? imageRevisions[i] : 0)
      ];

  /// What the leading badge says: a piece of a Heft is numbered inside the Heft.
  int? get number => bookletLabel == null ? ordering : pieceOrdering;

  /// The pages of the Heft that are not (yet) any piece of it.
  bool get isRestOfBooklet => bookletLabel != null && bookletLabel == label;
}

/// A Heft inside the Sammlung, as one collapsible row.
///
/// A Sammlung holds a Heft by holding its scan, so the whole booklet used to arrive as a
/// single entry: opening Kirchenblech put you on its first page and the Deutsche Messe was
/// six swipes away, during the piece. The pieces are listed under it instead - and when the
/// Sammlung is nothing but that one Heft, the Heft itself is skipped and its pieces are the
/// list.
class _Booklet {
  final String label;
  final List<_Piece> pieces = [];

  _Booklet(this.label);
}

/// A Sammlung as one of its lines reads it.
///
/// Which line that is arrives as an argument rather than being read out of the device:
/// the Stimme is picked per Sammlung (CollectionSelectionPage), because a player who reads
/// the 1. in one Mappe may well be handed the 3. in the next.
class CollectionPage extends StatefulWidget {
  static const routeName = '/collection';

  final int id;
  final String name;
  final CollectionSelection selection;

  const CollectionPage({
    Key? key,
    required this.id,
    required this.name,
    required this.selection,
  }) : super(key: key);

  @override
  State<CollectionPage> createState() => _CollectionPage();
}

class _CollectionPage extends State<CollectionPage> {
  List<CollectionComposition>? compositions;
  List<String> cachedFiles = List.empty();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  var isLoaded = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Cache first, then the server.
  ///
  /// The stored copy goes on screen immediately, so opening a Mappe is instant and works
  /// with no signal; the request behind it corrects the list a moment later. A failed
  /// request while something is already showing is *silent* - that is the offline
  /// feature doing its job, not an error worth a red bar during a rehearsal.
  Future<void> getData() async {
    await OfflineStore.load();
    final SharedPreferences prefs = await _prefs;
    cachedFiles = prefs.getStringList('cached-files') ?? List.empty();

    final cached = await RemoteServices()
        .cachedPieces(widget.id, widget.selection.kind, widget.selection.id);
    if (cached != null && mounted) {
      setState(() {
        compositions = cached;
        isLoaded = true;
      });
    }

    try {
      final fresh = await RemoteServices()
          .fetchPieces(widget.id, widget.selection.kind, widget.selection.id);
      if (!mounted) return;
      setState(() {
        compositions = fresh;
        isLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      // A rejected token is the one failure that is not "offline": the cached list is
      // no use if the account behind it is gone, so this goes back to the login screen
      // instead of staying quiet.
      if (e is SessionExpiredException) {
        await endSession(reason: sessionRejectedMessage);
        return;
      }
      setState(() => isLoaded = true);
      if (cached != null) return; // offline, and the Mappe is already on screen
      showError(context, 'Error: ${e.toString()}');
      compositions = [];
    }
  }

  /// Consecutive rows of the same piece and the same part are one entry. The server
  /// already returns them in order - by collection ordering, then piece, then page - so
  /// this only has to look at the previous row rather than sort anything.
  List<_Piece> get _pieces {
    final pieces = <_Piece>[];

    for (final row in compositions ?? <CollectionComposition>[]) {
      final last = pieces.isEmpty ? null : pieces.last;
      final sameEntry = last != null &&
          last.label == row.compositionLabel &&
          last.ordering == row.collectionOrdering &&
          last.pieceOrdering == row.pieceOrdering &&
          last.instrumentLabel == row.instrumentLabel;

      if (!sameEntry) {
        pieces.add(_Piece(row.compositionLabel, row.instrumentLabel, row.scoreNotes,
            row.collectionOrdering, row.bookletLabel, row.pieceOrdering));
      }

      // imageId 0 is the placeholder the server sends for a piece this line has no page
      // of - the entry still belongs in the list, greyed out.
      if (row.imageId != 0) {
        pieces.last.imageIds.add(row.imageId);
        pieces.last.imageRevisions.add(row.imageRevision);
      }
    }

    final String term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return pieces;

    return pieces.where((piece) => piece.label.toLowerCase().contains(term)).toList();
  }

  /// The list as it is drawn: pieces, and a Heft's pieces gathered under the Heft.
  ///
  /// While searching everything is flat - what is being looked for is a title, and hiding
  /// the hit inside a closed Heft would be the opposite of an answer. A Sammlung that *is*
  /// one Heft is flat too: there is nothing to tell apart, so the Heft row would only be a
  /// tap between the player and their music.
  List<Object> get _rows {
    final List<_Piece> pieces = _pieces;

    if (_search.text.trim().isNotEmpty) return pieces;

    final rows = <Object>[];
    for (final _Piece piece in pieces) {
      if (piece.bookletLabel == null) {
        rows.add(piece);
        continue;
      }

      final Object? last = rows.isEmpty ? null : rows.last;
      if (last is _Booklet && last.label == piece.bookletLabel) {
        last.pieces.add(piece);
      } else {
        rows.add(_Booklet(piece.bookletLabel!)..pieces.add(piece));
      }
    }

    if (rows.length == 1 && rows.first is _Booklet) {
      return (rows.first as _Booklet).pieces;
    }
    return rows;
  }

  /// Every page this line has, whatever the search box is currently hiding.
  List<String> get _allKeys => [
        for (final row in compositions ?? <CollectionComposition>[])
          if (row.imageId != 0) OfflineStore.imageKey(row.imageId, row.imageRevision)
      ];

  /// The whole screen is rebuilt from the offline store, not only the list: the title
  /// says whether this Stimme is here, and a download started on this screen goes on
  /// running when it is left and has to be found still going when it is opened again.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineStore.changes,
      builder: (context, _, _) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    final rows = _rows;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final OfflineSelection? saved =
        OfflineStore.forSelection(widget.id, widget.selection);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Stück suchen…',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text(
                        widget.selection.label,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                      ),
                      if (saved != null) ...[
                        const SizedBox(width: 6),
                        OfflineMark(
                          label: 'offline',
                          size: 14,
                          complete: saved.complete && !saved.missesAnyOf(_allKeys),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
        actions: [
          // The same control as on the pick screen: somebody who is already looking at
          // the pieces should not have to walk back out to take them along.
          OfflineButton(
            collectionId: widget.id,
            collectionName: widget.name,
            selection: widget.selection,
            currentKeys: _allKeys,
          ),
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Suche schließen' : 'Suchen',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          // Back to the pick screen, which is the route directly underneath - changing
          // Stimme mid-rehearsal is one tap rather than a walk back through the Sammlungen.
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Stimme wechseln',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: !isLoaded
          ? const LoadingBody('Loading Noten from API')
          : RefreshIndicator(
              onRefresh: getData,
              child: rows.isEmpty
                  ? EmptyBody(
                      icon: Icons.music_off_outlined,
                      title: _search.text.trim().isEmpty
                          ? 'Für ${widget.selection.label} ist hier nichts drin.'
                          : 'Kein Stück mit »${_search.text.trim()}«.',
                      hint: _search.text.trim().isEmpty ? 'Eine andere Stimme wählen: ⇄ oben rechts.' : null,
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (context, index) => const Divider(indent: 72, endIndent: 16),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return row is _Booklet
                            ? _bookletTile(row, scheme, saved)
                            : _tile(row as _Piece, scheme, saved);
                      },
                    ),
            ),
    );
  }

  /// A Heft as one row that opens. Collapsed, because that is the point of it: a Sammlung
  /// with a 40-piece Heft in it should still read as a Sammlung.
  Widget _bookletTile(_Booklet booklet, ColorScheme scheme, OfflineSelection? saved) {
    // Every piece that has pages at all has to be here - and at least one has to, or an
    // empty Heft would claim to be downloaded.
    final bool offline = saved != null &&
        booklet.pieces.any((piece) => piece.playable) &&
        booklet.pieces
            .every((piece) => !piece.playable || piece.keys.every(saved.holds));

    return ExpansionTile(
      leading: Icon(Icons.menu_book_outlined, color: scheme.primary),
      title: Text(booklet.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      // In the subtitle rather than as a trailing widget: ExpansionTile's trailing slot
      // is its own turning arrow, and a Heft that cannot be seen to open is worse than
      // one whose offline mark sits a line lower.
      subtitle: Row(
        children: [
          Text('${booklet.pieces.length} ${booklet.pieces.length == 1 ? 'Stück' : 'Stücke'}'),
          if (offline) ...[
            const SizedBox(width: 8),
            const OfflineMark(label: 'offline', size: 15),
          ],
        ],
      ),
      children: booklet.pieces
          .map((piece) => _tile(piece, scheme, saved, inset: true))
          .toList(),
    );
  }

  Widget _tile(_Piece piece, ColorScheme scheme, OfflineSelection? saved,
      {bool inset = false}) {
    final bool opened =
        piece.playable && cachedFiles.contains(piece.imageIds.first.toString());

    // Every page of it, not the first: half a piece on the device is not this piece
    // available offline.
    final bool offline =
        saved != null && piece.playable && piece.keys.every(saved.holds);

    // A piece of a Heft is numbered inside the Heft; pages nobody has cut out yet have no
    // number at all, and saying so is better than borrowing one.
    final Widget badge = Text(piece.number?.toString() ?? '·');
    final EdgeInsets padding =
        inset ? const EdgeInsets.only(left: 32, right: 16) : const EdgeInsets.symmetric(horizontal: 16);

    // The leftover pages of a Heft carry the Heft's own name, which says nothing twice.
    final String title = piece.isRestOfBooklet ? 'Weitere Seiten' : piece.label;

    if (!piece.playable) {
      return ListTile(
        contentPadding: padding,
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurfaceVariant,
          child: badge,
        ),
        title: Text(title),
        subtitle: const Text('keine Seite'),
        enabled: false,
      );
    }

    final String subtitle = [
      // Only when it is not simply what was picked: findForInstrument labels a page matched
      // through the register with the register's name, which is worth seeing.
      if (piece.instrumentLabel != widget.selection.label) piece.instrumentLabel,
      if (piece.notes != null) piece.notes!,
      if (piece.pages > 1) '${piece.pages} Seiten',
    ].join(' · ');

    return ListTile(
      contentPadding: padding,
      enabled: true,
      onTap: () => Navigator.pushNamed(
        context,
        ScorePage.routeName,
        arguments: ScoreArguments(
          piece.imageIds,
          piece.imageRevisions,
          title: title,
        ),
      ),
      leading: CircleAvatar(
        // Marked in the Vereinsgrün once it has been opened on this phone, which is how a
        // player finds their way back to the piece they were just looking at. The other
        // way round until 1.13.0, when green stopped being a spare colour and became the
        // brand's: everything would have been green, and nothing would have meant it.
        backgroundColor: opened ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        foregroundColor: opened ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        child: badge,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: piece.pages > 1 || offline
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (piece.pages > 1) ...[
                  Text('${piece.pages}', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 2),
                  Icon(Icons.auto_stories, size: 16, color: scheme.onSurfaceVariant),
                ],
                if (offline) ...[
                  const SizedBox(width: 8),
                  const OfflineMark(),
                ],
              ],
            )
          : null,
    );
  }
}
