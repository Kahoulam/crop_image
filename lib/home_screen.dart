import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'handler.dart';

const landscapeA6Size = Size(1825, 1311);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.size = landscapeA6Size, this.onFinish});

  final Size size;
  final ValueChanged<Uint8List?>? onFinish;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with GaImagePanZoomHandler {
  Uint8List? _imageBytes;
  Uint8List? _frameBytes;
  bool _loading = false;

  Future<Uint8List?> _crop() async {
    final image = await decodeImageFromList(_imageBytes!);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final src = getCropRectByFrame();
    final Rect dst = Rect.fromLTWH(0, 0, widget.size.width, widget.size.height);

    canvas.drawImageRect(image, src, dst, Paint());

    if (_frameBytes != null) {
      final frame = await decodeImageFromList(_frameBytes!);
      canvas.drawImage(frame, Offset.zero, Paint());
    }

    final picture = recorder.endRecording();
    return picture.toImage(dst.width.toInt(), dst.height.toInt()).then((value) => value.toBytes());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final previewRatio = constraints.maxWidth / widget.size.width;
      final scopeSize = Size(constraints.maxWidth, widget.size.height * previewRatio);

      return Scaffold(
        appBar: AppBar(title: const Text('照片編輯'), actions: [
          TextButton(
            onPressed: () async {
              setState(() => _loading = true);
              Future<Uint8List?> crop(_) async => _crop();
              _imageBytes = await compute(crop, null);
              widget.onFinish?.call(_imageBytes);
              setState(() => _loading = false);
            },
            child: const Text('完成'),
          ),
        ]),
        body: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_imageBytes != null)
                Positioned.fill(
                  child: buildInteractiveViewer(
                    minScale: 1.0,
                    child: Image.memory(_imageBytes!),
                  ),
                ),
              IgnorePointer(
                child: Column(
                  children: [
                    Expanded(child: Container(color: Colors.black26)),
                    if (_imageBytes != null) SizedBox.fromSize(size: scopeSize),
                    Expanded(child: Container(color: Colors.black26)),
                  ],
                ),
              ),
              if (_frameBytes != null) IgnorePointer(child: Image.memory(_frameBytes!)),
              if (_loading) const CircularProgressIndicator(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            _imageBytes = await const NetworkImage("https://i.ibb.co/HqCGHKh/568500.jpg")
                .info()
                .then((value) => value.image.toBytes());
            onLoadImage(_imageBytes!);
            setState(() {});
          },
          child: const Icon(Icons.refresh),
        ),
      );
    });
  }
}

extension UiImageExtension on ui.Image {
  Future<Uint8List?> toBytes([ImageByteFormat format = ImageByteFormat.png]) => toByteData(format: format).then((value) => value?.buffer.asUint8List());
}

extension ImageProviderExtension on ImageProvider {
  Future<ImageInfo> info() async {
    final completer = Completer<ImageInfo>();
    final stream = resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((ImageInfo info, bool _) => completer.complete(info));

    stream.addListener(listener);
    final value = await completer.future;
    stream.removeListener(listener);

    return value;
  }
}
