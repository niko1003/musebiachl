import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/auth_token.dart';
import 'package:musebiachl/service/remote_service.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade300,
      ));
    }
  }

  bool isVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        key: const Key("main"),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                constraints: const BoxConstraints.expand(),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 50,
                    ),
                    const Text(
                      'Muse Biachl',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    if (widget.message != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(widget.message!),
                      ),
                    TextField(
                      controller: usernameController,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        // Not Icons.mail: there is no e-mail address anywhere in the
                        // model, and a phone that autocapitalises the first letter of a
                        // case-sensitive username is its own support ticket.
                        prefixIcon: const Icon(Icons.person),
                        suffixIcon: usernameController.text.isEmpty
                            ? const Text('')
                            : GestureDetector(
                                onTap: () {
                                  usernameController.clear();
                                },
                                child: const Icon(Icons.close)),
                        hintText: 'Benutzername',
                        labelText: 'Benutzername',
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    TextField(
                      obscureText: isVisible,
                      controller: passwordController,
                      decoration: InputDecoration(
                        // icon: Icon(Icons.mail),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: GestureDetector(
                            onTap: () {
                              isVisible = !isVisible;
                              setState(() {});
                            },
                            child: Icon(isVisible
                                ? Icons.visibility
                                : Icons.visibility_off)),
                        hintText: 'Passwort',
                        labelText: 'Passwort',
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    ElevatedButton(
                        onPressed: login,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Text('Anmelden'),
                        ))
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
