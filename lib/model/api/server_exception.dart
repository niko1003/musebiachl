import 'dart:convert';

serverExceptionFromJson(String str) =>
    (ServerException.fromJson(json.decode(str)));

class ServerException {
  ServerException({required this.errorCode, required this.message});

  String errorCode;
  String message;
  factory ServerException.fromJson(Map<String, dynamic> json) =>
      ServerException(errorCode: json["errorCode"], message: json["message"]);

  Map<String, dynamic> toJson() => {"errorCode": errorCode, "message": message};
}
