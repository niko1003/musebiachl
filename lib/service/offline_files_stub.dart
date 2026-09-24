import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The web build, where there is no directory to keep anything in - the package's own
/// in-memory file system is all there is, and `flutter run -d web-server` is a way to look
/// at the app rather than a way to take a Mappe to a rehearsal.
///
/// It exists so that importing `path_provider` (and with it `dart:io`) stays out of the
/// web build, which would otherwise not compile at all.
Config offlinePagesConfig(
  String key, {
  required Duration stalePeriod,
  required int maxNrOfCacheObjects,
}) =>
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
    );
