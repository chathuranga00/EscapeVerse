import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/painting.dart';

import '../escape_verse_game.dart';
import '../models/inventory_item.dart';
import 'player.dart';

class Collectible extends PositionComponent
    with HasGameReference<EscapeVerseGame>, CollisionCallbacks, HasPaint {
  Collectible({
    required super.position,
    this.itemId = 'relic',
  }) : super(size: Vector2.all(_kSize), anchor: Anchor.center);

  final String itemId;
  static const double _kSize = 32.0;
  bool _collected = false;
  double _time = 0;

  // Sparkle positions (pre-baked, relative to centre)
  static final _rng = math.Random(7);
  late final List<_Sparkle> _sparkles;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sparkles = List.generate(6, (i) => _Sparkle(
      angle: i * math.pi / 3 + _rng.nextDouble() * 0.5,
      radius: 12 + _rng.nextDouble() * 6,
      phase: _rng.nextDouble() * math.pi * 2,
    ));
    await add(CircleHitbox(
      radius: _kSize / 2,
      anchor: Anchor.center,
      position: size / 2,
    ));
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_collected || other is! Player) return;
    _collected = true;
    game.missionManager.reportCollected(itemId);
    game.audio.playCollect();
    game.inventoryManager.addItem(InventoryItem(
      id: itemId,
      name: _displayName(itemId),
      iconCodePoint: _iconCode(itemId),
    ));
    game.triggerAutoSave();
    _playCollectEffect();
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = _kSize / 2;
    final cy = _kSize / 2;
    final bob = math.sin(_time * 2.2) * 4.0;
    final spin = _time * 1.4;

    // ── Vertical light shaft ──────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + bob - 20),
          width: 6, height: 50),
      Paint()
        ..color = const Color(0x22FFD740)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Outer glow ring ───────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy + bob),
      _kSize * 0.55,
      Paint()
        ..color = const Color(0x33FFD740)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Orbiting sparkles ─────────────────────────────────────────────────
    for (final s in _sparkles) {
      final a = s.angle + _time * 1.8 + s.phase;
      final sx = cx + math.cos(a) * (s.radius + math.sin(_time * 3 + s.phase) * 3);
      final sy = cy + bob + math.sin(a) * (s.radius * 0.5);
      final alpha = (0.5 + math.sin(_time * 4 + s.phase) * 0.4).clamp(0.1, 0.9);
      canvas.drawCircle(
        Offset(sx, sy), 2,
        Paint()..color = Color.fromRGBO(255, 220, 60, alpha),
      );
    }

    // ── Main relic body ───────────────────────────────────────────────────
    canvas.save();
    canvas.translate(cx, cy + bob);
    canvas.rotate(spin * 0.3);

    // Outer ring
    canvas.drawCircle(Offset.zero, 11,
        Paint()..color = const Color(0xFFD4A017));
    canvas.drawCircle(Offset.zero, 11,
        Paint()
          ..color = const Color(0xFFFFD740)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Inner gem
    canvas.rotate(spin * 0.7);
    final gemPath = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final r = (i.isEven) ? 8.0 : 5.0;
      if (i == 0) {
        gemPath.moveTo(math.cos(angle) * r, math.sin(angle) * r);
      } else {
        gemPath.lineTo(math.cos(angle) * r, math.sin(angle) * r);
      }
    }
    gemPath.close();

    canvas.drawPath(gemPath, Paint()..color = const Color(0xFFFF9800));
    canvas.drawPath(
      gemPath,
      Paint()
        ..color = const Color(0xFFFFCC02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Centre dot
    canvas.drawCircle(Offset.zero, 3,
        Paint()..color = const Color(0xFFFFFFE0));

    // Highlight
    canvas.drawCircle(const Offset(-3, -3), 2,
        Paint()..color = const Color(0x88FFFFFF));

    canvas.restore();

    // ── Ancient rune marks (static, below relic) ──────────────────────────
    final runePaint = Paint()
      ..color = const Color(0x66FFD740)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy + bob), 14, runePaint);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + _time * 0.5;
      canvas.drawLine(
        Offset(cx + math.cos(a) * 11, cy + bob + math.sin(a) * 11),
        Offset(cx + math.cos(a) * 15, cy + bob + math.sin(a) * 15),
        runePaint,
      );
    }
  }

  void _playCollectEffect() {
    addAll([
      ScaleEffect.by(Vector2.all(2.0), EffectController(duration: 0.2)),
      OpacityEffect.to(0, EffectController(duration: 0.2),
          onComplete: removeFromParent),
    ]);
  }

  static String _displayName(String id) =>
      const {'relic': 'Ancient Relic', 'ancient_seal': 'Ancient Seal'}[id] ?? id;

  static int _iconCode(String id) =>
      const {'relic': 0x1F3FA, 'ancient_seal': 0x1F4DC}[id] ?? 0x2753;
}

class _Sparkle {
  const _Sparkle({required this.angle, required this.radius, required this.phase});
  final double angle, radius, phase;
}
