import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/services/audio_service.dart';
import '../routes.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Subtle vertical gradient — dark jungle canopy fading into shadow.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkMoss,
              AppColors.deepJungle,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── App icon placeholder ──────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.stoneBrown,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.ancientGold,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.travel_explore,
                    size: 56,
                    color: AppColors.ancientGold,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  'ESCAPEVERSE',
                  style: textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'The jungle calls. Will you answer?',
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // ── CTA button ────────────────────────────────────────────
                ElevatedButton(
                  onPressed: () {
                    if (!kIsWeb) AudioService().playMenuTap();
                    Navigator.pushNamed(context, AppRoutes.characterSelect);
                  },
                  child: const Text('ENTER THE GAME'),
                ),

                const SizedBox(height: 16),

                // ── Version tag ───────────────────────────────────────────
                Text(
                  'v0.1.0 — Early Access',
                  style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
