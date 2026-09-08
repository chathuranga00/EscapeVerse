import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/escape_verse_game.dart';
import '../game/game_lifecycle_observer.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import '../widgets/attack_button.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/inventory_panel.dart';
import '../widgets/mission_hud.dart';
import '../widgets/mute_button.dart';
import '../widgets/pause_menu.dart';
import '../widgets/world_complete_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.args});

  final GameScreenArgs args;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final EscapeVerseGame _game;
  late final GameLifecycleObserver _lifecycleObserver;
  bool _inventoryOpen = false;

  @override
  void initState() {
    super.initState();
    _game = EscapeVerseGame(
      worldConfig:   widget.args.worldConfig,
      saveData:      widget.args.saveData,
      characterName: widget.args.characterName,
    );
    _lifecycleObserver = GameLifecycleObserver(game: _game);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  void _toggleInventory() {
    setState(() => _inventoryOpen = !_inventoryOpen);
    if (_inventoryOpen) {
      _game.overlays.add(kInventoryPanelOverlay);
    } else {
      _game.overlays.remove(kInventoryPanelOverlay);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad    = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Flame canvas + overlays ───────────────────────────────────
          GameWidget<EscapeVerseGame>(
            game: _game,
            loadingBuilder: (_) => const _LoadingOverlay(),
            errorBuilder:   (_, error) => _ErrorOverlay(error: error),
            backgroundBuilder: (_) => Container(color: AppColors.deepJungle),
            overlayBuilderMap: {
              kMissionHudOverlay: (_, game) =>
                  MissionHud(missionManager: game.missionManager),
              kAttackButtonOverlay: (_, game) =>
                  AttackButton(game: game),
              kDialogueOverlay: (_, game) => DialogueBox(
                    sequence:  game.activeDialogue!,
                    onDismiss: game.closeDialogue,
                    onAdvance: game.audio.playDialogue,
                  ),
              kInventoryButtonOverlay: (_, game) =>
                  InventoryButton(game: game),
              kInventoryPanelOverlay: (_, game) => InventoryPanel(
                    inventoryManager: game.inventoryManager,
                    onClose: _toggleInventory,
                  ),
              kWorldCompleteOverlay: (_, game) => WorldCompleteOverlay(
                    game: game,
                    worldConfig: game.worldConfig,
                  ),
              kPauseMenuOverlay: (_, game) =>
                  PauseMenu(game: game),
              kMuteButtonOverlay: (_, game) =>
                  MuteButton(game: game),
            },
          ),

          // ── Pause button (top-centre, above the game canvas) ──────────
          Positioned(
            top:  topPad + 12,
            left: 0,
            right: 0,
            child: Center(
              child: _PauseButton(onTap: () => _game.pauseGame()),
            ),
          ),

          // ── Back to menu (bottom-right) ───────────────────────────────
          Positioned(
            bottom: bottomPad + 16,
            right:  100,
            child: _BackButton(
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.darkMoss.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.stoneBrown, width: 1),
        ),
        child: const Icon(
          Icons.pause_rounded,
          color: AppColors.parchment,
          size: 20,
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deepJungle,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.ancientGold,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 24),
            Text(
              'Entering the Verse…',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.ancientGold,
                    letterSpacing: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deepJungle,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.ancientGold, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load the game world.',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.parchment),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedParchment),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkMoss.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.stoneBrown, width: 1),
        ),
        child: const Text(
          '← Menu',
          style: TextStyle(
            color: AppColors.mutedParchment,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
