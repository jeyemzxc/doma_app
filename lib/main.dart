// lib/main.dart  –  Doma Camote Classifier  (UI v5)
// Changes from v4:
//   • Removed "Position camote in frame" badge
//   • Removed old "Scanning…" badge
//   • Added dark green overlay (30% opacity) using the provided bg image when processing
//   • Added "Analyzing Image…" centered overlay with animated pulsing dots + spinner
//   • Polished AppBar, bottom action bar, and overall UI refinements

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

List<CameraDescription> _cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera: $e');
  }
  runApp(const DomaApp());
}

// ============================================================================
// DESIGN TOKENS
// ============================================================================

class C {
  static const primary = Color(0xFF00875A);
  static const primaryDark = Color(0xFF005C3D);
  static const primaryMid = Color(0xFF00C27A);
  static const primaryLight = Color(0xFFE8F5EF);
  static const primaryTint = Color(0xFFF0FBF6);

  static const bg = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFEAECF0);
  static const borderMid = Color(0xFFD1D5DB);

  static const textPrimary = Color(0xFF111827);
  static const textSec = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const err = Color(0xFFDC2626);
  static const errLight = Color(0xFFFEF2F2);
  static const warn = Color(0xFFD97706);
  static const warnLight = Color(0xFFFFFBEB);

  static const white = Colors.white;

  // Camera overlay dark bg color (matches the provided image)
  static const camOverlayDark = Color(0xFF071A10);
}

// ============================================================================
// VARIETY ACCENT COLOUR
// ============================================================================

Color _varietyAccent(String cls) {
  switch (cls.toLowerCase()) {
    case 'kadulaw':
      return const Color(0xFFD3510B);
    case 'minamon':
      return const Color(0xFFBA8E23);
    case 'kadabaw':
      return const Color(0xFF9B3B69);
    case 'tapol':
      return const Color(0xFFB1ACA8);
    default:
      return C.primary;
  }
}

// ============================================================================
// APP
// ============================================================================

class DomaApp extends StatelessWidget {
  const DomaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Doma – Camote Classifier',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.green,
      scaffoldBackgroundColor: C.bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: C.surface,
        foregroundColor: C.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: C.surface,
      ),
    ),
    home: const MainNavigation(),
  );
}

class TimeFormatter {
  static String rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  static String short(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}  $h:$m $ap';
  }

  static String full(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $h:$m $ap';
  }
}

// ============================================================================
// VARIETY DATA
// ============================================================================

class CamoteVariety {
  final String name,
      commonName,
      scientificName,
      skinColor,
      fleshColor,
      shape,
      texture,
      imagePath,
      description;
  final List<String> benefits, dishes, imagePaths;
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
    required this.imagePaths,
  });
}

const List<CamoteVariety> camoteVarieties = [
  CamoteVariety(
    name: 'Kadulaw',
    commonName: 'Orange Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Light orange to peach',
    fleshColor: 'Orange',
    shape: 'Elongated / Fusiform',
    texture: 'Smooth / Firm',
    imagePath: 'assets/images/orange_camote.jpg',
    description:
        'Light orange to peach skin with vibrant orange flesh. Elongated and fusiform in shape with a smooth, firm texture.',
    benefits: [
      'Rich in beta-carotene',
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
    imagePaths: [
      'assets/images/orange_camote.jpg',
      'assets/images/kadulaw2.png',
      'assets/images/kadulaw3.png',
      'assets/images/kadulaw4.png',
      'assets/images/kadulaw5.png',
    ],
  ),
  CamoteVariety(
    name: 'Minamon',
    commonName: 'Yellow Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Yellow to tan',
    fleshColor: 'Yellow',
    shape: 'Bent / Curved',
    texture: 'Lumpy / Gritty',
    imagePath: 'assets/images/yellow_camote.jpg',
    description:
        'Yellow to tan skin with bright yellow flesh. Bent curved shape with a characteristic lumpy texture.',
    benefits: [
      'Rich in complex carbohydrates',
      'Good source of fiber',
      'Contains potassium',
      'Sustained energy',
      'Supports digestion',
    ],
    dishes: [
      'Camote Cue',
      'Nilupak',
      'Minatamis na Camote',
      'Nilagang Camote',
      'Camote Porridge',
    ],
    imagePaths: [
      'assets/images/yellow_camote.jpg',
      'assets/images/minamon2.png',
      'assets/images/minamon3.png',
      'assets/images/minamon4.png',
      'assets/images/minamon5.png',
    ],
  ),
  CamoteVariety(
    name: 'Tapol',
    commonName: 'White Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'White to cream',
    fleshColor: 'Purple',
    shape: 'Round / Oblong',
    texture: 'Smooth / Hard',
    imagePath: 'assets/images/white_camote.jpg',
    description:
        'White to cream skin with striking purple flesh inside. Round or oblong shape with a hard, smooth texture.',
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
    imagePaths: [
      'assets/images/white_camote.jpg',
      'assets/images/tapol2.png',
      'assets/images/tapol3.png',
      'assets/images/tapol4.png',
      'assets/images/tapol5.png',
    ],
  ),
  CamoteVariety(
    name: 'Kadabaw',
    commonName: 'Violet Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Purple to reddish-violet',
    fleshColor: 'Yellow',
    shape: 'Irregular',
    texture: 'Rough',
    imagePath: 'assets/images/purple_camote.jpg',
    description:
        'Distinctive violet to reddish-purple skin with bright yellow flesh. Irregular shape and rough texture give it a rustic appearance.',
    benefits: [
      'High in anthocyanins',
      'Powerful antioxidants',
      'Anti-inflammatory',
      'Supports brain health',
      'Reduces chronic-disease risk',
    ],
    dishes: [
      'Camote Mash',
      'Nilagang Camote',
      'Minatamis na Camote',
      'Camote Cue',
      'Boiled Camote',
    ],
    imagePaths: [
      'assets/images/purple_camote.jpg',
      'assets/images/kadabaw2.png',
      'assets/images/kadabaw3.png',
      'assets/images/kadabaw4.png',
      'assets/images/kadabaw5.png',
    ],
  ),
];

// ============================================================================
// DETECTION MODELS
// ============================================================================

class _Det {
  final Rect box;
  final int cls;
  final double score;
  const _Det(this.box, this.cls, this.score);
}

class _ScanResult {
  final DetectionResult? winner;
  final _ScanState state;
  const _ScanResult({this.winner, this.state = _ScanState.ok});
  bool get found => winner != null && state == _ScanState.ok;
}

enum _ScanState { ok, notFound, multipleVariants }

class DetectionResult {
  final String className;
  final double confidence, x, y, width, height;
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
  factory DetectionResult.fromJson(Map<String, dynamic> j) => DetectionResult(
    className: j['className'],
    confidence: j['confidence'],
    x: j['x'],
    y: j['y'],
    width: j['width'],
    height: j['height'],
  );
}

class DetectionLog {
  final String id, imagePath;
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
  factory DetectionLog.fromJson(Map<String, dynamic> j) => DetectionLog(
    id: j['id'],
    imagePath: j['imagePath'],
    results: (j['results'] as List)
        .map((r) => DetectionResult.fromJson(r))
        .toList(),
    timestamp: DateTime.parse(j['timestamp']),
  );
}

class DetectionLogger {
  static const _k = 'detection_logs';
  static Future<void> save(DetectionLog log) async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? [];
    l.insert(0, jsonEncode(log.toJson()));
    await p.setStringList(_k, l);
  }

  static Future<List<DetectionLog>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    final result = <DetectionLog>[];
    for (final s in raw) {
      try {
        result.add(DetectionLog.fromJson(jsonDecode(s)));
      } catch (e) {
        debugPrint('[Doma] skip corrupt log entry: $e');
      }
    }
    return result;
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final l = (p.getStringList(_k) ?? [])
        .where((s) => DetectionLog.fromJson(jsonDecode(s)).id != id)
        .toList();
    await p.setStringList(_k, l);
  }

  static Future<void> clearAll() async =>
      (await SharedPreferences.getInstance()).remove(_k);
}

