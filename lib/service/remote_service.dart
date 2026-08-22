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

/// Network calls, and the store that makes the app work without a signal.
///
/// Every list is available two ways: `cachedX()` reads what is on the device and never
/// touches the network, `fetchX()` asks the server and writes the result back. Pages ask
/// for both - the cache renders at once, the fetch corrects it a moment later.
///
/// The store used to be the *only* path: once a response was written it was returned for
/// ever, with no expiry and nothing wired to clear it. A piece added to a Mappe never
/// reached anyone who had opened that Mappe before. That is what the split is for -
/// offline still works, it just stops being permanent.
class RemoteServices {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  //setup http client to handle multiple request
  var client = http.Client();

  static String baseUrl = 'https://klenig.at/muse';
  static String localToken = 'not-set';

  static const String _collectionsKey = 'collections';
  static const String _instrumentGroupsKey = 'instrument-groups';

  /// Deliberately not the old `collection-{1}-{uuid}`, whose literal braces came from a
  /// mis-typed interpolation. Renaming it is also the one-time flush of everything the
  /// unexpiring store had accumulated under the broken name.
  static String _compositionsKey(int collectionId, String instrumentId) =>
      'collection-$collectionId-$instrumentId';

  Future<Map<String, String>> createRequestHeaders() async {
    final SharedPreferences prefs = await _prefs;
    String t = prefs.getString("token") ?? localToken;
    return {"x-muse-token": t};
  }

  Future<void> persistAuthToken(AuthToken authToken) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString("token", authToken.token);
  }

  Future<void> clearAuthToken() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove("token");
  }

  Future<void> clearAll() async {
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

  // --- the pieces of one Mappe, for one instrument ------------------------------

  Future<List<CollectionComposition>?> cachedCollectionCompositions(
      String instrumentId, int collectionId) async {
    final String stored =
        await _read(_compositionsKey(collectionId, instrumentId));
    return stored.isEmpty ? null : collectionCompositionFromJson(stored);
  }

  Future<List<CollectionComposition>?> fetchCollectionCompositions(
      String instrumentId, int collectionId) async {
    final String json = await _get(
      '$baseUrl/app/collection/$collectionId/find-for-instrument?instrumentId=$instrumentId',
      const Duration(seconds: 15),
    );
    await _write(_compositionsKey(collectionId, instrumentId), json);
    return collectionCompositionFromJson(json);
  }

  // --- instruments --------------------------------------------------------------

  Future<List<InstrumentGroup>?> cachedInstrumentGroups() async {
    final String stored = await _read(_instrumentGroupsKey);
    return stored.isEmpty ? null : instrumentGroupsFromJson(stored);
  }

  Future<List<InstrumentGroup>?> fetchInstrumentGroups() async {
    final String json =
        await _get('$baseUrl/app/instrument', const Duration(seconds: 15));
    await _write(_instrumentGroupsKey, json);
    return instrumentGroupsFromJson(json);
  }

  // --- Mappen -------------------------------------------------------------------

  Future<List<Collection>?> cachedCollections() async {
    final String stored = await _read(_collectionsKey);
    return stored.isEmpty ? null : collectionsFromJson(stored);
  }

  Future<List<Collection>?> fetchCollections() async {
    final String json =
        await _get('$baseUrl/app/collection/', const Duration(seconds: 20));
    await _write(_collectionsKey, json);
    return collectionsFromJson(json);
  }

  // --- plumbing -----------------------------------------------------------------

  Future<String> _read(String key) async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getString(key) ?? '';
  }

  Future<void> _write(String key, String json) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(key, json);
  }

  /// One authenticated GET. Throws the server's own message on a non-200, so the caller
  /// can decide whether that is worth showing - offline with something already on screen
  /// is not.
  Future<String> _get(String url, Duration timeout) async {
    Response response;
    try {
      response = await client
          .get(Uri.parse(url), headers: await createRequestHeaders())
          .timeout(timeout);
    } on TimeoutException catch (_) {
      throw Exception('cannot reach server (timeout ${timeout.inSeconds}s)');
    }

    final String json = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return json;
    }

    throw Exception(serverExceptionFromJson(json).message);
  }
}
