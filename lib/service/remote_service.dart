import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:musebiachl/model/api/auth_token.dart';
import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/api/folder_composition.dart';
import 'package:musebiachl/model/api/server_exception.dart';

import 'package:shared_preferences/shared_preferences.dart';

//Class to make Network Calls
class RemoteServices {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  //setup http client to handle multiple request
  var client = http.Client();

  static String baseUrl = 'https://klenig.at/muse';
  static String localToken = 'not-set';

  persistAuthToken(AuthToken authToken) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString("token", authToken.token);
  }

  clearAuthToken() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove("token");
  }

  Future<AuthToken> login(String username, String password) async {
    var uri = Uri.parse(
        baseUrl + '/auth/token?username=' + username + "&password=" + password);
    var response = await client.post(uri);
    var json = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      AuthToken authToken = authTokenFromJson(json);
      localToken = authToken.token;
      persistAuthToken(authToken);

      return authToken;
    }

    ServerException serverException = serverExceptionFromJson(json);
    throw Exception(serverException.message);
  }

  Future<Map<String, String>> getHeaders() async {
    final SharedPreferences prefs = await _prefs;
    String t = prefs.getString("token") ?? localToken;
    return {"x-muse-token": t};
  }

  Future<List<FolderComposition>?> getFolderCompositions(
      int musicianId, int folderId) async {
    var uri = Uri.parse(baseUrl +
        '/app/folder/' +
        folderId.toString() +
        '/find-for-musician?musicianId=' +
        musicianId.toString());

    var response = await client.get(uri, headers: await getHeaders());

    //Check for response
    if (response.statusCode == 200) {
      var json = utf8.decode(response.bodyBytes);
      return folderCompositionFromJson(json);
    } else {
      return [];
    }
  }

  Future<List<Musician>?> getMusicians() async {
    //setup http client
    var uri = Uri.parse(baseUrl + '/app/musician');
    var response = await client.get(uri, headers: await getHeaders());

    //Check for response
    if (response.statusCode == 200) {
      var x = utf8.decode(response.bodyBytes);
      return musicansFromJson(x);
    } else {
      return [];
    }
  }

  Future<List<Folder>?> getFolders() async {
    //setup http client
    var uri = Uri.parse(baseUrl + '/app/folder/');
    var response = await client.get(uri, headers: await getHeaders());

    //Check for response
    if (response.statusCode == 200) {
      var json = utf8.decode(response.bodyBytes);
      return foldersFromJson(json);
    } else {
      return [];
    }
  }
}
