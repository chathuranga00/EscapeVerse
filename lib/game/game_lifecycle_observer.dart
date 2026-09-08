import 'package:flutter/widgets.dart';

import 'escape_verse_game.dart';
import 'systems/save_manager.dart';

/// Listens to app lifecycle changes and triggers an auto-save when the app
/// is backgrounded or paused, so progress is never lost if the OS kills it.
///
/// Register via [WidgetsBinding.instance.addObserver] in [GameScreen] and
/// remove it in [dispose].
///
/// ## Usage
/// ```dart
/// late final _lifecycleObserver = GameLifecycleObserver(game: _game);
///
/// @override
/// void initState() {
///   super.initState();
///   WidgetsBinding.instance.addObserver(_lifecycleObserver);
/// }
///
/// @override
/// void dispose() {
///   WidgetsBinding.instance.removeObserver(_lifecycleObserver);
///   super.dispose();
/// }
/// ```
class GameLifecycleObserver extends WidgetsBindingObserver {
  GameLifecycleObserver({required this.game});

  final EscapeVerseGame game;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is being backgrounded or interrupted — flush save immediately.
        SaveManager.save(
          SaveManager.snapshot(
            worldId:          game.worldConfig.id,
            characterName:    game.characterName,
            playerX:          game.player.position.x,
            playerY:          game.player.position.y,
            missions:         game.missionManager.missions.value,
            inventory:        game.inventoryManager,
            unlockedWorldIds: game.unlockedWorldIds,
          ),
        );
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break; // nothing to do
    }
  }
}
