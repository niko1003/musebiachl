import 'dart:io' as io;

import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Where a page that was deliberately made available offline is kept.
///
/// flutter_cache_manager's own `IOFileSystem` writes into the **temporary** directory.
/// That is the right place for a picture that can always be fetched again - and the wrong
/// place for the only copy of a Marschbuch in a hall with no reception: Android hands that
/// directory back to itself whenever storage runs short, "Cache leeren" empties it, and
/// every cleaner app on the phone does too.
///
/// These go to the application support directory instead, which nothing clears but
/// uninstalling the app or the Entfernen button in it.
class _SupportDirectoryFileSystem implements FileSystem {
  _SupportDirectoryFileSystem(this._folder) : _directory = _create(_folder);

  final String _folder;
  final Future<Directory> _directory;

  static Future<Directory> _create(String folder) async {
    final io.Directory base = await getApplicationSupportDirectory();

    const LocalFileSystem fs = LocalFileSystem();
    final Directory directory = fs.directory(base.path).childDirectory(folder);
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    Directory directory = await _directory;
    if (!await directory.exists()) {
      directory = await _create(_folder);
    }
    return directory.childFile(name);
  }
}

Config offlinePagesConfig(
  String key, {
  required Duration stalePeriod,
  required int maxNrOfCacheObjects,
}) =>
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileSystem: _SupportDirectoryFileSystem(key),
    );