// ============================================================================
// RESHAPE HELPER
// ============================================================================

extension ReshapeF on Float32List {
  List<dynamic> r4(List<int> s) {
    final b = s[0], h = s[1], w = s[2], c = s[3];
    return List.generate(
      b,
      (_) => List.generate(
        h,
        (y) => List.generate(
          w,
          (x) => List.generate(
            c,
            (ch) => this[(y * w + x) * c + ch],
            growable: false,
          ),
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );
  }
}

// ============================================================================
// CLASSIFIER
// ============================================================================

class CamoteClassifier {
  Interpreter? _interp;
  int _inSz = 640;

  static const double _rawGate = 0.70;
  static const double _displayGate = 0.70;
  static const double _iouThres = 0.45;
  static const double _minAspect = 0.25;
  static const double _maxAspect = 4.0;
  static const double _minArea = 0.02;
  static const double _maxArea = 0.90;

  static const List<String> labels = ['kadabaw', 'kadulaw', 'minamon', 'tapol'];

  Future<void> loadModel() async {
    try {
      _interp = await Interpreter.fromAsset(
        'assets/best_int8.tflite',
        options: InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true,
      );
      final inShape = _interp!.getInputTensor(0).shape;
      if (inShape.length == 4 && inShape[1] > 0) _inSz = inShape[1];
    } catch (e) {
      debugPrint('[Doma] load err: $e');
    }
  }

  void dispose() => _interp?.close();

  Future<_ScanResult> detect(File f) async {
    try {
      if (_interp == null) await loadModel();
      if (_interp == null) return const _ScanResult(state: _ScanState.notFound);
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return const _ScanResult(state: _ScanState.notFound);
      img.Image? im = img.decodeImage(bytes);
      if (im == null) return const _ScanResult(state: _ScanState.notFound);
      if (im.width < 32 || im.height < 32)
        return const _ScanResult(state: _ScanState.notFound);
      im = _enhance(im);
      return _infer(im);
    } catch (e, st) {
      debugPrint('[Doma] detect err: $e\n$st');
      return const _ScanResult(state: _ScanState.notFound);
    }
  }

  img.Image _enhance(img.Image src) {
    const maxDim = 1920;
    img.Image p = src;
    if (src.width > maxDim || src.height > maxDim) {
      final s = maxDim / math.max(src.width, src.height);
      p = img.copyResize(
        src,
        width: (src.width * s).round(),
        height: (src.height * s).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    double sR = 0, sG = 0, sB = 0;
    int cnt = 0;
    for (int y = 0; y < p.height; y += 4)
      for (int x = 0; x < p.width; x += 4) {
        final px = p.getPixel(x, y);
        sR += px.r.toDouble();
        sG += px.g.toDouble();
        sB += px.b.toDouble();
        cnt++;
      }
    final avg = (sR + sG + sB) / (cnt * 3.0);
    final bF = avg < 100
        ? 1.04
        : avg > 180
        ? 1.01
        : 1.02;
    final cF = avg < 100
        ? 1.10
        : avg > 180
        ? 1.04
        : 1.06;
    final out = img.Image(width: p.width, height: p.height);
    for (int y = 0; y < p.height; y++)
      for (int x = 0; x < p.width; x++) {
        final px = p.getPixel(x, y);
        double r = px.r.toDouble() * bF,
            g = px.g.toDouble() * bF,
            b = px.b.toDouble() * bF;
        r = 128 + (r - 128) * cF;
        g = 128 + (g - 128) * cF;
        b = 128 + (b - 128) * cF;
        out.setPixel(
          x,
          y,
          img.ColorRgb8(
            r.clamp(0, 255).round(),
            g.clamp(0, 255).round(),
            b.clamp(0, 255).round(),
          ),
        );
      }
    return out;
  }

  Float32List _letterbox(img.Image im) {
    final sz = _inSz, w = im.width, h = im.height;
    final out = Float32List(sz * sz * 3);
    final sc = math.min(sz / w, sz / h);
    final nW = (w * sc).floor(), nH = (h * sc).floor();
    final pX = ((sz - nW) / 2).floor(), pY = ((sz - nH) / 2).floor();
    const pv = 114.0 / 255.0;
    final inv = 1.0 / sc;
    for (int y = 0; y < sz; y++)
      for (int x = 0; x < sz; x++) {
        final p = (y * sz + x) * 3;
        if (x < pX || x >= pX + nW || y < pY || y >= pY + nH) {
          out[p] = pv;
          out[p + 1] = pv;
          out[p + 2] = pv;
        } else {
          final sx = (x - pX) * inv, sy = (y - pY) * inv;
          final x0 = math.max(0, math.min(w - 1, (sx - 0.5).floor()));
          final y0 = math.max(0, math.min(h - 1, (sy - 0.5).floor()));
          final x1 = math.max(0, math.min(w - 1, x0 + 1));
          final y1 = math.max(0, math.min(h - 1, y0 + 1));
          final fx = (sx - x0 - 0.5).clamp(0.0, 1.0),
              fy = (sy - y0 - 0.5).clamp(0.0, 1.0);
          final q00 = im.getPixel(x0, y0), q10 = im.getPixel(x1, y0);
          final q01 = im.getPixel(x0, y1), q11 = im.getPixel(x1, y1);
          double bi(a, b, c, d) =>
              (a * (1 - fx) * (1 - fy) +
                      b * fx * (1 - fy) +
                      c * (1 - fx) * fy +
                      d * fx * fy)
                  .clamp(0, 255);
          out[p] = bi(q00.r, q10.r, q01.r, q11.r) / 255.0;
          out[p + 1] = bi(q00.g, q10.g, q01.g, q11.g) / 255.0;
          out[p + 2] = bi(q00.b, q10.b, q01.b, q11.b) / 255.0;
        }
      }
    return out;
  }

  _ScanResult _infer(img.Image image) {
    final nCls = labels.length;
    final input = _letterbox(image);
    final oShape = _interp!.getOutputTensor(0).shape;
    final isSimple =
        oShape.length == 3 &&
        (oShape[2] == 6 || (oShape[1] == 6 && oShape[2] > 6));
    final raw = isSimple
        ? _decodeSimple(oShape, input)
        : _decodeYolo(oShape, nCls, input);
    final mapped = _unmap(raw, image.width.toDouble(), image.height.toDouble());
    final nmsed = _nms(mapped);
    if (nmsed.isEmpty) return const _ScanResult(state: _ScanState.notFound);
    final classes = nmsed.map((d) => d.cls).toSet();
    if (classes.length > 1) {
      return const _ScanResult(state: _ScanState.multipleVariants);
    }
    final w = nmsed.first;
    if (w.score < _displayGate) {
      return const _ScanResult(state: _ScanState.notFound);
    }
    final r = DetectionResult(
      className: labels[w.cls.clamp(0, labels.length - 1)],
      confidence: w.score,
      x: w.box.left,
      y: w.box.top,
      width: w.box.width,
      height: w.box.height,
    );
    return _ScanResult(winner: r, state: _ScanState.ok);
  }

  List<_Det> _decodeYolo(List<int> shape, int nCls, Float32List input) {
    final sz = _inSz, CC = 4 + nCls;
    late bool tr;
    late int N;
    if (shape.length == 3 && shape[1] == CC) {
      tr = true;
      N = shape[2];
    } else if (shape.length == 3 && shape[2] == CC) {
      tr = false;
      N = shape[1];
    } else if (shape.length == 2 && shape[1] == CC) {
      tr = false;
      N = shape[0];
    } else {
      tr = true;
      N = shape.length == 3 ? shape[2] : shape[0];
    }
    final buf = tr
        ? List.generate(
            1,
            (_) => List.generate(CC, (_) => List<double>.filled(N, 0.0)),
          )
        : List.generate(
            1,
            (_) => List.generate(N, (_) => List<double>.filled(CC, 0.0)),
          );
    _interp!.run(input.r4([1, sz, sz, 3]), buf);
    List<List<double>> preds;
    if (tr) {
      preds = List.generate(N, (i) => List<double>.filled(CC, 0.0));
      for (int c = 0; c < CC; c++)
        for (int n = 0; n < N; n++) preds[n][c] = buf[0][c][n];
    } else {
      preds = buf[0].cast<List<double>>();
    }
    return _parse(preds, nCls, sz);
  }

  List<_Det> _decodeSimple(List<int> shape, Float32List input) {
    final sz = _inSz;
    late int rows;
    late bool cf;
    if (shape.length == 3 && shape[2] == 6) {
      rows = shape[1];
      cf = false;
    } else {
      rows = shape[2];
      cf = true;
    }
    final buf = List.generate(
      1,
      (_) => cf
          ? List.generate(6, (_) => List<double>.filled(rows, 0.0))
          : List.generate(rows, (_) => List<double>.filled(6, 0.0)),
    );
    _interp!.run(input.r4([1, sz, sz, 3]), buf);
    final rows2d = cf
        ? List.generate(rows, (i) => List.generate(6, (c) => buf[0][c][i]))
        : buf[0].cast<List<double>>();
    final dets = <_Det>[];
    for (final row in rows2d) {
      if (row.length < 6) continue;
      final x1 = row[0], y1 = row[1], x2 = row[2], y2 = row[3];
      final raw = row[4];
      if (raw < _rawGate) continue;
      final score = _cal(raw);
      if (score < _displayGate || x2 <= x1 || y2 <= y1) continue;
      final cls = row[5].round().clamp(0, labels.length - 1);
      if (!_boxOk(x1, y1, x2, y2, 1.0)) continue;
      dets.add(_Det(Rect.fromLTRB(x1, y1, x2, y2), cls, score));
    }
    dets.sort((a, b) => b.score.compareTo(a.score));
    return dets.length > 200 ? dets.sublist(0, 200) : dets;
  }

  List<_Det> _parse(List<List<double>> preds, int nCls, int sz) {
    final dets = <_Det>[];
    for (final p in preds) {
      if (p.length < 4 + nCls) continue;
      double best = 0;
      int bestC = -1;
      for (int c = 0; c < nCls; c++) {
        final raw = _sig(p[4 + c]);
        if (raw > best) {
          best = raw;
          bestC = c;
        }
      }
      if (best < _rawGate || bestC < 0) continue;
      final score = _cal(best);
      if (score < _displayGate) continue;
      double cx = p[0], cy = p[1], w = p[2], h = p[3];
      if (cx.abs() <= 1.5 &&
          cy.abs() <= 1.5 &&
          w.abs() <= 1.5 &&
          h.abs() <= 1.5) {
        cx *= sz;
        cy *= sz;
        w *= sz;
        h *= sz;
      }
      double x1 = cx - w / 2, y1 = cy - h / 2, x2 = cx + w / 2, y2 = cy + h / 2;
      if (x2 <= x1 || y2 <= y1) {
        x1 = cx;
        y1 = cy;
        x2 = w;
        y2 = h;
      }
      if (x2 < -5 || y2 < -5 || x1 > sz + 5 || y1 > sz + 5) continue;
      if (!_boxOk(x1, y1, x2, y2, sz.toDouble())) continue;
      dets.add(_Det(Rect.fromLTRB(x1, y1, x2, y2), bestC, score));
    }
    dets.sort((a, b) => b.score.compareTo(a.score));
    return dets.length > 200 ? dets.sublist(0, 200) : dets;
  }

  bool _boxOk(double x1, double y1, double x2, double y2, double ds) {
    final bw = x2 - x1, bh = y2 - y1;
    if (ds > 1) {
      final mn = ds * 0.04, mx = ds * 0.92;
      if (bw < mn || bh < mn || bw > mx || bh > mx) return false;
    } else {
      final area = bw * bh;
      if (area < _minArea || area > _maxArea) return false;
    }
    final aspect = bh / (bw.abs() + 1e-9);
    return aspect >= _minAspect && aspect <= _maxAspect;
  }

  double _sig(double x) =>
      x >= 0 ? 1.0 / (1.0 + math.exp(-x)) : math.exp(x) / (1.0 + math.exp(x));

  double _cal(double s) {
    if (s < 0.70) return s;
    if (s < 0.85) return 0.70 + (s - 0.70) * 1.35;
    return 0.90 + (s - 0.85) * 1.0;
  }

  List<_Det> _unmap(List<_Det> dets, double srcW, double srcH) {
    final sz = _inSz.toDouble();
    final sc = math.min(sz / srcW, sz / srcH);
    final pX = (sz - srcW * sc) / 2.0, pY = (sz - srcH * sc) / 2.0;
    final out = <_Det>[];
    for (final d in dets) {
      final x1 = ((d.box.left - pX) / sc / srcW).clamp(0.0, 1.0);
      final y1 = ((d.box.top - pY) / sc / srcH).clamp(0.0, 1.0);
      final x2 = ((d.box.right - pX) / sc / srcW).clamp(0.0, 1.0);
      final y2 = ((d.box.bottom - pY) / sc / srcH).clamp(0.0, 1.0);
      if ((x2 - x1) < 0.01 || (y2 - y1) < 0.01) continue;
      if (!_boxOk(x1, y1, x2, y2, 1.0)) continue;
      out.add(_Det(Rect.fromLTRB(x1, y1, x2, y2), d.cls, d.score));
    }
    return out;
  }

  List<_Det> _nms(List<_Det> dets) {
    if (dets.isEmpty) return [];
    dets.sort((a, b) => b.score.compareTo(a.score));
    final sup = List<bool>.filled(dets.length, false);
    final keep = <_Det>[];
    for (int i = 0; i < dets.length; i++) {
      if (sup[i]) continue;
      keep.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (sup[j]) continue;
        if (_iou(dets[i].box, dets[j].box) > _iouThres) sup[j] = true;
      }
    }
    return keep;
  }

  double _iou(Rect a, Rect b) {
    final il = math.max(a.left, b.left), it = math.max(a.top, b.top);
    final ir = math.min(a.right, b.right), ib = math.min(a.bottom, b.bottom);
    final iW = math.max(0.0, ir - il), iH = math.max(0.0, ib - it);
    final iA = iW * iH;
    final u = a.width * a.height + b.width * b.height - iA;
    return u <= 0 ? 0 : iA / u;
  }
}

// ============================================================================
// BOUNDING BOX PAINTER
// ============================================================================

class _BBPainter extends CustomPainter {
  final DetectionResult? det;
  const _BBPainter({this.det});

  @override
  void paint(Canvas canvas, Size size) {
    final d = det;
    if (d == null) return;
    final color = _varietyAccent(d.className);
    final boxP = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final bgP = Paint()..color = color.withOpacity(0.92);
    final r = Rect.fromLTWH(
      d.x * size.width,
      d.y * size.height,
      d.width * size.width,
      d.height * size.height,
    );
    canvas.drawRect(r, boxP);
    final lbl =
        '${d.className.cap}  ${(d.confidence * 100).toStringAsFixed(0)}%';
    final tp = TextPainter(
      text: TextSpan(
        text: lbl,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 5.0;
    final bgR = Rect.fromLTWH(
      r.left,
      math.max(0, r.top - tp.height - pad * 2),
      tp.width + pad * 2,
      tp.height + pad * 2,
    );
    canvas.drawRect(bgR, bgP);
    tp.paint(canvas, Offset(bgR.left + pad, bgR.top + pad));
  }

  @override
  bool shouldRepaint(_BBPainter o) => o.det != det;
}

// ============================================================================
// ANALYZING IMAGE OVERLAY  (replaces old scanning badge)
// ============================================================================

class _AnalyzingOverlay extends StatefulWidget {
  const _AnalyzingOverlay();
  @override
  State<_AnalyzingOverlay> createState() => _AnalyzingOverlayState();
}

class _AnalyzingOverlayState extends State<_AnalyzingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _dotCtrl;
  late Animation<double> _pulseAnim;
  int _dotCount = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _dotTimer = Timer.periodic(const Duration(milliseconds: 480), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Positioned.fill(
      child: Container(
        // Dark overlay matching the provided camera background image tone
        decoration: const BoxDecoration(
          image: DecorationImage(
            // Use the scan background asset – falls back to solid color gracefully
            image: AssetImage('assets/images/scan_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.30,
          ),
          color: Color(0xCC071A10), // ~80% dark green backdrop
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing ring + spinner composite
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnim.value, child: child),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: C.primaryMid.withOpacity(0.35),
                        width: 2,
                      ),
                    ),
                  ),
                  // Spinner
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: AnimatedBuilder(
                      animation: _spinCtrl,
                      builder: (_, __) => Transform.rotate(
                        angle: _spinCtrl.value * 2 * math.pi,
                        child: CustomPaint(painter: _ArcPainter()),
                      ),
                    ),
                  ),
                  // Inner eco icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: C.primaryDark.withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco, color: C.primaryMid, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // "Analyzing Image" text with animated dots
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '   Analyzing Image...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    dots,
                    style: TextStyle(
                      color: C.primaryMid,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'The image is being processed.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.50),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a sweeping arc for the spinner
class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.primaryMid
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter o) => false;
}

// ============================================================================
// SHARED DESIGN COMPONENTS
// ============================================================================

class _TappableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;
  const _TappableCard({
    required this.child,
    required this.onTap,
    this.margin = const EdgeInsets.only(bottom: 10),
  });
  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) {
      setState(() => _pressed = false);
      widget.onTap();
    },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pressed ? C.primary : C.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: _pressed
                ? C.primary.withOpacity(0.12)
                : const Color(0x0A000000),
            blurRadius: _pressed ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.child,
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  const _Card({required this.child, this.padding, this.radius});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: radius ?? BorderRadius.circular(16),
      border: Border.all(color: C.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: C.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: C.textPrimary,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Pill(this.label, {this.bg = C.primaryLight, this.fg = C.primary});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
    ),
  );
}

class _ConfBar extends StatelessWidget {
  final double value;
  const _ConfBar(this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confidence Level',
                style: TextStyle(
                  fontSize: 12,
                  color: C.textSec,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _accLabel(value),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: C.primary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: C.primary,
              height: 1.0,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 8,
            backgroundColor: C.border,
            valueColor: const AlwaysStoppedAnimation(C.primary),
          ),
        ),
      ),
    ],
  );

  static String _accLabel(double c) => c >= 0.80
      ? 'High Accuracy'
      : c >= 0.50
      ? 'Medium Accuracy'
      : 'Low Accuracy';
}

