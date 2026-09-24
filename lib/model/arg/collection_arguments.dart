import 'package:musebiachl/model/api/collection_selection.dart';

/// A Sammlung and the line it is being read as.
///
/// The Sammlung comes first and the Stimme second (1.12.0): which Mappe is on the stand is
/// the thing a player knows, and which Stimme they read is a question only that Mappe can
/// pose - a Marschbuch assigned "1. in B" has no opinion about instruments at all.
class CollectionArguments {
  final int id;
  final String name;
  final CollectionSelection selection;

  CollectionArguments(this.id, this.name, this.selection);
}
