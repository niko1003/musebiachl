import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/api/folder_composition.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/score_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A Widget that accepts the necessary arguments via the constructor.

class FolderPage extends StatefulWidget {

  static const routeName = '/folder';

  final int id;
  final String name;

  const FolderPage({
    Key? key,
    required this.id,
    required this.name,
  }) : super(key: key);

  @override
  State<FolderPage> createState() => _FolderPage();
}

class _FolderPage extends State<FolderPage> {

  //List to store post data
  List<FolderComposition>? compositions;
  
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  //boolean to trigger if loaded
  var isLoaded = false;
  final String folderName = "schurli";

  @override
  void initState() {
    super.initState();
    getData();
  }

  //function to get Data from API
  getData() async {

    int musicianId = await _prefs.then((SharedPreferences prefs) {
      return prefs.getInt('musicianId') ?? 11;
    });

    if(musicianId != null) {
      compositions = await RemoteServices().getFolderCompositions(musicianId, widget.id);
    }

    if (compositions != null) {
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
        child: ListView.builder(
            itemCount: compositions?.length,
            itemBuilder: (context, index) {
            
              int fileId = compositions![index].imageId;
              int scoreId = compositions![index].scoreId;
              var label = compositions![index].compositionLabel;
              var instrumentLabel = compositions![index].instrumentLabel;
              int folderOrdering = compositions![index].folderOrdering;

              
              String subtitle = compositions![index].scoreNotes == null ? 
                instrumentLabel : 
                instrumentLabel + " - " + compositions![index].scoreNotes!;


              var listTile;
              if(fileId == 0) {
                  listTile = ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text(folderOrdering.toString()),
                      ),
                    title: Text(label),
                    enabled: false
                  );
              } else {
                  listTile = ListTile(
                    enabled: true,
                    onTap: () => Navigator.pushNamed(
                      context,
                      ScorePage.routeName,
                      arguments: ScoreArguments(
                        fileId,
                      ),
                    ),
                     leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(folderOrdering.toString()),
                      ),
                    title: Text(label),
                    subtitle: Text(subtitle),
                  );
              }
              return
                Container(
                  child: listTile
                );
            }
        ),
        replacement: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Loading Noten from API'),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
      ),
    );
  }
}