class _CharRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _CharRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: C.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: C.primary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: C.textSec),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: C.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// IMAGE CAROUSEL
// ============================================================================

class _ImageCarousel extends StatefulWidget {
  final List<String> imagePaths;
  const _ImageCarousel({required this.imagePaths});
  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _pc = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.imagePaths.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Image.asset(
              widget.imagePaths[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: C.bg,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: C.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.imagePaths.length, (i) {
          final sel = _current == i;
          return GestureDetector(
            onTap: () => _pc.animateToPage(
              i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: sel ? C.primary : C.borderMid,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    ],
  );
}

// ============================================================================
// APP BAR HELPER
// ============================================================================

PreferredSizeWidget _appBar(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: C.surface,
  surfaceTintColor: C.surface,
  scrolledUnderElevation: 0,
  elevation: 0,
  title: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: C.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.eco, color: C.primary, size: 20),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: C.textPrimary,
        ),
      ),
    ],
  ),
  actions: actions,
);

// ============================================================================
// MAIN NAVIGATION
// ============================================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  final _cls = CamoteClassifier();
  DetectionLog? _last;
  final _rKey = GlobalKey<_ResultsPageState>();
  final _hKey = GlobalKey<_HistoryPageState>();

  @override
  void initState() {
    super.initState();
    _cls.loadModel().catchError(
      (e) => debugPrint('[Doma] model load failed: $e'),
    );
  }

  @override
  void dispose() {
    _cls.dispose();
    super.dispose();
  }

  void _onResult(DetectionLog log) {
    setState(() {
      _last = log;
      _idx = 1;
    });
    _rKey.currentState?.update(log);
    _hKey.currentState?.add(log);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _idx,
      children: [
        ScanPage(classifier: _cls, onResult: _onResult, cameras: _cameras),
        ResultsPage(key: _rKey, result: _last),
        HistoryPage(key: _hKey),
        const LibraryPage(),
      ],
    ),
    bottomNavigationBar: _BottomNav(
      currentIndex: _idx,
      onTap: (i) => setState(() => _idx = i),
    ),
  );
}

