// Pure Dart — no Flutter or Flame imports. Safe to unit test in isolation.

import '../models/inventory_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryNotifier  (mirrors MissionNotifier pattern)
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight observable for the inventory list.
///
/// Same contract as Flutter's [ValueNotifier] so the UI can use
/// [ValueListenableBuilder] without this file importing Flutter.
class InventoryNotifier {
  final List<void Function()> _listeners = [];
  List<InventoryItem> _value;

  InventoryNotifier(List<InventoryItem> initial)
      : _value = List.unmodifiable(initial);

  /// Current snapshot — unmodifiable.
  List<InventoryItem> get value => _value;

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify(List<InventoryItem> updated) {
    _value = List.unmodifiable(updated);
    for (final l in _listeners) {
      l();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InventoryManager
// ─────────────────────────────────────────────────────────────────────────────

/// Manages the player's item inventory for a session.
///
/// Items are keyed by [InventoryItem.id]; stacking is handled automatically.
/// All mutations notify [items] so the UI rebuilds.
///
/// ## Save / restore
/// Use [toJson] / [fromJson] to serialise the full inventory into the save
/// document. The format is a plain JSON array, easy to swap for Firestore.
class InventoryManager {
  InventoryManager({List<InventoryItem>? initial})
      : _items = {
          for (final item in (initial ?? const <InventoryItem>[]))
            item.id: item,
        } {
    _notifier = InventoryNotifier(_items.values.toList());
  }

  // Internal map keyed by item id for O(1) lookups.
  final Map<String, InventoryItem> _items;
  late final InventoryNotifier _notifier;

  // ── Public observable ─────────────────────────────────────────────────────

  /// Reactive snapshot of all held items (non-zero counts only).
  InventoryNotifier get items => _notifier;

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Adds [amount] of [item] to the inventory, stacking if already present.
  ///
  /// If an item with the same [InventoryItem.id] exists, its count is
  /// incremented; otherwise the item is inserted as-is.
  void addItem(InventoryItem item, {int amount = 1}) {
    assert(amount > 0);
    if (_items.containsKey(item.id)) {
      _items[item.id]!.count += amount;
    } else {
      _items[item.id] = InventoryItem(
        id: item.id,
        name: item.name,
        iconCodePoint: item.iconCodePoint,
        count: amount,
      );
    }
    _notifier._notify(_items.values.toList());
  }

  /// Removes [amount] of [itemId] from the inventory.
  ///
  /// Clamps count at zero; removes the entry entirely when count hits 0.
  /// Returns true if the item existed, false if not found.
  bool removeItem(String itemId, {int amount = 1}) {
    assert(amount > 0);
    final item = _items[itemId];
    if (item == null) return false;

    item.count -= amount;
    if (item.count <= 0) {
      _items.remove(itemId);
    }
    _notifier._notify(_items.values.toList());
    return true;
  }

  /// Returns the held count for [itemId], or 0 if not in inventory.
  int countOf(String itemId) => _items[itemId]?.count ?? 0;

  /// Whether the inventory contains at least one of [itemId].
  bool has(String itemId) => countOf(itemId) > 0;

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Encodes the full inventory as a JSON-safe list.
  ///
  /// Suitable for embedding in [SaveData.toJson].
  /// Swap the target (shared_preferences → Firestore) without changing this.
  List<Map<String, dynamic>> toJson() =>
      _items.values.map((i) => i.toJson()).toList();

  /// Restores inventory from the JSON list produced by [toJson].
  factory InventoryManager.fromJson(List<dynamic> json) {
    final items = json
        .cast<Map<String, dynamic>>()
        .map(InventoryItem.fromJson)
        .toList();
    return InventoryManager(initial: items);
  }
}
