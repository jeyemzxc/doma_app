// lib/main.dart
// Camote Classifier App - Doma

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

List<CameraDescription> _cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera init error: $e');
  }
  runApp(const DomaApp());
}

// ============================================================================
// APP ROOT
// ============================================================================

class DomaApp extends StatelessWidget {
  const DomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doma - Camote Classifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.white,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

// ============================================================================
// CONSTANTS & DATA MODELS
// ============================================================================

class AppColors {
  static const primary = Color(0xFF00875A);
  static const primaryLight = Color(0xFFE8F5E9);
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const error = Color(0xFFDC2626);
}

class TimeFormatter {
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}min ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}

class CamoteVariety {
  final String name;
  final String commonName;
  final String scientificName;
  final String skinColor;
  final String fleshColor;
  final String shape;
  final String texture;
  final String imagePath;
  final String description;
  final List<String> benefits;
  final List<String> dishes;

  const CamoteVariety({
    required this.name,
    required this.commonName,
    required this.scientificName,
    required this.skinColor,
    required this.fleshColor,
    required this.shape,
    required this.texture,
    required this.imagePath,
    required this.description,
    required this.benefits,
    required this.dishes,
  });
}

const List<CamoteVariety> camoteVarieties = [
  CamoteVariety(
    name: 'Kadulaw',
    commonName: 'Orange Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Light orange to peach',
    fleshColor: 'Orange',
    shape: 'Elongated/Fusiform',
    texture: 'Smooth/Firm',
    imagePath: 'assets/images/orange_camote.jpg',
    description:
        'This camote has a light orange to peach skin with vibrant orange flesh. It is elongated and fusiform in shape with a smooth and firm texture, making it visually distinctive and easily recognizable.',
    benefits: [
      'Rich in beta-carotene for eye health',
      'High in antioxidants',
      'Supports immune system',
      'Good for skin and vision',
      'Contains vitamin A',
    ],
    dishes: [
      'Camote Cue',
      'Camote Fries',
      'Steamed Camote',
      'Ginataang Bilo-Bilo',
      'Sweet Potato Pie',
    ],
  ),
  CamoteVariety(
    name: 'Minamon',
    commonName: 'Yellow Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Yellow to tan',
    fleshColor: 'Yellow',
    shape: 'Bent/curved',
    texture: 'Lumpy/Gritty',
    imagePath: 'assets/images/yellow_camote.jpg',
    description:
        'This camote features a yellow to tan skin with bright yellow flesh throughout. Its bent, curved shape, and lumpy texture are characteristic features that distinguish it from other varieties.',
    benefits: [
      'Rich in complex carbohydrates',
      'Good source of fiber',
      'Contains minerals and potassium',
      'Provides sustained energy',
      'Supports digestive health',
    ],
    dishes: [
      'Camote Cue',
      'Nilupak',
      'Minatamis na Camote',
      'Nilagang Camote',
      'Camote Porridge',
    ],
  ),
  CamoteVariety(
    name: 'Tapol',
    commonName: 'White Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'White to cream',
    fleshColor: 'Purple',
    shape: 'Round/oblong',
    texture: 'Smooth/Hard',
    imagePath: 'assets/images/white_camote.jpg',
    description:
        'This camote has a white to cream-colored skin with striking and bright purple flesh inside. Its round or oblong shape and hard texture make it a unique variety with excellent visual contrast.',
    benefits: [
      'Mild and subtle flavor',
      'Easy to digest',
      'Contains manganese',
      'Good for bone health',
      'Low glycemic index',
    ],
    dishes: [
      'Turon na Camote',
      'White Camote Pastry',
      'Camote Pie',
      'Camote Halaya',
      'White Camote Dumplings',
    ],
  ),
  CamoteVariety(
    name: 'Kadabaw',
    commonName: 'Purple Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Purple to reddish',
    fleshColor: 'Yellow',
    shape: 'Irregular',
    texture: 'Rough',
    imagePath: 'assets/images/purple_camote.jpg',
    description:
        'This camote displays a distinctive purple to reddish skin with bright yellow flesh. Its irregular shape and rough texture give it a more rustic appearance, distinguishing it from other types.',
    benefits: [
      'High in anthocyanins (purple pigment)',
      'Powerful antioxidants',
      'Anti-inflammatory properties',
      'Supports brain health',
      'Reduces risk of chronic disease',
    ],
    dishes: [
      'Camote Mash',
      'Nilagang Camote',
      'Minatamis na Camote',
      'Camote Cue',
      'Boiled Camote',
    ],
  ),
];