// ============================================================================
// BOTTOM NAV
// ============================================================================

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.camera_alt_outlined, Icons.camera_alt, 'Scan'),
    (Icons.analytics_outlined, Icons.analytics, 'Results'),
    (Icons.history_outlined, Icons.history, 'History'),
    (Icons.photo_library_outlined, Icons.photo_library, 'Library'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: C.surface,
      border: Border(top: BorderSide(color: C.border, width: 1)),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final sel = currentIndex == i;
            final item = _items[i];
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? C.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sel ? item.$2 : item.$1,
                      color: sel ? C.primary : C.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? C.primary : C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
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

class _ScanPageState extends State<ScanPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _picker = ImagePicker();
  bool _busy = false;
  File? _previewFile;
  CameraController? _cam;
  bool _camReady = false;
  String? _camErr;
  bool _usingFront = false;
  late AnimationController _scanCtrl, _cornerCtrl;
  late Animation<double> _scanAnim, _cornerAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
    _cornerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _cornerAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _cornerCtrl, curve: Curves.easeInOut));
    _initCam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _scanCtrl.dispose();
    _cornerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_cam == null || !_cam!.value.isInitialized) return;
    if (s == AppLifecycleState.inactive) {
      _cam!.dispose();
      if (mounted) setState(() => _camReady = false);
    } else if (s == AppLifecycleState.resumed) {
      _initCam();
    }
  }

  Future<void> _initCam() async {
    if (widget.cameras.isEmpty) {
      if (mounted) setState(() => _camErr = 'No camera found.');
      return;
    }
    try {
      final old = _cam;
      _cam = null;
      if (mounted) setState(() => _camReady = false);
      try {
        await old?.dispose();
      } catch (_) {}
      final camDesc = (_usingFront && widget.cameras.length > 1)
          ? widget.cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => widget.cameras.first,
            )
          : widget.cameras.first;
      final c = CameraController(
        camDesc,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _cam = c;
      await c.initialize();
      if (!mounted) {
        try {
          await c.dispose();
        } catch (_) {}
        _cam = null;
        return;
      }
      try {
        await c.setFocusMode(FocusMode.auto);
        await c.setExposureMode(ExposureMode.auto);
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (mounted)
        setState(() {
          _camReady = true;
          _camErr = null;
        });
    } catch (e) {
      debugPrint('[Doma] camera error: $e');
      if (mounted) setState(() => _camErr = 'Camera unavailable.');
    }
  }

  Future<void> _switchCam() async {
    if (widget.cameras.length < 2 || _busy) return;
    setState(() => _usingFront = !_usingFront);
    await _initCam();
  }

  Future<void> _capture() async {
    if (_cam == null || !_cam!.value.isInitialized || _busy) return;
    try {
      final f = await _cam!.takePicture();
      await _process(File(f.path));
    } catch (e) {
      debugPrint('[Doma] capture error: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    if (_busy) return;
    final f = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 95,
    );
    if (f != null) await _process(File(f.path));
  }

  Future<void> _process(File file) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _previewFile = file;
    });
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final result = await widget.classifier.detect(file);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _previewFile = null;
      });
      switch (result.state) {
        case _ScanState.notFound:
          if (mounted) _showDlg(const _NoCamoteDlg());
          return;
        case _ScanState.multipleVariants:
          if (mounted) _showDlg(const _MultipleVariantsDlg());
          return;
        case _ScanState.ok:
          break;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/camote_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await file.copy(path);
      final winner = result.winner;
      if (winner == null) {
        if (mounted) _showDlg(const _NoCamoteDlg());
        return;
      }
      final log = DetectionLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: path,
        results: [winner],
        timestamp: DateTime.now(),
      );
      await DetectionLogger.save(log);
      widget.onResult(log);
    } catch (e, st) {
      debugPrint('[Doma] process error: $e\n$st');
      if (mounted) {
        setState(() {
          _busy = false;
          _previewFile = null;
        });
        _showDlg(const _NoCamoteDlg());
      }
    }
  }

  void _showDlg(Widget dlg) =>
      showDialog(context: context, builder: (_) => dlg);

  Widget _camView() {
    if (_camErr != null)
      return Container(
        color: const Color(0xFF0D1F17),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white38,
                size: 48,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _camErr!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    if (!_camReady || _cam == null)
      return Container(
        color: const Color(0xFF0D1F17),
        child: const Center(
          child: CircularProgressIndicator(
            color: C.primaryMid,
            strokeWidth: 2.5,
          ),
        ),
      );
    final preview = _cam!.value.previewSize;
    if (preview == null) {
      return Container(
        color: const Color(0xFF0D1F17),
        child: const Center(
          child: CircularProgressIndicator(
            color: C.primaryMid,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    return OverflowBox(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(_cam!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _appBar(
        'Scan Camote',
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            color: C.textSec,
            tooltip: 'How to Use',
            onPressed: () => _showDlg(const _HowToDlg()),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: C.textSec,
            tooltip: 'About',
            onPressed: () => _showDlg(const _AboutDlg()),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Camera viewport ────────────────────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Camera feed ─────────────────────────────────────────
                if (_previewFile != null && !_busy)
                  Image.file(_previewFile!, fit: BoxFit.cover)
                else if (!_busy)
                  _camView()
                else
                  // When busy: show the captured image dimly underneath
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_previewFile != null)
                        Image.file(_previewFile!, fit: BoxFit.cover)
                      else
                        _camView(),
                    ],
                  ),

                // ── Scan line (only when camera is live, not busy) ──────
                if (!_busy)
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) => Positioned(
                      top: 24 + (_scanAnim.value * (screenH * 0.6)),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              C.primaryMid.withOpacity(0.7),
                              C.primaryMid.withOpacity(0.7),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Corner brackets (only when not busy) ────────────────
                if (!_busy)
                  AnimatedBuilder(
                    animation: _cornerAnim,
                    builder: (_, __) => Positioned.fill(
                      child: CustomPaint(
                        painter: _FP(_cornerAnim.value, busy: false),
                      ),
                    ),
                  ),

                // ── Analyzing overlay (replaces old scanning badge) ─────
                if (_busy) const _AnalyzingOverlay(),
              ],
            ),
          ),

          // ── Bottom action bar ──────────────────────────────────────────
          Container(
            color: C.bg,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gallery — left
                _ActionBtn(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: _busy ? null : _gallery,
                  busy: _busy,
                ),

                // Shutter — circle-in-circle style in primary green
                GestureDetector(
                  onTap: _busy ? null : _capture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _busy ? C.primaryDark : C.primary,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: C.primary.withOpacity(_busy ? 0.08 : 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _busy
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: C.primary,
                                strokeWidth: 2.5,
                                backgroundColor: C.primary.withOpacity(0.2),
                              ),
                            )
                          : Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                color: C.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                ),

                // Camera switch — right
                _ActionBtn(
                  icon: Icons.flip_camera_ios_outlined,
                  label: 'Flip',
                  onTap: _busy ? null : _switchCam,
                  busy: _busy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small action button used in the bottom bar ───────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: busy ? C.border : C.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: busy ? C.border : C.borderMid,
              width: 1.5,
            ),
            boxShadow: busy
                ? []
                : [
                    BoxShadow(
                      color: const Color(0x0F000000),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(icon, size: 22, color: busy ? C.textMuted : C.textSec),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: busy ? C.textMuted : C.textSec,
          ),
        ),
      ],
    ),
  );
}

