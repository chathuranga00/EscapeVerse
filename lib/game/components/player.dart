import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'enemy.dart';

enum PlayerState { idle, walking, attacking }

/// The player-controlled character with real-time combat.
///
/// Combat design:
///  • [maxHp] = 100. [receiveDamage] reduces HP; ignored during [_iFrames].
///  • Pressing the attack button calls [attackNearbyEnemies]:
///    - All enemies within [_kAttackRadius] take [attackDamage] HP.
///    - Has [_kAttackCooldown] second cooldown between swings.
///    - A sword-swing arc is drawn for [_kSwingDuration] seconds.
///  • Invincibility frames ([_kIFrames]) prevent HP spam from contact damage.
///  • A red vignette flash plays when hit.
class Player extends PositionComponent
    with HasGameReference, CollisionCallbacks, HasPaint {
  Player({
    required Vector2 startPosition,
    Vector2? worldSize,
    this.speed      = 160.0,
    this.maxHp      = 100,
    this.attackDamage = 25,
  }) : _worldSize = worldSize ?? Vector2.zero(),
       _hp        = 100,
       super(
         position: startPosition,
         size: Vector2(_kW, _kH),
         anchor: Anchor.center,
       );

  static const double _kW             = 28.0;
  static const double _kH             = 44.0;
  static const double _kAttackRadius  = 80.0;    // reach of sword swing
  static const double _kAttackCooldown = 0.55;   // seconds between swings
  static const double _kSwingDuration  = 0.28;   // arc visible duration
  static const double _kIFrames        = 0.65;   // invincibility after hit

  final double speed;
  final int    maxHp;
  final int    attackDamage;

  PlayerState _state      = PlayerState.idle;
  bool        _facingLeft = false;
  bool        _dialoguePaused = false;
  bool        _isDead     = false;

  // ── Combat state ───────────────────────────────────────────────────────────
  int    _hp;
  double _attackCooldownTimer = 0;
  double _swingTimer          = 0;
  double _iFrameTimer         = 0;   // invincibility
  double _hitFlashTimer       = 0;   // red flash duration
  static const double _kFlashDuration = 0.25;

  // ── Internal ───────────────────────────────────────────────────────────────
  final Vector2 _worldSize;
  final Vector2 _moveDir = Vector2.zero();
  late final _PlayerBody _body;
  double _walkTime = 0;

  // ── Public accessors ───────────────────────────────────────────────────────
  PlayerState get state   => _state;
  int         get hp      => _hp;
  bool        get isAlive => !_isDead;
  bool        get isAttacking => _swingTimer > 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _body = _PlayerBody(playerRef: this);
    await add(_body);
    await add(RectangleHitbox(
      size:     Vector2(_kW * 0.7, _kH * 0.5),
      position: Vector2(_kW * 0.15, _kH * 0.5),
      anchor:   Anchor.topLeft,
    ));
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  bool get dialoguePaused => _dialoguePaused;

  void pauseForDialogue() {
    _dialoguePaused = true;
    _moveDir.setZero();
    _updateState(PlayerState.idle);
  }

  void resumeFromDialogue() => _dialoguePaused = false;

  void setMoveDirection(Vector2 direction) {
    if (_dialoguePaused || _isDead) return;
    _moveDir.setFrom(direction);
    if (direction.x < -0.1) _facingLeft = true;
    if (direction.x >  0.1) _facingLeft = false;
  }

  // ── Combat ─────────────────────────────────────────────────────────────────

  /// Called by AttackButton. Finds all enemies within [_kAttackRadius] and
  /// deals [attackDamage] to each. Respects cooldown timer.
  void attackNearbyEnemies() {
    if (_isDead || _attackCooldownTimer > 0) return;
    _attackCooldownTimer = _kAttackCooldown;
    _swingTimer          = _kSwingDuration;
    _updateState(PlayerState.attacking);

    // Walk up the scene graph: player → world (Flame World) →
    // game.world contains GameWorld which contains enemies.
    final gameRef = game;
    // Search all components in the Flame world for Enemy instances.
    _forEachEnemy(gameRef, (enemy) {
      if (position.distanceTo(enemy.position) <= _kAttackRadius) {
        enemy.takeDamage(attackDamage);
      }
    });
  }

  /// Called by Enemy on contact. Applies damage with invincibility guard.
  void receiveDamage(int damage) {
    if (_isDead || _iFrameTimer > 0) return;
    _hp           = (_hp - damage).clamp(0, maxHp);
    _iFrameTimer  = _kIFrames;
    _hitFlashTimer = _kFlashDuration;

    if (_hp <= 0) _die();
  }

  void _die() {
    if (_isDead) return;
    _isDead = true;
    _moveDir.setZero();
    // After a short delay respawn at spawn point with full HP.
    Future.delayed(const Duration(seconds: 2), _respawn);
  }

  void _respawn() {
    if (!isLoaded) return;
    _hp           = maxHp;
    _isDead       = false;
    _iFrameTimer  = 1.0; // brief grace period after respawn
    _hitFlashTimer = 0;
    // Reset to world centre-ish — the game will re-follow
    position.setFrom(parent != null ? _worldSize / 2 : Vector2.zero());
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Tick timers
    if (_attackCooldownTimer > 0) _attackCooldownTimer -= dt;
    if (_swingTimer          > 0) _swingTimer          -= dt;
    if (_iFrameTimer         > 0) _iFrameTimer         -= dt;
    if (_hitFlashTimer       > 0) _hitFlashTimer        -= dt;

    if (_isDead) {
      _updateState(PlayerState.idle);
      return;
    }

    if (_dialoguePaused || _moveDir.isZero()) {
      if (_swingTimer <= 0) _updateState(PlayerState.idle);
      return;
    }

    _walkTime += dt;
    position.addScaled(_moveDir, speed * dt);
    if (!_worldSize.isZero()) {
      position.x = position.x.clamp(size.x / 2, _worldSize.x - size.x / 2);
      position.y = position.y.clamp(size.y / 2, _worldSize.y - size.y / 2);
    }
    if (_swingTimer <= 0) _updateState(PlayerState.walking);
  }

  void _updateState(PlayerState newState) {
    if (_state == newState) return;
    _state = newState;
    _body.state = newState;
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Dead — blink effect using iframes
    if (_isDead) {
      final blink = ((_hitFlashTimer * 10).toInt() % 2 == 0);
      if (!blink) return; // skip every other frame while dying
    }

    if (_facingLeft) {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    // Hit flash: red overlay
    if (_hitFlashTimer > 0) {
      final alpha = (_hitFlashTimer / _kFlashDuration * 0.55).clamp(0.0, 0.55);
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.x, size.y), Paint());
      super.render(canvas);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()
          ..color     = Color.fromRGBO(255, 40, 40, alpha)
          ..blendMode = BlendMode.srcATop,
      );
      canvas.restore();
    } else {
      super.render(canvas);
    }

    if (_facingLeft) canvas.restore();

    // Sword swing arc — drawn in world space (not flipped)
    if (_swingTimer > 0) {
      _drawSwingArc(canvas);
    }

    // Player HP bar above head
    _drawHpBar(canvas);
  }

  void _drawSwingArc(Canvas canvas) {
    final progress  = 1.0 - (_swingTimer / _kSwingDuration);
    final cx        = size.x / 2 + (_facingLeft ? 0 : 0);
    final cy        = size.y * 0.3;
    final radius    = _kAttackRadius * 0.55;
    final startAngle = _facingLeft ? math.pi * 0.7  : -math.pi * 0.3;
    final sweepAngle = _facingLeft ? -math.pi * 0.9 :  math.pi * 0.9;
    final alpha      = (1.0 - progress) * 0.65;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: radius * 2,
        height: radius * 1.6,
      ),
      startAngle,
      sweepAngle * progress,
      false,
      Paint()
        ..color      = Color.fromRGBO(255, 220, 80, alpha)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap  = StrokeCap.round,
    );

    // Sparkle at tip
    final tipAngle = startAngle + sweepAngle * progress;
    final tipX     = cx + math.cos(tipAngle) * radius;
    final tipY     = cy + math.sin(tipAngle) * radius * 0.8;
    canvas.drawCircle(
      Offset(tipX, tipY), 4,
      Paint()..color = Color.fromRGBO(255, 255, 150, alpha * 0.9),
    );
  }

  void _drawHpBar(Canvas canvas) {
    const barW  = _kW * 1.1;
    const barH  = 4.0;
    const barX  = (_kW - barW) / 2;
    const barY  = -8.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x88000000),
    );

    final ratio = (_hp / maxHp).clamp(0.0, 1.0);
    if (ratio > 0) {
      final fillColor = ratio > 0.5
          ? const Color(0xFF4CAF50)
          : ratio > 0.25
              ? const Color(0xFFFF9800)
              : const Color(0xFFF44336);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * ratio, barH),
          const Radius.circular(2),
        ),
        Paint()..color = fillColor,
      );
    }
  }
}

