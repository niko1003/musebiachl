import 'package:flutter/material.dart';

import 'package:musebiachl/model/api/collection.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/arg/selection_arguments.dart';
import 'package:musebiachl/service/offline_store.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/collection_selection_page.dart';
import 'package:musebiachl/view/logout_button.dart';
import 'package:musebiachl/view/offline_button.dart';

/// Every Mappe the orchestra has, grouped by what it is.
///
/// The first screen of the app: tapping one asks which Stimme of it to read.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({Key? key}) : super(key: key);

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<Collection>? collections;
  var isLoaded = false;

  /// Local filtering only - the whole list is on the device anyway, and a Sammlung is
  /// found by a word of its name much faster than by scrolling past 30 of them.
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

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

  /// Cache first, then the server - see CollectionPage.getData for why the failure is
  /// silent once something is already on screen.
  Future<void> getData() async {
    await OfflineStore.load();
    final cached = await RemoteServices().cachedCollections();
    if (cached != null && mounted) {
      setState(() {
        collections = cached;
        isLoaded = true;
      });
    }

    try {
      final fresh = await RemoteServices().fetchCollections();
      if (!mounted) return;
      setState(() {
        collections = fresh;
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
      if (cached != null) return;
      showError(context, 'Error: ${e.toString()}');
      collections = [];
    }
  }

  static IconData _iconFor(CollectionType type) {
    switch (type) {
      case CollectionType.concertFolder:
        return Icons.folder_special_outlined;
      case CollectionType.marchBook:
        return Icons.directions_walk;
      case CollectionType.anthology:
        return Icons.library_music_outlined;
      case CollectionType.booklet:
        return Icons.menu_book_outlined;
    }
  }

  /// One flat list of section headers (CollectionType) and entries (Collection),
  /// in the enum's own order, so ListView.builder can render both.
  List<Object> get _rows {
    final String term = _search.text.trim().toLowerCase();

    final rows = <Object>[];
    for (final type in CollectionType.values) {
      final inType = (collections ?? [])
          .where((entry) => entry.type == type)
          .where((entry) => term.isEmpty || entry.name.toLowerCase().contains(term))
          .toList();
      if (inType.isEmpty) continue;
      rows.add(type);
      rows.addAll(inType);
    }
    return rows;
  }

  void _open(Collection collection) {
    Navigator.pushNamed(
      context,
      CollectionSelectionPage.routeName,
      arguments: SelectionArguments(collection.id, collection.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Sammlung suchen…',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Sammlungen'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Suche schließen' : 'Suchen',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          const LogoutButton(),
        ],
      ),
      // The offline marks come out of the store, which changes while a download runs in
      // a Sammlung two screens away.
      body: !isLoaded
          ? const LoadingBody('Loading Collections from API')
          : ValueListenableBuilder<int>(
              valueListenable: OfflineStore.changes,
              builder: (context, _, _) => RefreshIndicator(
                onRefresh: getData,
                child: rows.isEmpty
                    ? EmptyBody(
                        icon: Icons.library_music_outlined,
                        title: _search.text.trim().isEmpty
                            ? 'Noch keine Sammlung angelegt.'
                            : 'Keine Sammlung mit »${_search.text.trim()}«.',
                        hint: _search.text.trim().isEmpty
                            ? 'Mappen und Marschbücher werden im MuseAdmin zusammengestellt.'
                            : null,
                      )
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (context, index) =>
                            rows[index] is CollectionType || index + 1 >= rows.length || rows[index + 1] is CollectionType
                                ? const SizedBox.shrink()
                                : const Divider(indent: 68, endIndent: 16),
                        itemBuilder: (context, index) {
                          final row = rows[index];

                          if (row is CollectionType) {
                            return SectionHeader(row.label);
                          }

                          final collection = row as Collection;
                          final List<OfflineSelection> offline =
                              OfflineStore.inCollection(collection.id);

                          return ListTile(
                            onTap: () => _open(collection),
                            leading: Icon(_iconFor(collection.type), color: scheme.primary),
                            title: Text(
                              collection.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            // Which Stimme, not only that there is one: a phone holding the
                            // 3. Trompete of this Mappe has nothing for the player who reads
                            // the 1., and the difference is worth a line.
                            subtitle: offline.isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: OfflineMark(
                                      size: 15,
                                      complete: offline.every((saved) => saved.complete),
                                      label: offline.map((saved) => saved.label).join(' · '),
                                    ),
                                  ),
                            trailing: Icon(Icons.chevron_right, color: scheme.outline),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
