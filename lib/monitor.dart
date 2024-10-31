import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'dart:math' as math;

const List<String> YOLO_CLASSES = [
  'Cattle', 'Chicken', 'Goat', 'Goose', 'Horse',
  'Ostrich', 'Pig', 'Sheep', 'human'
];

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  _MonitorPageState createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Interpreter? _interpreter;
  List<Map<String, dynamic>>? _results;
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isModelLoading = false;
  bool _isProcessing = false;
  final List<AnimalRecord> _animalRecords = [];

  @override
  void initState() {
    super.initState();
    _loadModel();
    _fetchReportsFromFirestore();
  }

  Future<void> _loadModel() async {
    setState(() {
      _isModelLoading = true;
    });
    try {
      final modelDownloader = FirebaseModelDownloader.instance;
      final model = await modelDownloader.getModel(
        "apma",
        FirebaseModelDownloadType.localModel,
        FirebaseModelDownloadConditions(
          iosAllowsCellularAccess: true,
          iosAllowsBackgroundDownloading: true,
          androidChargingRequired: false,
          androidWifiRequired: false,
        ),
      );

      final interpreterOptions = InterpreterOptions()
        ..threads = 4
        ..useNnapi = true;
      
      _interpreter = Interpreter.fromFile(
        model.file,
        options: interpreterOptions,
      );
      
      logger.i('Model loaded successfully from Firebase ML');
    } catch (e) {
      logger.e('Error loading model: $e');
      _showError('Failed to load model: ${e.toString()}');
    } finally {
      setState(() {
        _isModelLoading = false;
      });
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    final resizedImage = img.copyResize(
      image,
      width: 640,
      height: 640,
      interpolation: img.Interpolation.linear,
    );

    var inputArray = List.generate(
      1,
      (b) => List.generate(
        640,
        (y) => List.generate(
          640,
          (x) => List<double>.filled(3, 0),
        ),
      ),
    );

    for (var y = 0; y < resizedImage.height; y++) {
      for (var x = 0; x < resizedImage.width; x++) {
        final pixel = resizedImage.getPixel(x, y);
        inputArray[0][y][x][0] = img.getRed(pixel) / 255.0;
        inputArray[0][y][x][1] = img.getGreen(pixel) / 255.0;
        inputArray[0][y][x][2] = img.getBlue(pixel) / 255.0;
      }
    }

    return inputArray;
  }

  Future<void> _detectObjects() async {
    if (_interpreter == null || _image == null) {
      _showError('Model or image not loaded');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final input = await _preprocessImage(_image!);

      var outputShape = [1, 13, 8400];
      var outputs = List.generate(
        outputShape[0],
        (i) => List.generate(
          outputShape[1],
          (j) => List<double>.filled(outputShape[2], 0),
        ),
      );

      _interpreter!.run(input, outputs);

      final imageInput = img.decodeImage(await _image!.readAsBytes());
      if (imageInput == null) throw Exception('Failed to decode image');

      var transposedOutputs = List.generate(
        8400,
        (i) => List.generate(
          13,
          (j) => outputs[0][j][i],
        ),
      );

      setState(() {
        _results = _processDetections(
          transposedOutputs,
          imageInput.width,
          imageInput.height,
        );
      });

    } catch (e) {
      logger.e('Detection error: $e');
      _showError('Detection failed: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  List<Map<String, dynamic>> _processDetections(
    List<List<double>> outputs,
    int originalWidth,
    int originalHeight,
  ) {
    const confidenceThreshold = 0.25;
    const nmsThreshold = 0.45;
    List<Map<String, dynamic>> detections = [];

    for (var i = 0; i < outputs.length; i++) {
      var output = outputs[i];
      var maxScore = 0.0;
      var maxScoreIndex = 0;

      for (var j = 4; j < output.length; j++) {
        if (output[j] > maxScore) {
          maxScore = output[j];
          maxScoreIndex = j - 4;
        }
      }

      if (maxScore > confidenceThreshold) {
        double x = output[0];
        double y = output[1];
        double w = output[2];
        double h = output[3];

        double x1 = (x - w/2) * originalWidth;
        double y1 = (y - h/2) * originalHeight;
        double x2 = (x + w/2) * originalWidth;
        double y2 = (y + h/2) * originalHeight;

        x1 = x1.clamp(0.0, originalWidth.toDouble());
        y1 = y1.clamp(0.0, originalHeight.toDouble());
        x2 = x2.clamp(0.0, originalWidth.toDouble());
        y2 = y2.clamp(0.0, originalHeight.toDouble());

        final species = YOLO_CLASSES[maxScoreIndex];
        final id = AnimalTrackingService.generateAnimalId(species);
        final healthStatus = AnimalTrackingService.assessHealth({
          'species': species,
          'confidence': maxScore,
          'box': {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
          },
        });

        final record = AnimalRecord(
          id: id,
          species: species,
          detectedAt: DateTime.now(),
          confidence: maxScore,
          healthStatus: healthStatus,
          notes: '',
          boundingBox: {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
          },
        );

        _animalRecords.add(record);
        _saveReportToFirestore(record);  // Save report to Firestore

        detections.add({
          'id': id,
          'box': {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
          },
          'confidence': maxScore,
          'class': maxScoreIndex,
          'class_name': species,
          'health_status': healthStatus,
        });
      }
    }

    return _applyNMS(detections, nmsThreshold);
  }

  Future<void> _saveReportToFirestore(AnimalRecord record) async {
    try {
      await _firestore.collection('animalReports').add(record.toMap());
      logger.i("Report saved to Firestore");
    } catch (e) {
      logger.e("Failed to save report: $e");
      _showError("Failed to save report: ${e.toString()}");
    }
  }

  Future<void> _fetchReportsFromFirestore() async {
    try {
      final querySnapshot = await _firestore.collection('animalReports').get();
      final reports = querySnapshot.docs.map((doc) {
        return AnimalRecord.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();

      setState(() {
        _animalRecords.addAll(reports);
      });
    } catch (e) {
      logger.e("Failed to fetch reports: $e");
      _showError("Failed to fetch reports: ${e.toString()}");
    }
  }

  List<Map<String, dynamic>> _applyNMS(
    List<Map<String, dynamic>> detections,
    double nmsThreshold
  ) {
    detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    List<Map<String, dynamic>> selected = [];

    for (var i = 0; i < detections.length; i++) {
      bool keep = true;
      for (var s in selected) {
        if (s['class'] == detections[i]['class']) {
          double iou = _calculateIOU(detections[i]['box'], s['box']);
          if (iou > nmsThreshold) {
            keep = false;
            break;
          }
        }
      }
      if (keep) selected.add(detections[i]);
    }

    return selected;
  }

  double _calculateIOU(Map<String, dynamic> box1, Map<String, dynamic> box2) {
    double intersectionX1 = math.max(box1['x1'] as double, box2['x1'] as double);
    double intersectionY1 = math.max(box1['y1'] as double, box2['y1'] as double);
    double intersectionX2 = math.min(box1['x2'] as double, box2['x2'] as double);
    double intersectionY2 = math.min(box1['y2'] as double, box2['y2'] as double);

    if (intersectionX2 < intersectionX1 || intersectionY2 < intersectionY1) {
      return 0.0;
    }

    double intersection = (intersectionX2 - intersectionX1) * 
                         (intersectionY2 - intersectionY1);
    
    double box1Area = ((box1['x2'] as double) - (box1['x1'] as double)) * 
                     ((box1['y2'] as double) - (box1['y1'] as double));
    double box2Area = ((box2['x2'] as double) - (box2['x1'] as double)) * 
                     ((box2['y2'] as double) - (box2['y1'] as double));
    
    double union = box1Area + box2Area - intersection;

    return intersection / union;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _results = null;
        });
        await _detectObjects();
      }
    } catch (e) {
      logger.e('Error picking image: $e');
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
      )
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Detection'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isModelLoading
                ? const Center(child: CircularProgressIndicator())
                : _image == null
                    ? const Center(child: Text('No image selected'))
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_image!, fit: BoxFit.contain),
                          if (_isProcessing)
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                          if (_results != null && !_isProcessing)
                            CustomPaint(
                              painter: BoundingBoxPainter(
                                _results!,
                                _image!.readAsBytesSync(),
                              ),
                              child: Container(),
                            ),
                        ],
                      ),
          ),
          if (_results != null && !_isProcessing)
            Container(
              height: 120,
              color: Colors.black87,
              child: ListView.builder(
                itemCount: _results!.length,
                itemBuilder: (context, index) {
                  final detection = _results![index];
                  return ListTile(
                    textColor: Colors.white,
                    leading: Icon(
                      Icons.pets,
                      color: Colors.white,
                    ),
                    title: Text(detection['class_name']),
                    subtitle: Text(
                      'Confidence: ${(detection['confidence'] * 100).toStringAsFixed(1)}%\nHealth: ${detection['health_status']}',
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isModelLoading || _isProcessing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                ElevatedButton.icon(
                  onPressed: _isModelLoading || _isProcessing
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on InterpreterOptions {
  set useNnapi(bool useNnapi) {}
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Uint8List imageBytes;

  BoundingBoxPainter(this.detections, this.imageBytes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final image = img.decodeImage(imageBytes);
    if (image == null) return;

    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;

    final colors = {
      'Cattle': Colors.red,
      'Chicken': Colors.blue,
      'Goat': Colors.green,
      'Goose': Colors.orange,
      'Horse': Colors.purple,
      'Ostrich': Colors.yellow,
      'Pig': Colors.pink,
      'Sheep': Colors.cyan,
      'human': Colors.white,
    };

    for (final detection in detections) {
      final box = detection['box'];
      final className = detection['class_name'];
      
      paint.color = colors[className] ?? Colors.red;

      final rect = Rect.fromLTRB(
        box['x1'] * scaleX,
        box['y1'] * scaleY,
        box['x2'] * scaleX,
        box['y2'] * scaleY,
      );
      
      canvas.drawRect(rect, paint);

      final labelText = ' ${detection['class_name']} ${(detection['confidence'] * 100).toStringAsFixed(0)}% ';
      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          backgroundColor: colors[className] ?? Colors.red,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(box['x1'] * scaleX, box['y1'] * scaleY - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimalRecord {
  final String id;
  final String species;
  final DateTime detectedAt;
  final double confidence;
  final String healthStatus;
  final String notes;
  final Map<String, double> boundingBox;

  AnimalRecord({
    required this.id,
    required this.species,
    required this.detectedAt,
    required this.confidence,
    required this.healthStatus,
    required this.notes,
    required this.boundingBox,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'species': species,
      'detectedAt': detectedAt.toIso8601String(),
      'confidence': confidence,
      'healthStatus': healthStatus,
      'notes': notes,
      'boundingBox': boundingBox,
    };
  }

  factory AnimalRecord.fromMap(Map<String, dynamic> map) {
    return AnimalRecord(
      id: map['id'] ?? 'unknown',
      species: map['species'] ?? 'unknown species',
      detectedAt: DateTime.tryParse(map['detectedAt'] ?? '') ?? DateTime.now(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      healthStatus: map['healthStatus'] ?? 'unknown',
      notes: map['notes'] ?? '',
      boundingBox: Map<String, double>.from(map['boundingBox'] ?? {}),
    );
  }
}

class AnimalTrackingService {
  static String generateAnimalId(String species) {
    return '${species}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String assessHealth(Map<String, dynamic> detectionData) {
    final confidence = detectionData['confidence'];
    return confidence > 0.6 ? 'Healthy' : 'At risk';
  }
}
