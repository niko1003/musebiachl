import 'package:musebiachl/model/composition.dart';

class Folder {
  int id;
  String name;
  String version;
  List compositions;


  Folder({required this.id, required this.name, required this.version, required this.compositions});

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
        id: json['id'],
        name: json['name'],
        version: json['version'],
        compositions: json['compositions'].map((data) => Composition.fromJson(data)).toList(),
    );
  }

  @override
  String toString() {
    return 'Folder{id: $id, name: $name, version: $version, compositions: $compositions}';
  }
}
