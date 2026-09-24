import 'package:flutter/material.dart';

import 'package:musebiachl/model/arg/collection_arguments.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/model/arg/selection_arguments.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/collection_page.dart';
import 'package:musebiachl/view/collection_selection_page.dart';
import 'package:musebiachl/view/score_page.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/view/auth/login_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Muse Biachl',
      // endSession() needs a navigator it can reach from the service layer: a token is
      // rejected inside whatever request is in flight, not on a page that has a context
      // to hand.
      navigatorKey: appNavigatorKey,
      onGenerateRoute: (settings) {
        // Pages that take arguments are registered here; everything else pushes a
        // MaterialPageRoute directly. Adding one means a routeName on the page, an args
        // class in lib/model/arg/, and a branch here.
        if (settings.name == CollectionSelectionPage.routeName) {
          final args = settings.arguments as SelectionArguments;
          return MaterialPageRoute(
            builder: (context) {
              return CollectionSelectionPage(
                id: args.id,
                name: args.name,
              );
            },
          );
        } else if (settings.name == CollectionPage.routeName) {
          final args = settings.arguments as CollectionArguments;
          return MaterialPageRoute(
            builder: (context) {
              return CollectionPage(
                id: args.id,
                name: args.name,
                selection: args.selection,
              );
            },
          );
        } else if (settings.name == ScorePage.routeName) {
          final args = settings.arguments as ScoreArguments;
          return MaterialPageRoute(
            builder: (context) {
              return ScorePage(
                imageIds: args.imageIds,
                imageRevisions: args.imageRevisions,
                index: args.index,
                title: args.title,
              );
            },
          );
        }

        assert(false, 'Need to implement ${settings.name}');
        return null;
      },
      theme: museTheme(Brightness.light),
      darkTheme: museTheme(Brightness.dark),
      // A phone on a music stand in a darkened hall is the normal case, so the app follows
      // whatever the device is set to.
      themeMode: ThemeMode.system,
      home: const LoginPage(),
    );
  }
}