class DetectionResult {
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  DetectionResult({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
    'className': className,
    'confidence': confidence,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory DetectionResult.fromJson(Map<String, dynamic> json) =>
      DetectionResult(
        className: json['className'],
        confidence: json['confidence'],
        x: json['x'],
        y: json['y'],
        width: json['width'],
        height: json['height'],
      );
}

class DetectionLog {
  final String id;
  final String imagePath;
  final List<DetectionResult> results;
  final DateTime timestamp;

  DetectionLog({
    required this.id,
    required this.imagePath,
    required this.results,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'results': results.map((r) => r.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory DetectionLog.fromJson(Map<String, dynamic> json) => DetectionLog(
    id: json['id'],
    imagePath: json['imagePath'],
    results: (json['results'] as List)
        .map((r) => DetectionResult.fromJson(r))
        .toList(),
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// ============================================================================
// DETECTION LOGGER SERVICE
// ============================================================================

class DetectionLogger {
  static const String _logsKey = 'detection_logs';

  static Future<void> saveLog(DetectionLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList(_logsKey) ?? [];
    logsJson.insert(0, jsonEncode(log.toJson()));
    await prefs.setStringList(_logsKey, logsJson);
  }

  static Future<List<DetectionLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList(_logsKey) ?? [];
    return logsJson
        .map((json) => DetectionLog.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> deleteLog(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList(_logsKey) ?? [];
    logsJson.removeWhere((json) {
      final log = DetectionLog.fromJson(jsonDecode(json));
      return log.id == id;
    });
    await prefs.setStringList(_logsKey, logsJson);
  }

  static Future<void> clearAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsKey);
  }
}

// ============================================================================
// TFLITE CLASSIFIER SERVICE
// ============================================================================

class CamoteClassifier {
  Interpreter? _interpreter;
  static const int inputSize = 640;

  // FIX: Raised thresholds to prevent false positives on non-camote images.
  // confidenceThreshold: pre-NMS gate — anchors below this are discarded early.
  // displayThreshold: final gate — only detections above this are shown/saved.
  static const double confidenceThreshold = 0.50;
  static const double displayThreshold = 0.75;

  static const double iouThreshold = 0.45;
  static const List<String> labels = ['kadabaw', 'kadulaw', 'minamon', 'tapol'];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      debugPrint('[Doma] Model loaded successfully');
    } catch (e) {
      debugPrint('Error loading model: $e');
      rethrow;
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  Future<List<DetectionResult>> detectFromFile(File imageFile) async {
    if (_interpreter == null) await loadModel();
    if (_interpreter == null) return [];
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) return [];
    return _runInference(image);
  }

  List<DetectionResult> _runInference(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final input = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }
    final output = List.generate(
      1,
      (_) => List.generate(8, (_) => List<double>.filled(8400, 0.0)),
    );
    _interpreter!.run(input.reshape([1, inputSize, inputSize, 3]), output);
    final detections = <DetectionResult>[];
    final outputData = output[0];
    for (int i = 0; i < 8400; i++) {
      double maxScore = 0;
      int maxClassIdx = 0;
      for (int c = 0; c < 4; c++) {
        final score = outputData[4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          maxClassIdx = c;
        }
      }
      if (maxScore >= confidenceThreshold) {
        final x = outputData[0][i];
        final y = outputData[1][i];
        final w = outputData[2][i];
        final h = outputData[3][i];

        // FIX: Reject detections with unrealistically tiny or huge bounding
        // boxes — noise anchors rarely produce sensible-sized boxes.

        detections.add(
          DetectionResult(
            className: labels[maxClassIdx],
            confidence: maxScore,
            x: (x - w / 2) / inputSize,
            y: (y - h / 2) / inputSize,
            width: w / inputSize,
            height: h / inputSize,
          ),
        );
      }
    }
    return _nonMaxSuppression(detections);
  }

  List<DetectionResult> _nonMaxSuppression(List<DetectionResult> detections) {
    if (detections.isEmpty) return [];
    // FIX: Apply the raised displayThreshold here as the final strict gate.
    detections.removeWhere((d) => d.confidence < displayThreshold);
    if (detections.isEmpty) return [];
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <DetectionResult>[];
    while (detections.isNotEmpty) {
      final best = detections.removeAt(0);
      selected.add(best);
      detections.removeWhere((d) => _calculateIoU(best, d) > iouThreshold);
    }
    return selected;
  }

  double _calculateIoU(DetectionResult a, DetectionResult b) {
    final x1 = math.max(a.x, b.x);
    final y1 = math.max(a.y, b.y);
    final x2 = math.min(a.x + a.width, b.x + b.width);
    final y2 = math.min(a.y + a.height, b.y + b.height);
    if (x2 <= x1 || y2 <= y1) return 0;
    final intersection = (x2 - x1) * (y2 - y1);
    return intersection /
        (a.width * a.height + b.width * b.height - intersection);
  }
}

// ============================================================================
// MAIN NAVIGATION
// ============================================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final CamoteClassifier _classifier = CamoteClassifier();
  DetectionLog? _lastResult;
  final GlobalKey<_ResultsPageState> _resultsPageKey = GlobalKey();
  final GlobalKey<_HistoryPageState> _historyPageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _classifier.loadModel();
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  void _setResult(DetectionLog result) {
    setState(() {
      _lastResult = result;
      _currentIndex = 1;
    });
    _resultsPageKey.currentState?.updateResult(result);
    _historyPageKey.currentState?.addNewLog(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ScanPage(
            classifier: _classifier,
            onResult: _setResult,
            cameras: _cameras,
          ),
          ResultsPage(key: _resultsPageKey, result: _lastResult),
          HistoryPage(key: _historyPageKey),
          const LibraryPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.camera_alt_outlined,
                  Icons.camera_alt,
                  'Scan',
                ),
                _buildNavItem(
                  1,
                  Icons.analytics_outlined,
                  Icons.analytics,
                  'Results',
                ),
                _buildNavItem(
                  2,
                  Icons.history_outlined,
                  Icons.history,
                  'History',
                ),
                _buildNavItem(
                  3,
                  Icons.photo_library_outlined,
                  Icons.photo_library,
                  'Library',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCAN PAGE
// ============================================================================

class ScanPage extends StatefulWidget {
  final CamoteClassifier classifier;
  final Function(DetectionLog) onResult;
  final List<CameraDescription> cameras;

  const ScanPage({
    super.key,
    required this.classifier,
    required this.onResult,
    required this.cameras,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  // Camera
  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) {
      if (mounted) {
        setState(() => _cameraError = 'No camera found on this device.');
      }
      return;
    }
    try {
      final controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _cameraController = controller;
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing)
      return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      await _processImage(File(photo.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture error: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 90,
    );
    if (image != null) {
      await _processImage(File(image.path));
    }
  }

  Future<void> _processImage(File imageFile) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final results = await widget.classifier.detectFromFile(imageFile);

      if (!mounted) return;

      // FIX: results is already filtered by displayThreshold (0.75) inside
      // the classifier, so an empty list here reliably means no camote found.
      if (results.isEmpty) {
        _showNoCamoteDialog();
        return;
      }

      final uniqueClasses = results.map((r) => r.className).toSet();
      if (uniqueClasses.length > 1) {
        _showMultipleCamotesDialog();
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'camote_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${appDir.path}/$fileName';
      await imageFile.copy(savedPath);

      final log = DetectionLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: savedPath,
        results: results,
        timestamp: DateTime.now(),
      );

      await DetectionLogger.saveLog(log);
      widget.onResult(log);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showNoCamoteDialog() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Invalid Image Detected!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please scan a valid camote. Make sure it is clearly visible in the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retake',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMultipleCamotesDialog() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Multiple Camotes Detected!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan one camote at a time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHowToUseDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How to Use',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStep(
                            1,
                            'Capture or Upload',
                            'Point the live camera at a camote and tap "Take Photo", or pick one from your gallery.',
                          ),
                          _buildStep(
                            2,
                            'Analyze Camote',
                            'Wait a few seconds while the app analyzes the camote.',
                          ),
                          _buildStep(
                            3,
                            'View Results',
                            'View details like shape, skin & flesh color, and texture.',
                          ),
                          _buildStep(
                            4,
                            'Explore Library',
                            'Explore references about your camote.',
                          ),
                          _buildStep(
                            5,
                            'Check History',
                            'Open history to review your previous scans.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Got It',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Doma',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A computer-vision based app for identifying and classifying sweet potato (camote) varieties commonly found in Tacloban City, Leyte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Container(
        color: const Color(0xFF1A2332),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white38,
                size: 52,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraReady || _cameraController == null) {
      return Container(
        color: const Color(0xFF1A2332),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D97E)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Scan Camote',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: const Icon(Icons.circle, color: AppColors.primary, size: 10),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: _showHowToUseDialog,
            color: AppColors.textSecondary,
            tooltip: 'How to Use',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: AppColors.textSecondary,
            onPressed: _showAboutDialog,
            tooltip: 'About',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 420,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF00D97E), width: 2.5),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraPreview(),

                  if (_cameraReady)
                    Positioned.fill(
                      child: CustomPaint(painter: _ScanFramePainter()),
                    ),

                  if (_isProcessing)
                    Container(
                      color: const Color.fromARGB(
                        255,
                        3,
                        28,
                        13,
                      ).withOpacity(0.75),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFF00D97E,
                                  ).withOpacity(0.3),
                                  width: 3,
                                ),
                              ),
                              child: const CircularProgressIndicator(
                                color: Color(0xFF00D97E),
                                strokeWidth: 5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Analyzing Image...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Please wait while we identify\nthe camote variety',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _dot(1.0),
                                const SizedBox(width: 8),
                                _dot(0.6),
                                const SizedBox(width: 8),
                                _dot(0.3),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _capturePhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  width: 58,
                  height: 58,
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _pickFromGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.photo_outlined, size: 24),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tips for Best Camote Results',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip(
                    '- Ensure the camote is fully visible and centered in the frame.',
                  ),
                  _buildTip('- Ensure good quality lighting.'),
                  _buildTip('- Recommended to use plain or simple background.'),
                  _buildTip('- Avoid blurry photos if necessary.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(double opacity) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color.fromARGB(255, 255, 255, 255).withOpacity(opacity),
    ),
  );

  Widget _buildTip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    ),
  );
}

