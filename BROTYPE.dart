// lib/main.dart  –  Doma Camote Classifier
// Refactored to match Calabash Fruit Detection app architecture:
//   1. Separate CameraDetectionPage (capture-then-analyze flow)
//   2. Separate GalleryDetectPage
//   3. Detection cards with cropped camote image + description popup
//   4. Calabash-style detection logging (cropped images saved per detection)
//   5. Full calabash inference pipeline (decodeYoloSmart, parseSimplifiedDetections,
//      mapBoxesToPreviewNormalized, nms, enhanceImageForDetection)
//   6. Multiple-detection support with scrollable cards dialog
//   7. Styled no-detection notification (gradient popup, auto-dismiss)

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
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
// APP & THEME
// ============================================================================

class DomaApp extends StatelessWidget {
  const DomaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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

class C {
  static const primary = Color(0xFF00875A);
  static const primaryLight = Color(0xFFE8F5E9);
  static const primaryMid = Color(0xFF00D97E);
  static const bg = Color(0xFFF8F9FA);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSec = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const err = Color(0xFFDC2626);
  static const white = Colors.white;
}

class TimeFormatter {
  static String rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}min ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  static String fmt(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year.toString().substring(2);
    int hour = dt.hour;
    final period = hour >= 12 ? 'pm' : 'am';
    if (hour == 0)
      hour = 12;
    else if (hour > 12)
      hour = hour - 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month/$day/$year  $hour:$minute $period';
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
  final List<String> benefits, dishes;
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
  ),
];

// ============================================================================
// DETECTION MODELS
// ============================================================================

class Detection {
  Rect box;
  int cls;
  double score;
  Detection(this.box, this.cls, this.score);
}

class DetectionLog {
  final String id;
  final String varietyName;
  final double accuracy;
  final String imagePath; // cropped image path
  final String fullImagePath; // full annotated image path
  final DateTime timestamp;
  final String detectionSource; // 'camera' or 'gallery'

  DetectionLog({
    required this.id,
    required this.varietyName,
    required this.accuracy,
    required this.imagePath,
    required this.fullImagePath,
    required this.timestamp,
    required this.detectionSource,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'varietyName': varietyName,
    'accuracy': accuracy,
    'imagePath': imagePath,
    'fullImagePath': fullImagePath,
    'timestamp': timestamp.toIso8601String(),
    'detectionSource': detectionSource,
  };

  factory DetectionLog.fromJson(Map<String, dynamic> j) => DetectionLog(
    id: j['id'],
    varietyName: j['varietyName'],
    accuracy: (j['accuracy'] as num).toDouble(),
    imagePath: j['imagePath'],
    fullImagePath: j['fullImagePath'] ?? j['imagePath'],
    timestamp: DateTime.parse(j['timestamp']),
    detectionSource: j['detectionSource'] ?? 'camera',
  );
}

class DetectionLogger {
  static const _logsDir = 'detection_logs';
  static const _imagesDir = 'detection_images';
  static const _logsFile = 'detection_logs.json';

  static Future<Directory> _getLogsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_logsDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _getImagesDir() async {
    final logs = await _getLogsDir();
    final dir = Directory('${logs.path}/$_imagesDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> _saveImage(img.Image image, String id) async {
    final dir = await _getImagesDir();
    final path = '${dir.path}/$id.jpg';
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 90));
    return path;
  }

