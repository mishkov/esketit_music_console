import 'dart:async';
import 'dart:math' as math;

import 'package:esketit_music_console/ui/catalog_submission/audio_object_url.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
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
  double _volume = 0.7;
  double _lastAudibleVolume = 0.7;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_player.setVolume(_volume));
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
    final progress = durationMs > 0
        ? (_position.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final colors = Theme.of(context).colorScheme;

    final playButton = SizedBox.square(
      dimension: 56,
      child: IconButton.filled(
        tooltip: playing ? 'Pause staged audio' : 'Play staged audio',
        onPressed: _isLoading ? null : _toggle,
        iconSize: 32,
        style: IconButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.6),
          minimumSize: const Size.square(56),
          padding: EdgeInsets.zero,
        ),
        icon: _isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
    final waveform = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 42,
          child: _WaveformProgress(
            key: ValueKey('staged-audio-progress-${widget.trackId}'),
            seed: widget.trackId,
            progress: progress,
            activeColor: colors.primary,
            inactiveColor: colors.onSurfaceVariant.withValues(alpha: 0.5),
            onSeek: durationMs > 0 && !_isLoading
                ? (fraction) => _seekTo(durationMs * fraction)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_position),
              key: ValueKey('staged-audio-position-${widget.trackId}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _formatDuration(_duration),
              key: ValueKey('staged-audio-duration-${widget.trackId}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
    final volumeControl = SizedBox(
      width: 160,
      child: Row(
        children: [
          IconButton(
            tooltip: _volume == 0 ? 'Unmute staged audio' : 'Mute staged audio',
            onPressed: _toggleMute,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _volume == 0
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                key: ValueKey('staged-audio-volume-${widget.trackId}'),
                value: _volume,
                onChanged: _setVolume,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return Column(
                children: [
                  Row(
                    children: [
                      playButton,
                      const SizedBox(width: 12),
                      Expanded(child: waveform),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerRight, child: volumeControl),
                ],
              );
            }
            return Row(
              children: [
                playButton,
                const SizedBox(width: 12),
                Expanded(child: waveform),
                const SizedBox(width: 16),
                volumeControl,
              ],
            );
          },
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

  void _setVolume(double volume) {
    if (volume > 0) _lastAudibleVolume = volume;
    setState(() => _volume = volume);
    unawaited(_player.setVolume(volume));
  }

  void _toggleMute() {
    _setVolume(_volume == 0 ? _lastAudibleVolume : 0);
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

class _WaveformProgress extends StatelessWidget {
  const _WaveformProgress({
    super.key,
    required this.seed,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
  });

  final int seed;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(double x) =>
            onSeek?.call((x / constraints.maxWidth).clamp(0.0, 1.0));

        return Semantics(
          label: 'Seek staged audio',
          value: '${(progress * 100).round()} percent',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onSeek == null
                ? null
                : (details) => seek(details.localPosition.dx),
            onHorizontalDragUpdate: onSeek == null
                ? null
                : (details) => seek(details.localPosition.dx),
            child: CustomPaint(
              painter: _VolumeSticksPainter(
                seed: seed,
                progress: progress,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              size: Size(constraints.maxWidth, 42),
            ),
          ),
        );
      },
    );
  }
}

class _VolumeSticksPainter extends CustomPainter {
  const _VolumeSticksPainter({
    required this.seed,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int seed;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.2;
    const barStep = 3.6;
    final count = (size.width / barStep).floor();
    if (count == 0) return;
    final leftInset = (size.width - (count - 1) * barStep - barWidth) / 2;
    final activePaint = Paint()..color = activeColor;
    final inactivePaint = Paint()..color = inactiveColor;

    for (var index = 0; index < count; index++) {
      final variation = math.sin(index * 0.57 + seed * 0.13).abs();
      final detail = math.sin(index * 1.71 + seed * 0.29).abs();
      final swell = math.sin(index * 0.085 + seed * 0.07).abs();
      final height = 6 + 22 * (0.35 * variation + 0.25 * detail + 0.4 * swell);
      final x = leftInset + index * barStep;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - height) / 2, barWidth, height),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        index / count < progress ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VolumeSticksPainter oldDelegate) =>
      seed != oldDelegate.seed ||
      progress != oldDelegate.progress ||
      activeColor != oldDelegate.activeColor ||
      inactiveColor != oldDelegate.inactiveColor;
}
