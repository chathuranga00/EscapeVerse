// Pure Dart — no Flutter or Flame imports. Safe to unit test in isolation.

/// The category of objective a [Mission] tracks.
enum MissionType {
  /// Player must collect [targetCount] items with a matching item id.
  collect,

  /// Player must physically reach a named zone in the world.
  reachLocation,

  /// Player must defeat [targetCount] enemies with a matching enemy id.
  defeatEnemy,

  /// Player must interact with a named NPC.
  talkToNpc,
}

// ─────────────────────────────────────────────────────────────────────────────

/// A single objective the player can complete.
///
/// [Mission] is intentionally immutable except for [currentCount], which is
/// incremented by [MissionManager]. All other fields are set at construction
/// and never change, making missions easy to serialise and restore.
class Mission {
  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetId,
    this.targetCount = 1,
  }) : assert(targetCount > 0, 'targetCount must be at least 1');

  /// Stable unique identifier, e.g. `'world1_collect_relics'`.
  final String id;

  /// Short display name shown in the HUD, e.g. `'Collect Ancient Relics'`.
  final String title;

  /// Longer explanation shown in a mission log / details screen.
  final String description;

  /// What kind of objective this is.
  final MissionType type;

  /// The item / zone / enemy / NPC identifier this mission tracks.
  ///
  /// For [MissionType.collect] this is the item id string.
  /// For [MissionType.reachLocation] this is the zone id string.
  /// For [MissionType.defeatEnemy] this is the enemy type id string.
  /// For [MissionType.talkToNpc] this is the NPC id string.
  final String targetId;

  /// How many times the objective must be triggered to complete the mission.
  /// Always ≥ 1. Ignored for [MissionType.reachLocation] and
  /// [MissionType.talkToNpc] (those complete on first trigger).
  final int targetCount;

  /// How many times the objective has been triggered so far.
  int currentCount = 0;

  /// Whether the mission has been fully completed.
  bool get isComplete => currentCount >= targetCount;

  /// Human-readable progress string, e.g. `"2 / 3"`.
  /// Returns `"Done"` once complete.
  String get progressLabel =>
      isComplete ? 'Done' : '$currentCount / $targetCount';

  @override
  String toString() =>
      'Mission($id, type: $type, progress: $progressLabel)';
}
