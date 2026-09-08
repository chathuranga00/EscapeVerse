import 'package:flutter/material.dart';

import '../game/escape_verse_game.dart';
import '../routes.dart';
import '../theme/app_theme.dart';

/// A semi-transparent pause overlay with Resume / Restart / Main Menu actions.
///
/// The game engine is already paused ([FlameGame.pauseEngine]) before this
/// overlay is shown; this widget only handles Flutter-side navigation.
class PauseMenu extends StatelessWidget {
  const PauseMenu({super.key, required this.game});

  final EscapeVerseGame game;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _resume() {
    game.resumeGame();
  }

  void _restartWorld(BuildContext context) {
    game.audio.stopBgm();
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: GameScreenArgs(
        characterName: game.characterName,
        worldConfig:   game.worldConfig,
        saveData:      null, // fresh start for this world
      ),
    );
  }

  void _mainMenu(BuildContext context) {
    game.audio.stopBgm();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC000000), // dark scrim
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1F0F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.ancientGold, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: AppColors.ancientGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game.worldConfig.name,
                style: const TextStyle(
                  color: AppColors.mutedParchment,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 32),

              // ── Resume ───────────────────────────────────────────────
              _PauseButton(
                label: 'RESUME',
                icon: Icons.play_arrow_rounded,
                primary: true,
                onTap: _resume,
              ),

              const SizedBox(height: 12),

              // ── Restart world ─────────────────────────────────────────
              _PauseButton(
                label: 'RESTART WORLD',
                icon: Icons.replay_rounded,
                onTap: () => _restartWorld(context),
              ),

              const SizedBox(height: 12),

              // ── Main menu ────────────────────────────────────────────
              _PauseButton(
                label: 'MAIN MENU',
                icon: Icons.home_outlined,
                onTap: () => _mainMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.ancientGold
              : AppColors.darkMoss.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: primary ? AppColors.ancientGold : AppColors.stoneBrown,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: primary ? AppColors.deepJungle : AppColors.parchment,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: primary ? AppColors.deepJungle : AppColors.parchment,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
