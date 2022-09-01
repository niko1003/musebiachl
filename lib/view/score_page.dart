import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ScorePage extends StatefulWidget {
  static const routeName = '/score';
  final int id;

  const ScorePage({Key? key, required this.id}) : super(key: key);

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  PhotoViewScaleStateController scaleStateController =
      PhotoViewScaleStateController();

  @override
  void initState() {
    super.initState();
    scaleStateController = PhotoViewScaleStateController();
  }

  @override
  void dispose() {
    scaleStateController.dispose();
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
              'https://klenig.at/muse/file/image/' + widget.id.toString()),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          gaplessPlayback: false,
          customSize: MediaQuery.of(context).size,
          enableRotation: !locked,
          disableGestures: locked,
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 1.8,
          initialScale: PhotoViewComputedScale.contained,
          basePosition: Alignment.center,
          scaleStateController: scaleStateController,
        )),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
              child: locked ? const Text('Unlock') : const Text("Lock"),
              style: locked
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.green),
                      padding:
                          MaterialStateProperty.all(const EdgeInsets.all(10)),
                      textStyle: MaterialStateProperty.all(
                          const TextStyle(fontSize: 10)))
                  : ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.red),
                      padding:
                          MaterialStateProperty.all(const EdgeInsets.all(10)),
                      textStyle: MaterialStateProperty.all(
                          const TextStyle(fontSize: 10))),
              onPressed: () {
                setState(() {
                  lock();
                });
              }),
        )
      ],
    );
  }
}
