import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/api/folder_composition.dart';
import 'package:musebiachl/model/constants.dart';

//Class to make Network Calls
class RemoteServices {
  //setup http client to handle multiple request
  var client = http.Client();

  String baseUrl = 'https://klenig.at/muse';

  Future<List<FolderComposition>?> getFolderCompositions(int folderId) async {

    var uri = Uri.parse(baseUrl + '/app/folder/' + folderId.toString() + '/find-for-musician?musicianId=' + Constants.selectedMusicianId.toString()); 
    var response = await client.get(uri);

    //Check for response
    if (response.statusCode == 200) {
      var json = utf8.decode(response.bodyBytes);
      return folderCompositionFromJson(json);
    } else {
      print('${response.statusCode}');
    }
  }

  Future<List<Musician>?> getMusicians() async {
    //setup http client
    var uri = Uri.parse(baseUrl + '/app/musician');
    var response = await client.get(uri);

    //Check for response
    if (response.statusCode == 200) {
      var x = utf8.decode(response.bodyBytes);
      return musicansFromJson(x);
    } else {
      print('${response.statusCode}');
    }
  }


  Future<List<Folder>?> getFolders() async {
    //setup http client
    var uri = Uri.parse(baseUrl + '/app/folder/');
    var response = await client.get(uri);

    //Check for response
    if (response.statusCode == 200) {
      var json = utf8.decode(response.bodyBytes);
      return foldersFromJson(json);
    } else {
      print('${response.statusCode}');
    }
  }

}
