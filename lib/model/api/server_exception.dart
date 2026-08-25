import 'dart:convert';

/// A readable message for a non-200 response.
///
/// The server's own ErrorInfo body ({errorCode, message}) when there is one - but not
/// every rejection carries one. Spring Security answers an invalid token with the
/// servlet container's HTML error page, and anything Apache turns away never reaches the
/// backend at all. The old ServerException.fromJson called json.decode straight out and
/// threw a FormatException on both, which is how a rejected token surfaced as a parse
/// error rather than as something a player could act on.
String messageForResponse(String body, int statusCode) {
  try {
    final dynamic decoded = json.decode(body);
    if (decoded is Map<String, dynamic> && decoded["message"] is String) {
      return decoded["message"] as String;
    }
  } catch (_) {
    // not the server's JSON - the status code is all there is to go on
  }

  return 'Server-Fehler ($statusCode)';
}