// ── Scan frame painter ────────────────────────────────────────────────────────

class _FP extends CustomPainter {
  final double op;
  final bool busy;
  const _FP(this.op, {this.busy = false});

  @override
  void paint(Canvas c, Size s) {
    final color = busy
        ? C.primaryMid.withOpacity(math.max(op, 0.85))
        : C.primaryMid.withOpacity(op * 0.9 + 0.1);

    final p = Paint()
      ..color = color
      ..strokeWidth = busy ? 3.0 : 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const pad = 24.0;
    const l = 28.0;

    final topCorners = [
      [Offset(pad, pad + l), Offset(pad, pad), Offset(pad + l, pad)],
      [
        Offset(s.width - pad - l, pad),
        Offset(s.width - pad, pad),
        Offset(s.width - pad, pad + l),
      ],
    ];

    for (final pts in topCorners) {
      c.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy),
        p,
      );
    }

    final bottomCorners = [
      [
        Offset(pad, s.height - pad - l),
        Offset(pad, s.height - pad),
        Offset(pad + l, s.height - pad),
      ],
      [
        Offset(s.width - pad - l, s.height - pad),
        Offset(s.width - pad, s.height - pad),
        Offset(s.width - pad, s.height - pad - l),
      ],
    ];

    for (final pts in bottomCorners) {
      c.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_FP o) => o.op != op || o.busy != busy;
}

