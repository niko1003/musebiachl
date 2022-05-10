import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ScorePage extends StatelessWidget {

  static const routeName = '/score';

  final int id;

  const ScorePage({
    Key? key,
    required this.id,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // old path http://localhost:8080/muse/
    https://klenig.at/muse
    return Container(
        child: PhotoView(
          imageProvider: NetworkImage('https://klenig.at/muse/file/image/' + id.toString()),
        )
    );
  }
}