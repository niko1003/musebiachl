import 'package:flutter_test/flutter_test.dart';
import 'package:musebiachl/model/api/user_drawing.dart';

void main() {
  test('a drawn stroke survives the round trip to the server and back', () {
    final drawn = [
      Stroke(const [Offset(0.1, 0.2), Offset(0.30001, 0.4), Offset(0.5, 0.6)]),
      Stroke(const [Offset(0.71234, 0.81111)]),
    ];

    final wire = marksToJson(drawn, const []);
    expect(wire, isNotNull);
    expect(wire, contains('"v":2'));

    final back = strokesFromJson(wire);
    expect(back.length, 2);
    expect(back[0].points.length, 3);
    expect(back[1].points.length, 1);
    // Four decimals: under half a pixel on any scan.
    expect(back[0].points[1].dx, closeTo(0.3, 0.0001));
    expect(back[1].points[0].dy, closeTo(0.8111, 0.0001));
  });

  test('an empty drawing encodes as null, which is what deletes the row', () {
    expect(marksToJson(const [], const []), isNull);
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

  test('a written word survives the round trip too', () {
    final wire = marksToJson(const [], const [
      Annotation(at: Offset(0.25, 0.4), text: '2x'),
      Annotation(at: Offset(0.6, 0.12), text: 'Achtung!', size: 0.05),
    ]);

    final back = textsFromJson(wire);
    expect(back.length, 2);
    expect(back[0].text, '2x');
    expect(back[0].at.dx, closeTo(0.25, 0.0001));
    expect(back[0].size, Annotation.defaultSize);
    expect(back[1].size, closeTo(0.05, 0.0001));
  });

  test('lines and words share one payload, and one without the other still reads', () {
    final wire = marksToJson(
      [Stroke(const [Offset(0.1, 0.1), Offset(0.2, 0.2)])],
      const [Annotation(at: Offset(0.5, 0.5), text: 'leise')],
    );

    expect(strokesFromJson(wire).length, 1);
    expect(textsFromJson(wire).length, 1);

    // A page written by an older app has no "texts" at all, and must still draw.
    expect(textsFromJson('{"v":1,"strokes":[[0.1,0.2,0.3,0.4]]}'), isEmpty);
    expect(strokesFromJson('{"v":1,"strokes":[[0.1,0.2,0.3,0.4]]}').length, 1);
  });

  test('a word with nothing in it, or nowhere to be, is dropped rather than drawn', () {
    expect(textsFromJson('{"v":2,"texts":"nope"}'), isEmpty);
    expect(textsFromJson('{"v":2,"texts":[{"t":"","x":0.1,"y":0.1}]}'), isEmpty);
    expect(textsFromJson('{"v":2,"texts":[{"t":"da","y":0.1}]}'), isEmpty);
    expect(textsFromJson('{"v":2,"texts":[{"t":"da","x":0.1,"y":0.1}]}').length, 1);
  });

  test('the cache round-trips a pending drawing', () {
    const drawing = UserDrawing(
      imageId: 7,
      imageRevision: 99,
      strokes: [],
      texts: [Annotation(at: Offset(0.3, 0.3), text: 'Fine')],
      pending: true,
    );
    final restored = UserDrawing.fromJson(drawing.toJson());
    expect(restored.imageId, 7);
    expect(restored.imageRevision, 99);
    expect(restored.pending, isTrue);
    expect(restored.texts.single.text, 'Fine');
    expect(restored.isEmpty, isFalse);
  });
}
