import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
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

  Future<Map<String, String>> createRequestHeaders() async {
    final SharedPreferences prefs = await _prefs;
    String t = prefs.getString("token") ?? localToken;
    return {"x-muse-token": t};
  }

  persistAuthToken(AuthToken authToken) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString("token", authToken.token);
  }

  clearAuthToken() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove("token");
  }

  clearAll() async {
    final SharedPreferences prefs = await _prefs;
    prefs.clear();
  }

  Future<AuthToken> login(String username, String password) async {
    var uri = Uri.parse(
        baseUrl + '/auth/token?username=' + username + "&password=" + password);

    Response response;
    try {
      response = await client.post(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException catch (_) {
      throw Exception("cannot reach server / Server offline.");
    }

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

  Future<List<FolderComposition>?> getFolderCompositions(
      int musicianId, int folderId) async {
    final String storedKey = "folder-{$folderId}-{$musicianId}";
    final SharedPreferences prefs = await _prefs;
    String m = prefs.getString(storedKey) ?? "";
    if (m.isNotEmpty) {
      return folderCompositionFromJson(m);
    }

    var uri = Uri.parse(baseUrl +
        '/app/folder/' +
        folderId.toString() +
        '/find-for-musician?musicianId=' +
        musicianId.toString());

    Response response;
    try {
      response = await client
          .get(uri, headers: await createRequestHeaders())
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (_) {
      throw Exception("cannot reach server (timeout 5 sec)");
    }
    //Check for response
    String json = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      prefs.setString(storedKey, json);
      return folderCompositionFromJson(json);
    } else {
      ServerException serverException = serverExceptionFromJson(json);
      throw Exception(serverException.message);
    }
  }

  Future<List<Musician>?> getMusicians() async {
    const String storedKey = "musicians";
    final SharedPreferences prefs = await _prefs;
    String m = prefs.getString(storedKey) ?? "";
    if (m.isNotEmpty) {
      return musicansFromJson(m);
    }

    //setup http client
    var uri = Uri.parse(baseUrl + '/app/musician');

    Response response;
    try {
      response = await client
          .get(uri, headers: await createRequestHeaders())
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (_) {
      throw Exception("cannot reach server (timout 5 sec)");
    }

    //Check for response
    String json = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      prefs.setString(storedKey, json);
      return musicansFromJson(json);
    } else {
      ServerException serverException = serverExceptionFromJson(json);
      throw Exception(serverException.message);
    }
  }

  Future<List<Folder>?> getFolders() async {
    //setup http client
    const String storedKey = "folders";
    final SharedPreferences prefs = await _prefs;
    String m = prefs.getString(storedKey) ?? "";
    if (m.isNotEmpty) {
      return foldersFromJson(m);
    }

    var uri = Uri.parse(baseUrl + '/app/folder/');

    Response response;
    try {
      response = await client
          .get(uri, headers: await createRequestHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (_) {
      throw Exception("cannot reach server (timeout 10 sec)");
    }

    //Check for response
    String json = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      prefs.setString(storedKey, json);
      return foldersFromJson(json);
    } else {
      ServerException serverException = serverExceptionFromJson(json);
      throw Exception(serverException.message);
    }
  }
}
