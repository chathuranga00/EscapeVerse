// =============================================================================
// GameWorld — tile-based level container
// =============================================================================
//
// REPLACING THE PLACEHOLDER WITH A REAL TILED MAP
// ─────────────────────────────────────────────────
// 1. Open Tiled (https://www.mapeditor.org) and create an Orthogonal map:
//      • Tile size : 48 × 48 px  (must match _kTileSize below)
//      • Map size  : e.g. 40 × 25 tiles
//      • Layer format: CSV
// 2. Import your tileset PNG via File → New Tileset → Based on Tileset Image.
//    Save the .tsx alongside the .tmx in assets/tiles/.
// 3. Paint ground, obstacle, and decoration layers.
//    Name the collidable layer "Obstacles".
// 4. Add an Object Layer "Spawns" with a Point object "PlayerSpawn".
// 5. Save/export as  assets/tiles/<WorldConfig.tmxFileName>.
// 6. List every tileset PNG under assets/tiles/ in pubspec.yaml.
// 7. Hot-restart — TiledComponent.load() picks it up; procedural fallback skips.
// =============================================================================

import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart' show TextDirection, TextStyle, FontWeight;
import 'package:flutter/painting.dart';

import '../data/worlds.dart';
import '../escape_verse_game.dart';
import '../models/dialogue.dart';
import 'collectible.dart';
import 'enemy.dart';
import 'npc.dart';

const double _kTileSize     = 48.0;
const int    _kFallbackCols = 48;   // wider world — no black edges at 1.5× zoom
const int    _kFallbackRows = 28;
const String _kObstacleLayer = 'Obstacles';

// ─────────────────────────────────────────────────────────────────────────────

class GameWorld extends Component with HasGameReference<EscapeVerseGame> {
  GameWorld({required this.config});

  final WorldConfig config;

  Vector2 get worldSize => _worldSize;
  final Vector2 _worldSize = Vector2.zero();

