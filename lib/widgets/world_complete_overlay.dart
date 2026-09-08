import 'package:flutter/material.dart';

import '../game/data/worlds.dart';
import '../game/escape_verse_game.dart';
import '../routes.dart';
import '../theme/app_theme.dart';

// kWorldCompleteOverlay is defined in escape_verse_game.dart — imported above.

/// Full-screen "World Complete" overlay shown when all missions are done.
///
/// Displays a summary of completed missions and two actions:
/// - Continue → navigate to the world-select screen.
/// - Stay    → dismiss the overlay and keep exploring.
class WorldCompleteOverlay extends StatelessWidget {
  const WorldCompleteOverlay({
    super.key,
    required this.game,
    required this.worldConfig,
  });

  final EscapeVerseGame game;
  final WorldConfig worldConfig;

  void _onContinue(BuildContext context) {
    game.overlays.remove(kWorldCompleteOverlay);
    // Navigate to world select, replacing the game screen so the player
    // doesn't come back to a completed world with back-swipe.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.worldSelect,
      (route) => route.settings.name == AppRoutes.home,
    );
  }

  void _onStay() {
    game.overlays.remove(kWorldCompleteOverlay);
    game.player.resumeFromDialogue(); // re-enable movement
  }

  @override
  Widget build(BuildContext context) {
    final completedMissions = game.missionManager.completedMissions;

    return Container(
      color: const Color(0xDD0D1F0F), // near-opaque dark jungle
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Trophy icon ──────────────────────────────────────────
                const Text('🏆', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),

                // ── Title ────────────────────────────────────────────────
                Text(
                  'WORLD COMPLETE',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.ancientGold,
                        letterSpacing: 2,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  worldConfig.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.parchment,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),
                const Divider(color: AppColors.stoneBrown),
                const SizedBox(height: 16),

                // ── Mission summary ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: AppColors.ancientGold,
                      fontSize: 11,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...completedMissions.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ancientGold,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.title,
                            style: const TextStyle(
                              color: AppColors.parchment,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Next world hint ──────────────────────────────────────
                _NextWorldHint(currentWorldId: worldConfig.id),

                const SizedBox(height: 32),

                // ── Buttons ──────────────────────────────────────────────
                ElevatedButton(
                  onPressed: () => _onContinue(context),
                  child: const Text('CONTINUE TO WORLD SELECT'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _onStay,
                  child: const Text(
                    'Keep Exploring',
                    style: TextStyle(color: AppColors.mutedParchment),
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

// ─────────────────────────────────────────────────────────────────────────────

class _NextWorldHint extends StatelessWidget {
  const _NextWorldHint({required this.currentWorldId});

  final String currentWorldId;

  @override
  Widget build(BuildContext context) {
    final next = nextWorld(currentWorldId);
    if (next == null) {
      return const Text(
        'You have conquered all worlds.\nThe verse is yours.',
        style: TextStyle(
          color: AppColors.ancientGold,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkMoss.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.stoneBrown),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded,
              color: AppColors.ancientGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNLOCKED',
                  style: TextStyle(
                    color: AppColors.ancientGold,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  next.name,
                  style: const TextStyle(
                    color: AppColors.parchment,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  next.subtitle,
                  style: const TextStyle(
                    color: AppColors.mutedParchment,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
