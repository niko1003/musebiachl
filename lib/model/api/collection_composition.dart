import 'dart:convert';


List<CollectionComposition> collectionCompositionFromJson(String str) => List<CollectionComposition>.from(json.decode(str).map((x) => CollectionComposition.fromJson(x)));
String collectionCompositionToJson(List<CollectionComposition> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));



class CollectionComposition {
  CollectionComposition({
    required this.compositionLabel,
    required this.scoreId,
    required this.imageId,
    required this.instrumentId,
    required this.instrumentLabel,
    required this.primaryInstrument,
    required this.collectionOrdering,
    required this.page,
    this.scoreNotes,
  });

  String compositionLabel;
  String? scoreNotes;
  
  int scoreId;
  int imageId;
  String instrumentId;
  String instrumentLabel;
  bool primaryInstrument;

  int collectionOrdering;
  int page;

  factory CollectionComposition.fromJson(Map<String, dynamic> json) => CollectionComposition(
    compositionLabel: json["compositionLabel"],
    scoreId: json["scoreId"],
    imageId: json["imageId"],
    instrumentId: json["instrumentId"],
    instrumentLabel: json["instrumentLabel"],
    primaryInstrument: json["primaryInstrument"],
    collectionOrdering: json["collectionOrdering"],
    page: json["page"],
    scoreNotes: json["scoreNotes"],
  );

  Map<String, dynamic> toJson() => {
    "compositionLabel": compositionLabel,
  };
}