  /// Clear open-grass spawn point for the player.
  /// Set by [_buildProceduralWorld] after layout is determined.
  Vector2 get playerSpawn => _playerSpawn;
  final Vector2 _playerSpawn = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      await _loadTiledMap();
    } catch (_) {
      await _buildProceduralWorld();
    }
  }

  Future<void> _loadTiledMap() async {
    final tiledMap = await TiledComponent.load(
      config.tmxFileName,
      Vector2.all(_kTileSize),
    );
    // Treat an empty map (no layers / zero tile count) as unusable —
    // fall through to the procedural generator instead.
    final tileMap = tiledMap.tileMap;
    final hasContent = tileMap.map.layers.isNotEmpty &&
        (tileMap.map.width > 0 && tileMap.map.height > 0);
    if (!hasContent) {
      throw Exception('TMX map "${config.tmxFileName}" has no tile layers — '
          'using procedural fallback.');
    }
    await add(tiledMap);
    _worldSize.setFrom(tiledMap.size);
    _addTiledObjectColliders(tiledMap);
  }

  void _addTiledObjectColliders(TiledComponent tiledMap) {
    final layer = tiledMap.tileMap.getLayer<ObjectGroup>(_kObstacleLayer);
    if (layer == null) return;
    for (final obj in layer.objects) {
      add(_RockCluster(
        position: Vector2(obj.x, obj.y),
        size:     Vector2(obj.width, obj.height),
        palette:  config.palette,
        seed:     obj.x.toInt() * 7 + obj.y.toInt() * 13,
      ));
    }
  }

  Future<void> _buildProceduralWorld() async {
    const ts = _kTileSize;
    _worldSize.setValues(_kFallbackCols * ts, _kFallbackRows * ts);

    // Player spawn — open grass area at tile (12, 6), well clear of rocks & path
    _playerSpawn.setValues(12 * ts + ts / 2, 6 * ts + ts / 2);

    // Layer 0 — rich textured ground (grass + dirt patches + stone areas)
    await add(_TerrainGround(
      cols: _kFallbackCols,
      rows: _kFallbackRows,
      tileSize: ts,
      palette: config.palette,
    ));

    // Layer 1 — stone-paved winding path
    await add(_StonePath(tileSize: ts, palette: config.palette));

    // Layer 2 — rock/boulder clusters (with collision)
    for (final (col, row, w, h, seed) in _kRockDefs) {
      add(_RockCluster(
        position: Vector2(col * ts, row * ts),
        size:     Vector2(w * ts, h * ts),
        palette:  config.palette,
        seed:     seed,
      ));
    }

    // Layer 3 — dense bush patches (no collision, visual fill)
    for (final (col, row, seed) in _kBushPositions) {
      add(_BushClump(
        position: Vector2(col * ts, row * ts),
        palette:  config.palette,
        seed:     seed,
      ));
    }

    // Layer 4 — decorative tropical trees
    for (final (col, row) in _kTreePositions(config.id)) {
      add(_Tree(
        position: Vector2(col * ts, row * ts),
        palette:  config.palette,
        seed:     col * 31 + row * 17,
      ));
    }

    // Layer 5 — animated grass tufts + wildflowers
    add(_AnimatedGrass(
      cols: _kFallbackCols, rows: _kFallbackRows,
      tileSize: ts, palette: config.palette,
    ));

    await _spawnEntities(ts);
  }

  // ── Layout definitions ────────────────────────────────────────────────────

  // (col, row, widthTiles, heightTiles, seed)
  static const _kRockDefs = <(int, int, int, int, int)>[
    (6,  5,  3, 2,  101),
    (16, 7,  2, 3,  202),
    (26, 4,  4, 2,  303),
    (36, 9,  3, 3,  404),
    (10, 16, 5, 2,  505),
    (42, 17, 2, 4,  606),
    (20, 21, 3, 2,  707),
    (3,  13, 2, 2,  808),
    (32, 6,  2, 2,  909),
    (44, 13, 2, 3, 1010),
    (13, 24, 3, 2, 1111),
    (38, 22, 2, 2, 1212),
  ];

  // (col, row, seed) — bush clumps
  static const _kBushPositions = <(int, int, int)>[
    (0,  2,  10), (8,  1,  20), (14, 3,  30), (22, 2,  40),
    (30, 1,  50), (38, 3,  60), (46, 2,  70),
    (1,  7,  80), (11, 9,  90), (18, 8, 100), (28, 10, 110),
    (35, 7, 120), (43, 9, 130),
    (4,  15, 140), (13, 16, 150), (23, 14, 160), (31, 16, 170),
    (40, 14, 180), (47, 16, 190),
    (5,  20, 200), (16, 22, 210), (27, 20, 220), (37, 23, 230),
    (45, 20, 240), (9, 26, 250), (24, 25, 260), (40, 26, 270),
  ];

  static List<(int, int)> _kTreePositions(String worldId) => [
    // Top border
    (0,  0), (4,  0), (9,  0), (15, 0), (21, 0), (27, 0),
    (33, 0), (39, 0), (45, 0),
    // Upper-mid scatter
    (2,  4), (12, 3), (19, 2), (29, 4), (41, 2), (47, 4),
    // Mid scatter
    (1,  10), (9,  11), (22, 10), (33, 12), (44, 11),
    // Lower scatter
    (4,  18), (14, 19), (25, 18), (36, 19), (46, 17),
    // Bottom border
    (0, 27), (5, 27), (11, 27), (17, 27), (23, 27),
    (29, 27), (35, 27), (41, 27), (47, 27),
  ];

  Future<void> _spawnEntities(double ts) async {
    switch (config.id) {
      case 'world1': await _spawnWorld1(ts);
      case 'world2': await _spawnWorld2(ts);
      default: break;
    }
  }

  Future<void> _spawnWorld1(double ts) async {
    // ── NPC: Elder Maro ──────────────────────────────────────────────────────
    await add(Npc(
      position: Vector2(10 * ts, 7 * ts),
      npcName:  'Elder Maro',
      sequence: DialogueSequence(
        lines: [
          const DialogueLine(speaker: 'Elder Maro',
              text: 'Traveller! You dare enter the cursed jungle? Then listen well.'),
          const DialogueLine(speaker: 'Elder Maro',
              text: 'Five ancient relics were scattered when the High Guardian rose. Recover them all.'),
          const DialogueLine(speaker: 'Elder Maro',
              text: 'Two scout sentinels patrol the outer ruins. Defeat them to open the inner path.'),
          const DialogueLine(speaker: 'Elder Maro',
              text: 'Three stone guardians guard the temple road. They are old magic — do not underestimate them.'),
          const DialogueLine(speaker: 'Elder Maro',
              text: 'And the High Guardian itself... it waits before the archway. Only then can you enter the temple.'),
          const DialogueLine(speaker: 'Elder Maro',
              text: 'The entrance is to the far east. Follow the stone road. Safe travels — you will need it.'),
        ],
        onComplete: () {
          game.missionManager.reportTalkedToNpc('elder_maro');
        },
      ),
    ));

    // ── 5 Relics spread across the map ───────────────────────────────────────
    for (final pos in [
      Vector2(5  * ts, 4  * ts),   // near spawn, easy
      Vector2(15 * ts, 16 * ts),   // mid-west, off path
      Vector2(24 * ts, 6  * ts),   // north mid
      Vector2(36 * ts, 20 * ts),   // south-east
      Vector2(43 * ts, 8  * ts),   // near temple, guarded
    ]) {
      await add(Collectible(position: pos, itemId: 'relic'));
    }

    // ── 2 Scout enemies (fast, weak) ─────────────────────────────────────────
    await add(Enemy(
      position:    Vector2(16 * ts, 11 * ts),
      patrolEnd:   Vector2(20 * ts, 11 * ts),
      enemyId:     'jungle_scout',
      maxHp:       30,
      patrolSpeed: 80,
      chaseSpeed:  140,
      chaseRadius: 130,
      contactDamagePerSec: 8,
    ));
    await add(Enemy(
      position:    Vector2(8  * ts, 18 * ts),
      patrolEnd:   Vector2(14 * ts, 18 * ts),
      enemyId:     'jungle_scout',
      maxHp:       30,
      patrolSpeed: 80,
      chaseSpeed:  140,
      chaseRadius: 130,
      contactDamagePerSec: 8,
    ));

    // ── 3 Standard Guardians ─────────────────────────────────────────────────
    await add(Enemy(
      position:    Vector2(26 * ts, 14 * ts),
      patrolEnd:   Vector2(33 * ts, 14 * ts),
      enemyId:     kJungleGuardianId,
      maxHp:       60,
      patrolSpeed: 55,
      chaseSpeed:  100,
    ));
    await add(Enemy(
      position:    Vector2(31 * ts, 20 * ts),
      patrolEnd:   Vector2(38 * ts, 20 * ts),
      enemyId:     kJungleGuardianId,
      maxHp:       60,
      patrolSpeed: 55,
      chaseSpeed:  100,
    ));
    await add(Enemy(
      position:    Vector2(38 * ts, 11 * ts),
      patrolEnd:   Vector2(44 * ts, 11 * ts),
      enemyId:     kJungleGuardianId,
      maxHp:       70,
      patrolSpeed: 50,
      chaseSpeed:  105,
      chaseRadius: 160,
    ));

    // ── High Guardian (boss) — guards the temple entrance ────────────────────
    await add(Enemy(
      position:    Vector2(43 * ts, 14 * ts),
      patrolEnd:   Vector2(46 * ts, 14 * ts),
      enemyId:     'high_guardian',
      maxHp:       180,
      patrolSpeed: 35,
      chaseSpeed:  85,
      chaseRadius: 200,
      contactDamagePerSec: 18,
    ));

    // ── Temple structure + entrance zone ─────────────────────────────────────
    // Visual stone temple at the east end of the map
    await add(_TempleStructure(
      position: Vector2(43 * ts, 3 * ts),
      tileSize: ts,
      palette: config.palette,
    ));

    // Trigger zone — contact completes the 'temple_entrance' mission
    await add(_TempleEntranceZone(
      position: Vector2(44.5 * ts, 12 * ts),
      size:     Vector2(3 * ts, 4 * ts),
    ));
  }

  Future<void> _spawnWorld2(double ts) async {
    await add(Collectible(position: Vector2(14 * ts, 10 * ts), itemId: 'ancient_seal'));
    await add(Enemy(
      position:    Vector2(30 * ts, 14 * ts),
      patrolEnd:   Vector2(42 * ts, 14 * ts),
      enemyId:     'stone_sentinel',
      maxHp:       90,
      patrolSpeed: 40,
      chaseSpeed:  80,
    ));
    await add(Npc(
      position: Vector2(6 * ts, 6 * ts),
      npcName:  'Archivist Vel',
      sequence: DialogueSequence(
        lines: [
          const DialogueLine(speaker: 'Archivist Vel',
              text: 'You have reached the Ancient Temple. Few make it this far.'),
          const DialogueLine(speaker: 'Archivist Vel',
              text: 'Find the Ancient Seal and defeat the Sentinel. Then the inner sanctum will open.'),
        ],
        onComplete: () => game.missionManager.reportReachedZone('archivist_met'),
      ),
    ));
  }
}

// =============================================================================
// _TerrainGround — richly textured multi-zone ground
// =============================================================================
// Divides the world into distinct biome zones using seeded noise:
//  • Dense grass (tileA/B/C) — dominant zone
//  • Dirt patches (tileDirt)  — random scattered areas
//  • Stone clearings (tileStone) — near rock clusters
// Each tile gets micro-detail: moss marks, pebbles, root lines, puddles.
// =============================================================================

class _TerrainGround extends PositionComponent {
  _TerrainGround({
    required this.cols,
    required this.rows,
    required this.tileSize,
    required this.palette,
  }) : super(
          position: Vector2.zero(),
          size: Vector2(cols * tileSize, rows * tileSize),
        );

  final int cols, rows;
  final double tileSize;
  final ProceduralPalette palette;

  // Per-tile noise values (seeded for determinism)
  late final List<double> _noise;
  // Per-tile "zone" type: 0=grass, 1=dirt, 2=stone
  late final List<int> _zone;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rng = math.Random(42);
    _noise = List.generate(cols * rows, (_) => rng.nextDouble());

