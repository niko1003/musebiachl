import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/collection_composition.dart';
import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/theme.dart';
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
  final List<int> imageIds = [];
  final List<int> imageRevisions = [];

  _Piece(this.label, this.instrumentLabel, this.notes, this.ordering);

  bool get playable => imageIds.isNotEmpty;
  int get pages => imageIds.length;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade300,
      ));
      compositions = [];
    }
  }

  /// Consecutive rows of the same piece and the same part are one entry. The server
  /// already returns them in order - by collection ordering, then page - so this only
  /// has to look at the previous row rather than sort anything.
  List<_Piece> get _pieces {
    final pieces = <_Piece>[];

    for (final row in compositions ?? <CollectionComposition>[]) {
      final last = pieces.isEmpty ? null : pieces.last;
      final sameEntry = last != null &&
          last.label == row.compositionLabel &&
          last.ordering == row.collectionOrdering &&
          last.instrumentLabel == row.instrumentLabel;

      if (!sameEntry) {
        pieces.add(_Piece(row.compositionLabel, row.instrumentLabel,
            row.scoreNotes, row.collectionOrdering));
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

  @override
  Widget build(BuildContext context) {
    final pieces = _pieces;
    final ColorScheme scheme = Theme.of(context).colorScheme;

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
                  Text(
                    widget.selection.label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
        actions: [
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
              child: pieces.isEmpty
                  ? EmptyBody(
                      icon: Icons.music_off_outlined,
                      title: _search.text.trim().isEmpty
                          ? 'Für ${widget.selection.label} ist hier nichts drin.'
                          : 'Kein Stück mit »${_search.text.trim()}«.',
                      hint: _search.text.trim().isEmpty ? 'Eine andere Stimme wählen: ⇄ oben rechts.' : null,
                    )
                  : ListView.separated(
                      itemCount: pieces.length,
                      separatorBuilder: (context, index) => const Divider(indent: 72, endIndent: 16),
                      itemBuilder: (context, index) => _tile(pieces[index], scheme),
                    ),
            ),
    );
  }

  Widget _tile(_Piece piece, ColorScheme scheme) {
    final bool opened =
        piece.playable && cachedFiles.contains(piece.imageIds.first.toString());

    if (!piece.playable) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurfaceVariant,
          child: Text(piece.ordering.toString()),
        ),
        title: Text(piece.label),
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
      enabled: true,
      onTap: () => Navigator.pushNamed(
        context,
        ScorePage.routeName,
        arguments: ScoreArguments(
          piece.imageIds,
          piece.imageRevisions,
          title: piece.label,
        ),
      ),
      leading: CircleAvatar(
        // Green once it has been opened on this phone, which is how a player finds their
        // way back to the piece they were just looking at.
        backgroundColor: opened ? scheme.tertiaryContainer : scheme.primaryContainer,
        foregroundColor: opened ? scheme.onTertiaryContainer : scheme.onPrimaryContainer,
        child: Text(piece.ordering.toString()),
      ),
      title: Text(piece.label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: piece.pages > 1
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${piece.pages}', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 2),
                Icon(Icons.auto_stories, size: 16, color: scheme.onSurfaceVariant),
              ],
            )
          : null,
    );
  }
}
