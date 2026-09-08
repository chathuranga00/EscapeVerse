import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../escape_verse_game.dart';
import '../models/dialogue.dart';

const double _kPromptRadius = 80.0;
const double _kTalkRadius   = 60.0;

/// A stationary NPC — rendered as a detailed robed elder figure.
///
/// Shows an animated speech bubble when the player is nearby.
/// Swap the render() block for a SpriteAnimationComponent when art is ready.
class Npc extends PositionComponent
    with HasGameReference<EscapeVerseGame>, TapCallbacks {
  Npc({
    required super.position,
    required this.sequence,
    this.npcName = 'Stranger',
  }) : super(size: Vector2(_kW, _kH), anchor: Anchor.center);

  final DialogueSequence sequence;
  final String npcName;

  static const double _kW = 32.0;
  static const double _kH = 52.0;

  bool _promptVisible = false;
  double _time = 0;

  static final _labelPainter = TextPainter(textDirection: TextDirection.ltr);

  @override
  Future<void> onLoad() async => super.onLoad();

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final dist = position.distanceTo(game.player.position);
    _promptVisible = dist <= _kPromptRadius && !game.player.dialoguePaused;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (position.distanceTo(game.player.position) > _kTalkRadius) return;
    if (game.player.dialoguePaused) return;
    game.openDialogue(sequence);
  }

  @override
  void render(Canvas canvas) {
    final w = _kW;
    final h = _kH;
    final cx = w / 2;

    // Idle sway
    final sway = math.sin(_time * 1.2) * 1.5;

    // ── Ground shadow ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h - 1), width: w * 0.8, height: 5),
      Paint()..color = const Color(0x44000000),
    );

    // ── Robe base (full body) ──────────────────────────────────────────────
    final robeBase = Paint()..color = const Color(0xFF3A5C3A); // forest green
    final robeDark = Paint()..color = const Color(0xFF243C24);
    final robeEdge = Paint()..color = const Color(0xFFD4A017);

    // Robe lower hem (wide trapezoid)
    final hemPath = Path()
      ..moveTo(cx - 13 + sway, h - 2)
      ..lineTo(cx + 13 + sway, h - 2)
      ..lineTo(cx + 9 + sway, h * 0.48)
      ..lineTo(cx - 9 + sway, h * 0.48)
      ..close();
    canvas.drawPath(hemPath, robeBase);

    // Robe shading (right side)
    final hemShade = Path()
      ..moveTo(cx + 3 + sway, h - 2)
      ..lineTo(cx + 13 + sway, h - 2)
      ..lineTo(cx + 9 + sway, h * 0.48)
      ..lineTo(cx + 1 + sway, h * 0.48)
      ..close();
    canvas.drawPath(hemShade, robeDark);

    // Gold hem trim
    canvas.drawLine(
      Offset(cx - 13 + sway, h - 3),
      Offset(cx + 13 + sway, h - 3),
      Paint()..color = robeEdge.color..strokeWidth = 1.5,
    );

    // Vertical robe lines (fabric folds)
    final foldPaint = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = 1.0;
    for (final xOff in [-4.0, 0.0, 4.0]) {
      canvas.drawLine(
        Offset(cx + xOff + sway, h * 0.5),
        Offset(cx + xOff * 1.3 + sway, h - 4),
        foldPaint,
      );
    }

    // ── Upper body / chest ────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 8 + sway, h * 0.28, 16, h * 0.22),
        const Radius.circular(3),
      ),
      robeBase,
    );

    // Chest emblem (gold circle)
    canvas.drawCircle(
      Offset(cx + sway, h * 0.37),
      4,
      Paint()..color = const Color(0xFFD4A017),
    );
    canvas.drawCircle(
      Offset(cx + sway, h * 0.37),
      2,
      Paint()..color = const Color(0xFFFFE066),
    );

    // ── Arms ──────────────────────────────────────────────────────────────
    final armFloat = math.sin(_time * 1.5) * 2.0;
    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 14 + sway, h * 0.3 + armFloat, 6, 14),
        const Radius.circular(3),
      ),
      robeBase,
    );
    // Staff hand
    canvas.drawCircle(
      Offset(cx - 11 + sway, h * 0.3 + 14 + armFloat),
      3.5,
      Paint()..color = const Color(0xFFD4956A),
    );

    // ── Staff ─────────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(cx - 11 + sway, h * 0.3 + 12 + armFloat),
      Offset(cx - 15 + sway, h - 4),
      Paint()
        ..color = const Color(0xFF6B4226)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Staff orb
    final orbGlow = 0.7 + math.sin(_time * 3) * 0.3;
    canvas.drawCircle(
      Offset(cx - 15 + sway, h * 0.28 + armFloat - 3),
      5,
      Paint()
        ..color = Color.fromRGBO(100, 200, 255, orbGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(cx - 15 + sway, h * 0.28 + armFloat - 3),
      3,
      Paint()..color = Color.fromRGBO(200, 240, 255, orbGlow.toDouble()),
    );

    // Right arm (resting in robe)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 8 + sway, h * 0.32 - armFloat * 0.5, 5, 12),
        const Radius.circular(3),
      ),
      robeDark,
    );

    // ── Head ──────────────────────────────────────────────────────────────
    // Hood (triangle-ish)
    final hoodPath = Path()
      ..moveTo(cx - 10 + sway, h * 0.17)
      ..quadraticBezierTo(cx + sway, h * 0.04, cx + 10 + sway, h * 0.17)
      ..lineTo(cx + 9 + sway, h * 0.28)
      ..lineTo(cx - 9 + sway, h * 0.28)
      ..close();
    canvas.drawPath(hoodPath, robeBase);
    canvas.drawPath(
      hoodPath,
      Paint()
        ..color = robeEdge.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Face
    canvas.drawOval(
      Rect.fromLTWH(cx - 6 + sway, h * 0.14, 12, 14),
      Paint()..color = const Color(0xFFD4A87A),
    );

    // Eyes — wise, calm
    canvas.drawOval(
        Rect.fromLTWH(cx - 4.5 + sway, h * 0.185, 3.5, 2.5),
        Paint()..color = const Color(0xFF3A2810));
    canvas.drawOval(
        Rect.fromLTWH(cx + 1 + sway, h * 0.185, 3.5, 2.5),
        Paint()..color = const Color(0xFF3A2810));

    // Beard
    final beardPath = Path()
      ..moveTo(cx - 5 + sway, h * 0.26)
      ..quadraticBezierTo(cx + sway, h * 0.32, cx + 5 + sway, h * 0.26)
      ..lineTo(cx + 3 + sway, h * 0.3)
      ..quadraticBezierTo(cx + sway, h * 0.35, cx - 3 + sway, h * 0.3)
      ..close();
    canvas.drawPath(beardPath, Paint()..color = const Color(0xFFEEEEDD));

    // ── Interaction prompt ─────────────────────────────────────────────────
    if (_promptVisible) {
      _drawSpeechBubble(canvas, cx, sway);
    }

    // ── Name tag ──────────────────────────────────────────────────────────
    _drawLabel(canvas, npcName, const Color(0xFFD4A017), -14);
  }

  void _drawSpeechBubble(Canvas canvas, double cx, double sway) {
    final bobY = math.sin(_time * 3) * 3.0;
    final bx = cx + sway;
    final by = -28.0 + bobY;

    // Bubble background
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(bx + 8, by), width: 52, height: 20),
      const Radius.circular(8),
    );
    canvas.drawRRect(bubbleRect,
        Paint()..color = const Color(0xEED4A017));

    // Bubble tail
    final tailPath = Path()
      ..moveTo(bx + 4, by + 8)
      ..lineTo(bx + 2, by + 16)
      ..lineTo(bx + 10, by + 8)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = const Color(0xEED4A017));

    // Bubble text
    _labelPainter.text = const TextSpan(
      text: '▲ Talk',
      style: TextStyle(
        color: Color(0xFF1A0F00),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
    _labelPainter.layout();
    _labelPainter.paint(
      canvas,
      Offset(bx + 8 - _labelPainter.width / 2, by - _labelPainter.height / 2),
    );
  }

  void _drawLabel(Canvas canvas, String text, Color color, double yOffset) {
    _labelPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        shadows: const [
          Shadow(color: Color(0xFF000000), blurRadius: 3),
        ],
      ),
    );
    _labelPainter.layout();
    _labelPainter.paint(
      canvas,
      Offset(size.x / 2 - _labelPainter.width / 2, yOffset),
    );
  }
}