    // Build a Perlin-like zone map with a simple low-frequency noise pass
    final zoneRng = math.Random(77);
    final zoneNoise = List.generate(cols * rows, (_) => zoneRng.nextDouble());
    // Smooth it with a tiny box blur (1-pass)
    _zone = List.generate(cols * rows, (i) {
      final r = i ~/ cols;
      final c = i % cols;
      var sum = 0.0;
      var count = 0;
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            sum += zoneNoise[nr * cols + nc];
            count++;
          }
        }
      }
      final avg = sum / count;
      if (avg < 0.28) return 1;  // dirt patch
      if (avg > 0.72) return 2;  // stone clearing
      return 0;                   // grass
    });
  }

  @override
  void render(Canvas canvas) {
    final ts = tileSize;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final n = _noise[idx];
        final zone = _zone[idx];

        // ── Base tile color ────────────────────────────────────────────
        final Color base;
        switch (zone) {
          case 1:
            base = _vary(palette.tileDirt, n, 18);
          case 2:
            base = _vary(palette.tileStone, n, 12);
          default:
            // Grass: cycle between 3 variants for natural patchiness
            final g = (c * 3 + r * 7 + (n * 7).toInt()) % 3;
            base = _vary(
              g == 0 ? palette.tileA : (g == 1 ? palette.tileB : palette.tileC),
              n, 22,
            );
        }

        final rect = Rect.fromLTWH(c * ts, r * ts, ts, ts);
        canvas.drawRect(rect, Paint()..color = base);

        // ── Tile border highlight (top+left edges simulate light) ──────
        canvas.drawLine(
          Offset(c * ts, r * ts),
          Offset((c + 1) * ts, r * ts),
          Paint()
            ..color = const Color(0x1AFFFFFF)
            ..strokeWidth = 1.0,
        );
        canvas.drawLine(
          Offset(c * ts, r * ts),
          Offset(c * ts, (r + 1) * ts),
          Paint()
            ..color = const Color(0x1AFFFFFF)
            ..strokeWidth = 1.0,
        );

        // ── Zone-specific micro-detail ─────────────────────────────────
        if (zone == 0) {
          // Grass: scattered small moss clumps
          if (n > 0.75) {
            _drawMossClump(canvas, c * ts + n * ts * 0.6, r * ts + n * ts * 0.5,
                n * 4 + 3, palette.canopyDark.withValues(alpha: 0.45));
          }
          // Occasional root line
          if (n > 0.88) {
            final rootPaint = Paint()
              ..color = palette.trunkShadow.withValues(alpha: 0.30)
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              Offset(c * ts + 4, r * ts + ts * 0.6),
              Offset(c * ts + ts - 6, r * ts + ts * 0.75),
              rootPaint,
            );
          }
        } else if (zone == 1) {
          // Dirt: small pebble clusters
          if (n > 0.4) {
            _drawPebble(canvas, c * ts + n * (ts - 8) + 4,
                r * ts + (1 - n) * (ts - 8) + 4,
                n * 2.5 + 1.5, palette.rockShadow.withValues(alpha: 0.55));
          }
          if (n > 0.65) {
            _drawPebble(canvas, c * ts + (1 - n) * (ts - 8) + 4,
                r * ts + n * (ts - 8) + 4,
                n * 1.5 + 1.0, palette.rockHighlight.withValues(alpha: 0.45));
          }
          // Tiny water puddle
          if (n < 0.06) {
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(c * ts + ts * 0.5, r * ts + ts * 0.55),
                width: ts * 0.45,
                height: ts * 0.22,
              ),
              Paint()..color = palette.waterColor.withValues(alpha: 0.50),
            );
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(c * ts + ts * 0.42, r * ts + ts * 0.48),
                width: ts * 0.18,
                height: ts * 0.07,
              ),
              Paint()..color = palette.waterHighlight.withValues(alpha: 0.55),
            );
          }
        } else {
          // Stone: crack lines + lichen dots
          if (n > 0.5) {
            final crackPaint = Paint()
              ..color = palette.rockShadow.withValues(alpha: 0.35)
              ..strokeWidth = 1.0;
            canvas.drawLine(
              Offset(c * ts + 5, r * ts + ts * 0.3),
              Offset(c * ts + ts * 0.6, r * ts + ts * 0.7),
              crackPaint,
            );
          }
          if (n < 0.3) {
            canvas.drawCircle(
              Offset(c * ts + ts * 0.7, r * ts + ts * 0.3),
              2.5,
              Paint()..color = palette.canopyMid.withValues(alpha: 0.50),
            );
          }
        }

        // ── Universal wildflower dots ──────────────────────────────────
        if (zone == 0) {
          if (n < 0.04) {
            _drawFlowerDot(canvas,
                c * ts + ts * 0.5, r * ts + ts * 0.38,
                palette.flowerRed, 3.5);
          } else if (n < 0.08) {
            _drawFlowerDot(canvas,
                c * ts + ts * 0.5, r * ts + ts * 0.38,
                palette.flowerYellow, 3.0);
          } else if (n < 0.11) {
            _drawFlowerDot(canvas,
                c * ts + ts * 0.5, r * ts + ts * 0.38,
                palette.flowerWhite, 3.0);
          }
        }
      }
    }
  }

  void _drawMossClump(Canvas canvas, double x, double y, double r, Color c) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: r * 2.5, height: r * 1.5),
      Paint()..color = c,
    );
  }

  void _drawPebble(Canvas canvas, double x, double y, double r, Color c) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: r * 2.2, height: r * 1.5),
      Paint()..color = c,
    );
  }

  void _drawFlowerDot(Canvas canvas, double x, double y, Color c, double r) {
    // Green stem
    canvas.drawLine(
      Offset(x, y + r),
      Offset(x, y + r * 2.5),
      Paint()
        ..color = palette.grassColor
        ..strokeWidth = 1.2,
    );
    // Petal ring (4 petals approximated with small circles)
    final petalPaint = Paint()..color = c;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawCircle(
        Offset(x + math.cos(angle) * r * 0.9, y + math.sin(angle) * r * 0.9),
        r * 0.7,
        petalPaint,
      );
    }
    // Centre
    canvas.drawCircle(Offset(x, y), r * 0.55,
        Paint()..color = palette.flowerYellow);
  }

  Color _vary(Color base, double n, int range) {
    final delta = ((n - 0.5) * range).round();
    final rv = ((base.r * 255).round() + delta).clamp(0, 255);
    final gv = ((base.g * 255).round() + delta).clamp(0, 255);
    final bv = ((base.b * 255).round() + delta).clamp(0, 255);
    return Color.fromARGB(255, rv, gv, bv);
  }
}

// =============================================================================
// _StonePath — hand-laid stone-paved road with edge grass bleed
// =============================================================================

class _StonePath extends PositionComponent {
  _StonePath({required this.tileSize, required this.palette})
      : super(
          position: Vector2.zero(),
          size: Vector2(
            _kFallbackCols * tileSize,
            _kFallbackRows * tileSize,
          ),
        );

  final double tileSize;
  final ProceduralPalette palette;

