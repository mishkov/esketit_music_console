import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

int requireTrackNumber(TextEditingController controller) {
  final number = int.tryParse(controller.text.trim());
  if (number == null || number < 1) {
    throw const FormatException('Enter a positive track number.');
  }
  return number;
}

class TrackNumberField extends StatefulWidget {
  const TrackNumberField({
    required this.controller,
    required this.album,
    this.itemKey,
    this.currentTrackId,
    this.initialNumber,
    this.enabled = true,
    super.key,
  });
  final TextEditingController controller;
  final Album? album;
  final Object? itemKey;
  final int? currentTrackId;
  final int? initialNumber;
  final bool enabled;
  @override
  State<TrackNumberField> createState() => _TrackNumberFieldState();
}

class _TrackNumberFieldState extends State<TrackNumberField> {
  List<Track> _tracks = const [];
  bool _loading = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrackNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album?.id != widget.album?.id ||
        oldWidget.itemKey != widget.itemKey ||
        (oldWidget.initialNumber == null && widget.initialNumber != null)) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final albumId = widget.album?.id;
    widget.controller.clear();
    if (albumId == null) {
      _tracks = const [];
      return;
    }
    _loading = true;
    _error = null;
    try {
      final tracks = await context.read<TracksStorage>().getAlbumTracks(
        albumId,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      var maximum = 0;
      for (final track in tracks) {
        if ((track.trackNumber ?? 0) > maximum) {
          maximum = track.trackNumber!;
        }
      }
      widget.controller.text = '${widget.initialNumber ?? maximum + 1}';
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _loading = false;
        _error =
            'Could not load existing track numbers. Refresh the album before saving.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled && widget.album != null && !_loading,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: 'Track number',
            helperText: _loading
                ? 'Loading existing numbers…'
                : 'Required. Gaps are allowed; existing tracks will not move.',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            if (number == null || number < 1) {
              return 'Enter a positive track number.';
            }
            for (final track in _tracks) {
              if (track.id != widget.currentTrackId &&
                  track.trackNumber == number) {
                return 'Track $number is already occupied by ${track.name}.';
              }
            }
            return null;
          },
        ),
        if (_tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tracks
                  .map(
                    (track) => Chip(
                      label: Text(
                        '${track.trackNumber ?? '?'} · ${track.name}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
