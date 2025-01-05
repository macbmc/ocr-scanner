import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraWidget extends StatefulWidget {
  final int maxImages;
  final Function(List<File>) onCaptureComplete;

  const CameraWidget({
    super.key,
    required this.maxImages,
    required this.onCaptureComplete,
  });

  @override
  _CameraWidgetState createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  CameraController? _controller;
  final List<XFile> _capturedImages = [];
  late Future<void> _cameraInitialization;

  // Initialize the camera
  Future<void> _initializeCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    final cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller?.initialize();
  }

  // Capture image
  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Camera is not initialized.");
      return;
    }

    if (_controller!.value.isTakingPicture) {
      print("Camera is busy taking a picture.");
      return;
    }

    try {
      final image = await _controller?.takePicture();
      if (image != null) {
        setState(() {
          _capturedImages.add(image);
        });
      }
    } catch (e) {
      print("Error while capturing image: $e");
    }

    // Check if the max images are reached and complete the capture
    if (_capturedImages.length >= widget.maxImages) {
      widget.onCaptureComplete(
          _capturedImages.map((xFile) => File(xFile.path)).toList());
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraInitialization = _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _cameraInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error initializing camera: ${snapshot.error}'),
          );
        } else {
          return Stack(
            children: [
              CameraPreview(_controller!),
              Positioned(
                bottom: 16.0,
                right: 16.0,
                child: FloatingActionButton(
                  child: const Icon(Icons.camera_alt),
                  onPressed: () async {
                    // Ensure we don't try to capture an image while the camera is busy
                    if (_controller != null && _controller!.value.isInitialized) {
                      await _captureImage();
                    }
                  },
                ),
              ),
              _capturedImages.isNotEmpty
                  ? Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 100.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.file(
                          File(_capturedImages[index].path),
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              )
                  : const SizedBox(),
            ],
          );
        }
      },
    );
  }
}