  @override
  void render(Canvas canvas) {
    final ts = tileSize;

    // ── Outer soft shadow (widest) ────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = const Color(0x30000000)
      ..strokeWidth = ts * 3.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // ── Earth edge ────────────────────────────────────────────────────────
    final edgePaint = Paint()
      ..color = palette.pathEdge
      ..strokeWidth = ts * 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // ── Dirt fill ─────────────────────────────────────────────────────────
    final dirtPaint = Paint()
      ..color = palette.tileDirt
      ..strokeWidth = ts * 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // ── Stone surface ─────────────────────────────────────────────────────
    final stonePaint = Paint()
      ..color = palette.tileStone
      ..strokeWidth = ts * 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // ── Path highlight (centre bright streak) ─────────────────────────────
    final highlightPaint = Paint()
      ..color = palette.obstacleHighlight.withValues(alpha: 0.25)
      ..strokeWidth = ts * 0.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Cubic Bezier winding path: left-edge → mid → right-edge
    final path = Path()
      ..moveTo(ts * 0,  ts * 8)
      ..cubicTo(ts * 10, ts * 7,  ts * 18, ts * 14, ts * 26, ts * 14)
      ..cubicTo(ts * 34, ts * 14, ts * 40, ts * 9,  ts * 48, ts * 10);

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, edgePaint);
    canvas.drawPath(path, dirtPaint);
    canvas.drawPath(path, stonePaint);
    canvas.drawPath(path, highlightPaint);

    // ── Stone slab segments along the path ────────────────────────────────
    _drawStoneSlabs(canvas, ts);
  }

  void _drawStoneSlabs(Canvas canvas, double ts) {
    // Sample points along the path and draw rectangular stone slabs
    final rng = math.Random(55);
    final slabPaint = Paint()..style = PaintingStyle.fill;
    final mortarPaint = Paint()
      ..color = palette.pathEdge.withValues(alpha: 0.60)
      ..strokeWidth = 1.2;

    // Path control points (must match bezier above)
    final segments = _samplePath(ts);
    for (var i = 0; i < segments.length; i++) {
      final pt = segments[i];
      final slabW = ts * 0.85 + rng.nextDouble() * ts * 0.2;
      final slabH = ts * 0.55 + rng.nextDouble() * ts * 0.15;
      final angle = i < segments.length - 1
          ? math.atan2(segments[i + 1].dy - pt.dy, segments[i + 1].dx - pt.dx)
          : 0.0;

      canvas.save();
      canvas.translate(pt.dx, pt.dy);
      canvas.rotate(angle);

      final r = Rect.fromCenter(
        center: Offset.zero,
        width: slabW,
        height: slabH,
      );

      // Slab body
      slabPaint.color = _stoneVariant(rng);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), slabPaint);

      // Top highlight
      canvas.drawLine(
        Offset(-slabW / 2 + 3, -slabH / 2 + 2),
        Offset(slabW / 2 - 3, -slabH / 2 + 2),
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 1.5,
      );

      // Mortar border
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        mortarPaint..style = PaintingStyle.stroke,
      );

      canvas.restore();
    }
  }

  Color _stoneVariant(math.Random rng) {
    final v = rng.nextDouble();
    if (v < 0.33) return const Color(0xFFA09880);
    if (v < 0.66) return const Color(0xFF8E8068);
    return const Color(0xFFB0A888);
  }

  List<Offset> _samplePath(double ts) {
    // Sample ~every 1.5 tiles along the bezier
    final pts = <Offset>[];
    const steps = 26;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps.toDouble();
      final p = _bezierPoint(t, ts);
      pts.add(p);
    }
    return pts;
  }

  Offset _bezierPoint(double t, double ts) {
    // The path has two cubic segments; split at t=0.5
    if (t <= 0.5) {
      final tt = t * 2;
      return _cubic(
        Offset(ts * 0,  ts * 8),
        Offset(ts * 10, ts * 7),
        Offset(ts * 18, ts * 14),
        Offset(ts * 26, ts * 14),
        tt,
      );
    } else {
      final tt = (t - 0.5) * 2;
      return _cubic(
        Offset(ts * 26, ts * 14),
        Offset(ts * 34, ts * 14),
        Offset(ts * 40, ts * 9),
        Offset(ts * 48, ts * 10),
        tt,
      );
    }
  }

  Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return Offset(
      u * u * u * p0.dx +
          3 * u * u * t * p1.dx +
          3 * u * t * t * p2.dx +
          t * t * t * p3.dx,
      u * u * u * p0.dy +
          3 * u * u * t * p1.dy +
          3 * u * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }
}

// =============================================================================
// _RockCluster — large multi-boulder rock formation with collision
// =============================================================================

class _RockCluster extends PositionComponent with CollisionCallbacks {
  _RockCluster({
    required super.position,
    required super.size,
    required this.palette,
    required this.seed,
  });

  final ProceduralPalette palette;
  final int seed;

  late final List<_BoulderSpec> _boulders;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Hitbox covers only the central 65% of the tile area — keeps corridors
    // between clusters passable and prevents the player getting stuck.
    final hbW = size.x * 0.65;
    final hbH = size.y * 0.65;
    await add(RectangleHitbox(
      size:     Vector2(hbW, hbH),
      position: Vector2((size.x - hbW) / 2, (size.y - hbH) / 2),
      anchor:   Anchor.topLeft,
      isSolid:  true,
    ));

    final rng = math.Random(seed);
    final count = 3 + rng.nextInt(4);
    _boulders = List.generate(count, (_) {
      final rx = rng.nextDouble() * size.x;
      final ry = rng.nextDouble() * size.y;
      final rw = size.x * (0.25 + rng.nextDouble() * 0.40);
      final rh = rw * (0.55 + rng.nextDouble() * 0.30);
      return _BoulderSpec(rx, ry, rw, rh, rng.nextDouble());
    });
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // Cluster-level ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2 + 4, h - 5),
        width: w * 0.9,
        height: h * 0.25,
      ),
      Paint()..color = const Color(0x44000000),
    );

    // Individual boulders (back-to-front)
    for (final b in _boulders) {
      _drawBoulder(canvas, b);
    }
  }

  void _drawBoulder(Canvas canvas, _BoulderSpec b) {
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(b.x + b.w * 0.1, b.y + b.h * 0.55),
        width: b.w * 0.95,
        height: b.h * 0.35,
      ),
      Paint()..color = const Color(0x33000000),
    );

    // Base fill — slightly varied tone
    final baseColor = _varyColor(palette.rockBaseColor, b.noise, 20);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(b.x, b.y), width: b.w, height: b.h),
      Paint()..color = baseColor,
    );

    // Right/bottom face (darker — fake 3-D)
    final shadowPath = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(b.x + b.w * 0.12, b.y + b.h * 0.12),
          width: b.w * 0.85,
          height: b.h * 0.85));
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = palette.rockShadow.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = b.w * 0.18,
    );

    // Top-left highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(b.x - b.w * 0.22, b.y - b.h * 0.22),
        width: b.w * 0.42,
        height: b.h * 0.30,
      ),
      Paint()..color = palette.rockHighlight.withValues(alpha: 0.75),
    );

    // Crack line
    if (b.noise > 0.5) {
      canvas.drawLine(
        Offset(b.x - b.w * 0.05, b.y - b.h * 0.15),
        Offset(b.x + b.w * 0.20, b.y + b.h * 0.20),
        Paint()
          ..color = palette.rockShadow.withValues(alpha: 0.55)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Moss patches on top
    if (b.noise < 0.45) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(b.x - b.w * 0.1, b.y - b.h * 0.25),
          width: b.w * 0.28,
          height: b.h * 0.18,
        ),
        Paint()..color = palette.canopyDark.withValues(alpha: 0.55),
      );
    }
  }

  Color _varyColor(Color base, double n, int range) {
    final d = ((n - 0.5) * range).round();
    final r = ((base.r * 255).round() + d).clamp(0, 255);
    final g = ((base.g * 255).round() + d).clamp(0, 255);
    final b = ((base.b * 255).round() + d).clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }
}

