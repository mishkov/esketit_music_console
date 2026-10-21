import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_number_assignment.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlbumTrackOrderDialog extends StatefulWidget {
  const AlbumTrackOrderDialog({
    this.submission,
    this.album,
    this.tracks = const [],
    this.assignments = const [],
    super.key,
  });
  final CatalogSubmission? submission;
  final Album? album;
  final List<Track> tracks;
  final List<TrackNumberAssignment> assignments;
  @override
  State<AlbumTrackOrderDialog> createState() => _AlbumTrackOrderDialogState();
}

class _AlbumTrackOrderDialogState extends State<AlbumTrackOrderDialog> {
  final _numbers = <int, TextEditingController>{};
  final _names = <int, String>{};
  final _reason = TextEditingController();
  final _revision = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final data = widget.submission?.retainedEntity;
    if (data != null) {
      final proposed = (data['tracks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final current = (data['currentTracks'] as List<dynamic>? ?? proposed)
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final item in current) {
        final id = (item['trackId'] as num).toInt();
        final value =
            proposed
                .where((entry) => entry['trackId'] == id)
                .firstOrNull?['trackNumber'] ??
            item['trackNumber'];
        _numbers[id] = TextEditingController(text: '$value');
      }
      for (final item
          in (data['trackDetails'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()) {
        _names[(item['id'] as num).toInt()] = item['name'].toString();
      }
      _revision.text =
          '${data['currentOrderRevision'] ?? data['expectedOrderRevision']}';
      _reason.text = data['reason']?.toString() ?? '';
    } else {
      for (final assignment in widget.assignments) {
        _numbers[assignment.trackId] = TextEditingController(
          text: '${assignment.trackNumber}',
        );
      }
      for (final track in widget.tracks) {
        _names[track.id!] = track.name;
      }
      _revision.text = '${widget.album!.orderRevision}';
    }
  }

  @override
  void dispose() {
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    _reason.dispose();
    _revision.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final seen = <int>{};
      final tracks = _numbers.entries.map((entry) {
        final number = int.tryParse(entry.value.text);
        if (number == null || number < 1 || !seen.add(number)) {
          throw const FormatException(
            'Every track needs a distinct positive number.',
          );
        }
        return TrackNumberAssignment(trackId: entry.key, trackNumber: number);
      }).toList();
      final revision = int.tryParse(_revision.text);
      if (revision == null || revision < 1) {
        throw const FormatException('A current album revision is required.');
      }
      final repository = context.read<CatalogSubmissionRepository>();
      final submission = widget.submission;
      if (submission == null) {
        await repository.submitAlbumTrackOrder(
          albumId: widget.album!.id!,
          tracks: tracks,
          expectedOrderRevision: revision,
          reason: _reason.text,
        );
      } else {
        await repository.updateAlbumTrackOrder(
          submissionId: submission.id,
          expectedRevision: submission.revision,
          tracks: tracks,
          expectedOrderRevision: revision,
          reason: _reason.text,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.submission == null
          ? 'Propose track numbers'
          : 'Correct track-number proposal',
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The album will change only after reviewer approval. Gaps are allowed; numbers must be unique.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final entry in _numbers.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: entry.value,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText:
                        '${_names[entry.key] ?? 'Track'} (#${entry.key})',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              enabled: !_saving,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(
          widget.submission == null ? 'Submit for review' : 'Save correction',
        ),
      ),
    ],
  );
}
