import 'dart:convert';


List<Musician> musicansFromJson(String str) => List<Musician>.from(json.decode(str).map((x) => Musician.fromJson(x)));
String musiciansToJson(List<Musician> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

List<Instrument> instrumentsFromJson(String str) => List<Instrument>.from(json.decode(str).map((x) => Instrument.fromJson(x)));
String instrumentsToJson(List<Instrument> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));


class Musician {
  Musician({
    required this.id,
    required this.firstName,
    required this.name,
    required this.instruments,
    required this.optionalInstruments,
  });

  int id;
  String firstName;
  String name;
  List<Instrument> instruments;
  List<Instrument> optionalInstruments;

  factory Musician.fromJson(Map<String, dynamic> json) => Musician(
    id: json["id"],
    firstName: json["firstName"],
    name: json["name"],
    instruments: List<Instrument>.from(json["instruments"].map((x) => Instrument.fromJson(x))),
    optionalInstruments: List<Instrument>.from(json["optionalInstruments"].map((x) => Instrument.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "firstName": firstName,
    "name": name,
    "instruments": instrumentsToJson(instruments),
    "optionalInstruments": instrumentsToJson(optionalInstruments)
  };
}

class Instrument {
  Instrument({
    required this.id,
    required this.label,
  });

  String id;
  String label;

  factory Instrument.fromJson(Map<String, dynamic> json) => Instrument(
    id: json["id"],
    label: json["label"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "label": label,
  };
}
