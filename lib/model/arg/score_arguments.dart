/// What the score viewer needs: every page of one part, and which to open on.
///
/// A part routinely runs over two or three pages, and turning one on stage is the worst
/// possible moment to be tapping back to a list - so the viewer gets the whole run and
/// swipes through it.
class ScoreArguments {
  final List<int> imageIds;
  final List<int> imageRevisions;
  final int index;
  final String title;

  ScoreArguments(this.imageIds, this.imageRevisions,
      {this.index = 0, this.title = ''});
}
