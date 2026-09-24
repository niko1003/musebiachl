import 'package:flutter/material.dart';

import 'package:musebiachl/model/api/instrument.dart';
import 'package:musebiachl/model/api/player_profile.dart';
import 'package:musebiachl/model/api/session_expired_exception.dart';
import 'package:musebiachl/service/remote_service.dart';
import 'package:musebiachl/service/session.dart';
import 'package:musebiachl/theme.dart';
import 'package:musebiachl/view/logout_button.dart';

/// What this player plays - a register, and optionally the exact instrument.
///
/// It belongs to the **account**, not to the phone: somebody who gets a new device has not
/// changed instrument, and the admin can set it over the telephone. The device keeps a copy
/// so the app opens with no signal, and a change made offline goes up on the next
/// connection rather than being lost or blocking the screen.
///
/// What it is for: in every Sammlung the player's own register is listed first. It
/// deliberately does not choose a Stimme for them - no register says whether somebody
/// plays the 1. or the 3., so that stays a decision per Mappe.
class FavoritePage extends StatefulWidget {
  const FavoritePage({Key? key}) : super(key: key);

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<InstrumentGroup>? groups;
  PlayerProfile? profile;

  var isLoaded = false;
  var saving = false;

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    profile = await RemoteServices().cachedProfile();

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
      // A rejected token is the one failure that is not "offline": the cached list is
      // no use if the account behind it is gone, so this goes back to the login screen
      // instead of staying quiet.
      if (e is SessionExpiredException) {
        await endSession(reason: sessionRejectedMessage);
        return;
      }
      setState(() => isLoaded = true);
      if (cached != null) return;
      showError(context, 'Error: ${e.toString()}');
      groups = [];
    }

    try {
      final fresh = await RemoteServices().fetchProfile();
      if (fresh != null && mounted) setState(() => profile = fresh);
    } catch (_) {
      // offline: the device copy above is what this screen works from anyway
    }
  }

  bool _isSelectedRegister(InstrumentGroup group) => profile?.registerId == group.id;

  bool _isSelectedInstrument(Instrument instrument) => profile?.instrumentId == instrument.id;

  Future<void> _save({
    String? registerId,
    String? registerLabel,
    String? instrumentId,
    String? instrumentLabel,
  }) async {
    setState(() => saving = true);

    final PlayerProfile saved;
    try {
      saved = await RemoteServices().saveFavorite(
        registerId: registerId,
        registerLabel: registerLabel,
        instrumentId: instrumentId,
        instrumentLabel: instrumentLabel,
      );
    } on SessionExpiredException {
      await endSession(reason: sessionRejectedMessage);
      return;
    }

    if (!mounted) return;
    setState(() {
      profile = saved;
      saving = false;
    });

    final String what = saved.label ?? 'Keine Angabe';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved.pending
          ? '$what gemerkt — wird bei der nächsten Verbindung gespeichert.'
          : '$what gespeichert.'),
      duration: const Duration(seconds: 2),
      backgroundColor: saved.pending ? Colors.amber.shade700 : Colors.green.shade600,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<InstrumentGroup> list = groups ?? <InstrumentGroup>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Instrument'),
        actions: const [LogoutButton()],
      ),
      body: !isLoaded
          ? const LoadingBody('Loading Instruments from API')
          : RefreshIndicator(
              onRefresh: getData,
              child: ListView.builder(
                itemCount: list.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _header(scheme);

                  final InstrumentGroup group = list[index - 1];
                  final bool mine = _isSelectedRegister(group);

                  return ExpansionTile(
                    leading: Icon(
                      mine ? Icons.check_circle : Icons.circle_outlined,
                      color: mine ? scheme.primary : scheme.outlineVariant,
                    ),
                    title: Text(
                      group.label,
                      style: TextStyle(fontWeight: mine ? FontWeight.w700 : FontWeight.w500),
                    ),
                    // Open on the register that holds the current answer.
                    initiallyExpanded: mine,
                    children: [
                      // Picking the register alone is a real answer: it is all the app needs
                      // to put this player's lines on top, and somebody who swaps between
                      // the 1. and the 2. should not have to name one of them.
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.groups_outlined, color: scheme.onSurfaceVariant),
                        title: const Text('Ganzes Register'),
                        subtitle: Text('Nur »${group.label}«, ohne bestimmte Stimme'),
                        trailing: mine && profile?.instrumentId == null
                            ? Icon(Icons.check, color: scheme.primary)
                            : null,
                        enabled: !saving,
                        onTap: () => _save(registerId: group.id, registerLabel: group.label),
                      ),
                      ...group.instruments.map((instrument) {
                        final bool selected = _isSelectedInstrument(instrument);

                        return Container(
                          color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 32, right: 16),
                            leading: Icon(Icons.queue_music_outlined, color: scheme.onSurfaceVariant),
                            title: Text(instrument.label),
                            trailing: selected ? Icon(Icons.check, color: scheme.primary) : null,
                            enabled: !saving,
                            onTap: () => _save(
                              registerId: group.id,
                              registerLabel: group.label,
                              instrumentId: instrument.id,
                              instrumentLabel: instrument.label,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _header(ColorScheme scheme) {
    final PlayerProfile? current = profile;
    final bool nothing = current == null || current.isEmpty;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nothing ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                nothing ? Icons.help_outline : Icons.music_note,
                color: nothing ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nothing ? 'Noch nichts gewählt' : current.label!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: nothing ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (!nothing)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Auswahl löschen',
                  color: scheme.onPrimaryContainer,
                  onPressed: saving ? null : () => _save(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nothing
                ? 'Sag, was du spielst — dann steht dein Register in jeder Sammlung oben.'
                : 'Steht in jeder Sammlung oben. Welche Stimme du in einer Mappe liest, '
                    'wählst du dort weiterhin selbst.',
            style: TextStyle(
              fontSize: 13,
              color: nothing ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
            ),
          ),
          if (current != null && current.pending) ...[
            const SizedBox(height: 8),
            Text(
              'Noch nicht übertragen — das passiert bei der nächsten Verbindung.',
              style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}
