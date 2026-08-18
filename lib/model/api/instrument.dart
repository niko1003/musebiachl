import 'dart:convert';

List<InstrumentGroup> instrumentGroupsFromJson(String str) =>
    List<InstrumentGroup>.from(
        json.decode(str).map((x) => InstrumentGroup.fromJson(x)));

String instrumentGroupsToJson(List<InstrumentGroup> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

/// A group of instruments, as delivered by GET /app/instrument.
/// The picker renders one expandable section per group.
class InstrumentGroup {
  InstrumentGroup({
    required this.id,
    required this.label,
    required this.instruments,
  });

  String id;
  String label;
  List<Instrument> instruments;

  factory InstrumentGroup.fromJson(Map<String, dynamic> json) =>
      InstrumentGroup(
        id: json["id"],
        label: json["label"],
        instruments: List<Instrument>.from(
            json["instruments"].map((x) => Instrument.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "label": label,
        "instruments":
            List<dynamic>.from(instruments.map((x) => x.toJson())),
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
