import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScorePage extends StatefulWidget {
  static const routeName = '/score';
  final int id;

  const ScorePage({Key? key, required this.id}) : super(key: key);

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  bool fileFetched = true;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  PhotoViewScaleStateController scaleStateController =
      PhotoViewScaleStateController();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    scaleStateController = PhotoViewScaleStateController();
    persistFile();
  }

  persistFile() async {
    final SharedPreferences prefs = await _prefs;
    final List<String> list = await _prefs.then((SharedPreferences prefs) {
      return prefs.getStringList('cached-files') ?? List.empty(growable: true);
    });
    String f = widget.id.toString();
    if (!list.contains(f) && fileFetched) {
      list.add(f);
    }
    await prefs.setStringList("cached-files", list);
  }

  @override
  void dispose() {
    scaleStateController.dispose();
    WakelockPlus.disable();
    locked = false;
    super.dispose();
  }

  bool locked = false;

  void lock() {
    locked = !locked;
    //scaleStateController.scaleState = PhotoViewScaleState.originalSize;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
            child: PhotoView(
                imageProvider: CachedNetworkImageProvider(
                    'https://klenig.at/muse/file/image/${widget.id}',
                    cacheKey: widget.id.toString(),
                    errorListener: (obj) => fileFetched = false
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                gaplessPlayback: false,
                customSize: MediaQuery.of(context).size,
                enableRotation: !locked,
                disableGestures: locked,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 1.8,
                initialScale: PhotoViewComputedScale.contained,
                basePosition: Alignment.center,
                scaleStateController: scaleStateController)),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.8)),
                  foregroundColor: WidgetStateProperty.all(Colors.black),
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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
                  style: locked
                      ? ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.green),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.all(10)),
                          textStyle: WidgetStateProperty.all(
                              const TextStyle(fontSize: 10)))
                      : ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.red),
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.all(10)),
                          textStyle: WidgetStateProperty.all(
                              const TextStyle(fontSize: 10))),
                  onPressed: () {
                    setState(() {
                      lock();
                    });
                  },
                  child: locked ? const Text('Unlock') : const Text("Lock")),
            ),
          ),
        )
      ],
    );
  }
}
