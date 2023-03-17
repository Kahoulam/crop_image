import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:rect_getter/rect_getter.dart';

class CalcuateImageRectResult {
  final ui.Rect rectResult;
  final double scale;
  final ui.Rect rectCanvas;
  const CalcuateImageRectResult({
    required this.rectResult,
    required this.scale,
    required this.rectCanvas,
  });
}

class GaImagePanZoomHandler {
  static final _devLogName = 'GavinDbg';
  final _interactiveViewerKey = RectGetter.createGlobalKey();

  late ui.Rect _rectCanvas;
  late ui.Rect _rectCanvasInit;
  late ui.Rect _rectImage;
  late ui.Rect _rectImageInit;
  late double _scaleImage;
  double _scale = 1.0;
  late double _maxScale;
  late double _minScale;

  Widget buildInteractiveViewer({
    double maxScale = 2.5,
    double minScale = 0.8,
    required Widget child,
  }) {
    _maxScale = maxScale;
    _minScale = minScale;
    return InteractiveViewer(
      key: _interactiveViewerKey,
      maxScale: maxScale,
      minScale: minScale,
      child: child,
      onInteractionUpdate: (update) {
        if(update.focalPointDelta.dx != 0 || update.focalPointDelta.dy != 0 ) {

          double newL = _rectCanvas.left + update.focalPointDelta.dx;
          if( newL > 0 ) {
            newL = 0;
          } else if( newL < _rectCanvasInit.width - _rectCanvas.width ) {
            newL = _rectCanvasInit.width - _rectCanvas.width;
          }
          double newT = _rectCanvas.top + update.focalPointDelta.dy;
          if( newT > 0 ) {
            newT = 0;
          } else if( newT < _rectCanvasInit.height - _rectCanvas.height ) {
            newT = _rectCanvasInit.height - _rectCanvas.height;
          }
          final delta = Offset(newL - _rectCanvas.left, newT - _rectCanvas.top);
          _rectImage = ui.Rect.fromLTWH(_rectImage.left + delta.dx, _rectImage.top + delta.dy, _rectImage.width, _rectImage.height);
          _rectCanvas = ui.Rect.fromLTWH(newL, newT, _rectCanvas.width, _rectCanvas.height);

          dev.log("[GaImagePanZoomHandler] Paning: (${delta.dx.toStringAsFixed(0)},${delta.dy.toStringAsFixed(0)})", name: _devLogName);
          dev.log("                        _rectCanvas is (${_rectCanvas.left.toStringAsFixed(0)}, ${_rectCanvas.top.toStringAsFixed(0)}, ${_rectCanvas.right
              .toStringAsFixed(0)}, ${_rectCanvas.bottom.toStringAsFixed(0)}) ${_rectCanvas.width.toStringAsFixed(0)}x${_rectCanvas.height.toStringAsFixed(0)}", name: _devLogName);
          dev.log("                        _rectImage is (${_rectImage.left.toStringAsFixed(0)}, ${_rectImage.top.toStringAsFixed(0)}, ${_rectImage.right
              .toStringAsFixed(0)}, ${_rectImage.bottom.toStringAsFixed(0)}) ${_rectImage.width.toStringAsFixed(0)}x${_rectImage.height.toStringAsFixed(0)}", name: _devLogName);
          dev.log("                        _scale is ${_scale.toStringAsFixed(4)}", name: _devLogName);
        } else if (update.scale != 1.0) {
          double scaleApply = update.scale;
          final newScale = _scale * scaleApply;
          if(newScale > _maxScale) {
            scaleApply = _maxScale / _scale;
            _scale = _maxScale;
          } else if (newScale < _minScale) {
            scaleApply = _minScale / _scale;
            _scale = _minScale;
          } else {
            _scale = newScale;
          }

          final focalPointInCanvas = Offset(update.localFocalPoint.dx - _rectCanvas.left, update.localFocalPoint.dy - _rectCanvas.top);
          double left = update.localFocalPoint.dx - focalPointInCanvas.dx * scaleApply;
          double top = update.localFocalPoint.dy - focalPointInCanvas.dy * scaleApply;
          double width = _rectCanvas.width * scaleApply;
          double height = _rectCanvas.height * scaleApply;
          _rectCanvas = ui.Rect.fromLTWH(left, top, width, height);

          final focalPointInImage = Offset(update.localFocalPoint.dx - _rectImage.left, update.localFocalPoint.dy - _rectImage.top);
          left = update.localFocalPoint.dx - focalPointInImage.dx * scaleApply;
          top = update.localFocalPoint.dy - focalPointInImage.dy * scaleApply;
          width = _rectImage.width * scaleApply;
          height = _rectImage.height * scaleApply;
          _rectImage = ui.Rect.fromLTWH(left, top, width, height);

          dev.log("[GaImagePanZoomHandler] Zooming:", name: _devLogName);
          dev.log("                        _rectCanvas is (${_rectCanvas.left.toStringAsFixed(0)}, ${_rectCanvas.top.toStringAsFixed(0)}, ${_rectCanvas.right
              .toStringAsFixed(0)}, ${_rectCanvas.bottom.toStringAsFixed(0)}) ${_rectCanvas.width.toStringAsFixed(0)}x${_rectCanvas.height.toStringAsFixed(0)}", name: _devLogName);
          dev.log("                        _rectImage is (${_rectImage.left.toStringAsFixed(0)}, ${_rectImage.top.toStringAsFixed(0)}, ${_rectImage.right
              .toStringAsFixed(0)}, ${_rectImage.bottom.toStringAsFixed(0)}) ${_rectImage.width.toStringAsFixed(0)}x${_rectImage.height.toStringAsFixed(0)}", name: _devLogName);
          dev.log("                        _scale is ${_scale.toStringAsFixed(4)}", name: _devLogName);
        }
      },
    );
  }

  static Future<CalcuateImageRectResult> calcuateImageRect_fitToWidget({
    required Uint8List imgBytes,
    required GlobalKey<RectGetterState> fitToKey,
  }) async {
    late ui.Rect result;
    late double scaleInit;
    // Get source image size and ratio (width/height)
    //
    final completer = Completer<ui.Image>();
    final imageSource = Image.memory(imgBytes);
    imageSource.image.resolve(ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    }));
    ui.Image imageSourceInfo = await completer.future;
    dev.log("[GaImagePanZoomHandler] source image size is ${imageSourceInfo.width}x${imageSourceInfo.height}", name: _devLogName);
    final ratioImageSource = imageSourceInfo.width / imageSourceInfo.height;
    final rectInteractiveViewer = RectGetter.getRectFromKey(fitToKey);
    dev.log("[GaImagePanZoomHandler] InteractiveViewer size is ${rectInteractiveViewer!.width}x${rectInteractiveViewer.height}", name: _devLogName);
    final ratioInteractiveViewer = rectInteractiveViewer.width / rectInteractiveViewer.height;
    if (ratioImageSource < ratioInteractiveViewer) {
      dev.log("[GaImagePanZoomHandler] ratioImageSource < ratioInteractiveViewer: ( ${ratioImageSource.toStringAsFixed(1)} < ${ratioInteractiveViewer
          .toStringAsFixed(1)} )", name: _devLogName);
      // The source image is more narrow than interactiveViewer
      // We should take fill height as initial _rectImage.bottom
      scaleInit = rectInteractiveViewer.height / imageSourceInfo.height;
      final imageWidth = imageSourceInfo.width * scaleInit;
      final x = (rectInteractiveViewer.width - imageWidth) / 2;
      result = ui.Rect.fromLTRB(x, 0, x + imageWidth, rectInteractiveViewer.bottom);
    } else if (ratioImageSource > ratioInteractiveViewer) {
      dev.log("[GaImagePanZoomHandler] ratioImageSource > ratioInteractiveViewer: ( ${ratioImageSource.toStringAsFixed(1)} > ${ratioInteractiveViewer
          .toStringAsFixed(1)} )", name: _devLogName);
      // The source image is wide than interactiveViewer
      // We should take fill width as initial _rectImage.right
      scaleInit = rectInteractiveViewer.width / imageSourceInfo.width;
      final imageHeight = imageSourceInfo.height * scaleInit;
      final y = (rectInteractiveViewer.height - imageHeight) / 2;
      result = ui.Rect.fromLTRB(0, y, rectInteractiveViewer.width, y + imageHeight);
    } else {
      dev.log("[GaImagePanZoomHandler] ratioImageSource == ratioInteractiveViewer: ( ${ratioImageSource.toStringAsFixed(1)} == ${ratioInteractiveViewer
          .toStringAsFixed(1)} )", name: _devLogName);
      scaleInit = rectInteractiveViewer.width / imageSourceInfo.width;
      result = ui.Rect.fromLTRB(0, 0, rectInteractiveViewer.width, rectInteractiveViewer.height);
    }
    return CalcuateImageRectResult(rectResult: result, scale: scaleInit, rectCanvas: ui.Rect.fromLTWH(0, 0, rectInteractiveViewer.width, rectInteractiveViewer.height));
  }

  void onLoadImage(Uint8List imageBytes) {
    Future.delayed(const Duration(milliseconds: 120), () async {
      final ans = await calcuateImageRect_fitToWidget(imgBytes: imageBytes, fitToKey: _interactiveViewerKey);
      _rectImageInit = ans.rectResult;
      _scaleImage = ans.scale;
      _rectImage = _rectImageInit;
      _scale = 1.0;
      _rectCanvasInit = ans.rectCanvas;
      _rectCanvas = _rectCanvasInit;
      dev.log("[GaImagePanZoomHandler] onLoadImage:", name: _devLogName);
      dev.log("                        _rectCanvas is (${_rectCanvas.left.toStringAsFixed(0)}, ${_rectCanvas.top.toStringAsFixed(0)}, ${_rectCanvas.right
          .toStringAsFixed(0)}, ${_rectCanvas.bottom.toStringAsFixed(0)}) ${_rectCanvas.width.toStringAsFixed(0)}x${_rectCanvas.height.toStringAsFixed(0)}", name: _devLogName);
      dev.log("                        _rectImage is (${_rectImage.left.toStringAsFixed(0)}, ${_rectImage.top.toStringAsFixed(0)}, ${_rectImage.right
          .toStringAsFixed(0)}, ${_rectImage.bottom.toStringAsFixed(0)}) ${_rectImage.width.toStringAsFixed(0)}x${_rectImage.height.toStringAsFixed(0)}", name: _devLogName);
      dev.log("                        _scaleImage is ${_scaleImage.toStringAsFixed(4)}", name: _devLogName);
      dev.log("                        _scale is ${_scale.toStringAsFixed(4)}", name: _devLogName);
    });
  }


  ui.Rect getCropRectByFrame() {
    final l = (_rectImageInit.left - _rectImage.left) / _scale / _scaleImage;
    final t = (_rectImageInit.top - _rectImage.top) / _scale / _scaleImage;
    final w = _rectImageInit.width / _scale / _scaleImage;
    final h = _rectImageInit.height / _scale / _scaleImage;
    final result = ui.Rect.fromLTWH(l, t, w, h);
    dev.log("[GaImagePanZoomHandler] getCropRectByFrame (${result.left.toStringAsFixed(0)},${result.top.toStringAsFixed(0)},${result.right.toStringAsFixed(0)},${result.bottom.toStringAsFixed(0)}) ${result.width.toStringAsFixed(0)}x${result.height.toStringAsFixed(0)}", name: _devLogName);
    return result;
  }
}