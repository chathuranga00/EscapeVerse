import 'package:flutter/material.dart';

import 'game/data/worlds.dart';
import 'game/systems/save_manager.dart';
import 'screens/character_select_screen.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/world_select_screen.dart';
import 'services/leaderboard_service.dart';

/// Named route path constants.
class AppRoutes {
  AppRoutes._();

  static const String home            = '/';
  static const String characterSelect = '/character-select';
  static const String worldSelect     = '/world-select';
  static const String game            = '/game';
  static const String leaderboard     = '/leaderboard';
}

// ─────────────────────────────────────────────────────────────────────────────
// Route argument types
// ─────────────────────────────────────────────────────────────────────────────

/// Arguments passed to [GameScreen].
class GameScreenArgs {
  const GameScreenArgs({
    required this.characterName,
    required this.worldConfig,
    this.saveData,
  });

  final String characterName;
  final WorldConfig worldConfig;

  /// Non-null when continuing an existing save for this world.
  final SaveData? saveData;
}

// ─────────────────────────────────────────────────────────────────────────────
// Route builder
// ─────────────────────────────────────────────────────────────────────────────

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return _fadeRoute(const HomeScreen(), settings);

    case AppRoutes.characterSelect:
      return _fadeRoute(const CharacterSelectScreen(), settings);

    case AppRoutes.worldSelect:
      final args = settings.arguments as WorldSelectArgs;
      return _fadeRoute(WorldSelectScreen(args: args), settings);

    case AppRoutes.game:
      final args = settings.arguments as GameScreenArgs;
      return _fadeRoute(GameScreen(args: args), settings, durationMs: 500);

    case AppRoutes.leaderboard:
      final lb = settings.arguments as LeaderboardService;
      return _fadeRoute(LeaderboardScreen(leaderboard: lb), settings);

    default:
      return _fadeRoute(const HomeScreen(), settings);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// A [PageRouteBuilder] that fades the incoming screen in over [durationMs].
PageRouteBuilder<dynamic> _fadeRoute(
  Widget page,
  RouteSettings settings, {
  int durationMs = 300,
}) {
  return PageRouteBuilder(
    settings: settings,
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: Duration(milliseconds: durationMs),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child,
      );
    },
  );
}
