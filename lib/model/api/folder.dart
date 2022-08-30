import 'dart:convert';

List<Folder> foldersFromJson(String str) =>
    List<Folder>.from(json.decode(str).map((x) => Folder.fromJson(x)));
String foldersToJson(List<Folder> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Folder {
  Folder({required this.id, required this.name, this.version});

  int id;
  String name;
  String? version;

  factory Folder.fromJson(Map<String, dynamic> json) =>
      Folder(id: json["id"], name: json["name"], version: json["version"]);

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "version": version,
      };

  @override
  String toString() {
    return "($id,$name,$version)";
  }
}
