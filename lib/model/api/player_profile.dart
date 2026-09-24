import 'dart:convert';

/// Who this phone is logged in as, and what they play.
///
/// It lives on the account, not on the device: a musician who gets a new phone has not
/// changed instrument. The device keeps a copy so the app opens with no signal, and so
/// that a change made offline can go up on the next connection ([pending]).
class PlayerProfile {
  PlayerProfile({
    this.username = '',
    this.registerId,
    this.registerLabel,
    this.instrumentId,
    this.instrumentLabel,
    this.pending = false,
  });

  String username;

  /// The register - Flügelhorn, Klarinette, Schlagwerk.
  String? registerId;
  String? registerLabel;

  /// The exact instrument, when this player has said. Sets the register with it.
  String? instrumentId;
  String? instrumentLabel;

  /// Set on a device copy the server has not accepted yet.
  bool pending;

  bool get isEmpty => registerId == null && instrumentId == null;

  /// What to show as "what I play": the instrument if there is one, else the register.
  String? get label => instrumentLabel ?? registerLabel;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        username: json["username"] ?? '',
        registerId: json["registerId"],
        registerLabel: json["registerLabel"],
        instrumentId: json["instrumentId"],
        instrumentLabel: json["instrumentLabel"],
        pending: json["pending"] ?? false,
      );

  static PlayerProfile fromJsonString(String str) =>
      PlayerProfile.fromJson(json.decode(str));

  Map<String, dynamic> toJson() => {
        "username": username,
        "registerId": registerId,
        "registerLabel": registerLabel,
        "instrumentId": instrumentId,
        "instrumentLabel": instrumentLabel,
        "pending": pending,
      };

  String toJsonString() => json.encode(toJson());
}
