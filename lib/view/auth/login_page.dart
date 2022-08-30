import 'package:flutter/material.dart';
import 'package:musebiachl/model/api/auth_token.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RemoteServices remoteService = RemoteServices();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String authToken = '';

  persistToken(String paramAuthToken) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString('authToken', paramAuthToken);
    authToken = paramAuthToken;
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  //function to get Data from API
  getData() async {
    authToken = await _prefs.then((SharedPreferences prefs) {
      return prefs.getString('authToken') ?? '';
    });
  }

  Future<void> login() async {
    remoteService.login(
      emailController.text,
      passwordController.text,
    );

    try {
      AuthToken authToken = await remoteService.login(
        emailController.text,
        passwordController.text,
      );

      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => HomePage(authToken: authToken.token)));

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
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
      backgroundColor: Colors.red.shade300,
      body: Container(
        key: const Key("main"),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Image.asset(
                'assets/images/profile.png',
                height: 200,
                width: 200,
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                constraints: const BoxConstraints.expand(),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(35),
                        topRight: Radius.circular(35))),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 50,
                    ),
                    const Text(
                      'Login',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    TextField(
                      controller: emailController,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                          // icon: Icon(Icons.mail),
                          prefixIcon: const Icon(Icons.mail),
                          suffixIcon: emailController.text.isEmpty
                              ? const Text('')
                              : GestureDetector(
                                  onTap: () {
                                    emailController.clear();
                                  },
                                  child: const Icon(Icons.close)),
                          hintText: 'TK Muse',
                          labelText: 'Username',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1))),
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
                          hintText: 'type your password',
                          labelText: 'Password',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 1))),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    ElevatedButton(
                        onPressed: login,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Text('Submit'),
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
