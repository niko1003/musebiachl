import 'dart:convert';


List<CollectionComposition> collectionCompositionFromJson(String str) => List<CollectionComposition>.from(json.decode(str).map((x) => CollectionComposition.fromJson(x)));
String collectionCompositionToJson(List<CollectionComposition> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));



class CollectionComposition {
  CollectionComposition({
    required this.compositionLabel,
    required this.scoreId,
    required this.imageId,
    required this.imageRevision,
    required this.instrumentId,
    required this.instrumentLabel,
    required this.primaryInstrument,
    required this.collectionOrdering,
    required this.page,
    this.scoreNotes,
    this.bookletLabel,
    this.pieceOrdering,
  });

  String compositionLabel;
  String? scoreNotes;
  
  int scoreId;
  int imageId;

  /// When that image last changed, epoch millis. Part of the image URL and of its cache
  /// key, because rotate/crop/tile and the black-and-white pass all rewrite a page while
  /// keeping its id - caching on the id alone shows the old picture for ever.
  int imageRevision;
  String instrumentId;
  String instrumentLabel;
  bool primaryInstrument;

  int collectionOrdering;
  int page;

  /// The Heft this page is a page of - "Kirchenblech" - or null for an ordinary piece.
  ///
  /// A Sammlung holds a Heft by holding its scan, one Score of up to 80 pages, so without
  /// this the whole booklet is a single entry and reaching the Deutsche Messe in it means
  /// swiping past everything printed before it. When it is set, [compositionLabel] is the
  /// piece printed on the page and the app lists the pieces under the Heft.
  String? bookletLabel;

  /// Where that piece sits in the Heft's printed index; null for a page not cut out yet.
  int? pieceOrdering;

  factory CollectionComposition.fromJson(Map<String, dynamic> json) => CollectionComposition(
    compositionLabel: json["compositionLabel"],
    scoreId: json["scoreId"],
    imageId: json["imageId"],
    imageRevision: json["imageRevision"] ?? 0,
    instrumentId: json["instrumentId"],
    instrumentLabel: json["instrumentLabel"],
    primaryInstrument: json["primaryInstrument"],
    collectionOrdering: json["collectionOrdering"],
    page: json["page"],
    scoreNotes: json["scoreNotes"],
    bookletLabel: json["bookletLabel"],
    pieceOrdering: json["pieceOrdering"],
  );

  Map<String, dynamic> toJson() => {
    "compositionLabel": compositionLabel,
  };
}