// ============================================================================
// DIALOG WIDGETS
// ============================================================================

class _WhiteDlg extends StatelessWidget {
  final Widget child;
  const _WhiteDlg({required this.child});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: C.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: child,
  );
}

class _NoCamoteDlg extends StatelessWidget {
  const _NoCamoteDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.errLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.search_off_rounded, color: C.err, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Camote Detected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: C.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Make sure the camote is clearly visible, well-lit, and centred in the frame!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.textSec, height: 1.55),
          ),
          const SizedBox(height: 24),
          _dlgBtnIcon(
            'Try Again',
            icon: Icons.replay_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _MultipleVariantsDlg extends StatelessWidget {
  const _MultipleVariantsDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.warnLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: C.warn,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Multiple Varieties Detected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: C.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'More than one camote variety was detected in this image. The scan has been rejected to ensure accuracy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.textSec, height: 1.55),
          ),
          const SizedBox(height: 24),
          _dlgBtnIcon(
            'Try Again',
            icon: Icons.replay_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _HowToDlg extends StatelessWidget {
  const _HowToDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: C.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: C.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'How to Use',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: C.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(Icons.close, size: 16, color: C.textSec),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _step(
                      1,
                      'Place ONE Camote',
                      'Put a single camote on a plain surface and centre it in the frame.',
                    ),
                    _step(
                      2,
                      'Capture',
                      'Tap the shutter or pick an image from your gallery.',
                    ),
                    _step(
                      3,
                      'Analyze',
                      'The AI model identifies the variety automatically.',
                    ),
                    _step(
                      4,
                      'View Results',
                      'See the variety name, confidence, shape, colours, and texture.',
                    ),
                    _step(
                      5,
                      'History & Library',
                      'Review past scans or browse all four varieties.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _dlgBtn('Got It!', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );

  Widget _step(int n, String t, String d) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: C.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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
                t,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                d,
                style: const TextStyle(
                  fontSize: 12,
                  color: C.textSec,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AboutDlg extends StatelessWidget {
  const _AboutDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.eco, color: C.primary, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'Doma',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: C.textPrimary,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Version 1.0',
              style: TextStyle(
                fontSize: 12,
                color: C.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A computer-vision app for identifying and classifying sweet potato (camote) varieties commonly found in Tacloban City, Leyte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.textSec, height: 1.55),
          ),
          const SizedBox(height: 22),
          _dlgBtn('Close', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

Widget _dlgBtn(String label, {required VoidCallback onTap}) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: C.primary,
      foregroundColor: C.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
);

Widget _dlgBtnIcon(
  String label, {
  required IconData icon,
  required VoidCallback onTap,
}) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: C.primary,
      foregroundColor: C.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: C.white),
      ],
    ),
  ),
);

