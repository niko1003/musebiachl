import 'package:flutter/material.dart';

import 'package:musebiachl/model/arg/collection_arguments.dart';
import 'package:musebiachl/model/arg/score_arguments.dart';
import 'package:musebiachl/view/collection_page.dart';
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
        // If you push the PassArguments route
        if (settings.name == CollectionPage.routeName) {
          // Cast the arguments to the correct type: ScreenArguments.
          final args = settings.arguments as CollectionArguments;

          // Then, extract the required data from
          // the arguments and pass the data to the
          // correct screen.
          return MaterialPageRoute(
            builder: (context) {
              return CollectionPage(
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
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}
