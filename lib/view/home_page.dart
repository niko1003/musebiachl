import 'package:flutter/material.dart';

import 'package:musebiachl/view/collections_page.dart';
import 'package:musebiachl/view/favorite_page.dart';

/// The two things a player does: open a Mappe, and say what they play.
///
/// Sammlungen is the first tab as of 1.12.0. Until then the app opened on an instrument
/// picker and would not show a Mappe until one was chosen, which asked the wrong question
/// first: which Mappe is on the stand is what a player knows, and which Stimme they read
/// is a question only that Mappe can pose - a Marschbuch assigned by Stimme has no opinion
/// about instruments at all.
class HomePage extends StatefulWidget {
  final String authToken;

  const HomePage({Key? key, required this.authToken}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Only the selected tab is in the tree, so it reloads when it is come back to -
      // which is what makes a favorite changed on the second tab show up on the first.
      body: _selectedIndex == 0 ? const CollectionsPage() : const FavoritePage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Sammlungen',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: 'Mein Instrument',
          ),
        ],
      ),
    );
  }
}
