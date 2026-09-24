import 'package:flutter/material.dart';

import 'package:musebiachl/model/api/collection_selection.dart';
import 'package:musebiachl/service/offline_store.dart';

/// The one control that takes a Stimme along, and the one place that says whether it is
/// here.
///
/// It is its own widget because the same question is asked on three screens - the pick
/// list, the Mappe itself, and (as [OfflineMark]) the list of Sammlungen - and because the
/// answer changes while nobody is looking at it: a download started on the pick screen
/// goes on running when the player walks into the Mappe. It rebuilds from
/// [OfflineStore.changes] rather than from a parent's setState for exactly that reason.
class OfflineButton extends StatefulWidget {
  const OfflineButton({
    Key? key,
    required this.collectionId,
    required this.collectionName,
    required this.selection,
    this.currentKeys,
  }) : super(key: key);

  final int collectionId;
  final String collectionName;
  final CollectionSelection selection;

  /// The pages this line really has right now, when the caller knows them - only
  /// CollectionPage does. It is what turns "offline" into "offline, but the Mappe has
  /// changed since".
  final List<String>? currentKeys;

  @override
  State<OfflineButton> createState() => _OfflineButtonState();
}

class _OfflineButtonState extends State<OfflineButton> {
  Future<void> _download() async {
    final String? problem = await OfflineStore.download(
      collectionId: widget.collectionId,
      collectionName: widget.collectionName,
      selection: widget.selection,
    );
    if (!mounted) return;

    final ColorScheme scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(problem ??
          '»${widget.selection.label}« ist jetzt offline verfügbar.'),
      backgroundColor: problem == null ? null : scheme.errorContainer,
    ));
  }

  Future<void> _remove(OfflineSelection saved) async {
    await OfflineStore.remove(saved);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('»${saved.label}« ist nicht mehr offline verfügbar.'),
    ));
  }

  /// What is here, how much of it, and the two things that can be done about it.
  Future<void> _details(OfflineSelection saved, bool outdated) async {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(
          outdated || !saved.complete ? Icons.sync_problem : Icons.offline_pin,
          color: outdated || !saved.complete ? scheme.error : scheme.primary,
        ),
        title: Text(saved.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              saved.complete
                  ? '${saved.pages} ${saved.pages == 1 ? 'Seite' : 'Seiten'} · ${saved.sizeLabel}'
                  : '${saved.keys.length} von ${saved.pages} Seiten · ${saved.sizeLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('auf diesem Gerät seit ${saved.savedLabel}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            if (outdated || !saved.complete) ...[
              const SizedBox(height: 12),
              Text(
                !saved.complete
                    ? 'Es fehlen Seiten. Ohne Netz sind nur die geladenen da.'
                    : 'In der Mappe hat sich seither etwas geändert.',
                style: TextStyle(color: scheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'remove'),
            child: Text('Entfernen', style: TextStyle(color: scheme.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'update'),
            child: const Text('Aktualisieren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );

    if (action == 'remove') await _remove(saved);
    if (action == 'update') await _download();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<int>(
      valueListenable: OfflineStore.changes,
      builder: (BuildContext context, int _, Widget? _) {
        final OfflineProgress? progress =
            OfflineStore.progressOf(widget.collectionId, widget.selection);

        if (progress != null) {
          return IconButton(
            tooltip: 'Abbrechen',
            onPressed: () =>
                OfflineStore.cancel(widget.collectionId, widget.selection),
            icon: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                // Indeterminate until the piece list says how many pages there are.
                value: progress.fraction,
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
          );
        }

        final OfflineSelection? saved =
            OfflineStore.forSelection(widget.collectionId, widget.selection);

        if (saved == null) {
          return IconButton(
            tooltip: 'Offline verfügbar machen',
            onPressed: _download,
            icon: Icon(Icons.download_for_offline_outlined,
                color: scheme.onSurfaceVariant),
          );
        }

        final bool outdated = saved.outdatedFor(widget.selection) ||
            (widget.currentKeys != null && saved.missesAnyOf(widget.currentKeys!));
        final bool trouble = outdated || !saved.complete;

        return IconButton(
          tooltip: trouble ? 'Offline, aber nicht aktuell' : 'Offline verfügbar',
          onPressed: () => _details(saved, outdated),
          icon: Icon(
            trouble ? Icons.sync_problem : Icons.offline_pin,
            color: trouble ? scheme.error : scheme.primary,
          ),
        );
      },
    );
  }
}

/// Offline, said in one glance and without a button: the Sammlungen list and the pieces
/// inside a Mappe both only have to *show* it.
class OfflineMark extends StatelessWidget {
  const OfflineMark({Key? key, this.label, this.size = 18, this.complete = true})
      : super(key: key);

  final String? label;
  final double size;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = complete ? scheme.primary : scheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(complete ? Icons.offline_pin : Icons.sync_problem, size: size, color: color),
        if (label != null) ...[
          const SizedBox(width: 4),
          Text(
            label!,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
