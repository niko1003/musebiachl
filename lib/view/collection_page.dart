import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/collection_composition.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/score_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  //List to store post data
  List<CollectionComposition>? compositions;
  List<String> cachedFiles = List.empty();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  //boolean to trigger if loaded
  var isLoaded = false;
  final String collectionName = "schurli";

  @override
  void initState() {
    super.initState();
    getData();
  }

  //function to get Data from API
  getData() async {
    String instrumentId = await _prefs.then((SharedPreferences prefs) {
      return prefs.getString('instrumentId') ?? '';
    });

    cachedFiles = await _prefs.then((SharedPreferences prefs) {
      return prefs.getStringList('cached-files') ?? List.empty();
    });

    try {
      compositions =
          await RemoteServices().getCollectionCompositions(instrumentId, widget.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade300,
      ));
      compositions = [];
    } finally {
      setState(() {
        isLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: ListView.builder(
            itemCount: compositions?.length,
            itemBuilder: (context, index) {
              int fileId = compositions![index].imageId;
              var label = compositions![index].compositionLabel;
              var instrumentLabel = compositions![index].instrumentLabel;
              int collectionOrdering = compositions![index].collectionOrdering;
              bool cached = cachedFiles.contains(fileId.toString());

              String subtitle = compositions![index].scoreNotes == null
                  ? instrumentLabel
                  : '$instrumentLabel - ${compositions![index].scoreNotes!}';

              var listTile = fileId == 0
                  ? ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text(collectionOrdering.toString()),
                      ),
                      title: Text(label),
                      enabled: false)
                  : ListTile(
                      enabled: true,
                      onTap: () => Navigator.pushNamed(
                        context,
                        ScorePage.routeName,
                        arguments: ScoreArguments(
                          fileId,
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            cached ? Colors.lightGreen : Colors.blue,
                        child: Text(collectionOrdering.toString()),
                      ),
                      title: Text(label),
                      subtitle: Text(subtitle),
                    );

              return Container(child: listTile);
            }),
      ),
    );
  }
}
