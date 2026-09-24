import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/model/api/user_drawing.dart';
import 'package:musebiachl/service/offline_store.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/theme.dart';

/// One part, all of its pages, swiped left and right - and markable with a pencil.
///
/// A part routinely runs over two or three pages. It used to show exactly one, so
/// turning a page meant going back to the list and finding the next entry - during the
/// piece. The gallery keeps the whole run under the thumb.
///
/// The pencil is the paper gesture people already have: a breath mark, a cut, the repeat
/// that catches them out every time. The marks are private to the player and belong to
/// the *page*, so they sit still when the page is zoomed and follow it into the next
/// rehearsal.
class ScorePage extends StatefulWidget {
  static const routeName = '/score';

  /// The way in for the screenshot harness, which has a picture but no server and no
  /// cache manager behind it. Null in every build that ships, and the only reason
  /// [_ScorePageState.imageOf] is typed as a plain ImageProvider.
  @visibleForTesting
  static ImageProvider Function(int imageId, int revision)? debugImageFor;

  final List<int> imageIds;
  final List<int> imageRevisions;
  final int index;
  final String title;

  const ScorePage({
    Key? key,
    required this.imageIds,
    required this.imageRevisions,
    this.index = 0,
    this.title = '',
  }) : super(key: key);

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> with WidgetsBindingObserver {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final RemoteServices _remote = RemoteServices();

  late final PageController pageController;
  late int current;

  bool locked = false;
  bool drawing = false;

  /// Whether the buttons are on the page. A tap on the page takes them and the status bar
  /// away, so the music gets the whole screen; the next tap brings them back.
  bool chrome = true;

  _Tool tool = _Tool.pen;

  bool get erasing => tool == _Tool.eraser;

  /// The page's own pixel size, needed before anything can be drawn on it in page
  /// coordinates. Filled in as the gallery builds each page - PhotoViewGallery only
  /// builds what is near the current page, so this stays as lazy as the viewer is.
  final Map<int, Size> _imageSizes = {};
  final Set<int> _sizeRequested = {};

  /// The marks, per image id. Mutated in place while drawing.
  final Map<int, List<Stroke>> _strokes = {};

  /// The words, per image id.
  final Map<int, List<Annotation>> _texts = {};

  /// The word currently under the finger, while it is being dragged somewhere better.
  int? _draggingText;

  /// Pages whose marks have not reached the server yet.
  final Set<int> _unpushed = {};

  /// Pages whose stored marks were drawn against an older revision of the image.
  final Set<int> _stale = {};

  /// The current image revision per image id, for deciding staleness on load and for
  /// stamping what gets saved.
  final Map<int, int> _revisions = {};

  Stroke? _active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    current = widget.index;
    pageController = PageController(initialPage: widget.index);

    for (int i = 0; i < widget.imageIds.length; i++) {
      _revisions[widget.imageIds[i]] =
          i < widget.imageRevisions.length ? widget.imageRevisions[i] : 0;
    }

    persistFile(widget.imageIds[current]);
    _loadDrawings();
  }

  @override
  void dispose() {
    // Fire and forget: the marks are already on the device (every stroke writes the
    // local cache), this is only the copy going up to the server.
    _pushAll();
    pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _showSystemBars();
    locked = false;
    super.dispose();
  }

