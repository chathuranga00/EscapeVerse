import 'package:flutter/material.dart';

import '../game/escape_verse_game.dart';
import '../theme/app_theme.dart';

/// A tap-to-attack button pinned bottom-right, mirroring the joystick layout.
///
/// Calls [Player.attackNearbyEnemies] on every tap. A brief visual flash
/// gives the player tactile feedback without any extra state management.
///
/// Registered in [GameWidget.overlayBuilderMap] under [kAttackButtonOverlay].
class AttackButton extends StatefulWidget {
  const AttackButton({super.key, required this.game});

  final EscapeVerseGame game;

  @override
  State<AttackButton> createState() => _AttackButtonState();
}

class _AttackButtonState extends State<AttackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _flash, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _onTap() {
    widget.game.player.attackNearbyEnemies();
    _flash.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 80;

    return Positioned(
      bottom: bottom,
      right: 24,
      child: GestureDetector(
        onTap: _onTap,
        // Allow holding down for rapid taps.
        onTapDown: (_) => widget.game.player.attackNearbyEnemies(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: _AttackButtonFace(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AttackButtonFace extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _AttackButtonFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCCB71C1C), // semi-transparent crimson
        border: Border.all(
          color: AppColors.ancientGold,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55FF0000),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '⚔',
          style: TextStyle(fontSize: 26),
          semanticsLabel: 'Attack',
        ),
      ),
    );
  }
}
