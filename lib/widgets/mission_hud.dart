import 'package:flutter/material.dart';

import '../game/models/mission.dart';
import '../game/systems/mission_manager.dart';
import '../theme/app_theme.dart';

/// A Flutter overlay widget that displays active mission progress.
///
/// Pinned to the top-left of the screen. Listens to [MissionManager.missions]
/// (a [MissionNotifier]) and rebuilds whenever progress changes.
///
/// Wire it up via [GameWidget.overlayBuilderMap] — see [GameScreen] for usage.
class MissionHud extends StatefulWidget {
  const MissionHud({super.key, required this.missionManager});

  final MissionManager missionManager;

  @override
  State<MissionHud> createState() => _MissionHudState();
}

class _MissionHudState extends State<MissionHud> {
  @override
  void initState() {
    super.initState();
    widget.missionManager.missions.addListener(_onMissionsChanged);
  }

  @override
  void dispose() {
    widget.missionManager.missions.removeListener(_onMissionsChanged);
    super.dispose();
  }

  void _onMissionsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final missions = widget.missionManager.missions.value;
    if (missions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      // Respect the status-bar safe area.
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      // Cap width so it never crowds the centre of the screen.
      width: 220,
      child: _MissionPanel(missions: missions),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({required this.missions});

  final List<Mission> missions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.deepJungle.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.stoneBrown.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────
          const Text(
            'MISSIONS',
            style: TextStyle(
              color: AppColors.ancientGold,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: AppColors.stoneBrown, height: 1, thickness: 1),
          const SizedBox(height: 6),
          // ── Mission rows ───────────────────────────────────────────
          ...missions.map((m) => _MissionRow(mission: m)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final isComplete = mission.isComplete;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title + completion tick ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 6),
                child: Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 13,
                  color: isComplete
                      ? AppColors.ancientGold
                      : AppColors.mutedParchment,
                ),
              ),
              // Title — strike-through when done
              Expanded(
                child: Text(
                  mission.title,
                  style: TextStyle(
                    color: isComplete
                        ? AppColors.mutedParchment
                        : AppColors.parchment,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: isComplete
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.mutedParchment,
                  ),
                ),
              ),
            ],
          ),
          // ── Progress bar (only for countable missions) ───────────
          if (_isCountable(mission.type)) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 19),
              child: _ProgressBar(
                current: mission.currentCount,
                target: mission.targetCount,
                label: mission.progressLabel,
                complete: isComplete,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns true for mission types where numeric progress makes sense.
  bool _isCountable(MissionType type) =>
      type == MissionType.collect || type == MissionType.defeatEnemy;
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.current,
    required this.target,
    required this.label,
    required this.complete,
  });

  final int current;
  final int target;
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final fraction = (current / target).clamp(0.0, 1.0);

    return Row(
      children: [
        // Bar track
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: AppColors.stoneBrown.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(
                  complete ? AppColors.ancientGold : AppColors.fadedGold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Numeric label
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedParchment,
            fontSize: 10,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
