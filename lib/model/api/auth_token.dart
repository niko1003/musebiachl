import 'dart:convert';

AuthToken authTokenFromJson(String str) => 
    (AuthToken.fromJson(json.decode(str)));

class AuthToken {
  AuthToken({
    required this.token,
    required this.username,
  });

  String token;
  String username;

  factory AuthToken.fromJson(Map<String, dynamic> json) =>
      AuthToken(token: json["authToken"], username: json["username"]);

  Map<String, dynamic> toJson() =>
      {"authToken": token, "username": username};
}