// ── _PlayerBody ───────────────────────────────────────────────────────────────
// Detailed humanoid drawing. Reads walk time from Player parent.

class _PlayerBody extends PositionComponent {
  _PlayerBody({required this.playerRef})
      : super(size: Vector2(Player._kW, Player._kH));

  final Player playerRef;
  PlayerState state = PlayerState.idle;

  // ── Paints ────────────────────────────────────────────────────────────────
  static final _shadowPaint = Paint()..color = const Color(0x44000000);
  static final _skinPaint   = Paint()..color = const Color(0xFFD4956A);
  static final _skinDark    = Paint()..color = const Color(0xFFB07040);
  static final _hairPaint   = Paint()..color = const Color(0xFF3B2010);
  static final _torsoPaint  = Paint()..color = const Color(0xFF2E5C8A);
  static final _torsoShade  = Paint()..color = const Color(0xFF1A3A5C);
  static final _beltPaint   = Paint()..color = const Color(0xFF8B6914);
  static final _legPaint    = Paint()..color = const Color(0xFF4A3020);
  static final _legShade    = Paint()..color = const Color(0xFF2E1E10);
  static final _bootPaint   = Paint()..color = const Color(0xFF2A1A08);
  static final _scarfPaint  = Paint()..color = const Color(0xFFD4A017);