// Corner-bracket scan-frame painter
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D97E)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const pad = 20.0;

    final corners = [
      [Offset(pad, pad + len), Offset(pad, pad), Offset(pad + len, pad)],
      [
        Offset(size.width - pad - len, pad),
        Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + len),
      ],
      [
        Offset(pad, size.height - pad - len),
        Offset(pad, size.height - pad),
        Offset(pad + len, size.height - pad),
      ],
      [
        Offset(size.width - pad - len, size.height - pad),
        Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad, size.height - pad - len),
      ],
    ];

    for (final corner in corners) {
      final path = Path()
        ..moveTo(corner[0].dx, corner[0].dy)
        ..lineTo(corner[1].dx, corner[1].dy)
        ..lineTo(corner[2].dx, corner[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// BOUNDING BOX PAINTER
// ============================================================================

class _BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;

  // FIX: Matched to the classifier's displayThreshold for consistency.
  static const double confidenceThreshold = 0.75;

  _BoundingBoxPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D97E)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final textPaint = TextPainter(textDirection: TextDirection.ltr);

    final validDetections = detections
        .where((d) => d.confidence >= confidenceThreshold)
        .toList();

    for (final detection in validDetections) {
      final rect = Rect.fromLTWH(
        detection.x * size.width,
        detection.y * size.height,
        detection.width * size.width,
        detection.height * size.height,
      );

      canvas.drawRect(rect, paint);

      final confidenceText =
          '${(detection.confidence * 100).toStringAsFixed(1)}%';
      textPaint.text = TextSpan(
        text: confidenceText,
        style: const TextStyle(
          color: Color(0xFF00D97E),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Color.fromARGB(200, 0, 0, 0),
        ),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(detection.x * size.width, detection.y * size.height - 24),
      );
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter oldDelegate) => true;
}

// ============================================================================
// RESULTS PAGE
// ============================================================================

class ResultsPage extends StatefulWidget {
  final DetectionLog? result;
  const ResultsPage({super.key, this.result});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late DetectionLog? _currentResult;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
  }

  @override
  void didUpdateWidget(ResultsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result != oldWidget.result) {
      setState(() => _currentResult = widget.result);
    }
  }

  void updateResult(DetectionLog result) {
    setState(() => _currentResult = result);
  }

  CamoteVariety? _getVarietyInfo(String className) {
    try {
      return camoteVarieties.firstWhere(
        (v) => v.name.toLowerCase() == className.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String _getAccuracyLabel(double confidence) {
    if (confidence >= 0.8) return 'High Accuracy';
    if (confidence >= 0.5) return 'Medium Accuracy';
    return 'Low Accuracy';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentResult == null || _currentResult!.results.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          scrolledUnderElevation: 0,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.eco,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Analysis Results',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No results yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan a camote to see results here',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // FIX: Consistent with the classifier's displayThreshold.
    const confidenceThreshold = 0.75;
    final validResults = _currentResult!.results
        .where((r) => r.confidence >= confidenceThreshold)
        .toList();

    if (validResults.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          scrolledUnderElevation: 0,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.eco,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Analysis Results',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 64,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Camote Detected',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The image does not contain a clear camote.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Try Another Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final topResult = validResults.first;
    final varietyInfo = _getVarietyInfo(topResult.className);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Analysis Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: File(_currentResult!.imagePath).existsSync()
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(_currentResult!.imagePath),
                            fit: BoxFit.cover,
                          ),
                          CustomPaint(
                            painter: _BoundingBoxPainter(
                              detections: _currentResult!.results,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              varietyInfo?.name ??
                                  topResult.className.capitalize(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (varietyInfo != null) ...[
                              Text(
                                varietyInfo.commonName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                varietyInfo.scientificName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confidence Level',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${(topResult.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: topResult.confidence,
                      backgroundColor: AppColors.border.withOpacity(0.5),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _getAccuracyLabel(topResult.confidence),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (varietyInfo != null) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Visual Characteristics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCharacteristic(
                      Icons.crop_square_outlined,
                      'Shape',
                      varietyInfo.shape,
                    ),
                    _buildCharacteristic(
                      Icons.palette_outlined,
                      'Skin Color',
                      varietyInfo.skinColor,
                    ),
                    _buildCharacteristic(
                      Icons.circle_outlined,
                      'Flesh Color',
                      varietyInfo.fleshColor,
                    ),
                    _buildCharacteristic(
                      Icons.texture,
                      'Surface Texture',
                      varietyInfo.texture,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristic(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HISTORY PAGE
// ============================================================================

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<DetectionLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await DetectionLogger.loadLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  void addNewLog(DetectionLog log) {
    setState(() => _logs.insert(0, log));
  }

  Future<void> _deleteLog(DetectionLog log) async {
    setState(() => _isLoading = true);
    await DetectionLogger.deleteLog(log.id);
    await _loadLogs();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Clear All History?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to delete all detection history? This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await DetectionLogger.clearAllLogs();
      await _loadLogs();
    }
  }

  CamoteVariety? _getVarietyInfo(String className) {
    try {
      return camoteVarieties.firstWhere(
        (v) => v.name.toLowerCase() == className.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _showHistoryDetail(
    BuildContext context,
    DetectionLog log,
    DetectionResult? topResult,
    CamoteVariety? varietyInfo,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detection Details',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topResult?.className.capitalize() ?? 'No detection',
                          style: const TextStyle(
                            fontSize: 24,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: File(log.imagePath).existsSync()
                    ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Accuracy',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (topResult != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Confidence Level',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(topResult.confidence * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: topResult.confidence,
                          backgroundColor: AppColors.border.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                          minHeight: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Detection Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${log.timestamp.month}/${log.timestamp.day}/${log.timestamp.year}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Relative',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              TimeFormatter.getRelativeTime(log.timestamp),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (varietyInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Variety Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCharacteristicDetail(
                        Icons.crop_square_outlined,
                        'Shape',
                        varietyInfo.shape,
                      ),
                      const SizedBox(height: 8),
                      _buildCharacteristicDetail(
                        Icons.palette_outlined,
                        'Skin Color',
                        varietyInfo.skinColor,
                      ),
                      const SizedBox(height: 8),
                      _buildCharacteristicDetail(
                        Icons.circle_outlined,
                        'Flesh Color',
                        varietyInfo.fleshColor,
                      ),
                      const SizedBox(height: 8),
                      _buildCharacteristicDetail(
                        Icons.texture,
                        'Surface Texture',
                        varietyInfo.texture,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _deleteLog(log);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Detection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacteristicDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Detection History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detection History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_logs.length} detection${_logs.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_logs.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: 18,
                    ),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No detection history',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final topResult = log.results.isNotEmpty
                            ? log.results.reduce(
                                (a, b) => a.confidence > b.confidence ? a : b,
                              )
                            : null;
                        final varietyInfo = _getVarietyInfo(
                          topResult?.className ?? '',
                        );

                        return GestureDetector(
                          onTap: () => _showHistoryDetail(
                            context,
                            log,
                            topResult,
                            varietyInfo,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              leading: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(11),
                                    bottomLeft: Radius.circular(11),
                                  ),
                                  border: Border(
                                    left: BorderSide(color: AppColors.border),
                                    top: BorderSide(color: AppColors.border),
                                    bottom: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    bottomLeft: Radius.circular(10),
                                  ),
                                  child: File(log.imagePath).existsSync()
                                      ? Image.file(
                                          File(log.imagePath),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.grey[100],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            size: 28,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topResult?.className.capitalize() ??
                                        'No detection',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (varietyInfo != null)
                                    Text(
                                      varietyInfo.commonName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (topResult != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: Text(
                                            '${(topResult.confidence * 100).toStringAsFixed(0)}% match',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        TimeFormatter.getRelativeTime(
                                          log.timestamp,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: SizedBox(
                                width: 32,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _deleteLog(log);
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIBRARY PAGE (CROP LIBRARY)
// ============================================================================

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Crop Library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Camote Varieties',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Doma can classify 4 varieties commonly found in Tacloban City.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ...camoteVarieties.map(
              (variety) => _buildVarietyCard(context, variety),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVarietyCard(BuildContext context, CamoteVariety variety) {
    return GestureDetector(
      onTap: () => _showVarietyDetail(context, variety),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
                child: SizedBox(
                  width: 120,
                  child: Image.asset(
                    variety.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            variety.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      Text(
                        variety.commonName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        variety.scientificName,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Skin: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              variety.skinColor,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Flesh: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              variety.fleshColor,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVarietyDetail(BuildContext context, CamoteVariety variety) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variety.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          variety.commonName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    variety.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      variety.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Health Benefits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...variety.benefits.map(
                      (benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Popular Dishes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...variety.dishes.map(
                      (dish) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dish,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EXTENSION FOR STRING CAPITALIZATION
// ============================================================================

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
