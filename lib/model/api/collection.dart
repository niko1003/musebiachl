import 'dart:convert';

List<Collection> collectionsFromJson(String str) =>
    List<Collection>.from(json.decode(str).map((x) => Collection.fromJson(x)));
String collectionsToJson(List<Collection> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

/// Mirrors Collection.CollectionType on the server. Unknown or missing values fall
/// back to concertFolder so an older server keeps working.
enum CollectionType {
  concertFolder('CONCERT_FOLDER', 'Konzertmappen'),
  marchBook('MARCH_BOOK', 'Marschbücher'),
  anthology('ANTHOLOGY', 'Sammlungen'),
  booklet('BOOKLET', 'Hefte');

  const CollectionType(this.key, this.label);

  final String key;
  final String label;

  static CollectionType fromKey(String? key) => CollectionType.values.firstWhere(
        (type) => type.key == key,
        orElse: () => CollectionType.concertFolder,
      );
}

class Collection {
  Collection({required this.id, required this.name, required this.type});

  int id;
  String name;
  CollectionType type;

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        id: json["id"],
        name: json["name"],
        type: CollectionType.fromKey(json["type"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "type": type.key,
      };

  @override
  String toString() {
    return "($id,$name,${type.key})";
  }
}
