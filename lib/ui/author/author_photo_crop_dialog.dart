import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

Future<Uint8List?> showAuthorPhotoCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
  required String fileName,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _AuthorPhotoCropDialog(imageBytes: imageBytes, fileName: fileName);
    },
  );
}

enum _CropAspectRatioOption {
  free('Free', null),
  square('1:1', 1),
  portrait('4:5', 4 / 5),
  wide('16:9', 16 / 9);

  const _CropAspectRatioOption(this.label, this.value);

  final String label;
  final double? value;
}

class _AuthorPhotoCropDialog extends StatefulWidget {
  const _AuthorPhotoCropDialog({
    required this.imageBytes,
    required this.fileName,
  });

  final Uint8List imageBytes;
  final String fileName;

  @override
  State<_AuthorPhotoCropDialog> createState() => _AuthorPhotoCropDialogState();
}

class _AuthorPhotoCropDialogState extends State<_AuthorPhotoCropDialog> {
  final _cropController = CropController();
  Completer<Uint8List?>? _cropResultCompleter;

  _CropAspectRatioOption _aspectRatio = _CropAspectRatioOption.free;
  bool _isCropping = false;
  bool _isCropReady = false;
  bool _canUndo = false;
  bool _canRedo = false;

  @override
  void dispose() {
    final cropResultCompleter = _cropResultCompleter;
    if (cropResultCompleter != null && !cropResultCompleter.isCompleted) {
      cropResultCompleter.complete(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxContentWidth = math.min(760.0, mediaQuery.size.width - 48);
    final cropHeight = math.min(
      math.max(280.0, mediaQuery.size.height - 340),
      560.0,
    );

    return AlertDialog(
      title: const Text('Crop photo'),
      content: SizedBox(
        width: maxContentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_CropAspectRatioOption>(
                  showSelectedIcon: false,
                  segments: [
                    for (final option in _CropAspectRatioOption.values)
                      ButtonSegment(value: option, label: Text(option.label)),
                  ],
                  selected: {_aspectRatio},
                  onSelectionChanged: _isCropping
                      ? null
                      : (selection) {
                          final selected = selection.single;
                          setState(() {
                            _aspectRatio = selected;
                          });
                          _cropController.aspectRatio = selected.value;
                        },
                ),
                IconButton(
                  onPressed: _canUndo && !_isCropping
                      ? _cropController.undo
                      : null,
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo crop change',
                ),
                IconButton(
                  onPressed: _canRedo && !_isCropping
                      ? _cropController.redo
                      : null,
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo crop change',
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: cropHeight,
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  aspectRatio: _aspectRatio.value,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 0.82,
                    aspectRatio: _aspectRatio.value,
                  ),
                  baseColor: Theme.of(context).colorScheme.surface,
                  maskColor: Colors.black.withValues(alpha: 0.56),
                  radius: 4,
                  imageCropper: legacyImageCropper,
                  cornerDotBuilder: (size, edgeAlignment) =>
                      const DotControl(color: Colors.white, padding: 6),
                  progressIndicator: const Center(
                    child: CircularProgressIndicator(),
                  ),
                  overlayBuilder: (context, rect) {
                    return CustomPaint(
                      painter: _CropGridPainter(color: Colors.white),
                    );
                  },
                  onHistoryChanged: (history) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _canUndo = history.undoCount > 0;
                      _canRedo = history.redoCount > 0;
                    });
                  },
                  onStatusChanged: (status) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _isCropReady = status == CropStatus.ready;
                    });
                  },
                  onCropped: (result) {
                    switch (result) {
                      case CropSuccess(:final croppedImage):
                        final cropResultCompleter = _cropResultCompleter;
                        if (cropResultCompleter != null &&
                            !cropResultCompleter.isCompleted) {
                          cropResultCompleter.complete(croppedImage);
                        }
                      case CropFailure(:final cause, :final stackTrace):
                        FlutterError.reportError(
                          FlutterErrorDetails(
                            exception: cause,
                            stack: stackTrace,
                            library: 'author photo crop',
                          ),
                        );
                        final cropResultCompleter = _cropResultCompleter;
                        if (cropResultCompleter != null &&
                            !cropResultCompleter.isCompleted) {
                          cropResultCompleter.complete(null);
                        }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isCropping || !_isCropReady ? null : _finishCrop,
          icon: _isCropping
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.crop),
          label: const Text('Use crop'),
        ),
      ],
    );
  }

  Future<void> _finishCrop() async {
    setState(() {
      _isCropping = true;
    });

    _cropResultCompleter = Completer<Uint8List?>();
    _cropController.crop();
    final croppedBytes = await _cropResultCompleter!.future;
    if (!mounted) {
      return;
    }
    _cropResultCompleter = null;

    if (croppedBytes == null) {
      setState(() {
        _isCropping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to crop ${widget.fileName}.')),
      );
      return;
    }

    Navigator.of(context).pop(croppedBytes);
  }
}

class _CropGridPainter extends CustomPainter {
  const _CropGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 1;

    canvas.drawRect(Offset.zero & size, paint..style = PaintingStyle.stroke);
    paint.style = PaintingStyle.stroke;

    for (final fraction in const [1 / 3, 2 / 3]) {
      final dx = size.width * fraction;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);

      final dy = size.height * fraction;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