class _BoulderSpec {
  const _BoulderSpec(this.x, this.y, this.w, this.h, this.noise);
  final double x, y, w, h, noise;
}

// =============================================================================
// _BushClump — dense low shrub cluster for visual fill
// =============================================================================

class _BushClump extends PositionComponent {
  _BushClump({
    required super.position,
    required this.palette,
    required this.seed,
  }) : super(
          anchor: Anchor.center,
          size: Vector2(72, 48),
        );

  final ProceduralPalette palette;
  final int seed;

  late final List<_CircleSpec> _lobes;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rng = math.Random(seed);
    final count = 3 + rng.nextInt(4);
    _lobes = List.generate(count, (_) {
      final x = (rng.nextDouble() - 0.5) * 56;
      final y = (rng.nextDouble() - 0.5) * 30;
      final r = 10.0 + rng.nextDouble() * 14;
      return _CircleSpec(x, y, r, rng.nextDouble());
    });
    // Resize bounding box to fit lobes
    final maxR = _lobes.map((l) => l.r).reduce(math.max);
    size.setValues(maxR * 4, maxR * 2.8);
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y * 0.6;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 3, cy + 4),
        width: size.x * 0.85,
        height: size.y * 0.22,
      ),
      Paint()..color = const Color(0x33000000),
    );

    // Dark back lobes
    for (final l in _lobes) {
      canvas.drawCircle(
        Offset(cx + l.x + 4, cy + l.y + 3),
        l.r,
        Paint()..color = palette.canopyDark.withValues(alpha: 0.85),
      );
    }

    // Main mid lobes
    for (final l in _lobes) {
      canvas.drawCircle(
        Offset(cx + l.x, cy + l.y),
        l.r,
        Paint()..color = _vary(palette.bushColor, l.noise, 18),
      );
    }

    // Highlight small blobs on top lobes
    for (final l in _lobes) {
      if (l.noise > 0.4) {
        canvas.drawCircle(
          Offset(cx + l.x - l.r * 0.28, cy + l.y - l.r * 0.35),
          l.r * 0.38,
          Paint()..color = palette.bushHighlight.withValues(alpha: 0.70),
        );
      }
    }

    // Berry dots on some lobes
    for (final l in _lobes) {
      if (l.noise < 0.2) {
        canvas.drawCircle(
          Offset(cx + l.x + l.r * 0.2, cy + l.y + l.r * 0.1),
          2.8,
          Paint()..color = palette.flowerRed,
        );
      } else if (l.noise > 0.85) {
        canvas.drawCircle(
          Offset(cx + l.x + l.r * 0.2, cy + l.y + l.r * 0.1),
          2.5,
          Paint()..color = palette.flowerYellow,
        );
      }
    }
  }

  Color _vary(Color base, double n, int range) {
    final d = ((n - 0.5) * range).round();
    final r = ((base.r * 255).round() + d).clamp(0, 255);
    final g = ((base.g * 255).round() + d).clamp(0, 255);
    final b = ((base.b * 255).round() + d).clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }
}

class _CircleSpec {
  const _CircleSpec(this.x, this.y, this.r, this.noise);
  final double x, y, r, noise;
}

// =============================================================================
// _Tree — lush tropical/jungle tree with multi-layer palm-style canopy
// =============================================================================
// Draws: ground shadow → curved trunk → back canopy layers → main canopy
//        → highlight blob → top fronds (radiating palm leaves)
// =============================================================================

class _Tree extends PositionComponent {
  _Tree({
    required super.position,
    required this.palette,
    required this.seed,
  }) : super(
          anchor: Anchor.bottomCenter,
          size: Vector2(100, 130),
        );

  final ProceduralPalette palette;
  final int seed;

