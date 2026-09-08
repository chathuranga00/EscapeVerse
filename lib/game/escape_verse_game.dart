import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../main.dart' show appLeaderboard;
import 'components/game_world.dart';
import 'components/player.dart';
import 'data/worlds.dart';
import 'models/dialogue.dart';
import 'services/audio_service.dart';
import 'systems/inventory_manager.dart';
import 'systems/mission_manager.dart';
import 'systems/save_manager.dart';

// ── Overlay key constants ─────────────────────────────────────────────────────
const String kMissionHudOverlay      = 'missionHud';
const String kAttackButtonOverlay    = 'attackButton';
const String kDialogueOverlay        = 'dialogue';
const String kInventoryButtonOverlay = 'inventoryButton';
const String kInventoryPanelOverlay  = 'inventoryPanel';
const String kWorldCompleteOverlay   = 'worldComplete';
const String kPauseMenuOverlay       = 'pauseMenu';
const String kMuteButtonOverlay      = 'muteButton';

// ─────────────────────────────────────────────────────────────────────────────

/// The root Flame game for EscapeVerse.
///
/// Accepts a [WorldConfig] so the same game class drives every world.
class EscapeVerseGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {

  EscapeVerseGame({
    required this.worldConfig,
    this.saveData,
    this.characterName = 'Unknown',
  });

  final WorldConfig  worldConfig;
  final SaveData?    saveData;
  final String       characterName;

  // ── Public systems ─────────────────────────────────────────────────────────

  late final MissionManager  missionManager;
  late final InventoryManager inventoryManager;
  late final AudioService    audio;

  DialogueSequence? activeDialogue;

  Player get player => _player;

  // ── Private ────────────────────────────────────────────────────────────────

  late final Player           _player;
  late final JoystickComponent _joystick;
  late final GameWorld        _gameWorld;

  /// Tracks unlocked world ids so they can be persisted on save.
  late List<String> _unlockedWorlds;

  /// True once the world-complete overlay has been triggered this session
  /// (prevents showing it twice if allComplete fires again in the same frame).
  bool _worldCompleteShown = false;

  /// Tracks when this game session started (used for totalTimeSeconds).
  late final DateTime _sessionStart;

  /// Whether the game loop is currently paused by the player.
  bool get isPaused => _isPaused;
  bool _isPaused = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Restore or initialise unlocked worlds list.
    _unlockedWorlds = List<String>.from(
      saveData?.unlockedWorldIds ?? ['world1'],
    );
    // Always ensure the current world is in the list (safety guard).
    if (!_unlockedWorlds.contains(worldConfig.id)) {
      _unlockedWorlds.add(worldConfig.id);
    }

    // ── Audio ─────────────────────────────────────────────────────────────
    audio = AudioService();
    _sessionStart = DateTime.now();
    await audio.playBgmForWorld(worldConfig.id);

    // ── Mission system ────────────────────────────────────────────────────
    final missions = worldConfig.missions();
    saveData?.restoreMissions(missions);
    missionManager = MissionManager(
      missions: missions,
      onAnyChange: _onMissionChange,
    );

    // ── Inventory ─────────────────────────────────────────────────────────
    inventoryManager = saveData?.restoreInventory() ?? InventoryManager();

    // ── Overlays ──────────────────────────────────────────────────────────
    overlays.add(kMissionHudOverlay);
    overlays.add(kAttackButtonOverlay);
    overlays.add(kInventoryButtonOverlay);
    overlays.add(kMuteButtonOverlay);

    // ── World ─────────────────────────────────────────────────────────────
    _gameWorld = GameWorld(config: worldConfig);
    await world.add(_gameWorld);

    // ── Player ────────────────────────────────────────────────────────────
    // Use the world's designated clear spawn point; fall back to save data.
    final spawnPos = _gameWorld.playerSpawn.isZero()
        ? _gameWorld.worldSize / 2
        : _gameWorld.playerSpawn;
    final startPos = saveData != null
        ? Vector2(saveData!.playerX, saveData!.playerY)
        : spawnPos;

    _player = Player(
      startPosition: startPos,
      worldSize:     _gameWorld.worldSize,
    );
    await world.add(_player);

    // ── Camera ────────────────────────────────────────────────────────────
    // 1.2× zoom — shows more of the world so the edges never go black.
    camera.viewfinder.zoom = 1.2;
    camera.follow(_player, maxSpeed: 400);
    camera.setBounds(
      Rectangle.fromRect(
        Rect.fromLTWH(0, 0, _gameWorld.worldSize.x, _gameWorld.worldSize.y),
      ),
      considerViewport: false,  // don't stop early — fill the whole viewport
    );

