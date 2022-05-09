import 'package:http/http.dart' as http;

import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/api/folder_composition.dart';

//Class to make Network Calls
class RemoteServices {
  //setup http client to handle multiple request
  var client = http.Client();

  Future<List<FolderComposition>?> getFolderCompositions(int folderId) async {

    var uri = Uri.parse('http://localhost:8080/muse/app/folder/' + folderId.toString() + '/find-for-musician?musicianId=1');
    var response = await client.get(uri);

    //Check for response
    if (response.statusCode == 200) {
      var json = response.body;
      return folderCompositionFromJson(json);
    } else {
      print('${response.statusCode}');
    }
  }

  Future<List<Musician>?> getMusicians() async {
    //setup http client
    var uri = Uri.parse('http://localhost:8080/muse/app/musician');
    var response = await client.get(uri);

    //Check for response
    if (response.statusCode == 200) {
      var json = response.body;
      return musicansFromJson(json);
    } else {
      print('${response.statusCode}');
    }
  }


  Future<List<Folder>?> getFolders() async {
    //setup http client
    var uri = Uri.parse('http://localhost:8080/muse/app/folder/');
    var response = await client.get(uri);

    //Check for response
    if (response.statusCode == 200) {
      var json = response.body;
      return foldersFromJson(json);
    } else {
      print('${response.statusCode}');
    }
  }

}
