import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../l10n/ui_strings.dart';

import '../models/prediction.dart';
import 'prediction_options.dart';

class PredictionImageOverlay extends StatefulWidget {
  const PredictionImageOverlay({
    super.key,
    required this.file,
    required this.predictions,
    this.onClose,
    this.fit = BoxFit.contain,
    this.selectedIssues,
    this.onToggleIssue,
    this.interactive = true,
  });

  final File file;
  final List<Prediction> predictions;
  final VoidCallback? onClose;
  final BoxFit fit;
  final Set<String>? selectedIssues;
  final ValueChanged<String>? onToggleIssue;
  final bool interactive;

  @override
  State<PredictionImageOverlay> createState() => _PredictionImageOverlayState();
}

class _PredictionImageOverlayState extends State<PredictionImageOverlay> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ui.Image? _sourceImage;
  final _transform = TransformationController();
  bool _imageFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant PredictionImageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _sourceImage = null;
      _imageFailed = false;
      _transform.value = Matrix4.identity();
      _resolveImage();
    }
  }

  void _resolveImage() {
    final stream = FileImage(
      widget.file,
    ).resolve(createLocalImageConfiguration(context));
    if (_imageStream?.key == stream.key) return;
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = stream;
    _imageListener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _sourceImage = info.image);
      },
      onError: (error, stack) {
        if (mounted) setState(() => _imageFailed = true);
      },
    );
    stream.addListener(_imageListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xFF071018),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final container = Size(constraints.maxWidth, constraints.maxHeight);
          final source = _sourceImage == null
              ? null
              : Size(
                  _sourceImage!.width.toDouble(),
                  _sourceImage!.height.toDouble(),
                );
          final imageRect = source == null
              ? null
              : displayedImageRect(container, source, fit: widget.fit);
          final issues = Prediction.uniqueIssues(widget.predictions);
          final canvas = SizedBox.fromSize(
            size: container,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageFailed)
                  Center(
                    child: Text(
                      UiStrings.of(
                        context,
                      ).text('Unable to display this photo.'),
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else
                  Image.file(
                    widget.file,
                    fit: widget.fit,
                    errorBuilder: (_, _, _) => SizedBox(),
                  ),
                if (imageRect != null)
                  ...widget.predictions.map((prediction) {
                    final rect = boundingBoxRect(
                      prediction.boundingBox,
                      imageRect,
                    );
                    if (rect.isEmpty) return SizedBox();
                    final index = issues.indexWhere(
                      (p) => p.issueKey == prediction.issueKey,
                    );
                    final selected =
                        widget.selectedIssues?.contains(prediction.issueKey) ??
                        true;
                    final color = selected
                        ? predictionColors[(index < 0 ? 0 : index) %
                              predictionColors.length]
                        : Colors.white38;
                    return Positioned.fromRect(
                      rect: rect,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: widget.onToggleIssue == null
                            ? null
                            : () => widget.onToggleIssue!(prediction.issueKey),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.09)
                                : Colors.transparent,
                            border: Border.all(
                              color: color,
                              width: selected ? 3 : 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              color: color,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Color(0xFF071018),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
          return ClipRect(
            child: Stack(
              children: [
                if (widget.interactive)
                  InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 5,
                    child: canvas,
                  )
                else
                  canvas,
                if (widget.onClose != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton.filledTonal(
                      tooltip: UiStrings.of(context).text('Close photo'),
                      onPressed: widget.onClose,
                      icon: Icon(Icons.close),
                    ),
                  ),
                if (widget.interactive)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IconButton(
                      tooltip: UiStrings.of(context).text('Reset image zoom'),
                      onPressed: () => _transform.value = Matrix4.identity(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(Icons.fit_screen),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Rect displayedImageRect(
  Size container,
  Size source, {
  BoxFit fit = BoxFit.cover,
}) {
  if (container.width <= 0 ||
      container.height <= 0 ||
      source.width <= 0 ||
      source.height <= 0) {
    return Offset.zero & container;
  }
  if (fit == BoxFit.fill) return Offset.zero & container;
  final horizontal = container.width / source.width;
  final vertical = container.height / source.height;
  final scale = fit == BoxFit.cover
      ? math.max(horizontal, vertical)
      : math.min(horizontal, vertical);
  final size = Size(source.width * scale, source.height * scale);
  return Rect.fromLTWH(
    (container.width - size.width) / 2,
    (container.height - size.height) / 2,
    size.width,
    size.height,
  );
}

Rect boundingBoxRect(List<double> box, Rect imageRect) {
  if (box.length != 4 || box.any((n) => !n.isFinite)) return Rect.zero;
  final ymin = math.min(box[0], box[2]).clamp(0, 1000).toDouble();
  final xmin = math.min(box[1], box[3]).clamp(0, 1000).toDouble();
  final ymax = math.max(box[0], box[2]).clamp(0, 1000).toDouble();
  final xmax = math.max(box[1], box[3]).clamp(0, 1000).toDouble();
  return Rect.fromLTRB(
    imageRect.left + xmin / 1000 * imageRect.width,
    imageRect.top + ymin / 1000 * imageRect.height,
    imageRect.left + xmax / 1000 * imageRect.width,
    imageRect.top + ymax / 1000 * imageRect.height,
  );
}
