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
    return Container(
        child: PhotoView(
          imageProvider: NetworkImage('http://localhost:8080/muse/file/image/' + id.toString()),
        )
    );
  }
}