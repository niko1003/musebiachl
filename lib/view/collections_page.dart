import 'package:flutter/material.dart';

import 'package:musebiachl/model/api/collection.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/arg/collection_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/view/collection_page.dart';
import 'package:musebiachl/view/logout_button.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({Key? key}) : super(key: key);

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

//
class _CollectionsPageState extends State<CollectionsPage> {
  List<Collection>? collections;
  var isLoaded = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  /// Cache first, then the server - see CollectionPage.getData for why the failure is
  /// silent once something is already on screen.
  Future<void> getData() async {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade300,
      ));
      collections = [];
    }
  }

  /// One flat list of section headers (CollectionType) and entries (Collection),
  /// in the enum's own order, so ListView.builder can render both.
  List<Object> get _rows {
    final rows = <Object>[];
    for (final type in CollectionType.values) {
      final inType =
          (collections ?? []).where((entry) => entry.type == type).toList();
      if (inType.isEmpty) continue;
      rows.add(type);
      rows.addAll(inType);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappe auswählen.'),
        centerTitle: true,
        actions: const [LogoutButton()],
      ),
      body: Visibility(
        visible: isLoaded,
        replacement: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Loading Collection from API'),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: getData,
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];

              if (row is CollectionType) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                );
              }

              final collection = row as Collection;

              return ListTile(
                onTap: () => Navigator.pushNamed(
                  context,
                  CollectionPage.routeName,
                  arguments:
                      CollectionArguments(collection.id, collection.name),
                ),
                title: Text(collection.name),
              );
            },
          ),
        ),
      ),
    );
  }
}
