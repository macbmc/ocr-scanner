import 'package:flutter/material.dart';
import 'package:ocr_demo/camera_stream_isolate.dart';
import 'package:ocr_demo/ocr_d.dart';
import 'package:ocr_demo/scalable_ocr.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Scalable OCR',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MenuScreen());
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Center(
        child: Column(
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CameraStreamIsolateWidget(
                              onTextRecognized: (text) {})));
                },
                child: Text("LIVE OCR")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CameraCaptureWidget(
                              onTextRecognized: (text) {})));
                },
                child: Text("Capture OCR")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              MyHomePage(title: "Scalable OCR")));
                },
                child: Text("SCALABLE Ocr"))
          ],
        ),
      )),
    );
  }
}
