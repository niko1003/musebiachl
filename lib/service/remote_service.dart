import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:convert';

import 'package:musebiachl/model/api/auth_token.dart';
import 'package:musebiachl/model/api/collection.dart';
import 'package:musebiachl/model/api/instrument.dart';
import 'package:musebiachl/model/api/collection_composition.dart';
import 'package:musebiachl/model/api/server_exception.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/api/user_drawing.dart';

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
    await prefs.setString("username", authToken.username);
  }

  Future<String> currentUsername() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getString("username") ?? '';
  }

  /// Ends the session on this device.
  ///
  /// The token, the name it belongs to, and the instrument that person picked - the
  /// phone may well be handed to someone else next. The cached Mappen and the
  /// instrument list stay: that is the same library for everyone, and keeping it is
  /// what lets the next login work in a rehearsal room with no signal.
  ///
  /// localToken has to go with it. createRequestHeaders falls back to it when the
  /// store has no token, so leaving it set would keep sending the token that was just
  /// thrown away.
  Future<void> clearSession() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove("token");
    await prefs.remove("username");
    await prefs.remove("instrumentId");
    localToken = 'not-set';
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

    throw Exception(messageForResponse(json, response.statusCode));
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

  // --- the player's own pencil marks ---------------------------------------------

  /// Per user *and* per image, so a phone that gets handed on does not show one player's
  /// markings to the next. Keying on the name rather than clearing the lot at logout is
  /// also what lets someone log back in and still find what they drew offline.
  static String _drawingKey(String username, int imageId) =>
      'drawing-$username-$imageId';

  Future<UserDrawing?> cachedDrawing(int imageId) async {
    final SharedPreferences prefs = await _prefs;
    final String stored =
        prefs.getString(_drawingKey(await currentUsername(), imageId)) ?? '';
    if (stored.isEmpty) return null;

    try {
      return UserDrawing.fromJson(json.decode(stored));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeDrawingCache(UserDrawing drawing) async {
    final SharedPreferences prefs = await _prefs;
    final String key = _drawingKey(await currentUsername(), drawing.imageId);

    if (drawing.isEmpty && !drawing.pending) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, json.encode(drawing.toJson()));
  }

  /// One request for every page of the part being opened.
  Future<List<UserDrawing>> fetchDrawings(List<int> imageIds) async {
    if (imageIds.isEmpty) return const [];

    final String ids = imageIds.join(',');
    final String body = await _get(
      '$baseUrl/app/drawing?imageIds=$ids',
      const Duration(seconds: 10),
    );
    return userDrawingsFromJson(body);
  }

  /// Sends one page up. Empty strokes delete it server-side, which is what rubbing a page
  /// clean has to mean.
  Future<UserDrawing> putDrawing(UserDrawing drawing) async {
    final String body = await _put(
      '$baseUrl/app/drawing/${drawing.imageId}',
      {
        'strokes': strokesToJson(drawing.strokes),
        'imageRevision': drawing.imageRevision,
      },
      const Duration(seconds: 10),
    );
    return UserDrawing.fromJson(json.decode(body));
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

  /// One authenticated PUT of a JSON body. Same rules as _get about what it throws.
  Future<String> _put(String url, Object body, Duration timeout) async {
    Response response;
    try {
      final Map<String, String> headers = await createRequestHeaders();
      headers['Content-Type'] = 'application/json';

      response = await client
          .put(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(timeout);
    } on TimeoutException catch (_) {
      throw Exception('cannot reach server (timeout ${timeout.inSeconds}s)');
    }

    final String responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return responseBody;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SessionExpiredException();
    }

    throw Exception(messageForResponse(responseBody, response.statusCode));
  }

  /// One authenticated GET.
  ///
  /// Throws the server's own message on a non-200, so the caller can decide whether that
  /// is worth showing - offline with something already on screen is not. The exception
  /// is a rejected token, which comes back typed as SessionExpiredException: that one the
  /// caller must act on rather than sit out.
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

    // 401 and not just 403: the /app/** filter fails authentication inside
    // AbstractAuthenticationProcessingFilter, whose default failure handler sends 401
    // long before SecurityConfig's 403 entry point is ever consulted. Both mean the
    // same thing here - this token is no good any more.
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SessionExpiredException();
    }

    throw Exception(messageForResponse(json, response.statusCode));
  }
}
