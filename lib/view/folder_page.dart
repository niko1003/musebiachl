import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/api/folder_composition.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/score_page.dart';

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
    compositions = await RemoteServices().getFolderCompositions(widget.id);
    if (compositions != null) {
      setState(() {
        print(compositions);
        isLoaded = true;
      });
    }


  }

  @override
  Widget build(BuildContext context) {
    print(context);
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

              int fileId = compositions![index].scoreParts[0].imageId;
              var label = compositions![index].compositionLabel + " - " + fileId.toString();
              return
                Container(
                  child: ListTile(
                    onTap: () => Navigator.pushNamed(
                      context,
                      ScorePage.routeName,
                      arguments: ScoreArguments(
                        fileId,
                      ),
                    ),
                    title: Text(label),
                  ),
                );
            }
        ),
        replacement: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Loading Musicians from API'),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
      ),
    );
  }
}
