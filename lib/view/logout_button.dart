import 'package:flutter/material.dart';

import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';

/// The way out, in the app bar of both Home tabs.
///
/// It asks first, and the question names two things worth knowing before answering: who
/// this phone is logged in as, and that getting back in needs a signal. Logging out in a
/// rehearsal room with no reception means not getting back in until there is some.
class LogoutButton extends StatelessWidget {
  const LogoutButton({Key? key}) : super(key: key);

  Future<void> _confirm(BuildContext context) async {
    final String username = await RemoteServices().currentUsername();
    if (!context.mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden?'),
        content: Text(username.isEmpty
            ? 'Für die nächste Anmeldung brauchst du Benutzername, Passwort und eine Internetverbindung.'
            : 'Dieses Gerät ist als »$username« angemeldet.\n\n'
                'Für die nächste Anmeldung brauchst du Benutzername, Passwort und eine Internetverbindung.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await endSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Abmelden',
      onPressed: () => _confirm(context),
    );
  }
}
