import 'dart:convert';


List<FolderComposition> folderCompositionFromJson(String str) => List<FolderComposition>.from(json.decode(str).map((x) => FolderComposition.fromJson(x)));
String folderCompositionToJson(List<FolderComposition> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

List<ScorePart> scorePartsFromJson(String str) => List<ScorePart>.from(json.decode(str).map((x) => ScorePart.fromJson(x)));
String scorePartsToJson(List<ScorePart> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));


class FolderComposition {
  FolderComposition({
    required this.musicianId,
    required this.compositionLabel,
    required this.scoreParts,
  });

  int musicianId;
  String compositionLabel;
  List<ScorePart> scoreParts;

  factory FolderComposition.fromJson(Map<String, dynamic> json) => FolderComposition(
    musicianId: json["musicianId"],
    compositionLabel: json["compositionLabel"],
    scoreParts: List<ScorePart>.from(json["scoreParts"].map((x) => ScorePart.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "musicianId": musicianId,
    "compositionLabel": compositionLabel,
    "scoreParts": scorePartsToJson(scoreParts),
  };
}

class ScorePart {
  ScorePart({
    required this.id,
    required this.imageId,
    this.instrumentLabel
  });

  int id;
  int imageId;
  String? instrumentLabel;

  factory ScorePart.fromJson(Map<String, dynamic> json) => ScorePart(
    id: json["id"],
    imageId: json["imageId"],
    instrumentLabel: json["instrumentLabel"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "imageId": imageId,
    "instrumentLabel": instrumentLabel,
  };
}
