// Pure Dart — no Flutter or Flame imports except Color (painting.dart).
// This file is the single source of truth for world configuration.
// Add a new WorldConfig entry here to add a new world — nothing else
// in the codebase needs to change for the world to appear in the select
// screen and load correctly in GameWorld.

import 'package:flutter/painting.dart';

import '../models/mission.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProceduralPalette
// ─────────────────────────────────────────────────────────────────────────────

/// Color scheme used by the procedural tile generator when no .tmx is present.
///
/// Each world can have its own palette so the fallback levels look distinct.
class ProceduralPalette {
  const ProceduralPalette({
    required this.tileA,
    required this.tileB,
    required this.obstacleColor,
    required this.obstacleOutline,
    required this.backgroundColor,
    // Extended visual fields
    this.obstacleHighlight = const Color(0xFFFFFFFF),
    this.pathColor = const Color(0xFF8B6914),
    this.pathEdge = const Color(0xFF5C4010),
    this.trunkColor = const Color(0xFF6B4226),
    this.trunkShadow = const Color(0xFF3E2010),
    this.canopyDark = const Color(0xFF1B4D1B),
    this.canopyMid = const Color(0xFF2D6B2D),
    this.canopyLight = const Color(0xFF4CAF50),
    this.grassColor = const Color(0xFF3A7D3A),
    this.grassTip = const Color(0xFF6DBF5A),
    // New rich-detail fields
    this.tileC = const Color(0xFF5B8C3A),
    this.tileDirt = const Color(0xFFC49A5A),
    this.tileStone = const Color(0xFFA09070),
    this.rockBaseColor = const Color(0xFF8A7A60),
    this.rockHighlight = const Color(0xFFB8A880),
    this.rockShadow = const Color(0xFF5A4E38),
    this.flowerRed = const Color(0xFFE84040),
    this.flowerYellow = const Color(0xFFFFD030),
    this.flowerWhite = const Color(0xFFF0EEE0),
    this.bushColor = const Color(0xFF2E7D32),
    this.bushHighlight = const Color(0xFF4CAF50),
    this.waterColor = const Color(0xFF1E88E5),
    this.waterHighlight = const Color(0xFF64B5F6),
  });

  final Color tileA;
  final Color tileB;
  final Color obstacleColor;
  final Color obstacleOutline;
  final Color backgroundColor;

  /// Top/left highlight on stone walls.
  final Color obstacleHighlight;

  /// Centre fill of the dirt path.
  final Color pathColor;

  /// Edge shadow of the dirt path.
  final Color pathEdge;

  /// Tree trunk fill.
  final Color trunkColor;

  /// Tree trunk right-side shadow.
  final Color trunkShadow;

  /// Back canopy layer (darkest).
  final Color canopyDark;

  /// Main canopy fill.
  final Color canopyMid;

  /// Canopy highlight blob.
  final Color canopyLight;

  /// Grass blade base colour.
  final Color grassColor;

  /// Grass blade tip colour.
  final Color grassTip;

  /// Third ground tile variant.
  final Color tileC;

  /// Dirt/earth tile colour.
  final Color tileDirt;

  /// Stone floor tile colour.
  final Color tileStone;

  /// Rock boulder base fill.
  final Color rockBaseColor;

  /// Rock boulder top-left highlight.
  final Color rockHighlight;

  /// Rock boulder right-bottom shadow.
  final Color rockShadow;

  /// Red flower accent.
  final Color flowerRed;

  /// Yellow flower accent.
  final Color flowerYellow;

  /// White/cream flower accent.
  final Color flowerWhite;

  /// Bush/shrub base fill.
  final Color bushColor;

  /// Bush highlight layer.
  final Color bushHighlight;

  /// Water body base colour.
  final Color waterColor;

  /// Water highlight / shimmer.
  final Color waterHighlight;

  // ── Built-in palettes ─────────────────────────────────────────────────────

