import 'package:flutter_test/flutter_test.dart';
import 'package:musebiachl/model/api/user_drawing.dart';

void main() {
  test('a drawn stroke survives the round trip to the server and back', () {
    final drawn = [
      Stroke(const [Offset(0.1, 0.2), Offset(0.30001, 0.4), Offset(0.5, 0.6)]),
      Stroke(const [Offset(0.71234, 0.81111)]),
    ];

    final wire = strokesToJson(drawn);
    expect(wire, isNotNull);
    expect(wire, contains('"v":1'));

    final back = strokesFromJson(wire);
    expect(back.length, 2);
    expect(back[0].points.length, 3);
    expect(back[1].points.length, 1);
    // Four decimals: under half a pixel on any scan.
    expect(back[0].points[1].dx, closeTo(0.3, 0.0001));
    expect(back[1].points[0].dy, closeTo(0.8111, 0.0001));
  });

  test('an empty drawing encodes as null, which is what deletes the row', () {
    expect(strokesToJson(const []), isNull);
  });

  test('a rubbed-clean page comes back from the server as null strokes', () {
    expect(strokesFromJson(null), isEmpty);
    expect(strokesFromJson(''), isEmpty);
  });

  test('unreadable strokes do not take the page down', () {
    expect(strokesFromJson('not json at all'), isEmpty);
    expect(strokesFromJson('[1,2,3]'), isEmpty);
    expect(strokesFromJson('{"v":1}'), isEmpty);
    expect(strokesFromJson('{"v":1,"strokes":"nope"}'), isEmpty);
  });

  test('an odd trailing coordinate is dropped rather than throwing', () {
    final back = strokesFromJson('{"v":1,"strokes":[[0.1,0.2,0.3]]}');
    expect(back.length, 1);
    expect(back[0].points.length, 1);
  });

  test('the cache round-trips a pending drawing', () {
    const drawing = UserDrawing(
        imageId: 7, imageRevision: 99, strokes: [], pending: true);
    final restored = UserDrawing.fromJson(drawing.toJson());
    expect(restored.imageId, 7);
    expect(restored.imageRevision, 99);
    expect(restored.pending, isTrue);
  });
}
