import 'dart:convert';

List<CollectionSelection> collectionSelectionsFromJson(String str) =>
    List<CollectionSelection>.from(
        json.decode(str).map((x) => CollectionSelection.fromJson(x)));

String collectionSelectionsToJson(List<CollectionSelection> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

/// What a player picked, and therefore how the backend finds their pages.
///
/// Mirrors SelectionKind on the server. An unknown value falls back to a Stimme rather
/// than throwing - a server that learns a fourth kind must not take the app down.
enum SelectionKind {
  notation('NOTATION', 'Stimme'),
  instrument('INSTRUMENT', 'Instrument'),
  register('REGISTER', 'Register');

  const SelectionKind(this.key, this.label);

  final String key;
  final String label;

  static SelectionKind fromKey(String? key) => SelectionKind.values.firstWhere(
        (kind) => kind.key == key,
        orElse: () => SelectionKind.notation,
      );
}

/// One line a Sammlung can be read as: "1. in B", "2. Flügelhorn in B", "Schlagwerk".
///
/// The list comes from the pages that are really in that Sammlung, so what is offered is
/// what exists. [registerLabel] is null for a Stimme, which is why a favorite register
/// cannot pick one and the player does it himself.
class CollectionSelection {
  CollectionSelection({
    required this.kind,
    required this.id,
    required this.label,
    required this.pageCount,
    this.registerId,
    this.registerLabel,
    this.registerOrder,
  });

  SelectionKind kind;
  String id;
  String label;
  int pageCount;

  /// The register this line belongs to, null for a Stimme. The id, not the label, is what
  /// the player's own register is matched against.
  String? registerId;
  String? registerLabel;
  int? registerOrder;

  /// The section this line is listed under. A Stimme belongs to no register.
  String get section => registerLabel ?? 'Stimmen';

  factory CollectionSelection.fromJson(Map<String, dynamic> json) =>
      CollectionSelection(
        kind: SelectionKind.fromKey(json["kind"]),
        id: json["id"],
        label: json["label"],
        pageCount: json["pageCount"] ?? 0,
        registerId: json["registerId"],
        registerLabel: json["registerLabel"],
        registerOrder: json["registerOrder"],
      );

  Map<String, dynamic> toJson() => {
        "kind": kind.key,
        "id": id,
        "label": label,
        "pageCount": pageCount,
        "registerId": registerId,
        "registerLabel": registerLabel,
        "registerOrder": registerOrder,
      };
}