  late double _trunkH, _trunkTilt;
  late double _r1, _r2, _r3;
  late int _frondCount;
  late bool _isPalm;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rng = math.Random(seed);
    _isPalm   = rng.nextDouble() > 0.45;   // ~55% palm-style, 45% round canopy
    _trunkH   = 32 + rng.nextDouble() * 28;
    _trunkTilt = (rng.nextDouble() - 0.5) * 10; // slight lean
    _r1        = 26 + rng.nextDouble() * 18;     // main canopy radius
    _r2        = _r1 * 0.72;
    _r3        = _r1 * 0.48;
    _frondCount = 5 + rng.nextInt(4);
    size.setValues(_r1 * 3.0, _trunkH + _r1 * 2.2);
  }

  @override
  void render(Canvas canvas) {
    final cx  = size.x / 2;
    final base = size.y; // bottom of trunk

    // ── Ground shadow ───────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + _trunkTilt, base - 2),
        width: _r1 * 1.6,
        height: _r1 * 0.30,
      ),
      Paint()..color = const Color(0x44000000),
    );

    // ── Trunk ───────────────────────────────────────────────────────────
    final trunkTop = base - _trunkH;
    _drawTrunk(canvas, cx, base, trunkTop);

    // ── Canopy ──────────────────────────────────────────────────────────
    final canopyCenter = Offset(cx + _trunkTilt * 0.6, trunkTop - _r1 * 0.15);

    if (_isPalm) {
      _drawPalmCanopy(canvas, canopyCenter);
    } else {
      _drawRoundCanopy(canvas, canopyCenter);
    }
  }

  void _drawTrunk(Canvas canvas, double cx, double base, double top) {
    // Trunk base is wider — taper effect via path
    final path = Path()
      ..moveTo(cx - 7, base)
      ..quadraticBezierTo(
          cx + _trunkTilt * 0.5 - 4, (base + top) / 2,
          cx + _trunkTilt - 3.5, top)
      ..lineTo(cx + _trunkTilt + 3.5, top)
      ..quadraticBezierTo(
          cx + _trunkTilt * 0.5 + 4, (base + top) / 2,
          cx + 7, base)
      ..close();

    canvas.drawPath(path, Paint()..color = palette.trunkColor);

    // Right-side shadow stripe
    final shadowPath = Path()
      ..moveTo(cx + _trunkTilt * 0.5 + 1, (base + top) / 2 - 8)
      ..quadraticBezierTo(
          cx + _trunkTilt * 0.7 + 2, (base + top) * 0.72,
          cx + _trunkTilt + 2, top + 4)
      ..lineTo(cx + _trunkTilt + 3.5, top)
      ..quadraticBezierTo(
          cx + _trunkTilt * 0.5 + 4, (base + top) / 2,
          cx + 5, base)
      ..lineTo(cx + 3, base)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()..color = palette.trunkShadow.withValues(alpha: 0.50),
    );

    // Bark ring lines
    final barkPaint = Paint()
      ..color = palette.trunkShadow.withValues(alpha: 0.28)
      ..strokeWidth = 1.0;
    final ringCount = (_trunkH / 10).floor();
    for (var i = 1; i < ringCount; i++) {
      final y = base - i * (_trunkH / ringCount);
      final taper = 1.0 - i / ringCount * 0.35;
      canvas.drawLine(
        Offset(cx - 6 * taper, y),
        Offset(cx + 6 * taper + _trunkTilt * 0.8, y),
        barkPaint,
      );
    }
  }

  void _drawRoundCanopy(Canvas canvas, Offset center) {
    // Layer 3 — deep shadow back blob
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(6, 5),
        width: _r1 * 2.1,
        height: _r1 * 1.65,
      ),
      Paint()..color = palette.canopyDark,
    );

    // Layer 2 — main canopy
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-3, 0),
        width: _r1 * 2.0,
        height: _r1 * 1.55,
      ),
      Paint()..color = palette.canopyMid,
    );

    // Layer 1 — secondary highlight blob
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(5, -_r1 * 0.25),
        width: _r2 * 1.7,
        height: _r2 * 1.3,
      ),
      Paint()..color = palette.canopyMid.withValues(alpha: 0.80),
    );

    // Top-left highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-_r1 * 0.30, -_r1 * 0.48),
        width: _r3 * 1.5,
        height: _r3 * 1.1,
      ),
      Paint()..color = palette.canopyLight,
    );

    // Bright tip
    canvas.drawCircle(
      center.translate(-_r1 * 0.22, -_r1 * 0.62),
      _r3 * 0.55,
      Paint()..color = palette.canopyLight.withValues(alpha: 0.80),
    );
  }

  void _drawPalmCanopy(Canvas canvas, Offset center) {
    // Palm fronds radiating outward
    final frondPaintDark = Paint()
      ..color = palette.canopyDark
      ..strokeWidth = _r1 * 0.28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final frondPaintMid = Paint()
      ..color = palette.canopyMid
      ..strokeWidth = _r1 * 0.20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final frondPaintLight = Paint()
      ..color = palette.canopyLight
      ..strokeWidth = _r1 * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < _frondCount; i++) {
      final angle = (i / _frondCount) * math.pi * 2
          - math.pi * 0.5 // start at top
          + (seed % 13) * 0.12; // slight rotation per tree
      final droop = 0.35 + (i % 3) * 0.08;

      final tipX = center.dx + math.cos(angle) * _r1 * 1.25;
      final tipY = center.dy + math.sin(angle) * _r1 * 1.25 + _r1 * droop;

      final ctrlX = center.dx + math.cos(angle) * _r1 * 0.65;
      final ctrlY = center.dy + math.sin(angle) * _r1 * 0.65 + _r1 * 0.18;

      final frond = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(ctrlX, ctrlY, tipX, tipY);

      canvas.drawPath(frond, frondPaintDark);
      canvas.drawPath(frond, frondPaintMid);
      canvas.drawPath(frond, frondPaintLight);
    }

    // Crown hub
    canvas.drawCircle(center, _r1 * 0.28,
        Paint()..color = palette.canopyDark);
    canvas.drawCircle(center, _r1 * 0.18,
        Paint()..color = palette.canopyMid);
    canvas.drawCircle(center, _r1 * 0.09,
        Paint()..color = palette.canopyLight);
  }
}

// =============================================================================
// _AnimatedGrass — wind-swaying grass tufts + animated wildflowers
// =============================================================================

class _AnimatedGrass extends PositionComponent {
  _AnimatedGrass({
    required this.cols,
    required this.rows,
    required this.tileSize,
    required this.palette,
  }) : super(
          position: Vector2.zero(),
          size: Vector2(cols * tileSize, rows * tileSize),
        );

  final int cols, rows;
  final double tileSize;
  final ProceduralPalette palette;

  late final List<_GrassTuft>  _tufts;
  late final List<_FlowerSpec> _flowers;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final rng = math.Random(99);

    _tufts = [];
    _flowers = [];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Denser grass — ~22% coverage
        if (rng.nextDouble() < 0.22) {
          _tufts.add(_GrassTuft(
            x:      c * tileSize + rng.nextDouble() * tileSize,
            y:      r * tileSize + rng.nextDouble() * tileSize,
            phase:  rng.nextDouble() * math.pi * 2,
            height: 7 + rng.nextDouble() * 10,
            bladeCount: 2 + rng.nextInt(3),
          ));
        }
        // Wildflowers — ~3% coverage
        if (rng.nextDouble() < 0.030) {
          final kind = rng.nextInt(3); // 0=red 1=yellow 2=white
          _flowers.add(_FlowerSpec(
            x:     c * tileSize + tileSize * 0.3 + rng.nextDouble() * tileSize * 0.4,
            y:     r * tileSize + tileSize * 0.3 + rng.nextDouble() * tileSize * 0.4,
            phase: rng.nextDouble() * math.pi * 2,
            kind:  kind,
            size:  2.5 + rng.nextDouble() * 2.0,
          ));
        }
      }
    }
  }

  double _time = 0;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    _renderGrass(canvas);
    _renderFlowers(canvas);
  }

  void _renderGrass(Canvas canvas) {
    final basePaint = Paint()
      ..color = palette.grassColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tipPaint = Paint()
      ..color = palette.grassTip
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final t in _tufts) {
      final sway = math.sin(_time * 1.8 + t.phase) * 3.2;
      for (var b = 0; b < t.bladeCount; b++) {
        final bx = t.x + (b - t.bladeCount / 2 + 0.5) * 3.2;
        final bSway = sway * (0.7 + b * 0.15);
        // Blade lower half
        canvas.drawLine(
          Offset(bx, t.y),
          Offset(bx + bSway * 0.5, t.y - t.height * 0.55),
          basePaint,
        );
        // Blade upper half (tip)
        canvas.drawLine(
          Offset(bx + bSway * 0.5, t.y - t.height * 0.55),
          Offset(bx + bSway, t.y - t.height),
          tipPaint,
        );
      }
    }
  }

  void _renderFlowers(Canvas canvas) {
    for (final f in _flowers) {
      final sway = math.sin(_time * 1.2 + f.phase) * 1.8;
      final stemH = f.size * 2.8;

      // Stem
      canvas.drawLine(
        Offset(f.x, f.y),
        Offset(f.x + sway * 0.4, f.y - stemH),
        Paint()
          ..color = palette.grassColor
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );

      // Petals
      final Color petalColor;
      switch (f.kind) {
        case 1:  petalColor = palette.flowerYellow; break;
        case 2:  petalColor = palette.flowerWhite;  break;
        default: petalColor = palette.flowerRed;    break;
      }
      final cx = f.x + sway * 0.4;
      final cy = f.y - stemH;
      for (var p = 0; p < 5; p++) {
        final a = p / 5 * math.pi * 2 + _time * 0.3 + f.phase;
        canvas.drawCircle(
          Offset(cx + math.cos(a) * f.size * 0.85,
                 cy + math.sin(a) * f.size * 0.85),
          f.size * 0.70,
          Paint()..color = petalColor.withValues(alpha: 0.90),
        );
      }
      // Centre
      canvas.drawCircle(Offset(cx, cy), f.size * 0.45,
          Paint()..color = palette.flowerYellow);
    }
  }
}

