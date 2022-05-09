import 'package:flutter/material.dart';


import 'package:musebiachl/model/api/folder.dart';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/api/folder_composition.dart';
import 'package:musebiachl/model/arg/folder_arguments.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/view/folders_page.dart';
import 'package:musebiachl/view/folder_page.dart';
import 'package:musebiachl/view/score_page.dart';

void main() =>  runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muse Biachl',

      onGenerateRoute: (settings) {
        // If you push the PassArguments route
        if (settings.name == FolderPage.routeName) {

          // Cast the arguments to the correct type: ScreenArguments.
          final args = settings.arguments as FolderArguments;

          // Then, extract the required data from
          // the arguments and pass the data to the
          // correct screen.
          return MaterialPageRoute(
            builder: (context) {
              return FolderPage(
                id: args.id,
                name: args.name,
              );
            },
          );
        } else if (settings.name == ScorePage.routeName) {

          final args = settings.arguments as ScoreArguments;
          return MaterialPageRoute(
            builder: (context) {
              return ScorePage(
                  id: args.id
              );
            },
          );
        }

        assert(false, 'Need to implement ${settings.name}');
        return null;
      },

      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FoldersPage(),
    );
  }
}