  @override
  void render(Canvas canvas) {
    final w       = Player._kW;
    final h       = Player._kH;
    final cx      = w / 2;
    final wt      = playerRef._walkTime;
    final isAtk   = state == PlayerState.attacking;

    final legSwing  = state == PlayerState.walking
        ? math.sin(wt * 8.0) * 5.0 : 0.0;
    final bodyBob   = state == PlayerState.walking
        ? math.sin(wt * 16.0) * 1.0 : 0.0;
    final armSwing  = state == PlayerState.walking
        ? math.sin(wt * 8.0) * 6.0
        : isAtk
            ? math.sin(wt * 20.0) * 14.0  // fast swing when attacking
            : 0.0;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h - 1), width: w * 0.9, height: 5),
      _shadowPaint,
    );

    // Legs
    _drawLeg(canvas, cx - 5, h - 12 + bodyBob, legSwing, false);
    _drawLeg(canvas, cx + 5, h - 12 + bodyBob, -legSwing, true);

    // Torso
    final torsoTop = h * 0.32 + bodyBob;
    final torsoBot = h - 12 + bodyBob;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 7, torsoTop, 14, torsoBot - torsoTop),
        const Radius.circular(3),
      ),
      _torsoPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 1, torsoTop + 2, 5, torsoBot - torsoTop - 4),
        const Radius.circular(2),
      ),
      _torsoShade,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - 7, torsoBot - 5, 14, 4),
      _beltPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - 6, torsoTop - 1, 12, 5),
      _scarfPaint,
    );

    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 11, torsoTop + 2 + armSwing * 0.3, 5, 14),
        const Radius.circular(2),
      ),
      _torsoPaint,
    );
    // Right arm (weapon hand)
    final armY = torsoTop + 2 - armSwing * 0.3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 6, armY, 5, 13),
        const Radius.circular(2),
      ),
      _torsoPaint,
    );

    // Sword
    final swordX   = cx + 14;
    final swordTop = armY + 4;
    // Blade
    canvas.drawLine(
      Offset(swordX, swordTop),
      Offset(swordX + 3, swordTop + 18),
      Paint()
        ..color      = isAtk ? const Color(0xFFFFE082) : const Color(0xFFD0D8E0)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(swordX + 0.5, swordTop + 1),
      Offset(swordX + 2.5, swordTop + 12),
      Paint()
        ..color      = const Color(0xFFFFFFFF)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    // Guard
    canvas.drawLine(
      Offset(swordX - 2, swordTop + 4),
      Offset(swordX + 5, swordTop + 4),
      Paint()..color = _beltPaint.color..strokeWidth = 2.5,
    );

    // Hands
    canvas.drawCircle(
      Offset(cx - 8, torsoTop + 16 + armSwing * 0.3), 3.5, _skinPaint);
    canvas.drawCircle(
      Offset(cx + 12, armY + 13), 3.5, _skinPaint);

    // Head
    final headY = h * 0.07 + bodyBob;
    canvas.drawRect(
      Rect.fromLTWH(cx - 3, torsoTop - 6 + bodyBob, 6, 7),
      _skinPaint,
    );
    canvas.drawOval(Rect.fromLTWH(cx - 9, headY, 18, 20), _skinPaint);
    canvas.drawOval(Rect.fromLTWH(cx + 1, headY + 3, 6, 12), _skinDark);
    canvas.drawOval(Rect.fromLTWH(cx - 9, headY - 1, 18, 10), _hairPaint);
    canvas.drawRect(Rect.fromLTWH(cx - 9, headY + 3, 4, 8), _hairPaint);

    // Eyes
    canvas.drawOval(Rect.fromLTWH(cx - 5, headY + 9, 4, 3),
        Paint()..color = const Color(0xFF1A0A00));
    canvas.drawOval(Rect.fromLTWH(cx + 2, headY + 9, 4, 3),
        Paint()..color = const Color(0xFF1A0A00));
    canvas.drawCircle(Offset(cx - 3.5, headY + 10), 1,
        Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(Offset(cx + 3.5, headY + 10), 1,
        Paint()..color = const Color(0xFFFFFFFF));
  }

  void _drawLeg(Canvas canvas, double cx, double baseY,
      double swing, bool isRight) {
    const legH = 14.0;
    const bootH = 7.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 4, baseY - swing * 0.5, 8, legH),
        const Radius.circular(2),
      ),
      _legPaint,
    );
    if (isRight) {
      canvas.drawRect(
        Rect.fromLTWH(cx - 1, baseY - swing * 0.5 + 2, 3, legH - 4),
        _legShade,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 5, baseY + legH - swing * 0.5, 10, bootH),
        const Radius.circular(3),
      ),
      _bootPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - 3, baseY + legH - swing * 0.5 + 1, 3, 2),
      Paint()..color = const Color(0xFF5A4A38),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

/// Recursively walks the component tree calling [callback] for every [Enemy].
void _forEachEnemy(dynamic root, void Function(Enemy) callback) {
  if (root == null) return;
  for (final child in (root.children as Iterable)) {
    if (child is Enemy) {
      callback(child);
    } else {
      _forEachEnemy(child, callback);
    }
  }
}
