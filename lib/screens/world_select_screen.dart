import 'package:flutter/material.dart';

import '../game/data/worlds.dart';
import '../game/systems/save_manager.dart';
import '../routes.dart';
import '../theme/app_theme.dart';

/// Arguments passed to [WorldSelectScreen] via Navigator.
class WorldSelectArgs {
  const WorldSelectArgs({
    required this.characterName,
    required this.unlockedWorldIds,
    this.existingSave,
  });

  final String characterName;
  final List<String> unlockedWorldIds;
  final SaveData? existingSave;
}

// ─────────────────────────────────────────────────────────────────────────────

class WorldSelectScreen extends StatelessWidget {
  const WorldSelectScreen({super.key, required this.args});

  final WorldSelectArgs args;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your World')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where will you venture?',
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            Expanded(
              child: ListView.separated(
                itemCount: kAllWorlds.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final world = kAllWorlds[index];
                  final isUnlocked =
                      args.unlockedWorldIds.contains(world.id);
                  return _WorldCard(
                    world: world,
                    isUnlocked: isUnlocked,
                    onTap: isUnlocked
                        ? () => _launchWorld(context, world)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchWorld(BuildContext context, WorldConfig world) {
    Navigator.pushNamed(
      context,
      AppRoutes.game,
      arguments: GameScreenArgs(
        characterName: args.characterName,
        worldConfig:   world,
        // Pass an existing save only if it's for this world (to restore
        // position + progress). For a different world, start fresh.
        saveData: (args.existingSave?.currentWorldId == world.id)
            ? args.existingSave
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.isUnlocked,
    this.onTap,
  });

  final WorldConfig world;
  final bool isUnlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isUnlocked ? 1.0 : 0.45,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: isUnlocked
                ? world.accentColor.withValues(alpha: 0.25)
                : AppColors.darkMoss.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUnlocked ? world.accentColor : AppColors.stoneBrown,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Color stripe
              Container(
                width: 8,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? world.accentColor
                      : AppColors.stoneBrown,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(7)),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name.toUpperCase(),
                      style: textTheme.headlineMedium?.copyWith(
                        color: isUnlocked
                            ? AppColors.parchment
                            : AppColors.mutedParchment,
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      world.subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedParchment,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Lock / play icon
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  isUnlocked ? Icons.play_circle_outline : Icons.lock_outline,
                  color: isUnlocked
                      ? world.accentColor
                      : AppColors.stoneBrown,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
