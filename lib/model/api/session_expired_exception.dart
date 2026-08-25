/// The server rejected the token: it was cleared, or the account behind it is gone.
///
/// It has its own type because it is the one failure that must *not* be treated like
/// being offline. A timeout, a 500, no signal at all - none of those say anything about
/// the session, and the cached Mappe stays on screen. A 401/403 does say something, and
/// it is the only thing that may take the player back to the login screen.
class SessionExpiredException implements Exception {
  final String message;

  SessionExpiredException(
      [this.message = 'Die Anmeldung ist nicht mehr gültig.']);

  @override
  String toString() => message;
}
