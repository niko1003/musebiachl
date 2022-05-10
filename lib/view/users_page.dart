import 'package:flutter/material.dart';


import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/model/constants.dart';
import 'package:musebiachl/service/remote_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  State<UsersPage> createState() => _UsersPageState();
}

//
class _UsersPageState extends State<UsersPage> {
  //List to store post data
  List<Musician>? user;

  //boolean to trigger if loaded
  var isLoaded = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  //function to get Data from API
  getData() async {
    user = await RemoteServices().getMusicians();
    if (user != null) {
      setState(() {
        //print("post: $post");
        isLoaded = true;
      });
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musiker auswählen.'),
        centerTitle: true,
      ),
      body: Visibility(
        visible: isLoaded,
        child: ListView.builder(
          itemCount: user?.length,
          itemBuilder: (context, index) {
            var userId = user![index].id;
            var label = user![index].firstName + " " + user![index].name;
             return 
              Container(
                color: (Constants.selectedMusicianId == userId) ? Colors.blue.withOpacity(0.5) : Colors.transparent,
                child: ListTile(
                  onTap: () => setState(
                    () => Constants.selectedMusicianId = userId,
                  ),
                  title: Text(label),
                ),
              );
          }
        ),
        replacement: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Loading Musicians from API'),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
      ),
    );
  }
}