    // ── Joystick ──────────────────────────────────────────────────────────
    _joystick = JoystickComponent(
      knob: CircleComponent(
        radius: _kKnobRadius,
        paint: Paint()..color = const Color(0xAAFFFFFF),
      ),
      background: CircleComponent(
        radius: _kJoystickRadius,
        paint: Paint()..color = const Color(0x55D4A017),
      ),
      margin:      const EdgeInsets.only(left: 60, bottom: 80),
      knobRadius:  _kJoystickRadius - _kKnobRadius,
    );
    await camera.viewport.add(_joystick);

    // If restoring a completed world, show complete overlay immediately.
    if (missionManager.allComplete && !_worldCompleteShown) {
      _triggerWorldComplete();
    }
  }

  // ── Dialogue ───────────────────────────────────────────────────────────────

  void openDialogue(DialogueSequence sequence) {
    activeDialogue = sequence;
    _player.pauseForDialogue();
    overlays.add(kDialogueOverlay);
  }

  void closeDialogue() {
    overlays.remove(kDialogueOverlay);
    activeDialogue = null;
    _player.resumeFromDialogue();
  }

  // ── World complete ─────────────────────────────────────────────────────────

  void _triggerWorldComplete() {
    if (_worldCompleteShown) return;
    _worldCompleteShown = true;

    // Unlock the next world and persist.
    final next = nextWorld(worldConfig.id);
    if (next != null && !_unlockedWorlds.contains(next.id)) {
      _unlockedWorlds.add(next.id);
    }

    // Pause player so they can't run around behind the overlay.
    _player.pauseForDialogue();

    // Stop BGM on world completion (world-select screen has no BGM yet).
    audio.stopBgm();

    // Update leaderboard — fire-and-forget.
    _updateLeaderboard();

    // Auto-save with updated unlocks before showing the overlay.
    _autoSave();

    overlays.add(kWorldCompleteOverlay);
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────

  void _updateLeaderboard() {
    final sessionSeconds =
        DateTime.now().difference(_sessionStart).inSeconds;
    final worldsCompleted = _unlockedWorlds.length - 1;
    appLeaderboard?.upsertEntry(
      displayName:      characterName,
      worldsCompleted:  worldsCompleted,
      totalTimeSeconds: sessionSeconds,
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  void _autoSave() {
    SaveManager.save(
      SaveManager.snapshot(
        worldId:          worldConfig.id,
        characterName:    characterName,
        playerX:          _player.position.x,
        playerY:          _player.position.y,
        missions:         missionManager.missions.value,
        inventory:        inventoryManager,
        unlockedWorldIds: _unlockedWorlds,
      ),
    );
  }

  void triggerAutoSave() => _autoSave();

  /// Unlocked world ids — read by WorldSelectScreen via the save or in-memory.
  List<String> get unlockedWorldIds => List.unmodifiable(_unlockedWorlds);

  // ── Mission change hook ────────────────────────────────────────────────────

  void _onMissionChange() {
    _autoSave();
    if (missionManager.allComplete && !_worldCompleteShown) {
      // Defer one frame so the last mission's progress paint finishes first.
      Future.microtask(_triggerWorldComplete);
    }
  }

  // ── Pause ──────────────────────────────────────────────────────────────────

  void pauseGame() {
    if (_isPaused) return;
    _isPaused = true;
    pauseEngine();
    audio.pauseBgm();
    overlays.add(kPauseMenuOverlay);
  }

  void resumeGame() {
    if (!_isPaused) return;
    _isPaused = false;
    overlays.remove(kPauseMenuOverlay);
    resumeEngine();
    audio.resumeBgm();
  }

  // ── Lifecycle (dispose) ────────────────────────────────────────────────────

  @override
  void onRemove() {
    audio.dispose();
    super.onRemove();
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _player.setMoveDirection(_joystick.relativeDelta);
  }

  // ── Visual ─────────────────────────────────────────────────────────────────

  @override
  Color backgroundColor() => worldConfig.palette.backgroundColor;

  // ── Constants ──────────────────────────────────────────────────────────────

  static const double _kJoystickRadius = 60.0;
  static const double _kKnobRadius     = 25.0;
}
