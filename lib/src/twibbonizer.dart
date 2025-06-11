import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'preview.dart';

class _RectClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(_RectClipper oldClipper) => false;
}

class Twibbonizer extends StatefulWidget {
  final String? titleAppbar;
  final String? imgAssets;
  final String? imgNetwork;

  const Twibbonizer({
    super.key,
    this.titleAppbar,
    this.imgAssets,
    this.imgNetwork,
  });

  @override
  State<Twibbonizer> createState() => _TwibbonizerState();
}

class _TwibbonizerState extends State<Twibbonizer> with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription>? cameras;
  int selectedCameraIndex = 1;
  bool flashMode = false;

  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 3.0;

  double? _aspectRatio = 1.0; //3 / 4;
  String _selectedRatio = '1:1';
  double _scale = 1.0;

  final Map<String, double?> _aspectRatioOptions = {
    '1:1': 1.0,
    '3:4': 3 / 4,
    '9:16': 9 / 16,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      if (mounted) {
        setState(() {});
        _initializeCamera();
      }
    } catch (e) {
      print("Error fetching cameras: $e");
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) {
      showInSnackBar('No camera found.');
      return;
    }

    final previousController = controller;
    final cameraController = CameraController(
      cameras![selectedCameraIndex],
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );

    await previousController?.dispose();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        print('Camera error: ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      _minAvailableZoom = await cameraController.getMinZoomLevel();
      _maxAvailableZoom = await cameraController.getMaxZoomLevel();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
      showInSnackBar('Error initializing camera');
    }
  }

  void _changeAspect(String ratioKey) {
    setState(() {
      _selectedRatio = ratioKey;
      _aspectRatio = _aspectRatioOptions[ratioKey];
      switch (ratioKey) {
        case '1:1':
          _scale = 1.4;
          break;
        case '3:4':
          _scale = 1.2;
          break;
        case '9:16':
          _scale = 1.0;
          break;
        default:
          _scale = 1.0;
          break;
      }
    });
  }

  Future<void> _onSwitchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    selectedCameraIndex = selectedCameraIndex == 1 ? 0 : 1;
    await _initializeCamera();
  }

  Future<void> _onTakePicture() async {
    if (flashMode) {
      await controller?.setFlashMode(FlashMode.always);
    } else {
      await controller?.setFlashMode(FlashMode.off);
    }

    try {
      final xfile = await controller!.takePicture();
      if (mounted && xfile != null) {
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => Preview(
              imgAsset: widget.imgAssets ?? "",
              imgNetwork: widget.imgNetwork ?? "",
              self: xfile.path,
              defaultScale: _scale,
              aspectRatio: _aspectRatio,
              isCamera: selectedCameraIndex == 1 ? true : false,
            ),
          ),
        )
            .then(
          (value) {
            Navigator.of(context).pop();
          },
        );
      }
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  void _onFlashCamera() async {
    flashMode = !flashMode;
    await controller
        ?.setFlashMode(flashMode ? FlashMode.always : FlashMode.off);
    setState(() {});
  }

  void _onBack() async {
    Navigator.pop(context);
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _slideZoom() {
    return Slider(
      value: _currentZoomLevel,
      min: _minAvailableZoom,
      max: _maxAvailableZoom,
      activeColor: Colors.white,
      inactiveColor: Colors.white30,
      onChanged: (value) async {
        setState(() {
          _currentZoomLevel = value;
        });
        await controller?.setZoomLevel(value);
      },
    );
  }

  Widget _cameraIcon(IconData icon, VoidCallback onTap, {double size = 40}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: size / 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    Widget imageWidget;
    if (widget.imgAssets != null && widget.imgAssets!.isNotEmpty) {
      imageWidget = Center(
        child: Image.asset(
          widget.imgAssets!,
        ),
      );
    } else if (widget.imgNetwork != null && widget.imgNetwork!.isNotEmpty) {
      imageWidget = Center(
        child: CachedNetworkImage(
          placeholder: (context, url) => const CircularProgressIndicator(),
          imageUrl: widget.imgNetwork!,
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    } else {
      imageWidget = const Icon(Icons.image_not_supported, size: 50);
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double previewHeight = screenWidth / (_aspectRatio ?? 3 / 4);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.titleAppbar ?? "Twibbon_mrh"),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ClipRect(
                child: SizedBox(
                  width: screenWidth,
                  height: previewHeight,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(
                        Platform.isAndroid && selectedCameraIndex == 1
                            ? math.pi
                            : 0,
                      ),
                      child: Transform.scale(
                        scale: _scale,
                        child: SizedBox(
                          width: controller!.value.previewSize!.height,
                          height: controller!.value.previewSize!.width,
                          child: CameraPreview(controller!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            imageWidget,
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: _aspectRatioOptions.keys.map((ratio) {
                      return ElevatedButton(
                        onPressed: () => _changeAspect(ratio),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedRatio == ratio
                              ? Colors.redAccent
                              : Colors.white24,
                        ),
                        child: Text(
                          ratio,
                          style: TextStyle(
                              color: _selectedRatio == ratio
                                  ? Colors.white
                                  : Colors.white70),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedCameraIndex == 0) _slideZoom(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        selectedCameraIndex == 1
                            ? _cameraIcon(Icons.arrow_back, _onBack)
                            : _cameraIcon(Icons.flash_on, _onFlashCamera),
                        _cameraIcon(Icons.camera_alt, _onTakePicture, size: 80),
                        _cameraIcon(Icons.flip_camera_ios, _onSwitchCamera),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
