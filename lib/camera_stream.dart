import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart'; // For image manipulation

class CameraStreamWidget extends StatefulWidget {
  final Function(String) onTextRecognized;

  const CameraStreamWidget({super.key, required this.onTextRecognized});

  @override
  _CameraStreamWidgetState createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> {
  CameraController? _controller;
  late Future<void> _cameraInitialization;
  bool isProcessing = false;
  late Size _screenSize;
  final GlobalKey _cameraPreviewKey = GlobalKey();
  List<String> recognizedTextList = [];
  int _frameCounter = 0;

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

    _controller?.startImageStream((CameraImage cameraImage) {
      _processFrame(cameraImage); // Process each frame from the stream
    });
  }

  Future<void> _processFrame(CameraImage cameraImage) async {
    if (_frameCounter % 5 == 0) {
      // Skip frames (process every 3rd frame)
      _frameCounter++;
      return;
    }

    _frameCounter++;

    // Crop and pass to ML Kit for recognition
    if (cameraImage != null) {
      final capturedImage = await processCameraImage(cameraImage);

      final overlayRect = _getOverlayRect(_screenSize);

      // Crop the captured image using the overlay's dimensions
      //final croppedImage = _cropImage(capturedImage, overlayRect);
      final croppedImage =
          await _cropAndRotateImage(capturedImage, overlayRect);

      final xfileImage = await convertImageToXFile(croppedImage!, "ocr-test");
      print("cropped image path:::${xfileImage.path}");
      await _recognizeText(xfileImage);

      // Convert cropped image to byte array
      final byteArray = _imageToByteArray(croppedImage);
      print("BYTE ARAYY:::${byteArray}");

      // Perform Text Recognition

      // Handle the recognized text
      // widget.onTextRecognized(recognizedText.text);
    }
  }

  Future<img.Image> processCameraImage(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;
    final Uint8List yBuffer = image.planes[0].bytes;
    final Uint8List uBuffer = image.planes[1].bytes;
    final Uint8List vBuffer = image.planes[2].bytes;

    // Create an empty RGB buffer
    Uint8List rgbBuffer = Uint8List(width * height * 3);

    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        int yIndex = i * width + j;
        int uvIndex = (i ~/ 2) * (width ~/ 2) + (j ~/ 2);

        int y = yBuffer[yIndex];
        int u = uBuffer[uvIndex];
        int v = vBuffer[uvIndex];

        int r = (y + (1.370705 * (v - 128))).toInt();
        int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).toInt();
        int b = (y + (1.732446 * (u - 128))).toInt();

        int rgbIndex = yIndex * 3;
        rgbBuffer[rgbIndex] = r.clamp(0, 255);
        rgbBuffer[rgbIndex + 1] = g.clamp(0, 255);
        rgbBuffer[rgbIndex + 2] = b.clamp(0, 255);
      }
    }

    // Create the image from the RGB buffer
    img.Image decodedImage = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBuffer.buffer.asByteData().buffer);
    img.Image rotatedImage = img.copyRotate(decodedImage, angle: 270);

    return rotatedImage;
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
        await _recognizeText(xfileImage);

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
      recognizedTextList.add(text);
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

  // Building UI
  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
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
            ],
          );
        }
      },
    );
  }
}
