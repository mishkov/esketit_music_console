import 'dart:async';

import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/ui/catalog_submission/audio_object_url.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class StagedAudioPlayer extends StatefulWidget {
  const StagedAudioPlayer({
    super.key,
    required this.trackId,
    required this.repository,
    this.leaseToken,
    this.objectUrlFactory,
  });

  final int trackId;
  final CatalogSubmissionRepository repository;
  final String? leaseToken;
  final AudioObjectUrlFactory? objectUrlFactory;

  @override
  State<StagedAudioPlayer> createState() => _StagedAudioPlayerState();
}

class _StagedAudioPlayerState extends State<StagedAudioPlayer> {
  late final AudioPlayer _player;
  late final AudioObjectUrlFactory _urlFactory;
  String? _objectUrl;
  String? _error;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  int _sourceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _urlFactory = widget.objectUrlFactory ?? BrowserAudioObjectUrlFactory();
    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
        unawaited(_player.pause());
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant StagedAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId ||
        oldWidget.leaseToken != widget.leaseToken) {
      _sourceGeneration += 1;
      _disposeObjectUrl();
      unawaited(_player.stop());
      setState(() {
        _error = null;
        _isLoading = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.playing;
    final durationMs = _duration.inMilliseconds;
    final maxMs = durationMs > 0 ? durationMs : 1;
    final positionMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: playing ? 'Pause staged audio' : 'Play staged audio',
              onPressed: _isLoading ? null : _toggle,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                key: ValueKey('staged-audio-progress-${widget.trackId}'),
                value: positionMs,
                max: maxMs.toDouble(),
                onChanged: !_isLoading && durationMs > 0 ? _seekTo : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
              key: ValueKey('staged-audio-time-${widget.trackId}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    try {
      if (_objectUrl == null) {
        final sourceGeneration = _sourceGeneration;
        setState(() {
          _isLoading = true;
          _error = null;
        });
        final data = await widget.repository.getStagedAudio(
          widget.trackId,
          leaseToken: widget.leaseToken,
        );
        if (!mounted || sourceGeneration != _sourceGeneration) return;
        final url = _urlFactory.create(
          data.bytes,
          contentType: data.contentType,
        );
        _disposeObjectUrl();
        _objectUrl = url;
        await _player.setUrl(url);
        if (!mounted || sourceGeneration != _sourceGeneration) return;
        setState(() => _isLoading = false);
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_playAndReportErrors());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _playAndReportErrors() async {
    try {
      await _player.play();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _seekTo(double milliseconds) async {
    final position = Duration(milliseconds: milliseconds.round());
    setState(() => _position = position);
    try {
      await _player.seek(position);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _disposeObjectUrl() {
    final url = _objectUrl;
    if (url != null) _urlFactory.revoke(url);
    _objectUrl = null;
  }

  @override
  void dispose() {
    _sourceGeneration += 1;
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _disposeObjectUrl();
    _player.dispose();
    super.dispose();
  }
}