  /// iOS resets the idle timer whenever the app leaves the foreground - a glance at a
  /// message, Control Center, the lock button - so enabling it once in initState keeps
  /// the screen on only until the first interruption. Back on the music stand it has to
  /// be switched on again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) WakelockPlus.enable();
  }

  /// The green-avatar bookkeeping: which pages this player has actually opened. Every
  /// page swiped to counts, not only the one tapped in the list.
  Future<void> persistFile(int imageId) async {
    final SharedPreferences prefs = await _prefs;
    final List<String> list =
        prefs.getStringList('cached-files') ?? List.empty(growable: true);
    final String f = imageId.toString();
    if (!list.contains(f)) {
      list.add(f);
      await prefs.setStringList('cached-files', list);
    }
  }

  // --- the marks ------------------------------------------------------------------

  int _revisionOf(int imageId) => _revisions[imageId] ?? 0;

  List<Stroke> _strokesFor(int imageId) =>
      _strokes.putIfAbsent(imageId, () => <Stroke>[]);

  List<Annotation> _textsFor(int imageId) =>
      _texts.putIfAbsent(imageId, () => <Annotation>[]);

  /// Device first, then the server - the same order as every list in this app, and for
  /// the same reason: what is on the phone is the only copy that exists in a rehearsal
  /// room with no signal.
  ///
  /// Anything drawn offline goes **up** before anything comes down, so the server's older
  /// copy can never overwrite marks it has not seen yet.
  Future<void> _loadDrawings() async {
    for (final imageId in widget.imageIds) {
      final UserDrawing? local = await _remote.cachedDrawing(imageId);
      if (local != null) _apply(imageId, local);
    }
    if (!mounted) return;
    setState(() {});

    final List<int> pending =
        widget.imageIds.where(_unpushed.contains).toList();
    for (final imageId in pending) {
      await _push(imageId);
    }

    final List<int> pull =
        widget.imageIds.where((id) => !_unpushed.contains(id)).toList();
    if (pull.isEmpty) return;

    try {
      final List<UserDrawing> fetched = await _remote.fetchDrawings(pull);
      final Map<int, UserDrawing> byImage = {
        for (final drawing in fetched) drawing.imageId: drawing
      };

      for (final imageId in pull) {
        final UserDrawing? server = byImage[imageId];
        if (server == null) {
          // The server has none, so neither should this device - it was rubbed clean
          // somewhere else.
          _strokes.remove(imageId);
          _texts.remove(imageId);
          _stale.remove(imageId);
          await _remote.writeDrawingCache(
              UserDrawing(imageId: imageId, imageRevision: 0, strokes: const []));
          continue;
        }
        _apply(imageId, server);
        await _remote.writeDrawingCache(server);
      }

      if (mounted) setState(() {});
    } on SessionExpiredException {
      if (mounted) await endSession(reason: sessionRejectedMessage);
    } catch (_) {
      // offline, and what is on the device stands
    }
  }

  /// Marks drawn against a revision the page no longer has are **not** rendered.
  ///
  /// Rotate, crop and tile all rewrite a page while keeping its id, and marks laid over a
  /// page that has since been turned or re-cut are worse than no marks at all - on a
  /// stand they are read as the music. They are not deleted either: drawing on the page
  /// again replaces them, and until then they are simply left alone.
  void _apply(int imageId, UserDrawing drawing) {
    if (!drawing.isEmpty && drawing.imageRevision != _revisionOf(imageId)) {
      _stale.add(imageId);
      return;
    }

    _stale.remove(imageId);
    _strokes[imageId] = List<Stroke>.from(drawing.strokes);
    _texts[imageId] = List<Annotation>.from(drawing.texts);
    if (drawing.pending) _unpushed.add(imageId);
  }

  /// Every stroke and every erase writes the device copy immediately, so nothing is lost
  /// if the app is closed mid-rehearsal. The server copy waits for a natural pause.
  Future<void> _markChanged(int imageId) async {
    _unpushed.add(imageId);
    _stale.remove(imageId);

    await _remote.writeDrawingCache(UserDrawing(
      imageId: imageId,
      imageRevision: _revisionOf(imageId),
      strokes: _strokesFor(imageId),
      texts: _textsFor(imageId),
      pending: true,
    ));
  }

  Future<void> _push(int imageId) async {
    try {
      final UserDrawing saved = await _remote.putDrawing(UserDrawing(
        imageId: imageId,
        imageRevision: _revisionOf(imageId),
        strokes: _strokesFor(imageId),
        texts: _textsFor(imageId),
      ));
      _unpushed.remove(imageId);
      await _remote.writeDrawingCache(saved);
    } on SessionExpiredException {
      if (mounted) await endSession(reason: sessionRejectedMessage);
    } catch (_) {
      // offline: it stays pending and goes up the next time this part is opened
    }
  }

  Future<void> _pushAll() async {
    for (final imageId in _unpushed.toList()) {
      await _push(imageId);
    }
  }

  // --- drawing input --------------------------------------------------------------

  Offset _normalise(Offset local, Size size) =>
      Offset(local.dx / size.width, local.dy / size.height);

  Offset _toPixels(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  void _panStart(int imageId, Offset local, Size size) {
    if (erasing) {
      _erase(imageId, local, size);
      return;
    }

    // In text mode a drag is not a line but a move: writing a word in exactly the right
    // place on the first try is not something anybody manages on a phone.
    if (tool == _Tool.text) {
      _draggingText = _textAt(imageId, local, size);
      return;
    }

    final Stroke stroke = Stroke(<Offset>[_normalise(local, size)]);
    _active = stroke;
    setState(() => _strokesFor(imageId).add(stroke));
  }

  void _panUpdate(int imageId, Offset local, Size size) {
    if (erasing) {
      _erase(imageId, local, size);
      return;
    }

    if (tool == _Tool.text) {
      final int? index = _draggingText;
      if (index == null) return;

      final List<Annotation> texts = _textsFor(imageId);
      final Annotation moved = texts[index];
      // The finger holds the middle of the word; the stored corner is where it starts.
      final Rect box = _boxOf(moved, size);
      setState(() => texts[index] = moved.copyWith(
            at: _normalise(
                local - Offset(box.width / 2, box.height / 2), size),
          ));
      return;
    }

    final Stroke? stroke = _active;
    if (stroke == null) return;

    // Thin the points as they come in - a finger produces far more than a line needs,
    // and every one of them ends up in the column and in the request.
    final Offset lastPixels = _toPixels(stroke.points.last, size);
    if ((local - lastPixels).distance < size.shortestSide * 0.004) return;

    setState(() => stroke.points.add(_normalise(local, size)));
  }

  void _panEnd(int imageId) {
    if (_draggingText != null) {
      _draggingText = null;
      _markChanged(imageId);
      return;
    }

    // Erasing saves from _erase itself, and only when something actually came off -
    // otherwise a stray tap with the eraser would queue a save of an unchanged page.
    if (_active == null) return;
    _active = null;
    _markChanged(imageId);
  }

  /// Which word is under this point, if any. Last one first: words written later are
  /// drawn on top, so they are what a finger on the overlap means.
  int? _textAt(int imageId, Offset local, Size size) {
    final List<Annotation> texts = _textsFor(imageId);

    for (int i = texts.length - 1; i >= 0; i--) {
      // A little larger than the ink: what is being hit is a word on a music stand.
      if (_boxOf(texts[i], size).inflate(size.shortestSide * 0.01).contains(local)) {
        return i;
      }
    }
    return null;
  }

  /// A tap in text mode: the word that was hit, or a new one where the finger landed.
  Future<void> _tapText(int imageId, Offset local, Size size) async {
    final List<Annotation> texts = _textsFor(imageId);
    final int? hit = _textAt(imageId, local, size);

    final _TextEdit? result = await showDialog<_TextEdit>(
      context: context,
      builder: (context) => _TextDialog(existing: hit == null ? null : texts[hit]),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (hit != null && result.delete) {
        texts.removeAt(hit);
      } else if (hit != null) {
        texts[hit] = texts[hit].copyWith(text: result.text, size: result.size);
      } else if (result.text.isNotEmpty) {
        // Centred on the tap rather than starting there: a finger pointing at a bar means
        // the middle of the word, not its first letter.
        final Annotation written =
            Annotation(at: Offset.zero, text: result.text, size: result.size);
        final Rect box = _boxOf(written, size);
        texts.add(written.copyWith(
          at: _normalise(local - Offset(box.width / 2, box.height / 2), size),
        ));
      }
    });

    await _markChanged(imageId);
  }

  /// The eraser takes whole strokes, not pixels.
  ///
  /// Rubbing a hole in the middle of a line is what a real eraser does and what nobody
  /// wants: the mark that is in the way is one mark, and lifting it whole is both what a
  /// player means by "no, not that one" and what keeps the stored drawing small.
  void _erase(int imageId, Offset local, Size size) {
    final List<Stroke> strokes = _strokesFor(imageId);
    final List<Annotation> texts = _textsFor(imageId);
    if (strokes.isEmpty && texts.isEmpty) return;

    final double radius = size.shortestSide * 0.03;
    final int before = strokes.length + texts.length;

    strokes.removeWhere((stroke) => stroke.points
        .any((point) => (_toPixels(point, size) - local).distance <= radius));

    // A word comes off whole too, and by its own box rather than by that radius: a long
    // one would otherwise survive being rubbed across its middle.
    texts.removeWhere((text) => _boxOf(text, size).contains(local));

    if (strokes.length + texts.length != before) {
      setState(() {});
      _markChanged(imageId);
    }
  }

  // --- the page itself ------------------------------------------------------------

  /// The revision is in the URL *and* in the cache key on purpose: rotate, crop, tile
  /// and the black-and-white pass rewrite a page while keeping its id, so caching on the
  /// id alone pins the old picture on the device for ever.
  ImageProvider imageOf(int index) {
    final int id = widget.imageIds[index];
    final int revision =
        index < widget.imageRevisions.length ? widget.imageRevisions[index] : 0;

    final ImageProvider Function(int, int)? override = ScorePage.debugImageFor;
    if (override != null) return override(id, revision);

    return CachedNetworkImageProvider(
      OfflineStore.imageUrl(id, revision),
      cacheKey: OfflineStore.imageKey(id, revision),
      // Not the package's default manager: a page somebody took along has to be the page
      // this screen finds, and the default one drops the oldest 200 files and expires
      // everything after 30 days. See MusePages.
      cacheManager: MusePages(),
    );
  }

  /// The page's pixel size, which PhotoView needs as childSize and the pencil needs as
  /// its coordinate system. Requested from the builder rather than up front so that
  /// opening a four-page part does not decode four scans at once.
  void _ensureSize(int index, int imageId) {
    if (_imageSizes.containsKey(imageId) || !_sizeRequested.add(imageId)) return;

    final ImageStream stream =
        imageOf(index).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    bool settled = false;

    // ImageStream.addListener calls back **synchronously** when the picture is already
    // decoded, which for a page that has been open before it always is - and this runs
    // from build(). setState from there throws, so the update goes through a microtask,
    // which is drained once the frame is finished.
    void finish(Size? size) {
      if (settled) return;
      settled = true;
      stream.removeListener(listener);

      if (size == null) {
        _sizeRequested.remove(imageId);
        return;
      }

      Future.microtask(() {
        if (!mounted) return;
        setState(() => _imageSizes[imageId] = size);
      });
    }

    listener = ImageStreamListener(
      (ImageInfo info, bool _) => finish(
          Size(info.image.width.toDouble(), info.image.height.toDouble())),
      onError: (Object error, StackTrace? stack) => finish(null),
    );

    stream.addListener(listener);
  }

  Widget _page(int index, int imageId, Size size) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: imageOf(index),
            fit: BoxFit.fill,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
          CustomPaint(
            painter: _MarkPainter(
              _strokes[imageId] ?? const [],
              _texts[imageId] ?? const [],
            ),
          ),
          if (drawing)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: tool == _Tool.text
                  ? (details) => _tapText(imageId, details.localPosition, size)
                  : null,
              onPanStart: (details) =>
                  _panStart(imageId, details.localPosition, size),
              onPanUpdate: (details) =>
                  _panUpdate(imageId, details.localPosition, size),
              onPanEnd: (_) => _panEnd(imageId),
            ),
        ],
      ),
    );
  }

  void _toggleChrome() {
    setState(() => chrome = !chrome);
    if (chrome) {
      _showSystemBars();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// Flutter's own default, which is what every other screen of the app runs in.
  void _showSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  }

  void lock() {
    setState(() => locked = !locked);
  }

  void _toggleDrawing() {
    setState(() {
      drawing = !drawing;
      if (drawing) {
        locked = false;
        tool = _Tool.pen;
      }
    });

    // Leaving the pencil behind is the natural moment to send the page up.
    if (!drawing) _pushAll();
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.imageIds.length;
    final int currentImageId = widget.imageIds[current];

    return Stack(
      children: <Widget>[
        Positioned.fill(
          // Locked, PhotoView switches its gestures off - its tap included - so the tap
          // that toggles the buttons is caught out here instead. Unlocked it is left to
          // PhotoView, whose detector tells a tap from the double tap that zooms.
          child: GestureDetector(
            onTap: locked && !drawing ? _toggleChrome : null,
            child: PhotoViewGallery.builder(
              itemCount: count,
              pageController: pageController,
              // Locking freezes the page turn as well as the zoom - on a music stand the
              // point is that nothing moves when the page is brushed. The pencil freezes
              // it too, or every line drawn would also drag the page.
              scrollPhysics: locked || drawing
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => current = index);
                persistFile(widget.imageIds[index]);
                _pushAll();
              },
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              builder: (context, index) {
                final int imageId = widget.imageIds[index];
                _ensureSize(index, imageId);
                final Size? size = _imageSizes[imageId];

                if (size == null) {
                  return PhotoViewGalleryPageOptions.customChild(
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    disableGestures: true,
                  );
                }

                // customChild rather than imageProvider: it puts the marks *inside* the
                // transform, so they zoom and pan with the page and a finger on the page
                // arrives in page coordinates. Doing it over the top instead would mean
                // re-deriving the transform on every frame and getting it wrong.
                return PhotoViewGalleryPageOptions.customChild(
                  child: _page(index, imageId, size),
                  childSize: size,
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 1.8,
                  basePosition: Alignment.center,
                  disableGestures: locked || drawing,
                  onTapUp: drawing ? null : (_, _, _) => _toggleChrome(),
                );
              },
            ),
          ),
        ),
        if (chrome)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(Colors.white.withValues(alpha: 0.8)),
                    foregroundColor: WidgetStateProperty.all(Colors.black),
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 18),
                      SizedBox(width: 4),
                      Text('Zurück', style: TextStyle(fontFamily: bodyFont)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (chrome)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The lock is about holding the page still; the pencil already does
                    // that, so showing both would be two buttons for one state.
                    if (!drawing)
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(
                              locked ? Colors.green : Colors.red),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.all(10)),
                        ),
                        onPressed: lock,
                        child: Icon(locked ? Icons.lock : Icons.lock_open,
                            size: 18),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                            drawing ? Colors.amber.shade700 : Colors.white.withValues(alpha: 0.8)),
                        foregroundColor: WidgetStateProperty.all(
                            drawing ? Colors.white : Colors.black),
                        padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
                      ),
                      onPressed: _toggleDrawing,
                      child: const Icon(Icons.edit, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_stale.contains(currentImageId))
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 56.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Seite wurde geändert — alte Zeichnung ausgeblendet',
                    style: TextStyle(
                        fontFamily: bodyFont, color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),

        if (drawing && tool == _Tool.text)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 62.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Tippen schreibt · auf ein Wort tippen ändert es · ziehen verschiebt',
                    style: TextStyle(
                        fontFamily: bodyFont, color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),

        if (drawing)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _toolButton(
                        icon: Icons.edit,
                        label: 'Stift',
                        active: tool == _Tool.pen,
                        onPressed: () => setState(() => tool = _Tool.pen),
                      ),
                      _toolButton(
                        icon: Icons.title,
                        label: 'Text',
                        active: tool == _Tool.text,
                        onPressed: () => setState(() => tool = _Tool.text),
                      ),
                      _toolButton(
                        icon: Icons.auto_fix_normal,
                        label: 'Radierer',
                        active: tool == _Tool.eraser,
                        onPressed: () => setState(() => tool = _Tool.eraser),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _toggleDrawing,
                        child: const Text('Fertig',
                            style: TextStyle(
                                fontFamily: bodyFont, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Only worth the space when there is something to turn to, only when the pencil
        // is not using that corner, and not in full screen.
        if (count > 1 && !drawing && chrome)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < count; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            width: i == current ? 9 : 7,
                            height: i == current ? 9 : 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == current
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'Seite ${current + 1} / $count',
                        style: const TextStyle(
                            fontFamily: bodyFont, color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon,
          size: 18, color: active ? Colors.amber.shade400 : Colors.white),
      label: Text(label,
          style: TextStyle(
              fontFamily: bodyFont,
              color: active ? Colors.amber.shade400 : Colors.white,
              fontSize: 12)),
    );
  }
}

