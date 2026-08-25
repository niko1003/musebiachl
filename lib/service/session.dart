import 'package:flutter/material.dart';

import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/auth/login_page.dart';

/// The app's navigator, so a session can be ended from anywhere.
///
/// A rejected token arrives inside whatever request happened to be in flight, which may
/// be three pages deep in a Mappe. Handing a BuildContext down to the service layer for
/// that one case is worse than one key on MaterialApp.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// What the login screen says when it was not the player who asked for it.
///
/// Not "abgelaufen": these tokens have no expiry. The account was deleted, or the token
/// was cleared - either way it is the same thing to whoever is holding the phone.
const String sessionRejectedMessage =
    'Die Anmeldung ist nicht mehr gültig. Bitte neu anmelden.';

/// Ends the session and puts the login screen back up, wherever the app is.
///
/// Only two things call this: the logout button, and a 401/403 from the backend. Being
/// offline never does - the app is built to work from its cache in a rehearsal room, and
/// throwing someone out to a login screen they cannot get past without a signal is the
/// one thing that must not happen.
///
/// pushAndRemoveUntil with a false predicate leaves exactly one route on the stack, so a
/// second call while the first is still settling is a no-op rather than a pile of login
/// screens.
Future<void> endSession({String? reason}) async {
  await RemoteServices().clearSession();

  final NavigatorState? navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => LoginPage(message: reason)),
    (route) => false,
  );
}
