import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/collection_composition.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
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

class CollectionPage extends StatefulWidget {
  static const routeName = '/collection';

  final int id;
  final String name;

  const CollectionPage({
    Key? key,
    required this.id,
    required this.name,
  }) : super(key: key);

  @override
  State<CollectionPage> createState() => _CollectionPage();
}

class _CollectionPage extends State<CollectionPage> {
  List<CollectionComposition>? compositions;
  List<String> cachedFiles = List.empty();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  var isLoaded = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  /// Cache first, then the server.
  ///
  /// The stored copy goes on screen immediately, so opening a Mappe is instant and works
  /// with no signal; the request behind it corrects the list a moment later. A failed
  /// request while something is already showing is *silent* - that is the offline
  /// feature doing its job, not an error worth a red bar during a rehearsal.
  Future<void> getData() async {
    final SharedPreferences prefs = await _prefs;
    final String instrumentId = prefs.getString('instrumentId') ?? '';
    cachedFiles = prefs.getStringList('cached-files') ?? List.empty();

    final cached = await RemoteServices()
        .cachedCollectionCompositions(instrumentId, widget.id);
    if (cached != null && mounted) {
      setState(() {
        compositions = cached;
        isLoaded = true;
      });
    }

    try {
      final fresh = await RemoteServices()
          .fetchCollectionCompositions(instrumentId, widget.id);
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

      // imageId 0 is the placeholder the server sends for a piece this instrument has
      // no page of - the entry still belongs in the list, greyed out.
      if (row.imageId != 0) {
        pieces.last.imageIds.add(row.imageId);
        pieces.last.imageRevisions.add(row.imageRevision);
      }
    }

    return pieces;
  }

  @override
  Widget build(BuildContext context) {
    final pieces = _pieces;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        centerTitle: true,
      ),
      body: Visibility(
        visible: isLoaded,
        replacement: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Loading Noten from API'),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: getData,
          child: ListView.builder(
              itemCount: pieces.length,
              itemBuilder: (context, index) {
                final piece = pieces[index];
                final bool opened = piece.playable &&
                    cachedFiles.contains(piece.imageIds.first.toString());

                final String subtitle = [
                  piece.instrumentLabel,
                  if (piece.notes != null) piece.notes!,
                  if (piece.pages > 1) '${piece.pages} Seiten',
                ].join(' · ');

                if (!piece.playable) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Text(piece.ordering.toString()),
                    ),
                    title: Text(piece.label),
                    enabled: false,
                  );
                }

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
                    backgroundColor: opened ? Colors.lightGreen : Colors.blue,
                    child: Text(piece.ordering.toString()),
                  ),
                  title: Text(piece.label),
                  subtitle: Text(subtitle),
                  trailing: piece.pages > 1
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${piece.pages}',
                                style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(width: 2),
                            Icon(Icons.auto_stories,
                                size: 16, color: Colors.grey.shade600),
                          ],
                        )
                      : null,
                );
              }),
        ),
      ),
    );
  }
}
