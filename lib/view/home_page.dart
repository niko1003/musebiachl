import 'package:flutter/material.dart';

import 'package:musebiachl/view/folders_page.dart';
import 'package:musebiachl/view/users_page.dart';

//
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //Bottom Nav bar Selection
  int _selectedIndex = 0;
  //List of Tab Pages assigned to each BottomNavBar
  List<Widget> tabWidget = [
    const FoldersPage(),
    const UsersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: tabWidget.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            label: 'Posts',
            icon: Icon(Icons.post_add),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Users',
          )
        ],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(
          () => _selectedIndex = index,
        ),
      ),
    );
  }
}
