import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart'; // For image manipulation

class CameraCaptureWidget extends StatefulWidget {
  final Function(String) onTextRecognized;

  const CameraCaptureWidget({super.key, required this.onTextRecognized});

  @override
  _CameraCaptureWidgetState createState() => _CameraCaptureWidgetState();
}

class _CameraCaptureWidgetState extends State<CameraCaptureWidget> {
  CameraController? _controller;
  late Future<void> _cameraInitialization;
  bool isProcessing = false;
  final GlobalKey _cameraPreviewKey = GlobalKey(); // Key for the CameraPreview
  String resultText = "";

  @override
  void initState() {
    super.initState();
    _cameraInitialization = _initializeCamera();
  }

  // Camera Initialization
  Future<void> _initializeCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    final cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller?.initialize();
    await _controller?.setFlashMode(FlashMode.off);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Function to calculate overlay rect based on screen size
  Rect _getOverlayRect(Size screenSize) {
    // Get the screen size for the current context

    // Storing the screen size

    // 15% from the left, 40% from the top, 70% width, and 10% height
    final overlayLeft = screenSize.width * 0.15;
    final overlayTop = screenSize.height * 0.4;
    final overlayWidth = screenSize.width * 0.7;
    final overlayHeight = screenSize.height * 0.1;

    return Rect.fromLTWH(overlayLeft, overlayTop, overlayWidth, overlayHeight);
  }

  // Capture the Camera Image and Process it
  Future<void> _captureAndRecognizeText(BuildContext context) async {
    final screenSize = MediaQuery.of(context).size;
    if (isProcessing) {
      print("IN CAMERA PROCESSSS");
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // Capture image from camera stream
      final cameraImage = await _controller?.takePicture();
      if (cameraImage != null) {
        final capturedImage =
            img.decodeImage(File(cameraImage.path).readAsBytesSync())!;
        final overlayRect = _getOverlayRect(screenSize);

        // Crop the captured image using the overlay's dimensions
        //final croppedImage = _cropImage(capturedImage, overlayRect);
        final croppedImage =
            await _cropAndRotateImage(capturedImage, overlayRect);

        final xfileImage = await convertImageToXFile(croppedImage!, "ocr-test");
        print("cropped image path:::${xfileImage.path}");
        final string = await _recognizeText(xfileImage);
        setState(() {
          resultText = string;
        });

        // Convert cropped image to byte array
        final byteArray = _imageToByteArray(croppedImage);
        print("BYTE ARAYY:::${byteArray}");

        // Perform Text Recognition

        // Handle the recognized text
        // widget.onTextRecognized(recognizedText.text);
      }
    } catch (e) {
      print("Error in capturing and recognizing text: $e");
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<XFile> convertImageToXFile(img.Image image, String fileName) async {
    // Encode the image to PNG (or JPEG as needed)
    Uint8List encodedImage = Uint8List.fromList(img.encodePng(image));

    // Get a temporary directory to save the file
    Directory tempDir = await getTemporaryDirectory();

    // Create a file path
    String filePath = '${tempDir.path}/$fileName.png';

    // Write the encoded image to the file
    File file = File(filePath);
    await file.writeAsBytes(encodedImage);

    // Create and return the XFile
    return XFile(filePath);
  }

  Future<String> _recognizeText(XFile image) async {
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      final String text = recognizedText.text;
      print("GL TEXT ${text}");
      await textRecognizer.close();
      return text;
    } on Exception {
      return "Try Again";
    }
  }

  Uint8List _imageToByteArray(img.Image image) {
    return Uint8List.fromList(img.encodeJpg(image));
  }

  Future<img.Image?> _cropAndRotateImage(
      img.Image image, Rect _selectionRect) async {
    try {
      if (image != null) {
        final RenderBox renderBox =
            _cameraPreviewKey.currentContext!.findRenderObject()! as RenderBox;
        final widgetWidth = renderBox.size.width;
        final widgetHeight = renderBox.size.height;

        final imageAspectRatio = image.width / image.height;
        final widgetAspectRatio = widgetWidth / widgetHeight;

        double effectiveImageWidth;
        double effectiveImageHeight;
        double offsetX = 0;
        double offsetY = 0;

        if (widgetAspectRatio > imageAspectRatio) {
          effectiveImageWidth = widgetHeight * imageAspectRatio;
          effectiveImageHeight = widgetHeight;
          offsetX = (widgetWidth - effectiveImageWidth) / 2;
        } else {
          effectiveImageWidth = widgetWidth;
          effectiveImageHeight = widgetWidth / imageAspectRatio;
          offsetY = (widgetHeight - effectiveImageHeight) / 2;
        }

        final scaleX = image.width / effectiveImageWidth;
        final scaleY = image.height / effectiveImageHeight;

        final cropX = ((_selectionRect.left - offsetX) * scaleX)
            .clamp(0, image.width)
            .toInt();
        final cropY = ((_selectionRect.top - offsetY) * scaleY)
            .clamp(0, image.height)
            .toInt();
        final cropWidth = (_selectionRect.width * scaleX)
            .clamp(1, (image.width - cropX).toDouble())
            .toInt();

        final cropHeight = (_selectionRect.height * scaleY)
            .clamp(1, (image.height - cropY).toDouble())
            .toInt();

        final croppedImage = img.copyCrop(
          image,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        );

        return croppedImage;
      }
    } catch (err) {
      return null;
    }
    return null;
  }

  // Function to crop the image based on the overlay rect
  img.Image? _cropImage(img.Image image, Rect overlayRect) {
    try {
      final _screenSize = MediaQuery.of(context).size;
      final double scaleX = image.width / _screenSize.width;
      final double scaleY = image.height / _screenSize.height;

      // Convert the overlay coordinates to the image's scale
      final int left = (overlayRect.left * scaleX).toInt();
      final int top = (overlayRect.top * scaleY).toInt();
      final int right = (overlayRect.right * scaleX).toInt();
      final int bottom = (overlayRect.bottom * scaleY).toInt();

      // Ensure the crop area does not exceed the image bounds using clamping
      final int cropLeft = left.clamp(0, image.width);
      final int cropTop = top.clamp(0, image.height);
      final int cropWidth = (right - cropLeft).clamp(0, image.width - cropLeft);
      final int cropHeight =
          (bottom - cropTop).clamp(0, image.height - cropTop);

      return img.copyCrop(image,
          x: cropLeft, y: cropTop, width: cropWidth, height: cropHeight);
    } on Exception catch (e) {
      print(e);
      return null;
    }
  }

  // Building UI
  @override
  Widget build(BuildContext context) {
    final _screenSize = MediaQuery.of(context).size;
    return FutureBuilder(
      future: _cameraInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Stack(
            children: [
              CameraPreview(
                _controller!,
                key: _cameraPreviewKey,
              ),
              Positioned(
                top: _screenSize.height * 0.4,
                // Position overlay based on calculated top
                left: _screenSize.width * 0.15,
                // Position overlay based on calculated left
                child: Container(
                  width: _screenSize.width * 0.7,
                  // Overlay width (70% of screen width)
                  height: _screenSize.height * 0.1,
                  // Overlay height (10% of screen height)
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                right: 30,
                child: FloatingActionButton(
                  onPressed: () async {
                    await _captureAndRecognizeText(context);
                  },
                  child: const Icon(Icons.camera_alt),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  resultText,
                  style: TextStyle(fontSize: 10),
                ),
              )
            ],
          );
        }
      },
    );
  }
}
/*

*/
