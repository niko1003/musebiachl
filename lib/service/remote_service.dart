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
 // String baseUrl = 'http://localhost:8080/muse';

  Future<dynamic> login(String username, String password) async {

    //  var uri = Uri.parse(baseUrl + 'auth/login?username='+username+'&password='+password); 
    //  var response = await client.post(uri);
    getMusicians();
    return {
      'authToken' : '5446734f-dde7-4ab9-a430-792725655f0f',
      'message': "Login sucessful.",
      "errorCode": null
    };
  }

  Future<List<FolderComposition>?> getFolderCompositions(int musicianId, int folderId) async {


    var uri = Uri.parse(baseUrl + '/app/folder/' + folderId.toString() + '/find-for-musician?musicianId=' + musicianId.toString()); 
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
