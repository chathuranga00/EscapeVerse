// Pure Dart — no Flutter or Flame imports. Safe to unit test in isolation.
// The only dart:core dependency is dart:core itself (ValueNotifier lives in
// package:flutter, so we use a thin hand-rolled notifier to stay UI-agnostic).

import '../models/mission.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight observable — keeps MissionManager free of Flutter imports
// ─────────────────────────────────────────────────────────────────────────────

/// A minimal observable value holder.
///
/// Mirrors the Flutter [ValueNotifier] contract so UI code can listen to
/// mission updates without MissionManager importing Flutter.
///
/// The UI layer (which *does* import Flutter) can wrap this in a real
/// [ValueListenableBuilder] by passing [MissionNotifier] as the listenable —
/// it satisfies the same interface.
class MissionNotifier {
  final List<void Function()> _listeners = [];

  List<Mission> _value;

  MissionNotifier(List<Mission> initial) : _value = List.unmodifiable(initial);

  /// The current snapshot of active missions (unmodifiable).
  List<Mission> get value => _value;

  /// Register a callback invoked whenever missions change.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Remove a previously registered callback.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Update the mission list and notify all listeners.
  void _notify(List<Mission> updated) {
    _value = List.unmodifiable(updated);
    for (final l in _listeners) {
      l();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MissionManager
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks all active missions for the current world and emits change
/// notifications when progress is made.
///
/// ## Usage
/// ```dart
/// final manager = MissionManager(missions: world1Missions());
///
/// // From a collectible component:
/// game.missionManager.reportCollected('relic');
///
/// // From UI:
/// ValueListenableBuilder(
///   valueListenable: game.missionManager.missions,
///   builder: (_, missions, __) { ... },
/// );
/// ```
///
/// ## Design rules
/// - No Flutter or Flame imports — keep this class unit-testable in plain Dart.
/// - All mutation goes through the `report*` methods so the notifier always
///   fires and the list stays consistent.
/// - Completed missions are kept in the list (with [Mission.isComplete] == true)
///   so the HUD can show a ✓ state instead of suddenly disappearing.
class MissionManager {
  MissionManager({
    required List<Mission> missions,
    this.onAnyChange,
  }) : _missions = List.of(missions) {
    _notifier = MissionNotifier(_missions);
  }

  final List<Mission> _missions;
  late final MissionNotifier _notifier;

  /// Optional callback fired after any mission progress change.
  /// Use this to trigger auto-save without coupling MissionManager to the game.
  final void Function()? onAnyChange;

  /// Observable snapshot of all missions (active and completed).
  ///
  /// Conforms to the same interface as Flutter's [ValueNotifier] / [ValueListenable]
  /// — wire it directly into [ValueListenableBuilder] in the UI layer.
  MissionNotifier get missions => _notifier;

  // ── Report methods ─────────────────────────────────────────────────────────

  /// Call when the player picks up a collectible with [itemId].
  ///
  /// Increments all incomplete [MissionType.collect] missions whose
  /// [Mission.targetId] matches [itemId].
  void reportCollected(String itemId) {
    _increment(MissionType.collect, itemId);
  }

  /// Call when the player enters a named trigger zone with [zoneId].
  ///
  /// Completes all incomplete [MissionType.reachLocation] missions whose
  /// [Mission.targetId] matches [zoneId] (counts up to [Mission.targetCount],
  /// which is typically 1).
  void reportReachedZone(String zoneId) {
    _increment(MissionType.reachLocation, zoneId);
  }

  /// Call when the player defeats an enemy with type id [enemyId].
  ///
  /// Increments all incomplete [MissionType.defeatEnemy] missions whose
  /// [Mission.targetId] matches [enemyId].
  void reportEnemyDefeated(String enemyId) {
    _increment(MissionType.defeatEnemy, enemyId);
  }

  /// Call when the player finishes talking to an NPC with [npcId].
  ///
  /// Completes all incomplete [MissionType.talkToNpc] missions whose
  /// [Mission.targetId] matches [npcId].
  void reportTalkedToNpc(String npcId) {
    _increment(MissionType.talkToNpc, npcId);
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Returns all missions that are not yet complete.
  List<Mission> get activeMissions =>
      _missions.where((m) => !m.isComplete).toList(growable: false);

  /// Returns all completed missions.
  List<Mission> get completedMissions =>
      _missions.where((m) => m.isComplete).toList(growable: false);

  /// Whether every mission in this world is complete.
  bool get allComplete => _missions.every((m) => m.isComplete);

  /// Looks up a mission by [id]. Returns null if not found.
  Mission? findById(String id) {
    for (final m in _missions) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _increment(MissionType type, String targetId) {
    var changed = false;

    for (final mission in _missions) {
      if (mission.type != type) continue;
      if (mission.targetId != targetId) continue;
      if (mission.isComplete) continue;

      mission.currentCount =
          (mission.currentCount + 1).clamp(0, mission.targetCount);
      changed = true;
    }

    if (changed) {
      _notifier._notify(_missions);
      onAnyChange?.call();
    }
  }
}
