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

/// What one player has pencilled onto one page.
///
/// [pending] is local-only bookkeeping: true when these marks have not reached the server
/// yet, which is the normal state of anything drawn in a rehearsal room with no signal.
/// It is what stops the next fetch from quietly overwriting them.
class UserDrawing {
  final int imageId;
  final int imageRevision;
  final List<Stroke> strokes;
  final bool pending;

  const UserDrawing({
    required this.imageId,
    required this.imageRevision,
    required this.strokes,
    this.pending = false,
  });

  bool get isEmpty => strokes.isEmpty;

  UserDrawing copyWith({List<Stroke>? strokes, int? imageRevision, bool? pending}) =>
      UserDrawing(
        imageId: imageId,
        imageRevision: imageRevision ?? this.imageRevision,
        strokes: strokes ?? this.strokes,
        pending: pending ?? this.pending,
      );

  factory UserDrawing.fromJson(Map<String, dynamic> json) => UserDrawing(
        imageId: json["imageId"],
        imageRevision: json["imageRevision"] ?? 0,
        strokes: strokesFromJson(json["strokes"]),
        pending: json["pending"] ?? false,
      );

  /// The shape the local cache holds - the server payload plus [pending].
  Map<String, dynamic> toJson() => {
        "imageId": imageId,
        "imageRevision": imageRevision,
        "strokes": strokesToJson(strokes),
        "pending": pending,
      };
}

List<UserDrawing> userDrawingsFromJson(String str) => List<UserDrawing>.from(
    json.decode(str).map((x) => UserDrawing.fromJson(x)));

/// Strokes travel as their own JSON string, which the server stores without ever looking
/// inside it: `{"v":1,"strokes":[[x,y,x,y,...],...]}`.
///
/// One flat list of doubles per stroke rather than pairs of pairs, and four decimals -
/// that is well under half a pixel on any scan, and it keeps a page of scribbles down to
/// a couple of kilobytes.
String? strokesToJson(List<Stroke> strokes) {
  if (strokes.isEmpty) return null;

  final List<List<double>> encoded = strokes
      .map((stroke) => <double>[
            for (final point in stroke.points) ...[
              _round(point.dx),
              _round(point.dy),
            ]
          ])
      .toList();

  return json.encode({"v": 1, "strokes": encoded});
}

List<Stroke> strokesFromJson(String? raw) {
  if (raw == null || raw.isEmpty) return const [];

  try {
    final dynamic decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) return const [];

    final dynamic strokes = decoded["strokes"];
    if (strokes is! List) return const [];

    return strokes.whereType<List>().map((flat) {
      final points = <Offset>[];
      for (int i = 0; i + 1 < flat.length; i += 2) {
        points.add(Offset(
            (flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble()));
      }
      return Stroke(points);
    }).where((stroke) => stroke.points.isNotEmpty).toList();
  } catch (_) {
    // A drawing that cannot be read is not worth taking the page down for.
    return const [];
  }
}

double _round(double value) => (value * 10000).roundToDouble() / 10000;
