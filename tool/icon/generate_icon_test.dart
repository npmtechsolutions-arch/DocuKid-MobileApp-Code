// Renders the DocuKit launcher icon with Flutter's canvas (DESIGN_SYSTEM §10):
// a folded-corner document with text lines and a small spark, on the primary
// gradient. Run: `flutter test tool/icon/generate_icon_test.dart`, then
// `tool/icon/apply_icons.sh` to resize into the Android/iOS icon sets.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = Color(0xFF2F5BEA);
const _navy = Color(0xFF1E3FB8);
const _orange = Color(0xFFFF8A50);
const _teal = Color(0xFF5FD3C3);

/// [full]: draw the background (iOS / legacy). [foregroundOnly]: transparent
/// background, glyph inside the 66/108 safe zone (Android adaptive foreground).
/// [mono]: single-colour glyph for Android 13 themed icons.
void paintIcon(Canvas c, double s, {bool background = true, bool mono = false, double glyphScale = 1}) {
  if (background) {
    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(s, s), [_blue, _navy]),
    );
    // Soft highlight.
    c.drawCircle(Offset(s * 0.82, s * 0.12), s * 0.38, Paint()..color = Colors.white.withValues(alpha: 0.07));
  }
  c.save();
  c.translate(s / 2, s / 2);
  c.scale(glyphScale);
  c.translate(-s / 2, -s / 2);

  final docW = s * 0.46, docH = s * 0.58;
  final left = (s - docW) / 2 - s * 0.02, top = (s - docH) / 2;
  final fold = docW * 0.30;
  final r = s * 0.045;
  final doc = Path()
    ..moveTo(left + r, top)
    ..lineTo(left + docW - fold, top)
    ..lineTo(left + docW, top + fold)
    ..lineTo(left + docW, top + docH - r)
    ..quadraticBezierTo(left + docW, top + docH, left + docW - r, top + docH)
    ..lineTo(left + r, top + docH)
    ..quadraticBezierTo(left, top + docH, left, top + docH - r)
    ..lineTo(left, top + r)
    ..quadraticBezierTo(left, top, left + r, top)
    ..close();
  if (!mono) c.drawShadow(doc, Colors.black, s * 0.02, false);
  c.drawPath(doc, Paint()..color = Colors.white);

  // Folded corner.
  final corner = Path()
    ..moveTo(left + docW - fold, top)
    ..lineTo(left + docW - fold, top + fold - r * 0.6)
    ..quadraticBezierTo(left + docW - fold, top + fold, left + docW - fold + r * 0.6, top + fold)
    ..lineTo(left + docW, top + fold)
    ..close();
  c.drawPath(corner, Paint()..color = mono ? Colors.white : const Color(0xFFC9D6FF));

  // Text lines.
  final line = Paint()
    ..color = mono ? Colors.transparent : _blue.withValues(alpha: 0.85)
    ..strokeWidth = s * 0.032
    ..strokeCap = StrokeCap.round;
  final lx = left + docW * 0.18;
  for (var i = 0; i < 3; i++) {
    final y = top + docH * (0.40 + i * 0.15);
    final w = docW * (i == 2 ? 0.38 : 0.62);
    c.drawLine(Offset(lx, y), Offset(lx + w, y), line..color = mono ? Colors.transparent : (i == 0 ? _teal : _blue));
  }

  // Spark (four-point star) at the bottom-right corner.
  final cx = left + docW * 0.98, cy = top + docH * 0.92, R = s * 0.13, rr = s * 0.035;
  final star = Path()
    ..moveTo(cx, cy - R)
    ..quadraticBezierTo(cx + rr * 0.6, cy - rr * 0.6, cx + R, cy)
    ..quadraticBezierTo(cx + rr * 0.6, cy + rr * 0.6, cx, cy + R)
    ..quadraticBezierTo(cx - rr * 0.6, cy + rr * 0.6, cx - R, cy)
    ..quadraticBezierTo(cx - rr * 0.6, cy - rr * 0.6, cx, cy - R)
    ..close();
  if (!mono) c.drawCircle(Offset(cx, cy), R * 0.75, Paint()..color = _navy);
  c.drawPath(star, Paint()..color = mono ? Colors.white : _orange);
  c.restore();
}

Future<void> render(String path, double size, {bool background = true, bool mono = false, double glyphScale = 1}) async {
  final rec = ui.PictureRecorder();
  paintIcon(Canvas(rec), size, background: background, mono: mono, glyphScale: glyphScale);
  final image = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  test('render icons', () async {
    final out = Directory('tool/icon/out')..createSync(recursive: true);
    await render('${out.path}/icon_1024.png', 1024);
    // Adaptive foreground: 108 dp canvas, glyph within the 66 dp safe zone.
    await render('${out.path}/foreground_432.png', 432, background: false, glyphScale: 0.66);
    await render('${out.path}/monochrome_432.png', 432, background: false, mono: true, glyphScale: 0.66);
  });
}
