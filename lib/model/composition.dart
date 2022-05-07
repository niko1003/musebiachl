class Composition {
  String id;
  String? name;
  int? scoreId;

  Composition({required this.id, this.name, this.scoreId});

  factory Composition.fromJson(Map<String, dynamic> json) {
    return Composition(
      id: json['id'],
      name: json['name'],
      scoreId: json['scoreId']
    );
  }

  @override
  String toString() {
    return 'Composition{id: $id, name: $name, scoreId: $scoreId}';
  }
}