  static Future<List<DetectionLog>> load() async {
    try {
      final dir = await _getLogsDir();
      final file = File('${dir.path}/$_logsFile');
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List;
      return list.map((e) => DetectionLog.fromJson(e)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Load logs error: $e');
      return [];
    }
  }

  static Future<DetectionLog> log({
    required img.Image croppedImage,
    required img.Image fullImage,
    required String varietyName,
    required double accuracy,
    required String source,
  }) async {
    final ts = DateTime.now();
    final id =
        '${ts.millisecondsSinceEpoch}_${varietyName.replaceAll(' ', '_')}';
    final croppedPath = await _saveImage(croppedImage, '${id}_crop');
    final fullPath = await _saveImage(fullImage, '${id}_full');

    final entry = DetectionLog(
      id: id,
      varietyName: varietyName,
      accuracy: accuracy,
      imagePath: croppedPath,
      fullImagePath: fullPath,
      timestamp: ts,
      detectionSource: source,
    );

    final existing = await load();
    existing.insert(0, entry);
    final dir = await _getLogsDir();
    await File(
      '${dir.path}/$_logsFile',
    ).writeAsString(jsonEncode(existing.map((e) => e.toJson()).toList()));
    return entry;
  }

  static Future<void> delete(DetectionLog log) async {
    try {
      for (final p in [log.imagePath, log.fullImagePath]) {
        final f = File(p);
        if (await f.exists()) await f.delete();
      }
      final existing = await load();
      existing.removeWhere((e) => e.id == log.id);
      final dir = await _getLogsDir();
      await File(
        '${dir.path}/$_logsFile',
      ).writeAsString(jsonEncode(existing.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Delete log error: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      final logsDir = await _getLogsDir();
      final imgDir = await _getImagesDir();
      if (await imgDir.exists()) {
        await imgDir.delete(recursive: true);
        await imgDir.create(recursive: true);
      }
      final f = File('${logsDir.path}/$_logsFile');
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('ClearAll error: $e');
    }
  }
}

// ============================================================================
// INFERENCE HELPERS  (ported from Calabash app)
// ============================================================================

extension ReshapeF on Float32List {
  List reshape(List<int> shape) => [
    List.generate(
      shape[1],
      (y) => List.generate(
        shape[2],
        (x) => [
          this[(y * shape[2] + x) * 3 + 0].toDouble(),
          this[(y * shape[2] + x) * 3 + 1].toDouble(),
          this[(y * shape[2] + x) * 3 + 2].toDouble(),
        ],
        growable: false,
      ),
      growable: false,
    ),
  ];
}

/// Resize large images, then adaptive brightness+contrast enhancement.
img.Image enhanceImageForDetection(img.Image image) {
  const maxDim = 1920;
  img.Image p = image;
  if (image.width > maxDim || image.height > maxDim) {
    final s = maxDim / math.max(image.width, image.height);
    p = img.copyResize(
      image,
      width: (image.width * s).round(),
      height: (image.height * s).round(),
      interpolation: img.Interpolation.linear,
    );
  }
  return _enhanceFast(p);
}

img.Image _enhanceFast(img.Image image) {
  double sR = 0, sG = 0, sB = 0;
  int cnt = 0;
  const step = 4;
  for (int y = 0; y < image.height; y += step) {
    for (int x = 0; x < image.width; x += step) {
      final px = image.getPixel(x, y);
      sR += px.r.toDouble();
      sG += px.g.toDouble();
      sB += px.b.toDouble();
      cnt++;
    }
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

  final out = img.Image(width: image.width, height: image.height);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final px = image.getPixel(x, y);
      double r = px.r.toDouble() * bF;
      double g = px.g.toDouble() * bF;
      double b = px.b.toDouble() * bF;
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
  }
  return out;
}

/// RGBA img.Image → letterboxed Float32 [size,size,3] with bilinear interp.
Float32List rgbaToLetterbox(img.Image im, int size) {
  final w = im.width, h = im.height;
  final out = Float32List(size * size * 3);
  final scale = math.min(size / w, size / h);
  final nW = (w * scale).floor(), nH = (h * scale).floor();
  final pX = ((size - nW) / 2).floor(), pY = ((size - nH) / 2).floor();
  const pad = 114.0 / 255.0;
  final inv = 1.0 / scale;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final p = (y * size + x) * 3;
      if (x < pX || x >= pX + nW || y < pY || y >= pY + nH) {
        out[p] = pad;
        out[p + 1] = pad;
        out[p + 2] = pad;
      } else {
        final sx = (x - pX) * inv, sy = (y - pY) * inv;
        final x0 = math.max(0, math.min(w - 1, (sx - 0.5).floor()));
        final y0 = math.max(0, math.min(h - 1, (sy - 0.5).floor()));
        final x1 = math.max(0, math.min(w - 1, x0 + 1));
        final y1 = math.max(0, math.min(h - 1, y0 + 1));
        final fx = (sx - x0 - 0.5).clamp(0.0, 1.0);
        final fy = (sy - y0 - 0.5).clamp(0.0, 1.0);
        final p00 = im.getPixel(x0, y0), p10 = im.getPixel(x1, y0);
        final p01 = im.getPixel(x0, y1), p11 = im.getPixel(x1, y1);
        double bi(num a, num b, num c, num d) =>
            (a * (1 - fx) * (1 - fy) +
                    b * fx * (1 - fy) +
                    c * (1 - fx) * fy +
                    d * fx * fy)
                .clamp(0, 255);
        out[p] = bi(p00.r, p10.r, p01.r, p11.r) / 255.0;
        out[p + 1] = bi(p00.g, p10.g, p01.g, p11.g) / 255.0;
        out[p + 2] = bi(p00.b, p10.b, p01.b, p11.b) / 255.0;
      }
    }
  }
  return out;
}

double _sig(double x) =>
    x >= 0 ? 1.0 / (1.0 + math.exp(-x)) : math.exp(x) / (1.0 + math.exp(x));

double _calibrate(double s) {
  if (s < 0.4) return s * 0.85;
  if (s < 0.6) return 0.4 + (s - 0.4) * 1.15;
  if (s < 0.75) return 0.63 + (s - 0.6) * 1.67;
  final e = s - 0.75;
  return (0.88 + e * 1.6 + e * e * 2.0).clamp(0.0, 1.0);
}

List<Detection> decodeYoloSmart(
  List<List<double>> preds,
  int numClasses,
  int inputSize, {
  double confThres = 0.55,
  int topK = 100,
}) {
  final dets = <Detection>[];
  for (final p in preds) {
    if (p.length < 4 + numClasses) continue;
    double best = 0.0;
    int bestCls = -1;
    for (int c = 0; c < numClasses; c++) {
      final s = _calibrate(_sig(p[4 + c]));
      if (s > best) {
        best = s;
        bestCls = c;
      }
    }
    if (best < confThres || bestCls < 0) continue;

    double cx = p[0], cy = p[1], w = p[2], h = p[3];
    final norm =
        cx.abs() <= 1.5 && cy.abs() <= 1.5 && w.abs() <= 1.5 && h.abs() <= 1.5;
    if (norm) {
      cx *= inputSize;
      cy *= inputSize;
      w *= inputSize;
      h *= inputSize;
    }
    double x1 = cx - w / 2, y1 = cy - h / 2, x2 = cx + w / 2, y2 = cy + h / 2;
    if (x2 <= x1 || y2 <= y1) {
      x1 = cx;
      y1 = cy;
      x2 = w;
      y2 = h;
    }
    if (x2 < -5 || y2 < -5 || x1 > inputSize + 5 || y1 > inputSize + 5)
      continue;
    final bw = x2 - x1, bh = y2 - y1;
    final mn = inputSize * 0.03, mx = inputSize * 0.95;
    if (bw < mn || bh < mn || bw > mx || bh > mx) continue;
    dets.add(Detection(Rect.fromLTRB(x1, y1, x2, y2), bestCls, best));
  }
  dets.sort((a, b) => b.score.compareTo(a.score));
  return dets.length > topK ? dets.sublist(0, topK) : dets;
}

List<Detection> parseSimplified(
  List<List<double>> rows, {
  required double confThres,
}) {
  final out = <Detection>[];
  for (final row in rows) {
    if (row.length < 6) continue;
    final x1 = row[0], y1 = row[1], x2 = row[2], y2 = row[3];
    double score = _calibrate(row[4]);
    final cls = row[5].toInt();
    if (score < confThres || x2 <= x1 || y2 <= y1) continue;
    final bw = x2 - x1, bh = y2 - y1;
    final est = math.max(x2, y2);
    final mn = est * 0.03, mx = est * 0.95;
    if (bw < mn || bh < mn || bw > mx || bh > mx) continue;
    out.add(Detection(Rect.fromLTRB(x1, y1, x2, y2), cls, score));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out.length > 100 ? out.sublist(0, 100) : out;
}

List<Detection> mapBoxesNorm(
  List<Detection> dets,
  double srcW,
  double srcH,
  double inSize, {
  required int quarterTurns,
  bool mirror = false,
}) {
  final scale = math.min(inSize / srcW, inSize / srcH);
  final padX = (inSize - srcW * scale) / 2.0;
  final padY = (inSize - srcH * scale) / 2.0;
  final double rotW = quarterTurns % 2 == 0 ? srcW : srcH;
  final double rotH = quarterTurns % 2 == 0 ? srcH : srcW;

  Offset rp(Offset p, double w, double h, int q) {
    switch (q % 4) {
      case 1:
        return Offset(p.dy, w - p.dx);
      case 2:
        return Offset(w - p.dx, h - p.dy);
      case 3:
        return Offset(h - p.dy, p.dx);
      default:
        return p;
    }
  }

  Rect rr(Rect r, double w, double h, int q) {
    final pts = [
      rp(Offset(r.left, r.top), w, h, q),
      rp(Offset(r.right, r.top), w, h, q),
      rp(Offset(r.left, r.bottom), w, h, q),
      rp(Offset(r.right, r.bottom), w, h, q),
    ];
    final xs = pts.map((p) => p.dx).toList()..sort();
    final ys = pts.map((p) => p.dy).toList()..sort();
    return Rect.fromLTRB(xs.first, ys.first, xs.last, ys.last);
  }

  final out = <Detection>[];
  for (final d in dets) {
    final x1 = (d.box.left - padX) / scale;
    final y1 = (d.box.top - padY) / scale;
    final x2 = (d.box.right - padX) / scale;
    final y2 = (d.box.bottom - padY) / scale;
    Rect r = Rect.fromLTRB(x1, y1, x2, y2);
    r = rr(r, srcW, srcH, quarterTurns);
    if (mirror)
      r = Rect.fromLTRB(rotW - r.right, r.top, rotW - r.left, r.bottom);
    final nx1 = (r.left / rotW).clamp(0.0, 1.0);
    final ny1 = (r.top / rotH).clamp(0.0, 1.0);
    final nx2 = (r.right / rotW).clamp(0.0, 1.0);
    final ny2 = (r.bottom / rotH).clamp(0.0, 1.0);
    if (nx2 - nx1 > 0.01 && ny2 - ny1 > 0.01) {
      out.add(Detection(Rect.fromLTRB(nx1, ny1, nx2, ny2), d.cls, d.score));
    }
  }
  return out;
}

double _iou(Rect a, Rect b) {
  final il = math.max(a.left, b.left), it = math.max(a.top, b.top);
  final ir = math.min(a.right, b.right), ib = math.min(a.bottom, b.bottom);
  final iA = math.max(0.0, ir - il) * math.max(0.0, ib - it);
  final u = a.width * a.height + b.width * b.height - iA;
  return u <= 0 ? 0 : iA / u;
}

List<Detection> nms(List<Detection> dets, {double iouThres = 0.40}) {
  if (dets.isEmpty) return [];
  dets.sort((a, b) => b.score.compareTo(a.score));
  final sup = List<bool>.filled(dets.length, false);
  final keep = <Detection>[];
  for (int i = 0; i < dets.length; i++) {
    if (sup[i]) continue;
    keep.add(dets[i]);
    for (int j = i + 1; j < dets.length; j++) {
      if (sup[j]) continue;
      final ov = _iou(dets[i].box, dets[j].box);
      final szRatio =
          (dets[i].box.width * dets[i].box.height) /
          (dets[j].box.width * dets[j].box.height + 1e-9);
      final simSz = szRatio > 0.7 && szRatio < 1.43;
      if ((dets[i].cls == dets[j].cls && ov > iouThres) ||
          ov > 0.50 ||
          (ov > 0.30 && simSz && dets[i].cls == dets[j].cls)) {
        sup[j] = true;
      }
    }
  }
  return keep.length > 10 ? keep.sublist(0, 10) : keep;
}

// ============================================================================
// LABELS
// ============================================================================

const List<String> kLabels = ['kadabaw', 'kadulaw', 'minamon', 'tapol'];

CamoteVariety? varietyFor(String cls) {
  try {
    return camoteVarieties.firstWhere(
      (v) => v.name.toLowerCase() == cls.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
}

Color varietyColor(String cls) {
  switch (cls.toLowerCase()) {
    case 'kadulaw':
      return const Color(0xFFE85D04);
    case 'minamon':
      return const Color(0xFFD4A017);
    case 'tapol':
      return const Color(0xFF7B2D8B);
    case 'kadabaw':
      return const Color(0xFF6A1BE0);
    default:
      return C.primary;
  }
}

// ============================================================================
// SHARED INFERENCE MIXIN
// ============================================================================

mixin InferenceMixin {
  Interpreter? get interpreter;
  int get inputSize;

  List<List<double>> runSimplified(Float32List input) {
    final s = interpreter!.getOutputTensor(0).shape;
    final rows = s.length == 3 ? s[1] : s[0];
    final out = List.generate(rows, (_) => List<double>.filled(6, 0.0));
    interpreter!.run(
      input.reshape([1, inputSize, inputSize, 3]),
      s.length == 3 ? [out] : out,
    );
    return out;
  }

  List<List<double>> runOldStyle(Float32List input) {
    final nCls = kLabels.length;
    final C = 4 + nCls;
    final s = interpreter!.getOutputTensor(0).shape;
    late bool tr;
    late int N;
    if (s.length == 3 && s[1] == C) {
      tr = true;
      N = s[2];
    } else if (s.length == 3 && s[2] == C) {
      tr = false;
      N = s[1];
    } else if (s.length == 2 && s[1] == C) {
      tr = false;
      N = s[0];
    } else {
      tr = true;
      N = s.length == 3 ? s[2] : s[0];
    }

    final buf = tr
        ? List.generate(
            1,
            (_) => List.generate(C, (_) => List<double>.filled(N, 0.0)),
          )
        : List.generate(
            1,
            (_) => List.generate(N, (_) => List<double>.filled(C, 0.0)),
          );
    interpreter!.run(input.reshape([1, inputSize, inputSize, 3]), buf);
    if (!tr) return buf[0];
    final preds = List.generate(N, (_) => List<double>.filled(C, 0.0));
    for (int c = 0; c < C; c++)
      for (int n = 0; n < N; n++) preds[n][c] = buf[0][c][n];
    return preds;
  }

  List<Detection> runInference(img.Image image) {
    final outShape = interpreter!.getOutputTensor(0).shape;
    final input = rgbaToLetterbox(image, inputSize);
    final isSimple =
        (outShape.length == 3 && outShape[2] == 6) ||
        (outShape.length == 2 && outShape[1] == 6);

    final raw = isSimple
        ? parseSimplified(runSimplified(input), confThres: 0.55)
        : decodeYoloSmart(
            runOldStyle(input),
            kLabels.length,
            inputSize,
            confThres: 0.55,
          );

    final mapped = mapBoxesNorm(
      raw,
      image.width.toDouble(),
      image.height.toDouble(),
      inputSize.toDouble(),
      quarterTurns: 0,
      mirror: false,
    );
    return nms(mapped, iouThres: 0.45);
  }
}

// ============================================================================
// BOX PAINTER
// ============================================================================

class BoxPainter extends CustomPainter {
  final List<Detection> dets;
  final double strokeWidth;
  const BoxPainter(this.dets, {this.strokeWidth = 3.5});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dets) {
      final color = varietyColor(
        d.cls >= 0 && d.cls < kLabels.length ? kLabels[d.cls] : '',
      );
      final boxP = Paint()
        ..color = C.primary
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final r = Rect.fromLTWH(
        d.box.left * size.width,
        d.box.top * size.height,
        d.box.width * size.width,
        d.box.height * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        boxP,
      );

      // Corner accents
      const cl = 18.0;
      final cp = Paint()
        ..color = C.primary
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      void corner(Offset a, Offset b, Offset c) {
        canvas.drawLine(a, b, cp);
        canvas.drawLine(a, c, cp);
      }

      corner(
        Offset(r.left, r.top),
        Offset(r.left + cl, r.top),
        Offset(r.left, r.top + cl),
      );
      corner(
        Offset(r.right, r.top),
        Offset(r.right - cl, r.top),
        Offset(r.right, r.top + cl),
      );
      corner(
        Offset(r.left, r.bottom),
        Offset(r.left + cl, r.bottom),
        Offset(r.left, r.bottom - cl),
      );
      corner(
        Offset(r.right, r.bottom),
        Offset(r.right - cl, r.bottom),
        Offset(r.right, r.bottom - cl),
      );

      final lbl = d.cls >= 0 && d.cls < kLabels.length
          ? '${kLabels[d.cls].cap}  ${(d.score * 100).toStringAsFixed(1)}%'
          : '${(d.score * 100).toStringAsFixed(1)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: lbl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      const pad = 6.0;
      final bg = Rect.fromLTWH(
        r.left,
        math.max(0, r.top - tp.height - pad * 2),
        tp.width + pad * 2,
        tp.height + pad * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(5)),
        Paint()..color = C.primary.withOpacity(0.92),
      );
      tp.paint(canvas, Offset(bg.left + pad, bg.top + pad));
    }
  }

  @override
  bool shouldRepaint(BoxPainter o) => o.dets != dets;
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
  int _idx = 0;
  final _hKey = GlobalKey<_HistoryPageState>();

  void _onLogged() => _hKey.currentState?.reload();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _idx,
      children: [
        ScanMenuPage(cameras: _cameras, onLogged: _onLogged),
        HistoryPage(key: _hKey),
        const LibraryPage(),
      ],
    ),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _nb(0, Icons.home_outlined, Icons.home, 'Home'),
              _nb(1, Icons.history_outlined, Icons.history, 'History'),
              _nb(
                2,
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

  Widget _nb(int i, IconData ico, IconData aIco, String lbl) {
    final sel = _idx == i;
    return GestureDetector(
      onTap: () => setState(() => _idx = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? C.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sel ? aIco : ico,
              color: sel ? C.primary : C.textSec,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              lbl,
              style: TextStyle(
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? C.primary : C.textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCAN MENU PAGE  (mirrors Calabash MainInterface)
// ============================================================================

class ScanMenuPage extends StatelessWidget {
  final List<CameraDescription> cameras;
  final VoidCallback onLogged;
  const ScanMenuPage({
    super.key,
    required this.cameras,
    required this.onLogged,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.primary, const Color(0xFF005C3D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Doma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (v) {
                    if (v == 'about') {
                      showDialog(
                        context: context,
                        builder: (_) => const _AboutDlg(),
                      );
                    } else if (v == 'how') {
                      showDialog(
                        context: context,
                        builder: (_) => const _HowToDlg(),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    _pmi('about', Icons.info_outline, 'About Us'),
                    _pmi('how', Icons.help_outline, 'How to Use'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  // Title section
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => LinearGradient(
                          colors: [C.primary, const Color(0xFF38EF7D)],
                        ).createShader(b),
                        child: const Text(
                          'Camote Classifier',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Variety Detection System',
                        style: TextStyle(
                          fontSize: 16,
                          color: C.textSec,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 3,
                        width: 70,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [C.primary, Color(0xFF38EF7D)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Choose your detection method',
                        style: TextStyle(fontSize: 14, color: C.textSec),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _menuBtn(
                    context: context,
                    icon: Icons.camera_alt,
                    title: 'Open Camera',
                    subtitle: 'Capture & detect camote variety',
                    g1: const Color(0xFF00875A),
                    g2: const Color(0xFF005C3D),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraDetectionPage(
                          cameras: cameras,
                          onLogged: onLogged,
                        ),
                      ),
                    ),
                  ),
                  _menuBtn(
                    context: context,
                    icon: Icons.image,
                    title: 'Pick from Gallery',
                    subtitle: 'Detect variety from an image',
                    g1: const Color(0xFF11998E),
                    g2: const Color(0xFF38EF7D),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GalleryDetectPage(onLogged: onLogged),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Text(
                    'Powered by Machine Learning · Tacloban City, Leyte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: C.textSec.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  PopupMenuItem<String> _pmi(String v, IconData icon, String lbl) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, color: C.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              lbl,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  Widget _menuBtn({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color g1,
    required Color g2,
    required VoidCallback onTap,
  }) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      width: w * 0.9,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: g1.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g1, g2],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
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
// SHARED DETECTION HELPERS
// ============================================================================

img.Image? cropDetection(img.Image src, Detection d) {
  final l = (d.box.left * src.width).round().clamp(0, src.width);
  final t = (d.box.top * src.height).round().clamp(0, src.height);
  final r = (d.box.right * src.width).round().clamp(0, src.width);
  final b = (d.box.bottom * src.height).round().clamp(0, src.height);
  final w = (r - l).clamp(1, src.width);
  final h = (b - t).clamp(1, src.height);
  if (w <= 0 || h <= 0) return null;
  return img.copyCrop(src, x: l, y: t, width: w, height: h);
}

String varietyDescription(String cls) {
  switch (cls.toLowerCase()) {
    case 'kadulaw':
      return 'Kadulaw (Orange Sweet Potato) has light orange to peach skin with '
          'vibrant orange flesh. It is rich in beta-carotene and antioxidants, '
          'making it excellent for supporting the immune system, skin health, '
          'and vision. Commonly used in Camote Cue, Camote Fries, and Ginataang Bilo-Bilo.';
    case 'minamon':
      return 'Minamon (Yellow Sweet Potato) has yellow to tan skin with bright '
          'yellow flesh and a characteristic bent shape with lumpy texture. It is '
          'rich in complex carbohydrates and fiber, providing sustained energy and '
          'supporting digestion. Popular in Nilupak and Minatamis na Camote.';
    case 'tapol':
      return 'Tapol (White Sweet Potato) has white to cream skin with striking '
          'purple flesh. It has a mild, subtle flavor, is easy to digest, and '
          'has a low glycemic index making it suitable for various diets. '
          'Used in Turon na Camote, Camote Halaya, and White Camote Dumplings.';
    case 'kadabaw':
      return 'Kadabaw (Violet Sweet Potato) has distinctive violet to reddish-purple '
          'skin with bright yellow flesh. It is high in anthocyanins — powerful '
          'antioxidants with anti-inflammatory properties that support brain health '
          'and reduce chronic-disease risk. Often boiled or used in Camote Mash.';
    default:
      return 'Sweet potato (camote) variety detected. Camotes are nutritious root '
          'vegetables rich in vitamins, fiber, and antioxidants.';
  }
}

void showNoDetectionDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00875A), Color(0xFF005C3D)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: C.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.search_off,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Camote Detected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Place the camote on a plain surface,\nensure good lighting, and try again.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
  Future.delayed(const Duration(seconds: 3), () {
    // pop only if still mounted & dialog is showing
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  });
}

void showAllDetectionCards(
  BuildContext context,
  List<Detection> dets,
  img.Image src,
  List<DetectionLog> logs,
) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected (${dets.length})',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: C.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: C.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: C.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: dets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (ctx, i) => _DetectionCard(
                  detection: dets[i],
                  src: src,
                  number: i + 1,
                  log: i < logs.length ? logs[i] : null,
                  onViewDesc: (lbl, desc) => _showDescPopup(ctx, lbl, desc),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showDescPopup(BuildContext context, String lbl, String desc) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: varietyColor(lbl),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lbl.cap,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: C.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: C.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Description & Benefits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.primary.withOpacity(0.2)),
              ),
              child: Text(
                desc,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: C.textPrimary,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetectionCard extends StatelessWidget {
  final Detection detection;
  final img.Image src;
  final int number;
  final DetectionLog? log;
  final void Function(String lbl, String desc) onViewDesc;
  const _DetectionCard({
    required this.detection,
    required this.src,
    required this.number,
    required this.log,
    required this.onViewDesc,
  });

  @override
  Widget build(BuildContext context) {
    final cls = detection.cls >= 0 && detection.cls < kLabels.length
        ? kLabels[detection.cls]
        : 'unknown';
    final conf = (detection.score * 100).toStringAsFixed(0);
    final cropped = cropDetection(src, detection);
    final croppedBytes = cropped != null
        ? Uint8List.fromList(img.encodeJpg(cropped, quality: 92))
        : null;
    final variety = varietyFor(cls);
    final color = varietyColor(cls);
    final desc = varietyDescription(cls);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Camote #$number',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cls.cap,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$conf%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (croppedBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: Image.memory(
                  croppedBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.error, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
          if (variety != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _row(Icons.straighten, 'Shape', variety.shape),
                  const SizedBox(height: 4),
                  _row(Icons.palette_outlined, 'Skin', variety.skinColor),
                  const SizedBox(height: 4),
                  _row(Icons.circle_outlined, 'Flesh', variety.fleshColor),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => onViewDesc(cls, desc),
            icon: const Icon(Icons.info_outline, size: 17),
            label: const Text(
              'View Description & Benefits',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String lbl, String val) => Row(
    children: [
      Icon(icon, size: 14, color: C.primary),
      const SizedBox(width: 8),
      SizedBox(
        width: 50,
        child: Text(
          lbl,
          style: const TextStyle(
            fontSize: 11,
            color: C.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Text(
          val,
          style: const TextStyle(
            fontSize: 11,
            color: C.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

// ============================================================================
// CAMERA DETECTION PAGE  (mirrors Calabash DetectionPage)
// ============================================================================

class CameraDetectionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final VoidCallback onLogged;
  const CameraDetectionPage({
    super.key,
    required this.cameras,
    required this.onLogged,
  });
  @override
  State<CameraDetectionPage> createState() => _CameraDetectionPageState();
}

class _CameraDetectionPageState extends State<CameraDetectionPage>
    with WidgetsBindingObserver, InferenceMixin {
  @override
  Interpreter? interpreter;
  @override
  int inputSize = 640;

  CameraController? _cam;
  bool _camReady = false;
  int _quarterTurns = 0;
  bool _mirror = false;

  Uint8List? _capturedBytes;
  img.Image? _capturedDecoded;
  List<Detection> _dets = [];
  List<DetectionLog> _logs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    interpreter?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_cam == null || !_cam!.value.isInitialized) return;
    if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused) {
      try {
        _cam!.pausePreview();
      } catch (_) {}
    } else if (s == AppLifecycleState.resumed) {
      try {
        _cam!.resumePreview();
      } catch (_) {}
    }
  }

  Future<void> _init() async {
    // Load interpreter
    interpreter = await Interpreter.fromAsset(
      'assets/model.tflite',
      options: InterpreterOptions()
        ..threads = 6
        ..useNnApiForAndroid = true,
    );
    final inShape = interpreter!.getInputTensor(0).shape;
    if (inShape.length == 4 && inShape[1] > 0) inputSize = inShape[1];

    // Init camera
    if (widget.cameras.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final back = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    _cam = CameraController(
      back,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cam!.initialize();
    try {
      await _cam!.setFlashMode(FlashMode.off);
      await _cam!.setFocusMode(FocusMode.auto);
      await _cam!.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    _quarterTurns = (_cam!.description.sensorOrientation ~/ 90) % 4;
    _mirror = _cam!.description.lensDirection == CameraLensDirection.front;
    if (mounted) setState(() => _camReady = true);
  }

  Future<void> _captureAndDetect() async {
    if (_cam == null ||
        !_cam!.value.isInitialized ||
        interpreter == null ||
        _busy)
      return;
    setState(() {
      _busy = true;
      _dets = [];
      _logs = [];
    });
    try {
      final shot = await _cam!.takePicture();
      var decoded = img.decodeImage(await shot.readAsBytes());
      if (decoded == null) {
        setState(() => _busy = false);
        return;
      }

      if (_quarterTurns % 4 != 0)
        decoded = img.copyRotate(decoded, angle: 90 * _quarterTurns);
      if (_mirror) decoded = img.flipHorizontal(decoded);
      decoded = enhanceImageForDetection(decoded);

      final kept = runInference(decoded);
      final display = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));

      // Log each detection
      final newLogs = <DetectionLog>[];
      for (final d in kept) {
        final cls = d.cls >= 0 && d.cls < kLabels.length
            ? kLabels[d.cls]
            : 'unknown';
        final cropped = cropDetection(decoded, d);
        if (cropped != null) {
          final l = await DetectionLogger.log(
            croppedImage: cropped,
            fullImage: decoded,
            varietyName: cls,
            accuracy: d.score,
            source: 'camera',
          );
          newLogs.add(l);
        }
      }
      widget.onLogged();

      if (mounted) {
        setState(() {
          _capturedBytes = display;
          _capturedDecoded = decoded;
          _dets = kept;
          _logs = newLogs;
          _busy = false;
        });
        if (kept.isEmpty) {
          showNoDetectionDialog(context);
        } else {
          showAllDetectionCards(context, kept, decoded, newLogs);
        }
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearCapture() => setState(() {
    _capturedBytes = null;
    _capturedDecoded = null;
    _dets = [];
    _logs = [];
  });

  @override
  Widget build(BuildContext context) {
    final hasShot = _capturedBytes != null && _capturedDecoded != null;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [C.primary, const Color(0xFF005C3D)],
            ),
          ),
          child: AppBar(
            title: const Text(
              'Capture Detection',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (hasShot && _dets.isNotEmpty && _capturedDecoded != null)
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  tooltip: 'View results',
                  onPressed: _busy
                      ? null
                      : () => showAllDetectionCards(
                          context,
                          _dets,
                          _capturedDecoded!,
                          _logs,
                        ),
                ),
              if (hasShot)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Retake',
                  onPressed: _busy ? null : _clearCapture,
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: interpreter == null
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [C.primary, Color(0xFF005C3D)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: C.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _busy ? null : _captureAndDetect,
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera, color: Colors.white),
                label: Text(
                  _busy
                      ? 'Processing…'
                      : hasShot
                      ? 'Capture Again'
                      : 'Capture',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
      body: Center(
        child: (!_camReady || _cam == null)
            ? const CircularProgressIndicator(color: C.primary)
            : hasShot
            ? _capturedView()
            : _liveView(),
      ),
    );
  }

  Widget _liveView() {
    final ps = _cam!.value.previewSize!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: ps.height,
        height: ps.width,
        child: CameraPreview(_cam!),
      ),
    );
  }

  Widget _capturedView() {
    final iw = _capturedDecoded!.width.toDouble();
    final ih = _capturedDecoded!.height.toDouble();
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: iw,
        height: ih,
        child: Stack(
          children: [
            Positioned.fill(child: Image.memory(_capturedBytes!)),
            Positioned.fill(child: CustomPaint(painter: BoxPainter(_dets))),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x22000000),
                  child: Center(
                    child: CircularProgressIndicator(color: C.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GALLERY DETECT PAGE  (mirrors Calabash GalleryDetectPage)
// ============================================================================

class GalleryDetectPage extends StatefulWidget {
  final VoidCallback onLogged;
  const GalleryDetectPage({super.key, required this.onLogged});
  @override
  State<GalleryDetectPage> createState() => _GalleryDetectPageState();
}

class _GalleryDetectPageState extends State<GalleryDetectPage>
    with InferenceMixin {
  @override
  Interpreter? interpreter;
  @override
  int inputSize = 640;

  Uint8List? _imageBytes;
  img.Image? _decoded;
  List<Detection> _dets = [];
  List<DetectionLog> _logs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    interpreter = await Interpreter.fromAsset(
      'assets/model.tflite',
      options: InterpreterOptions()
        ..threads = 6
        ..useNnApiForAndroid = true,
    );
    final s = interpreter!.getInputTensor(0).shape;
    if (s.length == 4 && s[1] > 0) inputSize = s[1];
    if (mounted) setState(() {});
  }

  Future<void> _pickAndRun() async {
    if (interpreter == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 95,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to decode image.')));
      return;
    }
    decoded = enhanceImageForDetection(decoded);
    setState(() {
      _imageBytes = bytes;
      _decoded = decoded;
      _dets = [];
      _busy = true;
    });

    try {
      final kept = runInference(decoded);
      final newLogs = <DetectionLog>[];
      for (final d in kept) {
        final cls = d.cls >= 0 && d.cls < kLabels.length
            ? kLabels[d.cls]
            : 'unknown';
        final cropped = cropDetection(decoded, d);
        if (cropped != null) {
          final l = await DetectionLogger.log(
            croppedImage: cropped,
            fullImage: decoded,
            varietyName: cls,
            accuracy: d.score,
            source: 'gallery',
          );
          newLogs.add(l);
        }
      }
      widget.onLogged();

      if (mounted) {
        setState(() {
          _dets = kept;
          _logs = newLogs;
          _busy = false;
        });
        if (kept.isEmpty) {
          showNoDetectionDialog(context);
        } else {
          showAllDetectionCards(context, kept, decoded, newLogs);
        }
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = _imageBytes != null && _decoded != null;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
            ),
          ),
          child: AppBar(
            title: const Text(
              'Image Detection',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (hasImg && _dets.isNotEmpty && _decoded != null)
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  tooltip: 'View results',
                  onPressed: _busy
                      ? null
                      : () => showAllDetectionCards(
                          context,
                          _dets,
                          _decoded!,
                          _logs,
                        ),
                ),
              IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.white),
                tooltip: 'Pick image',
                onPressed: interpreter == null ? null : _pickAndRun,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: interpreter == null
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF11998E).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _pickAndRun,
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.image_search, color: Colors.white),
                label: const Text(
                  'Pick Image',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
      body: Center(
        child: interpreter == null
            ? const CircularProgressIndicator(color: C.primary)
            : !hasImg
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_search,
                    size: 72,
                    color: C.textSec.withOpacity(0.3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pick an image to run detection.',
                    style: TextStyle(fontSize: 15, color: C.textSec),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (_, c) {
                  final iw = _decoded!.width.toDouble();
                  final ih = _decoded!.height.toDouble();
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: iw,
                      height: ih,
                      child: Stack(
                        children: [
                          Positioned.fill(child: Image.memory(_imageBytes!)),
                          Positioned.fill(
                            child: CustomPaint(painter: BoxPainter(_dets)),
                          ),
                          if (_busy)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x22000000),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: C.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
    if (mounted) setState(() => _loading = false);
  }

  void reload() => _load();

  Future<void> _delete(DetectionLog log) async {
    setState(() => _loading = true);
    await DetectionLogger.delete(log);
    await _load();
  }

  Future<void> _clearAll() async {
    if (_logs.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Clear All History?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This will permanently delete all ${_logs.length} detection logs.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: C.textSec,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: const BorderSide(color: C.border),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
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

  void _showDetail(DetectionLog log) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detection Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        log.varietyName.cap,
                        style: TextStyle(
                          fontSize: 15,
                          color: varietyColor(log.varietyName),
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
                      color: C.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Show full image if available, else cropped
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 240,
                child: File(log.fullImagePath).existsSync()
                    ? Image.file(File(log.fullImagePath), fit: BoxFit.cover)
                    : File(log.imagePath).existsSync()
                    ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Confidence
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: C.primary, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Confidence',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Score',
                        style: TextStyle(fontSize: 13, color: C.textSec),
                      ),
                      Text(
                        '${(log.accuracy * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: C.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: log.accuracy,
                      minHeight: 8,
                      backgroundColor: C.border.withOpacity(0.4),
                      valueColor: const AlwaysStoppedAnimation(C.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Time & source
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: C.primary, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Detection Info',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _tc('Date/Time', TimeFormatter.fmt(log.timestamp)),
                      _tc(
                        'Source',
                        log.detectionSource == 'camera'
                            ? '📷 Camera'
                            : '🖼 Gallery',
                      ),
                      _tcG('Ago', TimeFormatter.rel(log.timestamp)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _delete(log);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Detection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.err,
                  foregroundColor: C.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tc(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(fontSize: 11, color: C.textSec)),
      const SizedBox(height: 3),
      Text(
        v,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _tcG(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(fontSize: 11, color: C.textSec)),
      const SizedBox(height: 3),
      Text(
        v,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: C.primary,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.white,
      surfaceTintColor: C.white,
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
          const Text(
            'Detection History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: C.textPrimary,
            ),
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detection History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_logs.length} record${_logs.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: C.textSec),
                  ),
                ],
              ),
              if (_logs.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: C.err,
                    size: 15,
                  ),
                  label: const Text(
                    'Clear',
                    style: TextStyle(color: C.err, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: C.err),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 70,
                        color: C.textSec.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No detection history',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: C.textSec,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: C.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      return _HistoryCard(
                        log: log,
                        onTap: () => _showDetail(log),
                        onDelete: () => _delete(log),
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
  final VoidCallback onTap, onDelete;
  const _HistoryCard({
    required this.log,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 60,
            height: 60,
            child: File(log.imagePath).existsSync()
                ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 24,
                      color: Colors.grey[400],
                    ),
                  ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.varietyName.cap,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              varietyFor(log.varietyName)?.commonName ?? '',
              style: TextStyle(
                fontSize: 11,
                color: varietyColor(log.varietyName),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: C.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(log.accuracy * 100).toStringAsFixed(0)}% match',
                  style: const TextStyle(
                    fontSize: 10,
                    color: C.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                log.detectionSource == 'camera'
                    ? Icons.camera_alt
                    : Icons.image,
                size: 10,
                color: C.textSec.withOpacity(0.6),
              ),
              const SizedBox(width: 3),
              Text(
                TimeFormatter.rel(log.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: C.textSec.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 17, color: C.err),
          padding: EdgeInsets.zero,
          onPressed: onDelete,
        ),
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
    appBar: AppBar(
      backgroundColor: C.white,
      surfaceTintColor: C.white,
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
          const Text(
            'Crop Library',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: C.textPrimary,
            ),
          ),
        ],
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Camote Varieties',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Doma can classify 4 varieties commonly found in Tacloban City.',
            style: TextStyle(fontSize: 13, color: C.textSec, height: 1.45),
          ),
          const SizedBox(height: 14),
          ...camoteVarieties.map((v) => _VC(v)),
        ],
      ),
    ),
  );
}

class _VC extends StatelessWidget {
  final CamoteVariety v;
  const _VC(this.v);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _show(context),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: SizedBox(
                width: 110,
                child: Image.asset(
                  v.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: C.primary,
                        ),
                      ],
                    ),
                    Text(
                      v.commonName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: C.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      v.scientificName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: C.textSec,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _m('Skin', v.skinColor),
                    _m('Flesh', v.fleshColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _m(String l, String val) => Row(
    children: [
      Text(
        '$l: ',
        style: const TextStyle(
          fontSize: 11,
          color: C.textSec,
          fontWeight: FontWeight.w600,
        ),
      ),
      Expanded(
        child: Text(
          val,
          style: const TextStyle(fontSize: 11, color: C.textPrimary),
        ),
      ),
    ],
  );

  void _show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        v.commonName,
                        style: const TextStyle(
                          fontSize: 14,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: C.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(Icons.close, size: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 240,
                child: Image.asset(
                  v.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sec(
              Icons.description,
              'Description',
              Text(
                v.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: C.textSec,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sec(
              Icons.favorite,
              'Health Benefits',
              Column(children: v.benefits.map(_bul).toList()),
            ),
            const SizedBox(height: 12),
            _sec(
              Icons.restaurant,
              'Popular Dishes',
              Column(children: v.dishes.map(_bul).toList()),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );

  Widget _sec(IconData icon, String title, Widget body) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: C.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: C.primary),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    ),
  );

  Widget _bul(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 6),
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
// DIALOGS
// ============================================================================

class _HowToDlg extends StatelessWidget {
  const _HowToDlg();
  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: C.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, color: C.primary, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'How to Use',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _step(
                      1,
                      'Open Camera or Gallery',
                      'Tap "Open Camera" to capture or "Pick from Gallery" to select an image.',
                    ),
                    _step(
                      2,
                      'Place ONE Camote',
                      'For best results, scan a single camote on a plain, well-lit surface.',
                    ),
                    _step(
                      3,
                      'Tap Capture / Pick Image',
                      'The model will analyze the camote variety automatically.',
                    ),
                    _step(
                      4,
                      'View Detection Cards',
                      'See each detection with cropped image, variety name, and confidence.',
                    ),
                    _step(
                      5,
                      'View Description',
                      'Tap "View Description & Benefits" for detailed variety info.',
                    ),
                    _step(
                      6,
                      'History & Library',
                      'Review past detections in History or browse all varieties in Library.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary,
                  foregroundColor: C.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Got It',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
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
          width: 28,
          height: 28,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                d,
                style: const TextStyle(
                  fontSize: 12,
                  color: C.textSec,
                  height: 1.4,
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
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: C.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, color: C.primary, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'Doma',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Version 1.0',
            style: TextStyle(fontSize: 13, color: C.textSec),
          ),
          const SizedBox(height: 14),
          const Text(
            'A computer-vision app for identifying and classifying sweet potato (camote) varieties commonly found in Tacloban City, Leyte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.textSec, height: 1.5),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.primary,
                foregroundColor: C.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// EXTENSIONS
// ============================================================================

extension StringX on String {
  String get cap => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
