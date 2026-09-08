// This file imports shared_preferences (Flutter plugin) and dart:convert.
// It is intentionally kept as a thin I/O layer.
//
// ## Backend
// When [SaveManager.cloudSave] is set (done in main.dart after Firebase init),
// all reads and writes go through [CloudSaveService], which writes to both
// Firestore AND local shared_preferences.  When it is null (before Firebase
// initialises, or in unit tests), all I/O falls back to local
// shared_preferences only — identical to the pre-Firebase behaviour.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission.dart';
import '../../services/cloud_save_service.dart';
import 'inventory_manager.dart';

/// The key under which the save JSON is stored in shared_preferences.
const String _kSaveKey = 'escapeverse_save_v1';

// ─────────────────────────────────────────────────────────────────────────────
// MissionProgress  (lightweight save DTO — not Mission itself)
// ─────────────────────────────────────────────────────────────────────────────

/// Snapshot of a single mission's progress for serialisation.
///
/// Deliberately separate from [Mission] so the save format doesn't couple to
/// the runtime model — a future schema migration only needs to update
/// [MissionProgress.fromJson].
class MissionProgress {
  const MissionProgress({required this.id, required this.currentCount});

  final String id;
  final int currentCount;

  Map<String, dynamic> toJson() => {'id': id, 'currentCount': currentCount};

  factory MissionProgress.fromJson(Map<String, dynamic> json) =>
      MissionProgress(
        id: json['id'] as String,
        currentCount: json['currentCount'] as int,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SaveData
// ─────────────────────────────────────────────────────────────────────────────

/// Full serialisable game state.
///
/// ## Swapping the backend
/// The JSON schema here is the contract between the game and storage.
/// To move from [shared_preferences] to Firestore:
///   1. Keep [toJson] / [fromJson] exactly as-is.
///   2. Replace [SaveManager._write] / [SaveManager._read] with Firestore
///      document read/write calls.
///   3. Nothing else in the game needs to change.
class SaveData {
  SaveData({
    required this.currentWorldId,
    required this.characterName,
    required this.playerX,
    required this.playerY,
    required this.missionProgress,
    required this.inventory,
    List<String>? unlockedWorldIds,
    DateTime? savedAt,
  }) : unlockedWorldIds = unlockedWorldIds ?? ['world1'],
       savedAt = savedAt ?? DateTime.now();

  final String currentWorldId;
  final String characterName;
  final double playerX;
  final double playerY;
  final List<MissionProgress> missionProgress;
  final List<Map<String, dynamic>> inventory;

  /// World ids the player has unlocked. Always contains at least `'world1'`.
  final List<String> unlockedWorldIds;

  final DateTime savedAt;

  // ── JSON ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'currentWorldId': currentWorldId,
        'characterName': characterName,
        'playerX': playerX,
        'playerY': playerY,
        'missionProgress': missionProgress.map((m) => m.toJson()).toList(),
        'inventory': inventory,
        'unlockedWorldIds': unlockedWorldIds,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SaveData.fromJson(Map<String, dynamic> json) => SaveData(
        currentWorldId: json['currentWorldId'] as String,
        characterName:  json['characterName'] as String,
        playerX:  (json['playerX'] as num).toDouble(),
        playerY:  (json['playerY'] as num).toDouble(),
        missionProgress: (json['missionProgress'] as List)
            .cast<Map<String, dynamic>>()
            .map(MissionProgress.fromJson)
            .toList(),
        inventory: (json['inventory'] as List).cast<Map<String, dynamic>>(),
        unlockedWorldIds: json.containsKey('unlockedWorldIds')
            ? (json['unlockedWorldIds'] as List).cast<String>()
            : ['world1'], // back-compat for saves before this field existed
        savedAt: DateTime.parse(json['savedAt'] as String),
      );

  /// Applies this save's mission progress onto [missions].
  ///
  /// Missions not mentioned in the save are left at currentCount = 0.
  void restoreMissions(List<Mission> missions) {
    final byId = {for (final m in missionProgress) m.id: m};
    for (final mission in missions) {
      final saved = byId[mission.id];
      if (saved != null) {
        mission.currentCount =
            saved.currentCount.clamp(0, mission.targetCount);
      }
    }
  }

  /// Builds an [InventoryManager] populated from this save.
  InventoryManager restoreInventory() =>
      InventoryManager.fromJson(inventory);
}

// ─────────────────────────────────────────────────────────────────────────────
// SaveManager
// ─────────────────────────────────────────────────────────────────────────────

/// Persists and retrieves [SaveData] using [SharedPreferences].
///
/// All methods are static for convenience — there is only ever one save slot
/// per device in this version. Add a slot index parameter later for multiple
/// save files.
class SaveManager {
  SaveManager._();

  // ── Cloud backend (optional) ──────────────────────────────────────────────

  /// Set this once Firebase is initialised (in main.dart) so all subsequent
  /// saves and loads go through Firestore with local fallback.
  ///
  /// When null, pure shared_preferences is used (offline / test mode).
  static CloudSaveService? cloudSave;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns true if a save exists (locally or in Firestore).
  static Future<bool> hasSave() async {
    if (cloudSave != null) {
      return (await cloudSave!.load()) != null;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kSaveKey);
  }

  /// Loads the save. Cloud is preferred; falls back to local when offline.
  static Future<SaveData?> load() async {
    if (cloudSave != null) return cloudSave!.load();
    return _localLoad();
  }

  /// Writes [data] to cloud (if available) and local storage.
  static Future<void> save(SaveData data) async {
    if (cloudSave != null) {
      await cloudSave!.save(data);
    } else {
      await _localSave(data);
    }
  }

  /// Deletes the save (used by "New Game").
  static Future<void> deleteSave() async {
    if (cloudSave != null) {
      await cloudSave!.deleteSave();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSaveKey);
    }
  }

  // ── Local-only fallback methods ───────────────────────────────────────────

  static Future<SaveData?> _localLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSaveKey);
      if (raw == null) return null;
      return SaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _localSave(SaveData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSaveKey, jsonEncode(data.toJson()));
    } catch (_) {}
  }

  /// Convenience builder — snapshot current game state into a [SaveData].
  ///
  /// Pass the live runtime objects; this method does not hold references to
  /// them after returning.
  static SaveData snapshot({
    required String worldId,
    required String characterName,
    required double playerX,
    required double playerY,
    required List<Mission> missions,
    required InventoryManager inventory,
    List<String>? unlockedWorldIds,
  }) =>
      SaveData(
        currentWorldId: worldId,
        characterName: characterName,
        playerX: playerX,
        playerY: playerY,
        missionProgress: missions
            .map((m) => MissionProgress(id: m.id, currentCount: m.currentCount))
            .toList(),
        inventory: inventory.toJson(),
        unlockedWorldIds: unlockedWorldIds ?? ['world1'],
      );
}