  static const jungle = ProceduralPalette(
    // Ground tiles — vivid greens like the reference image
    tileA:             Color(0xFF4CAF50),   // vibrant mid-green
    tileB:             Color(0xFF66BB6A),   // lighter bright green
    tileC:             Color(0xFF388E3C),   // deep rich green patch
    tileDirt:          Color(0xFFC8A96A),   // warm sandy dirt
    tileStone:         Color(0xFF9E9478),   // ancient stone
    obstacleColor:     Color(0xFF9E8060),   // warm tan rock
    obstacleOutline:   Color(0xFF6A5030),
    obstacleHighlight: Color(0xFFD4AA70),
    backgroundColor:   Color(0xFF2E7D32),   // rich green (shown only at edges)
    pathColor:         Color(0xFFD4A95A),   // warm golden dirt path
    pathEdge:          Color(0xFF8B6830),   // darker path edge
    trunkColor:        Color(0xFF795548),   // warm brown trunk
    trunkShadow:       Color(0xFF4E342E),
    canopyDark:        Color(0xFF2E7D32),   // deep jungle green
    canopyMid:         Color(0xFF43A047),   // mid jungle green
    canopyLight:       Color(0xFF76C442),   // bright lime highlight
    grassColor:        Color(0xFF56A838),   // vivid grass
    grassTip:          Color(0xFF8BC34A),   // bright tip
    // Rocks
    rockBaseColor:     Color(0xFF8D7B60),
    rockHighlight:     Color(0xFFBEA882),
    rockShadow:        Color(0xFF5A4A32),
    // Flowers
    flowerRed:         Color(0xFFE53935),
    flowerYellow:      Color(0xFFFFD600),
    flowerWhite:       Color(0xFFF5F0E0),
    // Bushes
    bushColor:         Color(0xFF2E7D32),
    bushHighlight:     Color(0xFF66BB6A),
    // Water
    waterColor:        Color(0xFF1976D2),
    waterHighlight:    Color(0xFF64B5F6),
  );

  static const temple = ProceduralPalette(
    tileA:             Color(0xFF5A5560),
    tileB:             Color(0xFF6A6570),
    tileC:             Color(0xFF4A4550),
    tileDirt:          Color(0xFF7A6850),
    tileStone:         Color(0xFF8A8278),
    obstacleColor:     Color(0xFF7A7080),
    obstacleOutline:   Color(0xFF9A90A0),
    obstacleHighlight: Color(0xFFB0A8B8),
    backgroundColor:   Color(0xFF1A2028),
    pathColor:         Color(0xFF7A6850),
    pathEdge:          Color(0xFF4A4030),
    trunkColor:        Color(0xFF5A4838),
    trunkShadow:       Color(0xFF352820),
    canopyDark:        Color(0xFF2A4A38),
    canopyMid:         Color(0xFF3A6A50),
    canopyLight:       Color(0xFF509070),
    grassColor:        Color(0xFF3A6848),
    grassTip:          Color(0xFF60A870),
    rockBaseColor:     Color(0xFF6A6070),
    rockHighlight:     Color(0xFF9A90A0),
    rockShadow:        Color(0xFF2A2530),
    flowerRed:         Color(0xFF9050A0),
    flowerYellow:      Color(0xFF70A890),
    flowerWhite:       Color(0xFFD0C8E0),
    bushColor:         Color(0xFF2A4A38),
    bushHighlight:     Color(0xFF4A7860),
    waterColor:        Color(0xFF1A3050),
    waterHighlight:    Color(0xFF3060A0),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WorldConfig
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable configuration for a single game world.
///
/// All fields that [GameWorld] and [EscapeVerseGame] need are here —
/// add fields freely without touching game logic files.
class WorldConfig {
  const WorldConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.tmxFileName,
    required this.palette,
    required this.missions,
    required this.accentColor,
    this.isLockedByDefault = true,
  });

  /// Stable identifier used in save files, e.g. `'world1'`.
  final String id;

  /// Display name, e.g. `'Jungle Temple'`.
  final String name;

  /// Short flavour line shown on the world-select card.
  final String subtitle;

  /// Filename of the .tmx asset inside `assets/tiles/`.
  /// [GameWorld] tries to load this; falls back to the procedural generator.
  final String tmxFileName;

  /// Colors for the procedural fallback renderer.
  final ProceduralPalette palette;

  /// Mission list factory — called fresh each time the world is started.
  final List<Mission> Function() missions;

  /// Accent color for the world card UI.
  final Color accentColor;

  /// Whether this world requires a prior completion to unlock.
  final bool isLockedByDefault;
}

// ─────────────────────────────────────────────────────────────────────────────
// World definitions
// ─────────────────────────────────────────────────────────────────────────────