class _GrassTuft {
  const _GrassTuft({
    required this.x,
    required this.y,
    required this.phase,
    required this.height,
    required this.bladeCount,
  });
  final double x, y, phase, height;
  final int bladeCount;
}

class _FlowerSpec {
  const _FlowerSpec({
    required this.x,
    required this.y,
    required this.phase,
    required this.kind,
    required this.size,
  });
  final double x, y, phase, size;
  final int kind;
}

// =============================================================================
// _TempleEntranceZone — invisible trigger that completes the reach mission
// =============================================================================

/// A rectangular trigger zone placed at the temple archway.
/// When the player walks into it, [MissionManager.reportReachedZone] fires
/// with id `'temple_entrance'`, completing that mission objective.
///
/// Draws a faint golden glow so the player can see it exists.
class _TempleEntranceZone extends PositionComponent
    with HasGameReference<EscapeVerseGame>, CollisionCallbacks {
  _TempleEntranceZone({
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.topLeft);

  bool _triggered = false;
  double _pulseTime = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(
      size:     size,
      anchor:   Anchor.topLeft,
      isSolid:  false, // passable — just a sensor
    ));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_triggered) return;
    if (other.runtimeType.toString() != 'Player') return;
    _triggered = true;
    game.missionManager.reportReachedZone('temple_entrance');
    game.audio.playCollect(); // satisfying sound on entry
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt;
  }

  @override
  void render(Canvas canvas) {
    if (_triggered) return; // hide once used

    final alpha = (math.sin(_pulseTime * 2.5) * 0.12 + 0.18).clamp(0.0, 0.35);
    // Glow fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      Paint()..color = Color.fromRGBO(255, 215, 0, alpha),
    );
    // Dashed border
    final borderPaint = Paint()
      ..color      = Color.fromRGBO(255, 215, 0, alpha * 2.5)
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      borderPaint,
    );

    // "ENTER" label
    final tp = (TextPainter(
      text: const TextSpan(
        text: '⬆ ENTER',
        style: TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout());
    tp.paint(
      canvas,
      Offset((size.x - tp.width) / 2,
             size.y / 2 - tp.height / 2),
    );
  }
}

// =============================================================================
// _TempleStructure — drawn stone temple at the east end of the jungle map
// =============================================================================
// Draws:
//  • Two massive outer wall columns
//  • A wide stone base platform
//  • A grand arched entrance doorway with glowing portal effect
//  • Decorative glyphs and torches
//  • Moss and vines on the stonework
// =============================================================================

class _TempleStructure extends PositionComponent {
  _TempleStructure({
    required super.position,
    required this.tileSize,
    required this.palette,
  }) : super(
          anchor: Anchor.topLeft,
          size: Vector2(6 * tileSize, 10 * tileSize),
        );

  final double tileSize;
  final ProceduralPalette palette;

  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final ts = tileSize;
    final w  = size.x;   // ~288 px
    final h  = size.y;   // ~480 px

    // ── Base platform ─────────────────────────────────────────────────────
    _drawStonePlatform(canvas, w, h, ts);

    // ── Left and right outer columns ──────────────────────────────────────
    _drawColumn(canvas, ts * 0.3, ts * 1.2, ts * 0.9, ts * 5.5);
    _drawColumn(canvas, w - ts * 1.2, ts * 1.2, ts * 0.9, ts * 5.5);

    // ── Inner gateway columns ─────────────────────────────────────────────
    _drawColumn(canvas, w * 0.32, ts * 2.0, ts * 0.7, ts * 4.2);
    _drawColumn(canvas, w * 0.62, ts * 2.0, ts * 0.7, ts * 4.2);

    // ── Temple roof / pediment ────────────────────────────────────────────
    _drawPediment(canvas, w, ts);

    // ── Grand archway ─────────────────────────────────────────────────────
    _drawArch(canvas, w, h, ts);

    // ── Animated portal glow inside arch ─────────────────────────────────
    _drawPortal(canvas, w, h, ts);

    // ── Torches ───────────────────────────────────────────────────────────
    _drawTorch(canvas, w * 0.22, ts * 3.8);
    _drawTorch(canvas, w * 0.72, ts * 3.8);

    // ── Glyphs on columns ─────────────────────────────────────────────────
    _drawGlyphs(canvas, w, ts);

