import 'package:flutter/material.dart';

import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/arg/folder_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/folder_page.dart';

class FoldersPage extends StatefulWidget {

  const FoldersPage({Key? key}) : super(key: key);

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

//
class _FoldersPageState extends State<FoldersPage> {

  List<Folder>? folders;
  var isLoaded = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  //function to get Data from API
  getData() async {
    folders = await RemoteServices().getFolders();
    if (folders != null) {
      setState(() {
        isLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappe auswählen.'),
        centerTitle: true,
      ),
      body: Visibility(
        visible: isLoaded,

        child: ListView.builder(
            itemCount: folders?.length,
            itemBuilder: (context, index) {
              var folderId = folders![index].id;
              var label = folders![index].version == null ? folders![index].name : folders![index].name + " (" + folders![index].version! + ")" ;

              return
                Container(
                  child: ListTile(
                    onTap: () => Navigator.pushNamed(
                      context,
                      FolderPage.routeName,
                      arguments: FolderArguments(
                          folderId,
                          label
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
              Text('Loading Folder from API'),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
      ),
    );
  }

}
