import 'dart:convert';


List<FolderComposition> folderCompositionFromJson(String str) => List<FolderComposition>.from(json.decode(str).map((x) => FolderComposition.fromJson(x)));
String folderCompositionToJson(List<FolderComposition> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));



class FolderComposition {
  FolderComposition({
    required this.musicianId,
    required this.compositionLabel,
    required this.scoreId,
    required this.imageId,
    required this.instrumentId,
    required this.instrumentLabel,
    required this.primaryInstrument,
    required this.optionalInstrument,
  });

  int musicianId;
  String compositionLabel;
  
  int scoreId;
  int imageId;
  String instrumentId;
  String instrumentLabel;
  bool primaryInstrument;
  bool optionalInstrument;

  factory FolderComposition.fromJson(Map<String, dynamic> json) => FolderComposition(
    musicianId: json["musicianId"],
    compositionLabel: json["compositionLabel"],
    scoreId: json["scoreId"],
    imageId: json["imageId"],
    instrumentId: json["instrumentId"],
    instrumentLabel: json["instrumentLabel"],
    primaryInstrument: json["primaryInstrument"],
    optionalInstrument: json["optionalInstrument"],
  );

  Map<String, dynamic> toJson() => {
    "musicianId": musicianId,
    "compositionLabel": compositionLabel,
    
  };
}