/// All worlds in release order.
///
/// Index 0 is always the starting world. The unlock system uses the order here:
/// completing world[n] unlocks world[n+1].
const List<WorldConfig> kAllWorlds = [world1Jungle, world2Temple];

// ── World 1 — Jungle ─────────────────────────────────────────────────────────

const WorldConfig world1Jungle = WorldConfig(
  id:             'world1',
  name:           'Jungle Temple',
  subtitle:       'Ancient ruins swallowed by the wild.',
  tmxFileName:    'World1_Jungle.tmx',
  palette:        ProceduralPalette.jungle,
  accentColor:    Color(0xFF2E6B3E),
  isLockedByDefault: false, // always available
  missions:       _world1Missions,
);

List<Mission> _world1Missions() => [
  Mission(
    id:          'w1_talk_elder',
    title:       'Speak with Elder Maro',
    description: 'Find Elder Maro deep in the jungle. He knows the way to the temple.',
    type:        MissionType.talkToNpc,
    targetId:    'elder_maro',
    targetCount: 1,
  ),
  Mission(
    id:          'w1_collect_relics',
    title:       'Collect Ancient Relics',
    description: 'Gather 5 relics scattered across the jungle ruins.',
    type:        MissionType.collect,
    targetId:    'relic',
    targetCount: 5,
  ),
  Mission(
    id:          'w1_defeat_scouts',
    title:       'Defeat the Jungle Scouts',
    description: 'Two guardian scouts patrol the outer ruins. Eliminate them.',
    type:        MissionType.defeatEnemy,
    targetId:    'jungle_scout',
    targetCount: 2,
  ),
  Mission(
    id:          'w1_defeat_guardian',
    title:       'Defeat the Jungle Guardians',
    description: 'Three powerful stone guardians protect the temple path.',
    type:        MissionType.defeatEnemy,
    targetId:    'jungle_guardian',
    targetCount: 3,
  ),
  Mission(
    id:          'w1_defeat_boss',
    title:       'Slay the High Guardian',
    description: 'The High Guardian is an ancient beast of immense power. It must fall.',
    type:        MissionType.defeatEnemy,
    targetId:    'high_guardian',
    targetCount: 1,
  ),
  Mission(
    id:          'w1_reach_temple',
    title:       'Reach the Temple Entrance',
    description: 'Pass through the great stone archway to enter the ancient temple.',
    type:        MissionType.reachLocation,
    targetId:    'temple_entrance',
    targetCount: 1,
  ),
];

// ── World 2 — Ancient Temple ──────────────────────────────────────────────────

const WorldConfig world2Temple = WorldConfig(
  id:          'world2',
  name:        'Ancient Temple',
  subtitle:    'Stone corridors hiding forgotten secrets.',
  tmxFileName: 'World2_Temple.tmx',
  palette:     ProceduralPalette.temple,
  accentColor: Color(0xFF8B7355),
  missions:    _world2Missions,
);

List<Mission> _world2Missions() => [
  Mission(
    id:          'w2_find_seal',
    title:       'Find the Ancient Seal',
    description: 'Recover the seal that unlocks the inner sanctum.',
    type:        MissionType.collect,
    targetId:    'ancient_seal',
    targetCount: 1,
  ),
  Mission(
    id:          'w2_defeat_sentinel',
    title:       'Defeat the Stone Sentinel',
    description: 'The sentinel guards the exit. It must fall.',
    type:        MissionType.defeatEnemy,
    targetId:    'stone_sentinel',
    targetCount: 1,
  ),
  Mission(
    id:          'w2_reach_sanctum',
    title:       'Enter the Inner Sanctum',
    description: 'Pass through the great doors at the temple\'s heart.',
    type:        MissionType.reachLocation,
    targetId:    'inner_sanctum',
    targetCount: 1,
  ),
];

// ── Lookup helpers ────────────────────────────────────────────────────────────

/// Returns the [WorldConfig] for [id], or null if not found.
WorldConfig? worldById(String id) {
  for (final w in kAllWorlds) {
    if (w.id == id) return w;
  }
  return null;
}

/// Returns the world that comes after [worldId] in the list, or null if
/// [worldId] is already the last world.
WorldConfig? nextWorld(String worldId) {
  final idx = kAllWorlds.indexWhere((w) => w.id == worldId);
  if (idx < 0 || idx >= kAllWorlds.length - 1) return null;
  return kAllWorlds[idx + 1];
}
