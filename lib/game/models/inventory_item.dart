// Pure Dart — no Flutter or Flame imports. Safe to unit test in isolation.

/// A single type of item the player can carry.
///
/// [count] is the only mutable field; everything else is set at construction.
/// Items are identified by [id] across save/load cycles.
class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    this.count = 1,
  }) : assert(count >= 0);

  /// Stable unique identifier, e.g. `'relic'`.
  final String id;

  /// Human-readable name shown in the inventory grid.
  final String name;

  /// Unicode code point of the icon character used as placeholder art.
  /// e.g. `0x1F3FA` for 🏺. Replace with a sprite reference when art lands.
  final int iconCodePoint;

  /// Stack count — how many of this item the player currently holds.
  int count;

  // ── JSON ──────────────────────────────────────────────────────────────────

  /// Serialise to a map suitable for JSON encoding.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'count': count,
      };

  /// Deserialise from a JSON map produced by [toJson].
  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        iconCodePoint: json['iconCodePoint'] as int,
        count: json['count'] as int,
      );

  @override
  String toString() => 'InventoryItem($id ×$count)';
}
