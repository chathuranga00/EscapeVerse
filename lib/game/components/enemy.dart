import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/painting.dart';

import '../escape_verse_game.dart';

const String kJungleGuardianId = 'jungle_guardian';

enum _EnemyState { patrolling, chasing, attacking, defeated }

/// Real-time patrol-chase-attack enemy with health bar.
///
/// Combat design:
///  • Has [maxHp] hit points.
///  • [Player.attackNearbyEnemies] calls [takeDamage] with a damage value.
///  • On contact with the player it enters [_EnemyState.attacking] and deals
///    [contactDamagePerSec] damage every frame (capped by player invincibility).
///  • A red flash plays when hit; health bar shown at top of sprite.
///  • On reaching 0 HP it fades out and reports the kill to MissionManager.
class Enemy extends PositionComponent
    with HasGameReference<EscapeVerseGame>, CollisionCallbacks, HasPaint {
  Enemy({
    required Vector2 position,
    required this.patrolEnd,
    this.patrolSpeed       = 60.0,
    this.chaseSpeed        = 110.0,
    this.chaseRadius       = 150.0,
    this.contactDamagePerSec = 12.0,
    this.maxHp             = 60,
    this.enemyId           = kJungleGuardianId,
  }) : _patrolStart = position.clone(),
       _hp          = maxHp,
       super(
         position: position,
         size: Vector2.all(_kSize),
         anchor: Anchor.center,
       );

  // ── Config ─────────────────────────────────────────────────────────────────
  final String enemyId;
  final double patrolSpeed, chaseSpeed, chaseRadius, contactDamagePerSec;
  final int    maxHp;
  static const double _kSize        = 40.0;
  static const double _kAttackRange = 36.0;   // pixels — melee range for contact

  // ── State ──────────────────────────────────────────────────────────────────
  final Vector2 _patrolStart;
  final Vector2 patrolEnd;
  _EnemyState _state      = _EnemyState.patrolling;
  int         _hp;
  bool        _defeated   = false;
  bool        _facingLeft = false;
  double      _animTime   = 0;

  // Hit-flash
  double _flashTimer = 0;
  static const double _kFlashDuration = 0.12;

  // Contact damage throttle — only apply damage every 0.5 s to give player
  // time to react (invincibility handled on the Player side too).
  bool   _inContact  = false;
  double _damageTimer = 0;

  final Vector2 _toTarget = Vector2.zero();

  // ── Public accessors ───────────────────────────────────────────────────────
  int  get hp       => _hp;
  bool get isAlive  => !_defeated;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _patrolTarget = patrolEnd.clone();
    await add(RectangleHitbox(size: size, anchor: Anchor.topLeft));
  }

  late Vector2 _patrolTarget;

  // ── Public combat API ──────────────────────────────────────────────────────

  /// Called by Player.attackNearbyEnemies. [damage] is subtracted from HP.
  void takeDamage(int damage) {
    if (_defeated) return;
    _hp = (_hp - damage).clamp(0, maxHp);
    _flashTimer = _kFlashDuration;
    game.audio.playHit();

    // Knock back slightly toward away-from-player direction
    final knockDir = (position - game.player.position);
    if (knockDir.length2 > 0) {
      knockDir.normalize();
      position.addScaled(knockDir, 18);
    }

    if (_hp <= 0) _die();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _die() {
    if (_defeated) return;
    _defeated = true;
    _state    = _EnemyState.defeated;
    game.missionManager.reportEnemyDefeated(enemyId);
    // Spawn death particles via scale + fade
    addAll([
      ScaleEffect.by(
        Vector2.all(1.5),
        EffectController(duration: 0.18),
      ),
      OpacityEffect.to(
        0, EffectController(duration: 0.35),
        onComplete: removeFromParent,
      ),
    ]);
  }

  // ── Collision ──────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_defeated) return;
    if (other.runtimeType.toString() == 'Player') {
      _inContact = true;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other.runtimeType.toString() == 'Player') {
      _inContact  = false;
      _damageTimer = 0;
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (_state == _EnemyState.defeated) return;

    _animTime += dt;

    // Hit-flash timer
    if (_flashTimer > 0) {
      _flashTimer = (_flashTimer - dt).clamp(0.0, _kFlashDuration);
    }

    // Contact damage
    if (_inContact) {
      _damageTimer += dt;
      if (_damageTimer >= 0.45) {
        _damageTimer = 0;
        game.player.receiveDamage(contactDamagePerSec.round());
      }
    }

    // State machine
    final dist = position.distanceTo(game.player.position);

    if (_state == _EnemyState.patrolling && dist <= chaseRadius) {
      _state = _EnemyState.chasing;
    } else if (_state == _EnemyState.chasing && dist > chaseRadius * 2.2) {
      _state = _EnemyState.patrolling;
    }

    if (_state == _EnemyState.chasing && dist <= _kAttackRange) {
      _state = _EnemyState.attacking;
    } else if (_state == _EnemyState.attacking && dist > _kAttackRange * 1.5) {
      _state = _EnemyState.chasing;
    }

    switch (_state) {
      case _EnemyState.patrolling:
        _moveToward(_patrolTarget, patrolSpeed, dt);
        if (position.distanceTo(_patrolTarget) < 4.0) {
          _patrolTarget = (_patrolTarget == patrolEnd)
              ? _patrolStart.clone() : patrolEnd.clone();
        }
      case _EnemyState.chasing:
        _moveToward(game.player.position, chaseSpeed, dt);
      case _EnemyState.attacking:
        // Slow lunge into player
        _moveToward(game.player.position, chaseSpeed * 0.5, dt);
      case _EnemyState.defeated:
        break;
    }

    if (_toTarget.x < -0.5) _facingLeft = true;
    if (_toTarget.x >  0.5) _facingLeft = false;
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (_facingLeft) {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    // Hit-flash overlay
    if (_flashTimer > 0) {
      final alpha = (_flashTimer / _kFlashDuration * 0.75).clamp(0.0, 0.75);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint(),
      );
      _drawEnemy(canvas);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color        = Color.fromRGBO(255, 60, 60, alpha)
          ..blendMode    = BlendMode.srcATop,
      );
      canvas.restore();
    } else {
      _drawEnemy(canvas);
    }

    if (_facingLeft) canvas.restore();

    // Health bar (always above sprite, outside flip transform)
    _drawHealthBar(canvas);
  }

  void _drawHealthBar(Canvas canvas) {
    const barW  = _kSize * 0.9;
    const barH  = 5.0;
    const barX  = (_kSize - barW) / 2;
    const barY  = -10.0;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x88000000),
    );

    // HP fill
    final ratio = (_hp / maxHp).clamp(0.0, 1.0);
    final fillColor = ratio > 0.5
        ? const Color(0xFF4CAF50)
        : ratio > 0.25
            ? const Color(0xFFFF9800)
            : const Color(0xFFF44336);

    if (ratio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * ratio, barH),
          const Radius.circular(2),
        ),
        Paint()..color = fillColor,
      );
    }

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(2),
      ),
      Paint()
        ..color      = const Color(0xFFFFFFFF)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawEnemy(Canvas canvas) {
    final w  = _kSize;
    final h  = _kSize;
    final cx = w / 2;
    final isChasing   = _state == _EnemyState.chasing;
    final isAttacking = _state == _EnemyState.attacking;
    final isAggro     = isChasing || isAttacking;

    // ── Threat aura ────────────────────────────────────────────────────────
    if (isAggro) {
      final auraAlpha = (0.3 + math.sin(_animTime * 6) * 0.15).clamp(0.1, 0.5);
      final auraScale = isAttacking ? 1.7 : 1.4;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, h * 0.6),
          width:  w * auraScale + math.sin(_animTime * 4) * 4,
          height: h * 1.2       + math.sin(_animTime * 4) * 3,
        ),
        Paint()..color = Color.fromRGBO(200, 30, 30, auraAlpha),
      );
    }

    // ── Ground shadow ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h - 2), width: w * 0.85, height: 6),
      Paint()..color = const Color(0x44000000),
    );

    // ── Feet / claws ───────────────────────────────────────────────────────
    final walkBob  = (isAggro || _state == _EnemyState.patrolling)
        ? math.sin(_animTime * 6) * 2.5 : 0.0;
    final footColor = isAggro
        ? const Color(0xFF6A0000) : const Color(0xFF4A3828);

    for (final xOff in [-7.0, 7.0]) {
      final sway = xOff > 0 ? walkBob : -walkBob;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx + xOff - 4, h - 9 + sway, 8, 9),
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(3),
        ),
        Paint()..color = footColor,
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(cx + xOff - 2 + i * 2.5, h + sway - 1),
          Offset(cx + xOff - 3 + i * 2.5, h + sway + 3),
          Paint()
            ..color      = const Color(0xFFCCBBAA)
            ..strokeWidth = 1.5
            ..strokeCap  = StrokeCap.round,
        );
      }
    }

    // ── Body ───────────────────────────────────────────────────────────────
    final bodyColor = isAggro
        ? const Color(0xFF7A2020) : const Color(0xFF5A5040);
    final bodyShade = isAggro
        ? const Color(0xFF4A1010) : const Color(0xFF3A3028);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 11, h * 0.35, 22, h * 0.42),
        const Radius.circular(5),
      ),
      Paint()..color = bodyColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 3, h * 0.38, 7, h * 0.36),
        const Radius.circular(3),
      ),
      Paint()..color = bodyShade,
    );
    final crackPaint = Paint()
      ..color       = bodyShade
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 5, h * 0.44), Offset(cx - 2, h * 0.58), crackPaint);
    canvas.drawLine(Offset(cx + 2, h * 0.48), Offset(cx + 5, h * 0.62), crackPaint);

    // Moss patches
    final mossPaint = Paint()..color = const Color(0xFF3A6A30);
    canvas.drawOval(Rect.fromLTWH(cx - 9, h * 0.38, 7, 5), mossPaint);
    canvas.drawOval(Rect.fromLTWH(cx + 3, h * 0.55, 6, 4), mossPaint);

    // ── Arms ───────────────────────────────────────────────────────────────
    final armSwing = math.sin(_animTime * 5) * (isAggro ? 10.0 : 4.0);
    for (final side in [-1, 1]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx + side * (side < 0 ? -18 : 11),
            h * 0.38 + (side > 0 ? -armSwing : armSwing) * 0.3,
            7, 16,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = bodyColor,
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(cx + side * (side < 0 ? -14.5 + i * 2.5 : 12 + i * 2.5),
              h * 0.38 + 16 + (side > 0 ? -armSwing : armSwing) * 0.3),
          Offset(cx + side * (side < 0 ? -15.5 + i * 2.5 : 11 + i * 2.5),
              h * 0.38 + 22 + (side > 0 ? -armSwing : armSwing) * 0.3),
          Paint()
            ..color      = const Color(0xFFCCBBAA)
            ..strokeWidth = 1.5
            ..strokeCap  = StrokeCap.round,
        );
      }
    }

    // ── Head ───────────────────────────────────────────────────────────────
    final headBob   = math.sin(_animTime * 5) * (isAggro ? 1.5 : 0.5);
    final headColor = isAggro
        ? const Color(0xFF6A1A1A) : const Color(0xFF4A4038);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, h * 0.06 + headBob, 20, 20),
        const Radius.circular(5),
      ),
      Paint()..color = headColor,
    );

    // Horns
    final hornColor = isAggro
        ? const Color(0xFF8A2020) : const Color(0xFF6A5A40);
    for (final side in [-1, 1]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + side * 8, h * 0.08 + headBob)
          ..lineTo(cx + side * 12, headBob - 6)
          ..lineTo(cx + side * 4, h * 0.06 + headBob),
        Paint()..color = hornColor,
      );
    }

    // Eyes
    final eyeGlow  = isAggro
        ? (0.8 + math.sin(_animTime * 8) * 0.2)
        : (0.6 + math.sin(_animTime * 2) * 0.2);
    final eyeColor = isAggro
        ? Color.fromRGBO(255, 50, 0, eyeGlow)
        : Color.fromRGBO(200, 160, 0, eyeGlow);

    for (final ex in [-8.0, 2.0]) {
      canvas.drawOval(
        Rect.fromLTWH(cx + ex, h * 0.14 + headBob, 6, 5),
        Paint()..color = const Color(0xFF1A1010),
      );
      canvas.drawOval(
        Rect.fromLTWH(cx + ex + 1, h * 0.145 + headBob, 4, 3.5),
        Paint()..color = eyeColor,
      );
      canvas.drawLine(
        Offset(cx + ex + 3, h * 0.15 + headBob),
        Offset(cx + ex + 3, h * 0.17 + headBob),
        Paint()..color = const Color(0xFF000000)..strokeWidth = 1,
      );
    }

    // Mouth
    final mouthPath = Path();
    if (isAggro) {
      mouthPath
        ..moveTo(cx - 5, h * 0.22 + headBob)
        ..quadraticBezierTo(cx, h * 0.19 + headBob, cx + 5, h * 0.22 + headBob);
    } else {
      mouthPath
        ..moveTo(cx - 4, h * 0.22 + headBob)
        ..quadraticBezierTo(cx, h * 0.25 + headBob, cx + 4, h * 0.22 + headBob);
    }
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color       = const Color(0xFF1A0A00)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap   = StrokeCap.round,
    );

    // Attack slash effect
    if (isAttacking) {
      final slashAlpha = (0.4 + math.sin(_animTime * 12) * 0.3).clamp(0.0, 0.8);
      canvas.drawLine(
        Offset(cx - 14, h * 0.35 + armSwing),
        Offset(cx + 14, h * 0.55 - armSwing),
        Paint()
          ..color      = Color.fromRGBO(255, 100, 50, slashAlpha)
          ..strokeWidth = 3.5
          ..strokeCap  = StrokeCap.round,
      );
    }
  }

  void _moveToward(Vector2 target, double speed, double dt) {
    _toTarget
      ..setFrom(target)
      ..sub(position);
    if (_toTarget.length2 < 1) return;
    _toTarget.normalize();
    position.addScaled(_toTarget, speed * dt);
  }
}
