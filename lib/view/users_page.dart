import 'package:flutter/material.dart';

import 'dart:async';
import 'package:musebiachl/model/api/musician.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersPage extends StatefulWidget {
  final VoidCallback? onMusicianSelected;

  const UsersPage({Key? key, this.onMusicianSelected}) : super(key: key);

  @override
  State<UsersPage> createState() => _UsersPageState();
}

//
class _UsersPageState extends State<UsersPage> {
  //List to store post data
  List<Musician>? user;

  //boolean to trigger if loaded
  var isLoaded = false;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  int musicianId = 11;

  persistMusicianId(int paramMusicianId) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setInt('musicianId', paramMusicianId);
    musicianId = paramMusicianId;
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  //function to get Data from API
  getData() async {
    musicianId = await _prefs.then((SharedPreferences prefs) {
      return prefs.getInt('musicianId') ?? 11;
    });
    try {
      user = await RemoteServices().getMusicians();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade300,
      ));
      user = [];
    } finally {
      setState(() {
        isLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musiker:in auswählen.'),
        centerTitle: true,
      ),
      body: Visibility(
        visible: isLoaded,
        child: ListView.builder(
            itemCount: user?.length,
            itemBuilder: (context, index) {
              var userId = user![index].id;
              var label = user![index].firstName + " " + user![index].name;
              var subtitle =
                  user![index].instruments.map((item) => item.label).join(", ");

              if (user![index].optionalInstruments.isNotEmpty) {
                subtitle = subtitle +
                    " | " +
                    user![index]
                        .optionalInstruments
                        .map((item) => item.label)
                        .join(", ");
              }

              return Container(
                color: (musicianId == userId)
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.transparent,
                child: ListTile(
                  onTap: () async {
                    setState(() {
                      musicianId = userId;
                    });
                    await persistMusicianId(userId);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$label ausgewählt'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: Colors.green.shade600,
                    ));
                    if (widget.onMusicianSelected != null) {
                      widget.onMusicianSelected!();
                    }
                  },
                  title: Text(label),
                  subtitle: Text(subtitle),
                ),
              );
            }),
        replacement: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Loading Musicians from API',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
      ),
    );
  }
}