    // ── Vines ─────────────────────────────────────────────────────────────
    _drawVines(canvas, w, h, ts);
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _drawStonePlatform(Canvas canvas, double w, double h, double ts) {
    // Main platform base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h - ts * 2.5, w, ts * 2.5),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF7A7060),
    );
    // Platform top edge highlight
    canvas.drawLine(
      Offset(0, h - ts * 2.5),
      Offset(w, h - ts * 2.5),
      Paint()
        ..color      = const Color(0xFFB0A880)
        ..strokeWidth = 3,
    );
    // Stone block lines
    final blockPaint = Paint()
      ..color      = const Color(0xFF5A5040)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < w; x += ts * 0.8) {
      canvas.drawLine(
        Offset(x, h - ts * 2.5),
        Offset(x, h),
        blockPaint,
      );
    }
    // Steps at the front
    for (var s = 0; s < 3; s++) {
      final stepY = h - ts * 2.5 + s * 8.0;
      canvas.drawLine(
        Offset(w * 0.28 + s * 6, stepY),
        Offset(w * 0.72 - s * 6, stepY),
        Paint()
          ..color      = const Color(0xFF9A9070)
          ..strokeWidth = 7,
      );
    }
  }

  void _drawColumn(Canvas canvas, double x, double y, double cw, double ch) {
    // Shadow
    canvas.drawRect(
      Rect.fromLTWH(x + 4, y + 4, cw, ch),
      Paint()..color = const Color(0x44000000),
    );
    // Base stone
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cw, ch),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF848070),
    );
    // Right shade
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + cw * 0.65, y + 4, cw * 0.3, ch - 8),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x44000000),
    );
    // Top cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 4, y, cw + 8, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFAA9F80),
    );
    // Bottom base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 4, y + ch - 10, cw + 8, 10),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFAA9F80),
    );
    // Horizontal fluting lines
    final flutePaint = Paint()
      ..color      = const Color(0xFF5A5040)
      ..strokeWidth = 1.0;
    for (var fy = y + 18; fy < y + ch - 12; fy += 14) {
      canvas.drawLine(Offset(x + 4, fy), Offset(x + cw - 4, fy), flutePaint);
    }
  }

  void _drawPediment(Canvas canvas, double w, double ts) {
    // Triangular pediment above entrance
    final path = Path()
      ..moveTo(w * 0.15, ts * 1.2)
      ..lineTo(w * 0.5,  ts * 0.1)
      ..lineTo(w * 0.85, ts * 1.2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF9A8F70));
    // Pediment outline
    canvas.drawPath(
      path,
      Paint()
        ..color      = const Color(0xFFB0A880)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Eye of the temple glyph in pediment centre
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, ts * 0.7), width: 18, height: 12),
      Paint()..color = const Color(0xFFFFD700),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, ts * 0.7), width: 8, height: 8),
      Paint()..color = const Color(0xFF1A1000),
    );
  }

  void _drawArch(Canvas canvas, double w, double h, double ts) {
    final archLeft   = w * 0.3;
    final archRight  = w * 0.7;
    final archBottom = h - ts * 2.5;
    final archTop    = ts * 2.2;
    final archW      = archRight - archLeft;
    final archH      = archBottom - archTop;

    // Arch opening (dark interior)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(archLeft, archTop, archW, archH),
        topLeft:     Radius.circular(archW * 0.5),
        topRight:    Radius.circular(archW * 0.5),
        bottomLeft:  Radius.zero,
        bottomRight: Radius.zero,
      ),
      Paint()..color = const Color(0xFF0A0806),
    );

    // Arch stone border
    final archPaint = Paint()
      ..color      = const Color(0xFF9A8F70)
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(archLeft, archTop, archW, archH),
        topLeft:     Radius.circular(archW * 0.5),
        topRight:    Radius.circular(archW * 0.5),
        bottomLeft:  Radius.zero,
        bottomRight: Radius.zero,
      ),
      archPaint,
    );

    // Keystone at arch apex
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5 - 10, archTop - 4)
        ..lineTo(w * 0.5, archTop - 14)
        ..lineTo(w * 0.5 + 10, archTop - 4)
        ..close(),
      Paint()..color = const Color(0xFFD4B86A),
    );
  }

  void _drawPortal(Canvas canvas, double w, double h, double ts) {
    final archLeft   = w * 0.3;
    final archRight  = w * 0.7;
    final archBottom = h - ts * 2.5;
    final archTop    = ts * 2.2;
    final cx         = w * 0.5;
    final cy         = (archTop + archBottom) / 2;
    final archW      = archRight - archLeft;
    final archH      = archBottom - archTop;

    // Animated purple/teal portal shimmer
    final t      = _time;
    final alpha1 = (math.sin(t * 1.8) * 0.10 + 0.25).clamp(0.0, 0.4);
    final alpha2 = (math.sin(t * 2.5 + 1.2) * 0.08 + 0.18).clamp(0.0, 0.3);

    // Radial glow layers
    for (var layer = 3; layer >= 0; layer--) {
      final r     = (archW * 0.38) * (1.0 - layer * 0.18);
      final alpha = (alpha1 - layer * 0.04).clamp(0.0, 0.4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy - archH * 0.05),
          width: r * 2, height: r * 1.6,
        ),
        Paint()..color = Color.fromRGBO(80, 20, 160, alpha),
      );
    }

    // Teal shimmer lines
    for (var i = 0; i < 5; i++) {
      final lineY = archTop + (archH * 0.2) +
          (archH * 0.6) * (i / 4.0) +
          math.sin(t * 3 + i * 0.8) * 4;
      canvas.drawLine(
        Offset(archLeft + 10, lineY),
        Offset(archRight - 10, lineY),
        Paint()
          ..color      = Color.fromRGBO(60, 200, 180, alpha2)
          ..strokeWidth = 1.5,
      );
    }

    // Floating sparkles inside arch
    for (var i = 0; i < 6; i++) {
      final sx = archLeft + archW * 0.15 +
          (archW * 0.7) * ((math.sin(t * 0.7 + i * 1.4) + 1) / 2);
      final sy = archTop + archH * 0.1 +
          (archH * 0.75) * ((math.cos(t * 0.9 + i * 1.1) + 1) / 2);
      final sa = (math.sin(t * 4 + i * 2) * 0.4 + 0.5).clamp(0.0, 0.9);
      canvas.drawCircle(
        Offset(sx, sy), 2.5,
        Paint()..color = Color.fromRGBO(180, 160, 255, sa),
      );
    }
  }

  void _drawTorch(Canvas canvas, double x, double y) {
    // Pole
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3, y, 6, 28),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6B4226),
    );
    // Bracket
    canvas.drawRect(
      Rect.fromLTWH(x - 6, y, 12, 8),
      Paint()..color = const Color(0xFF8B6B3A),
    );
    // Flame (animated)
    final flicker = math.sin(_time * 8 + x) * 3;
    final flamePath = Path()
      ..moveTo(x - 5, y)
      ..quadraticBezierTo(x - 4 + flicker, y - 12, x, y - 20)
      ..quadraticBezierTo(x + 4 - flicker, y - 12, x + 5, y)
      ..close();
    canvas.drawPath(flamePath, Paint()..color = const Color(0xFFFF6F00));
    // Inner bright flame
    final innerPath = Path()
      ..moveTo(x - 3, y - 2)
      ..quadraticBezierTo(x + flicker * 0.5, y - 10, x, y - 16)
      ..quadraticBezierTo(x - flicker * 0.5, y - 10, x + 3, y - 2)
      ..close();
    canvas.drawPath(innerPath, Paint()..color = const Color(0xFFFFE082));
    // Glow
    canvas.drawCircle(
      Offset(x, y - 8), 16,
      Paint()..color = const Color(0x33FF9800),
    );
  }

  void _drawGlyphs(Canvas canvas, double w, double ts) {
    final glyphPaint = Paint()
      ..color      = const Color(0x88FFD700)
      ..strokeWidth = 1.5
      ..style      = PaintingStyle.stroke;

    // Glyph on left column
    _drawSingleGlyph(canvas, glyphPaint, w * 0.08, ts * 3.5);
    _drawSingleGlyph(canvas, glyphPaint, w * 0.08, ts * 4.5);
    // Glyph on right column
    _drawSingleGlyph(canvas, glyphPaint, w * 0.88, ts * 3.5);
    _drawSingleGlyph(canvas, glyphPaint, w * 0.88, ts * 4.5);
  }

  void _drawSingleGlyph(Canvas canvas, Paint paint, double x, double y) {
    // Simple rune shape
    canvas.drawLine(Offset(x, y), Offset(x, y + 12), paint);
    canvas.drawLine(Offset(x - 5, y + 4), Offset(x + 5, y + 4), paint);
    canvas.drawLine(Offset(x - 4, y + 8), Offset(x + 4, y + 8), paint);
    canvas.drawCircle(Offset(x, y + 14), 2, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  void _drawVines(Canvas canvas, double w, double h, double ts) {
    final vinePaint = Paint()
      ..color      = const Color(0x99386A30)
      ..strokeWidth = 2.0
      ..strokeCap  = StrokeCap.round;
    // Left-column vines
    for (var i = 0; i < 6; i++) {
      final vy = ts * 1.5 + i * ts * 0.65;
      final sway = math.sin(_time * 0.8 + i * 0.7) * 5;
      canvas.drawLine(
        Offset(w * 0.1, vy),
        Offset(w * 0.1 + sway + 8, vy + ts * 0.5),
        vinePaint,
      );
      // Leaf dot
      canvas.drawCircle(
        Offset(w * 0.1 + sway + 8, vy + ts * 0.5),
        4,
        Paint()..color = const Color(0x994CAF50),
      );
    }
    // Right-column vines
    for (var i = 0; i < 5; i++) {
      final vy = ts * 2.0 + i * ts * 0.7;
      final sway = math.sin(_time * 0.9 + i * 0.6) * 5;
      canvas.drawLine(
        Offset(w * 0.9, vy),
        Offset(w * 0.9 - sway - 8, vy + ts * 0.55),
        vinePaint,
      );
      canvas.drawCircle(
        Offset(w * 0.9 - sway - 8, vy + ts * 0.55),
        4,
        Paint()..color = const Color(0x994CAF50),
      );
    }
  }
}
