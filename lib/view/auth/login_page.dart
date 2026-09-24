import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/auth_token.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  /// Why the login screen is up, when it is not simply the app starting - a rejected
  /// token, or a logout. Shown above the form, not as a SnackBar: a bar that has already
  /// slid away by the time someone looks at the phone explains nothing.
  final String? message;

  const LoginPage({Key? key, this.message}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RemoteServices remoteService = RemoteServices();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String authToken = '';

  @override
  void initState() {
    super.initState();
    getData();
  }

  /// A stored token goes straight through to HomePage without being checked first.
  ///
  /// That is deliberate: verifying it would need the network, and the app has to open in
  /// a rehearsal room with no signal. A token that is no longer good is caught by the
  /// first real request instead - the 401/403 comes back as SessionExpiredException and
  /// lands the player back here, with a line saying so.
  getData() async {
    authToken = await _prefs.then((SharedPreferences prefs) {
      return prefs.getString('token') ?? '';
    });

    if (authToken.isNotEmpty && mounted) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => HomePage(authToken: authToken)));
    }
  }

  Future<void> login() async {
    try {
      AuthToken authToken = await remoteService.login(
        usernameController.text.trim(),
        passwordController.text,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => HomePage(authToken: authToken.token)));

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      showError(context, 'Error: ${e.toString()}');
    }
  }

  bool isVisible = true;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Enough room for the keyboard, and a width that does not stretch the form
            // across a tablet.
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The Vereinslogo rather than a Material note glyph: this is the one
                  // screen with room for it, and the one moment where saying whose
                  // Noten these are is the whole message.
                  const Center(child: BrandLogo(width: 200)),
                  const SizedBox(height: 24),
                  Text(
                    'Muse Biachl',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Die Noten der Kapelle',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  if (widget.message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: scheme.onSecondaryContainer, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.message!,
                              style: TextStyle(color: scheme.onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    controller: usernameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      // Not Icons.mail: there is no e-mail address anywhere in the
                      // model, and a phone that autocapitalises the first letter of a
                      // case-sensitive username is its own support ticket.
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: usernameController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(usernameController.clear),
                            ),
                      labelText: 'Benutzername',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: isVisible,
                    controller: passwordController,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => login(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => isVisible = !isVisible),
                      ),
                      labelText: 'Passwort',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: login,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Anmelden'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Zum Anmelden brauchst du eine Internetverbindung. Danach funktioniert '
                    'das Biachl auch ohne Empfang.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