// ============================================================================
// RESULTS PAGE
// ============================================================================

class ResultsPage extends StatefulWidget {
  final DetectionLog? result;
  const ResultsPage({super.key, this.result});
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage>
    with SingleTickerProviderStateMixin {
  DetectionLog? _r;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _r = widget.result;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (_r != null) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResultsPage old) {
    super.didUpdateWidget(old);
    if (widget.result != old.result) {
      setState(() => _r = widget.result);
      _ctrl.forward(from: 0);
    }
  }

  void update(DetectionLog log) {
    setState(() => _r = log);
    _ctrl.forward(from: 0);
  }

  CamoteVariety? _v(String cls) {
    try {
      return camoteVarieties.firstWhere(
        (v) => v.name.toLowerCase() == cls.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_r == null || _r!.results.isEmpty)
      return Scaffold(
        backgroundColor: C.bg,
        appBar: _appBar('Analysis Results'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.border, width: 2),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: C.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No results yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: C.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan a camote to see results here',
                style: TextStyle(fontSize: 13, color: C.textSec),
              ),
            ],
          ),
        ),
      );

    final top = _r!.results.first;
    final variety = _v(top.className);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: _appBar('Analysis Results'),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: File(_r!.imagePath).existsSync()
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(_r!.imagePath), fit: BoxFit.cover),
                            CustomPaint(painter: _BBPainter(det: top)),
                          ],
                        )
                      : Container(
                          color: C.bg,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 56,
                            color: C.textMuted,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    children: [
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader('Camote Variant'),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: C.border),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _varietyAccent(top.className),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        variety?.name ?? top.className.cap,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: C.textPrimary,
                                        ),
                                      ),
                                      if (variety != null) ...[
                                        Text(
                                          variety.commonName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: C.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          variety.scientificName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: C.textSec,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1, color: C.border),
                            const SizedBox(height: 16),
                            _ConfBar(top.confidence),
                          ],
                        ),
                      ),
                      if (variety != null) ...[
                        const SizedBox(height: 12),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader('Overview'),
                              const SizedBox(height: 10),
                              Text(
                                variety.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: C.textSec,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader('Characteristics'),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: C.border),
                              _CharRow(
                                Icons.straighten,
                                'Shape',
                                variety.shape,
                              ),
                              const Divider(height: 1, color: C.border),
                              _CharRow(
                                Icons.palette_outlined,
                                'Skin Color',
                                variety.skinColor,
                              ),
                              const Divider(height: 1, color: C.border),
                              _CharRow(
                                Icons.circle_outlined,
                                'Flesh Color',
                                variety.fleshColor,
                              ),
                              const Divider(height: 1, color: C.border),
                              _CharRow(
                                Icons.texture,
                                'Surface Texture',
                                variety.texture,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _logs = await DetectionLogger.load();
    setState(() => _loading = false);
  }

  void add(DetectionLog log) => setState(() => _logs.insert(0, log));

  Future<void> _del(DetectionLog log) async {
    setState(() => _loading = true);
    await DetectionLogger.delete(log.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _WhiteDlg(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: C.errLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: C.err, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'Clear All History?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: C.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'This will permanently delete all detection history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: C.textSec, height: 1.5),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: C.borderMid),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: C.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.err,
                        foregroundColor: C.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      setState(() => _loading = true);
      await DetectionLogger.clearAll();
      await _load();
    }
  }

  CamoteVariety? _v(String cls) {
    try {
      return camoteVarieties.firstWhere(
        (v) => v.name.toLowerCase() == cls.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _detail(DetectionLog log, DetectionResult? top, CamoteVariety? v) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DetailSheet(
          log: log,
          top: top,
          variety: v,
          onDelete: () async {
            await _del(log);
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: _appBar('Detection History'),
    body: Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_logs.length}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: C.primary,
                      ),
                    ),
                    Text(
                      _logs.length == 1 ? 'detection' : 'detections',
                      style: const TextStyle(fontSize: 12, color: C.textSec),
                    ),
                  ],
                ),
              ),
              if (_logs.isNotEmpty)
                GestureDetector(
                  onTap: _clearAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: C.errLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, color: C.err, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Clear',
                          style: TextStyle(
                            color: C.err,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: C.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.border, width: 2),
                        ),
                        child: const Icon(
                          Icons.history,
                          size: 40,
                          color: C.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No detection history',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: C.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan a camote to get started',
                        style: TextStyle(fontSize: 13, color: C.textSec),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: C.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      final top = log.results.isEmpty
                          ? null
                          : log.results.first;
                      final v = _v(top?.className ?? '');
                      return _HistoryCard(
                        log: log,
                        top: top,
                        variety: v,
                        index: i,
                        onTap: () => _detail(log, top, v),
                        onDelete: () => _del(log),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  final DetectionLog log;
  final DetectionResult? top;
  final CamoteVariety? variety;
  final int index;
  final VoidCallback onTap, onDelete;
  const _HistoryCard({
    required this.log,
    required this.top,
    required this.variety,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => _TappableCard(
    onTap: onTap,
    margin: const EdgeInsets.only(bottom: 10),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: _varietyAccent(top?.className ?? ''),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: SizedBox(
              width: 80,
              child: File(log.imagePath).existsSync()
                  ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                  : Container(
                      color: C.bg,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 24,
                        color: C.textMuted,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    top?.className.cap ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variety != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      variety!.commonName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: C.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: C.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          TimeFormatter.short(log.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: C.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        TimeFormatter.rel(log.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: C.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (top != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: C.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(top!.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 48,
            padding: const EdgeInsets.only(bottom: 12, right: 4),
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: C.errLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: C.err,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailSheet extends StatelessWidget {
  final DetectionLog log;
  final DetectionResult? top;
  final CamoteVariety? variety;
  final Future<void> Function() onDelete;
  const _DetailSheet({
    required this.log,
    this.top,
    this.variety,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.87,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (_, sc) => Container(
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detection Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: C.textSec,
                        ),
                      ),
                      if (top != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          top!.className.cap,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: C.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        if (variety != null)
                          Text(
                            variety!.commonName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: C.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(Icons.close, size: 16, color: C.textSec),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: C.border),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 240,
                    child: File(log.imagePath).existsSync()
                        ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                        : Container(
                            color: C.bg,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 56,
                              color: C.textMuted,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (top != null) ...[
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Confidence'),
                        const SizedBox(height: 14),
                        _ConfBar(top!.confidence),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Timestamp'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: C.textSec,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              TimeFormatter.full(log.timestamp),
                              style: const TextStyle(
                                fontSize: 13,
                                color: C.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: C.textSec,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TimeFormatter.rel(log.timestamp),
                            style: const TextStyle(
                              fontSize: 13,
                              color: C.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await onDelete();
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete this Detection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.err,
                      foregroundColor: C.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

// ============================================================================
// LIBRARY PAGE
// ============================================================================

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: _appBar('Crop Library'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ...camoteVarieties.map((v) => _VarietyCard(v)),
        ],
      ),
    ),
  );
}

class _VarietyCard extends StatelessWidget {
  final CamoteVariety v;
  const _VarietyCard(this.v);

  @override
  Widget build(BuildContext context) => _TappableCard(
    onTap: () => _show(context),
    margin: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(13),
            topRight: Radius.circular(13),
          ),
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: Image.asset(
              v.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: C.bg,
                child: const Center(
                  child: Icon(Icons.image, color: C.textMuted, size: 40),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: C.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      v.commonName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: C.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v.scientificName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: C.textSec,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: C.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: C.textPrimary,
                          ),
                        ),
                        Text(
                          v.commonName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: C.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.border),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: C.textSec,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: C.border),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(20),
                children: [
                  _ImageCarousel(imagePaths: v.imagePaths),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Characteristics'),
                        const SizedBox(height: 6),
                        _CharRow(Icons.straighten, 'Shape', v.shape),
                        const Divider(height: 1, color: C.border),
                        _CharRow(
                          Icons.palette_outlined,
                          'Skin Color',
                          v.skinColor,
                        ),
                        const Divider(height: 1, color: C.border),
                        _CharRow(
                          Icons.circle_outlined,
                          'Flesh Color',
                          v.fleshColor,
                        ),
                        const Divider(height: 1, color: C.border),
                        _CharRow(Icons.texture, 'Texture', v.texture),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Overview'),
                        const SizedBox(height: 10),
                        Text(
                          v.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: C.textSec,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Health Benefits'),
                        const SizedBox(height: 10),
                        ...v.benefits.map(_bullet),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Popular Dishes'),
                        const SizedBox(height: 10),
                        ...v.dishes.map(_bullet),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: C.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(fontSize: 13, color: C.textSec, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// EXTENSIONS
// ============================================================================

extension StringX on String {
  String get cap => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
