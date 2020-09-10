import 'package:camera/camera.dart';
import 'package:camera_ocr/src/scanner_utils.dart';
import 'package:camera_ocr/src/text_detector_painter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MaterialApp(
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CameraController _camera;
  bool _isDetecting = false;
  VisionText _textScanResults;
  CameraLensDirection _direction = CameraLensDirection.back;

  final TextRecognizer _textRecognizer =
      FirebaseVision.instance.textRecognizer();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final CameraDescription description =
        await ScannerUtils.getCamera(_direction);
    _camera = CameraController(description, ResolutionPreset.high,
        enableAudio: false);
    await _camera.initialize();
    _camera.startImageStream((image) {
      if (_isDetecting) return;
      setState(() {
        _isDetecting = true;
      });
      ScannerUtils.detect(
        image: image,
        detectInImage: _getDetectionMethod(),
        imageRotation: description.sensorOrientation,
      ).then((results) {
        setState(() {
          if (results != null) {
            setState(() {
              _textScanResults = results;
              _isDetecting = false;
            });
          }
        });
      });
    });
  }

  Future<VisionText> Function(FirebaseVisionImage image) _getDetectionMethod() {
    return _textRecognizer.processImage;
  }

  void closeCamera() async {
    await _camera.stopImageStream();
    setState(() {
      _isDetecting = false;
      _textScanResults = null;
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _camera == null
              ? Container(
                  color: Colors.black,
                )
              : Container(
                  height: MediaQuery.of(context).size.height - 150,
                  child: CameraPreview(_camera)),
          _buildResults(_textScanResults),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                    body: Container(
                        child: Center(
                  child: Text(_textScanResults.text),
                ))),
              ));
        },
        child: Icon(Icons.camera),
      ),
    );
  }

  Widget _buildResults(VisionText scanResults) {
    CustomPainter painter;
    if (scanResults != null) {
      final Size imageSize = Size(
        _camera.value.previewSize.height - 100,
        _camera.value.previewSize.width,
      );
      painter = TextDetectorPainter(imageSize, scanResults);
      //getWords(scanResults);

      return CustomPaint(
        painter: painter,
      );
    } else {
      return Container();
    }
  }
}
