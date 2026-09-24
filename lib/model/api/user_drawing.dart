import 'dart:convert';
import 'dart:ui' show Offset;

/// One run of the pencil: the points it passed through, in **normalised** image
/// coordinates (0..1 across the page, 0..1 down it).
///
/// Normalised and not pixels, because the same marks have to land in the same place on a
/// phone held upright, a tablet, and the same page zoomed in to one bar.
class Stroke {
  final List<Offset> points;

  const Stroke(this.points);
}

/// A word written on the page - "2x", "Achtung!", "leise", a bar number.
///
/// The other half of what people do to paper, and the half a pencil is bad at: nobody
/// finger-writes legibly on a phone, and what is meant is a word, not a shape.
///
/// [at] is the top-left corner and [size] the cap height, both normalised the same way a
/// stroke's points are - [size] against the page's *shorter* side, so a note keeps its
/// proportion on a page in either orientation.
class Annotation {
  /// About 3.5% of the page's short side: roughly the height of a rehearsal mark printed
  /// on the page, which is the size people write in by hand.
  static const double defaultSize = 0.035;
  static const double minSize = 0.015;
  static const double maxSize = 0.09;

  final Offset at;
  final String text;
  final double size;

  const Annotation({required this.at, required this.text, this.size = defaultSize});

  Annotation copyWith({Offset? at, String? text, double? size}) => Annotation(
        at: at ?? this.at,
        text: text ?? this.text,
        size: size ?? this.size,
      );
}

/// What one player has put onto one page: lines, and words.
///
/// [pending] is local-only bookkeeping: true when these marks have not reached the server
/// yet, which is the normal state of anything written in a rehearsal room with no signal.
/// It is what stops the next fetch from quietly overwriting them.
class UserDrawing {
  final int imageId;
  final int imageRevision;
  final List<Stroke> strokes;
  final List<Annotation> texts;
  final bool pending;

  const UserDrawing({
    required this.imageId,
    required this.imageRevision,
    required this.strokes,
    this.texts = const [],
    this.pending = false,
  });

  bool get isEmpty => strokes.isEmpty && texts.isEmpty;

  UserDrawing copyWith({
    List<Stroke>? strokes,
    List<Annotation>? texts,
    int? imageRevision,
    bool? pending,
  }) =>
      UserDrawing(
        imageId: imageId,
        imageRevision: imageRevision ?? this.imageRevision,
        strokes: strokes ?? this.strokes,
        texts: texts ?? this.texts,
        pending: pending ?? this.pending,
      );

  factory UserDrawing.fromJson(Map<String, dynamic> json) => UserDrawing(
        imageId: json["imageId"],
        imageRevision: json["imageRevision"] ?? 0,
        strokes: strokesFromJson(json["strokes"]),
        texts: textsFromJson(json["strokes"]),
        pending: json["pending"] ?? false,
      );

  /// The shape the local cache holds - the server payload plus [pending].
  ///
  /// One string for both kinds of mark, under the key the server calls `strokes`: that
  /// column is the page's whole annotation and always was, and the server has never
  /// looked inside it.
  Map<String, dynamic> toJson() => {
        "imageId": imageId,
        "imageRevision": imageRevision,
        "strokes": marksToJson(strokes, texts),
        "pending": pending,
      };
}

List<UserDrawing> userDrawingsFromJson(String str) => List<UserDrawing>.from(
    json.decode(str).map((x) => UserDrawing.fromJson(x)));

/// Everything on a page travels as one JSON string, which the server stores without ever
/// looking inside it:
///
/// ```json
/// {"v":2,"strokes":[[x,y,x,y,...],...],"texts":[{"x":..,"y":..,"s":..,"t":"2x"}]}
/// ```
///
/// One flat list of doubles per stroke rather than pairs of pairs, and four decimals -
/// that is well under half a pixel on any scan, and it keeps a page of scribbles down to
/// a couple of kilobytes.
///
/// `v` went from 1 to 2 when the words arrived. Nothing had to be migrated: an app that
/// only knows v1 reads `strokes` and ignores the rest, which is the right behaviour -
/// it draws the lines it understands rather than refusing the page.
String? marksToJson(List<Stroke> strokes, List<Annotation> texts) {
  if (strokes.isEmpty && texts.isEmpty) return null;

  final List<List<double>> encoded = strokes
      .map((stroke) => <double>[
            for (final point in stroke.points) ...[
              _round(point.dx),
              _round(point.dy),
            ]
          ])
      .toList();

  return json.encode({
    "v": 2,
    "strokes": encoded,
    if (texts.isNotEmpty)
      "texts": [
        for (final Annotation text in texts)
          {
            "x": _round(text.at.dx),
            "y": _round(text.at.dy),
            "s": _round(text.size),
            "t": text.text,
          }
      ],
  });
}

List<Stroke> strokesFromJson(String? raw) {
  final dynamic strokes = _field(raw, "strokes");
  if (strokes is! List) return const [];

  return strokes.whereType<List>().map((flat) {
    final points = <Offset>[];
    for (int i = 0; i + 1 < flat.length; i += 2) {
      points.add(Offset(
          (flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble()));
    }
    return Stroke(points);
  }).where((stroke) => stroke.points.isNotEmpty).toList();
}

List<Annotation> textsFromJson(String? raw) {
  final dynamic texts = _field(raw, "texts");
  if (texts is! List) return const [];

  final List<Annotation> parsed = <Annotation>[];
  for (final dynamic entry in texts) {
    if (entry is! Map) continue;

    final dynamic text = entry["t"];
    final dynamic x = entry["x"];
    final dynamic y = entry["y"];
    if (text is! String || text.isEmpty || x is! num || y is! num) continue;

    final dynamic size = entry["s"];
    parsed.add(Annotation(
      at: Offset(x.toDouble(), y.toDouble()),
      text: text,
      size: size is num ? size.toDouble() : Annotation.defaultSize,
    ));
  }
  return parsed;
}

/// One key out of the stored object, or null for anything that cannot be read.
///
/// A drawing that cannot be parsed is not worth taking the page down for - and a page
/// that has been written on since this version of the app was built must still show its
/// lines.
dynamic _field(String? raw, String key) {
  if (raw == null || raw.isEmpty) return null;

  try {
    final dynamic decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded[key];
  } catch (_) {
    return null;
  }
}

double _round(double value) => (value * 10000).roundToDouble() / 10000;
