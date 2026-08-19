import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:convert';

import 'package:musebiachl/model/api/auth_token.dart';
import 'package:musebiachl/model/api/collection.dart';
import 'package:musebiachl/model/api/instrument.dart';
import 'package:musebiachl/model/api/collection_composition.dart';
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
    Uri uri = Uri.parse(
        '$baseUrl/auth/token?username=$username&password=$password');

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

  Future<List<CollectionComposition>?> getCollectionCompositions(
      String instrumentId, int collectionId) async {
    final String storedKey = "collection-{$collectionId}-{$instrumentId}";
    final SharedPreferences prefs = await _prefs;
    String m = prefs.getString(storedKey) ?? "";
    if (m.isNotEmpty) {
      return collectionCompositionFromJson(m);
    }

    Uri uri = Uri.parse(
        '$baseUrl/app/collection/$collectionId/find-for-instrument?instrumentId=$instrumentId');

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
      return collectionCompositionFromJson(json);
    } else {
      ServerException serverException = serverExceptionFromJson(json);
      throw Exception(serverException.message);
    }
  }

  Future<List<InstrumentGroup>?> getInstrumentGroups() async {
    const String storedKey = "instrument-groups";
    final SharedPreferences prefs = await _prefs;
    String m = prefs.getString(storedKey) ?? "";
    if (m.isNotEmpty) {
      return instrumentGroupsFromJson(m);
    }

    //setup http client
    Uri uri = Uri.parse('$baseUrl/app/instrument');

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
      return instrumentGroupsFromJson(json);
    } else {
      ServerException serverException = serverExceptionFromJson(json);
      throw Exception(serverException.message);
    }
  }

  Future<List<Collection>?> getCollections() async {
    //setup http client
    const String storedKey = "collections";
    final SharedPreferences prefs = await _prefs;
    String m = prefs.getString(storedKey) ?? "";
    if (m.isNotEmpty) {
      return collectionsFromJson(m);
    }

    Uri uri = Uri.parse('$baseUrl/app/collection/');

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
      return collectionsFromJson(json);
    } else {
      ServerException serverException = serverExceptionFromJson(json);
      throw Exception(serverException.message);
    }
  }
}
