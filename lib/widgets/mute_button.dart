import 'package:flutter/material.dart';

import '../game/escape_verse_game.dart';
import '../theme/app_theme.dart';

// kMuteButtonOverlay is defined in escape_verse_game.dart — imported above.

class MuteButton extends StatefulWidget {
  const MuteButton({super.key, required this.game});

  final EscapeVerseGame game;

  @override
  State<MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<MuteButton> {
  void _toggle() {
    widget.game.audio.toggleMute();
    setState(() {}); // rebuild to swap icon
  }

  @override
  Widget build(BuildContext context) {
    final muted = widget.game.audio.isMuted;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      // Sits left of the inventory button (which is at right:12).
      right: 58,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.darkMoss.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: muted ? AppColors.stoneBrown : AppColors.ancientGold,
              width: 1.5,
            ),
          ),
          child: Icon(
            muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            color: muted ? AppColors.stoneBrown : AppColors.ancientGold,
            size: 22,
          ),
        ),
      ),
    );
  }
}
