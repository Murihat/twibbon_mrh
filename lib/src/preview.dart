import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class Preview extends StatefulWidget {
  final String? imgAsset, imgNetwork, self;
  final double? defaultScale;
  final bool? isCamera;
  final double? aspectRatio;

  const Preview({
    Key? key,
    this.imgAsset,
    this.imgNetwork,
    this.self,
    this.defaultScale,
    this.isCamera,
    this.aspectRatio,
  }) : super(key: key);

  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  final ScreenshotController screenshotController = ScreenshotController();
  Offset offset = Offset.zero;
  double scale = 1.0;
  double rotation = 0.0;

  @override
  void initState() {
    super.initState();
    scale = widget.defaultScale ?? 1.0;
  }

  Future<void> _onDownload() async {
    final now = DateTime.now();
    final fileName = "${now.millisecondsSinceEpoch}.png";
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final image = await screenshotController.capture();
    if (image != null) {
      final file = await File(filePath).create();
      await file.writeAsBytes(image);
      await GallerySaver.saveImage(file.path, albumName: 'MyApp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery!')),
        );
      }
    }
  }

  Future<void> _onShare() async {
    final now = DateTime.now();
    final fileName = "${now.millisecondsSinceEpoch}.png";
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    final image = await screenshotController.capture();
    if (image != null) {
      final file = await File(filePath).create();
      await file.writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'Check out my creation!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final previewHeight =
        widget.aspectRatio != null ? screenWidth / widget.aspectRatio! : null;

    // Determine overlay image
    Widget overlayWidget;
    if (widget.imgAsset != null && widget.imgAsset!.isNotEmpty) {
      overlayWidget = Image.asset(widget.imgAsset!, fit: BoxFit.cover);
    } else if (widget.imgNetwork != null && widget.imgNetwork!.isNotEmpty) {
      overlayWidget = CachedNetworkImage(
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        imageUrl: widget.imgNetwork!,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) =>
            const Icon(Icons.error, color: Colors.red),
      );
    } else {
      overlayWidget = const Icon(Icons.image_not_supported, size: 50);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main interactive area
            Positioned.fill(
              child: GestureDetector(
                onScaleUpdate: (details) {
                  setState(() {
                    offset += details.focalPointDelta;
                    scale = (widget.defaultScale ?? 1.0) *
                        details.scale.clamp(0.5, 3.0);
                    rotation += details.rotation;
                  });
                },
                child: Screenshot(
                  controller: screenshotController,
                  child: Stack(
                    children: [
                      // Camera image preview with aspect ratio crop
                      Center(
                        child: AspectRatio(
                          aspectRatio: widget.aspectRatio ?? 1.0,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..translate(offset.dx, offset.dy)
                                    ..scale(scale)
                                    ..rotateZ(rotation)
                                    ..rotateY(
                                        widget.isCamera == true ? math.pi : 0),
                                  child: SizedBox(
                                    width: screenWidth,
                                    height: previewHeight,
                                    child: Image.file(
                                      File(widget.self!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Overlay image centered on top
                      Center(child: overlayWidget),
                    ],
                  ),
                ),
              ),
            ),

            // Close button
            Positioned(
              top: 20,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
            ),

            // Action buttons
            Positioned(
              bottom: 30,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(Icons.download, _onDownload,
                      heroTag: 'download'),
                  _actionButton(Icons.rotate_right, () {
                    setState(() {
                      rotation += math.pi / 4;
                    });
                  }, heroTag: 'rotate'),
                  _actionButton(Icons.share, _onShare, heroTag: 'share'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onPressed,
      {required String heroTag}) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.white,
      heroTag: heroTag,
      onPressed: onPressed,
      child: Icon(icon, color: Colors.black),
    );
  }
}
