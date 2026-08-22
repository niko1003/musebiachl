import 'package:flutter/material.dart';

import 'dart:async';
import 'package:musebiachl/model/api/instrument.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replaces the old musician picker: the player selects the instrument they play,
/// grouped by instrument group so the list stays navigable.
class InstrumentsPage extends StatefulWidget {
  final VoidCallback? onInstrumentSelected;

  const InstrumentsPage({Key? key, this.onInstrumentSelected})
      : super(key: key);

  @override
  State<InstrumentsPage> createState() => _InstrumentsPageState();
}

class _InstrumentsPageState extends State<InstrumentsPage> {
  List<InstrumentGroup>? groups;

  var isLoaded = false;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  /// Instrument ids are UUIDs; empty means nothing picked yet.
  String instrumentId = '';

  Future<void> persistInstrumentId(String paramInstrumentId) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString('instrumentId', paramInstrumentId);
    instrumentId = paramInstrumentId;
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    instrumentId = await _prefs.then((SharedPreferences prefs) {
      return prefs.getString('instrumentId') ?? '';
    });
    final cached = await RemoteServices().cachedInstrumentGroups();
    if (cached != null && mounted) {
      setState(() {
        groups = cached;
        isLoaded = true;
      });
    }

    try {
      final fresh = await RemoteServices().fetchInstrumentGroups();
      if (!mounted) return;
      setState(() {
        groups = fresh;
        isLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoaded = true);
      if (cached != null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade300,
      ));
      groups = [];
    }
  }

  bool _groupHasSelection(InstrumentGroup group) {
    return group.instruments.any((i) => i.id == instrumentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrument auswählen.'),
        centerTitle: true,
      ),
      body: Visibility(
        visible: isLoaded,
        replacement: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Loading Instruments from API',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
              SizedBox(height: 10.0),
              CircularProgressIndicator()
            ],
          ),
        ),
        child: ListView.builder(
            itemCount: groups?.length,
            itemBuilder: (context, index) {
              final InstrumentGroup group = groups![index];

              return ExpansionTile(
                title: Text(group.label),
                // open the group that holds the current selection
                initiallyExpanded: _groupHasSelection(group),
                children: group.instruments.map((instrument) {
                  return Container(
                    color: (instrumentId == instrument.id)
                        ? Colors.blue.withValues(alpha: 0.5)
                        : Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      title: Text(instrument.label),
                      onTap: () async {
                        setState(() {
                          instrumentId = instrument.id;
                        });
                        await persistInstrumentId(instrument.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${instrument.label} ausgewählt'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: Colors.green.shade600,
                        ));
                        if (widget.onInstrumentSelected != null) {
                          widget.onInstrumentSelected!();
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            }),
      ),
    );
  }
}
