import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musebiachl/service/remote_service.dart';

/// One part, all of its pages, swiped left and right.
///
/// A part routinely runs over two or three pages. It used to show exactly one, so
/// turning a page meant going back to the list and finding the next entry - during the
/// piece. The gallery keeps the whole run under the thumb.
class ScorePage extends StatefulWidget {
  static const routeName = '/score';

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

class _ScorePageState extends State<ScorePage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  late final PageController pageController;
  late int current;

  bool locked = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    current = widget.index;
    pageController = PageController(initialPage: widget.index);
    persistFile(widget.imageIds[current]);
  }

  @override
  void dispose() {
    pageController.dispose();
    WakelockPlus.disable();
    locked = false;
    super.dispose();
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

  /// The revision is in the URL *and* in the cache key on purpose: rotate, crop, tile
  /// and the black-and-white pass rewrite a page while keeping its id, so caching on the
  /// id alone pins the old picture on the device for ever.
  CachedNetworkImageProvider imageOf(int index) {
    final int id = widget.imageIds[index];
    final int revision =
        index < widget.imageRevisions.length ? widget.imageRevisions[index] : 0;

    return CachedNetworkImageProvider(
      '${RemoteServices.baseUrl}/file/image/$id?v=$revision',
      cacheKey: '$id-$revision',
    );
  }

  void lock() {
    setState(() => locked = !locked);
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.imageIds.length;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: PhotoViewGallery.builder(
            itemCount: count,
            pageController: pageController,
            // Locking freezes the page turn as well as the zoom - on a music stand the
            // point is that nothing moves when the page is brushed.
            scrollPhysics: locked
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => current = index);
              persistFile(widget.imageIds[index]);
            },
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: imageOf(index),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 1.8,
              basePosition: Alignment.center,
              disableGestures: locked,
            ),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
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
                    Text('back'),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                      locked ? Colors.green : Colors.red),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
                ),
                onPressed: lock,
                child: Icon(locked ? Icons.lock : Icons.lock_open, size: 18),
              ),
            ),
          ),
        ),

        // Only worth the space when there is something to turn to.
        if (count > 1)
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
                            color: Colors.white, fontSize: 12),
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
}