/// Which of the three the finger is doing.
enum _Tool { pen, text, eraser }

/// The ink a player writes in. Red, because it has to be found at a glance on a
/// black-and-white scan, and because printed music never uses it.
const Color _markColour = Color(0xFFE53935);

TextStyle _writtenStyle(double fontSize) => TextStyle(
      // The app's own body face rather than the platform default - the only thing
      // ScorePage takes from the theme, and only because a word written on a page should
      // look like the rest of the Biachl.
      fontFamily: bodyFont,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.1,
      color: _markColour,
    );

TextPainter _layoutText(Annotation text, Size size) => TextPainter(
      text: TextSpan(
          text: text.text, style: _writtenStyle(size.shortestSide * text.size)),
      textDirection: TextDirection.ltr,
    )..layout();

/// Where a word sits on the page, in page pixels.
///
/// Laid out rather than estimated, and in one place: the painter draws by it and the
/// finger hits by it, and two different guesses would mean words that cannot be grabbed
/// where they are seen.
Rect _boxOf(Annotation text, Size size) {
  final TextPainter painter = _layoutText(text, size);
  return Rect.fromLTWH(text.at.dx * size.width, text.at.dy * size.height,
      painter.width, painter.height);
}

/// Draws what the player put on the page, in page coordinates.
///
/// Sizes come off the page rather than the screen - the painter lives inside PhotoView's
/// transform, so a line drawn at one zoom has to be the same line at another.
class _MarkPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Annotation> texts;

  const _MarkPainter(this.strokes, this.texts);

  @override
  void paint(Canvas canvas, Size size) {
    _paintStrokes(canvas, size);
    _paintTexts(canvas, size);
  }

  void _paintStrokes(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    final double width = size.shortestSide * 0.006;
    final Paint line = Paint()
      ..color = _markColour
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final Paint dot = Paint()
      ..color = line.color
      ..style = PaintingStyle.fill;

    for (final Stroke stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      if (stroke.points.length == 1) {
        canvas.drawCircle(_at(stroke.points.first, size), width / 2, dot);
        continue;
      }

      final Path path = Path()..moveTo(_at(stroke.points.first, size).dx, _at(stroke.points.first, size).dy);
      for (int i = 1; i < stroke.points.length; i++) {
        final Offset point = _at(stroke.points[i], size);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
    }
  }

  /// Each word on a white patch. Not decoration: red letters laid straight over a stave
  /// are read as part of the music, and the one thing a written note must never be is
  /// hard to tell from the print underneath.
  void _paintTexts(Canvas canvas, Size size) {
    if (texts.isEmpty) return;

    final Paint patch = Paint()..color = const Color(0xF2FFFFFF);

    for (final Annotation text in texts) {
      final TextPainter painter = _layoutText(text, size);
      final Rect box = Rect.fromLTWH(text.at.dx * size.width,
          text.at.dy * size.height, painter.width, painter.height);
      final double pad = painter.height * 0.12;

      canvas.drawRRect(
        RRect.fromRectAndRadius(box.inflate(pad), Radius.circular(pad * 1.6)),
        patch,
      );
      painter.paint(canvas, box.topLeft);
    }
  }

  Offset _at(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  /// The lists are mutated in place while drawing, so identity says nothing about
  /// whether they changed. Repaints only happen on setState anyway.
  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => true;
}

/// What came back from the little dialog: a word and how big, or the decision to take it
/// off the page again.
class _TextEdit {
  const _TextEdit({required this.text, required this.size, this.delete = false});

  final String text;
  final double size;
  final bool delete;
}

/// Writing a word, and changing one.
///
/// A dialog rather than typing onto the page itself: a phone keyboard covers half the
/// screen, so the spot being written at would be hidden by the act of writing at it. The
/// tap decides where; this decides what.
class _TextDialog extends StatefulWidget {
  const _TextDialog({this.existing});

  final Annotation? existing;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.existing?.text ?? '');
  late double _size = widget.existing?.size ?? Annotation.defaultSize;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// An emptied word is a deleted word - that is what rubbing out the letters means, and
  /// it saves hunting for a button.
  void _done() {
    final String text = _controller.text.trim();

    if (text.isEmpty) {
      Navigator.pop(
          context,
          widget.existing == null
              ? null
              : const _TextEdit(text: '', size: 0, delete: true));
      return;
    }
    Navigator.pop(context, _TextEdit(text: text, size: _size));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double preview =
        16 + (_size - Annotation.minSize) / (Annotation.maxSize - Annotation.minSize) * 26;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Text schreiben' : 'Text ändern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _done(),
            decoration: const InputDecoration(
              hintText: 'z. B. 2x, Achtung, leise, Fine',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.format_size, size: 16, color: scheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: _size,
                  min: Annotation.minSize,
                  max: Annotation.maxSize,
                  onChanged: (value) => setState(() => _size = value),
                ),
              ),
              Icon(Icons.format_size, size: 24, color: scheme.onSurfaceVariant),
            ],
          ),
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              _controller.text.trim().isEmpty ? 'Vorschau' : _controller.text.trim(),
              style: _writtenStyle(preview),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.pop(
                context, const _TextEdit(text: '', size: 0, delete: true)),
            child: Text('Löschen', style: TextStyle(color: scheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        TextButton(onPressed: _done, child: const Text('Fertig')),
      ],
    );
  }
}
