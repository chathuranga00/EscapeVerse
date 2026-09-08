import 'package:flutter/material.dart';

import '../game/models/dialogue.dart';
import '../theme/app_theme.dart';

/// A Flutter overlay that shows one [DialogueLine] at a time.
///
/// Pinned to the bottom of the screen, styled as a stone-and-gold temple
/// inscription panel. The player taps anywhere on the box to advance to the
/// next line; after the last line the box calls [onDismiss] so the game can
/// close the overlay and resume player input.
///
/// Registered in [GameWidget.overlayBuilderMap] under [kDialogueOverlay].
class DialogueBox extends StatefulWidget {
  const DialogueBox({
    super.key,
    required this.sequence,
    required this.onDismiss,
    this.onAdvance,
  });

  final DialogueSequence sequence;
  final VoidCallback onDismiss;

  /// Optional callback fired each time a line advances (for SFX).
  final void Function()? onAdvance;

  @override
  State<DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<DialogueBox>
    with SingleTickerProviderStateMixin {
  int _lineIndex = 0;

  // Fade-in animation controller for each new line.
  late final AnimationController _fade;
  late final Animation<double> _opacity;

  DialogueLine get _currentLine =>
      widget.sequence.lines[_lineIndex];

  bool get _isLastLine =>
      _lineIndex >= widget.sequence.lines.length - 1;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
    _opacity =
        CurvedAnimation(parent: _fade, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _advance() {
    widget.onAdvance?.call();
    if (_isLastLine) {
      // Trigger onComplete callback then dismiss.
      widget.sequence.onComplete?.call();
      widget.onDismiss();
    } else {
      setState(() => _lineIndex++);
      _fade.forward(from: 0); // fade in next line
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPad + 12,
      left: 12,
      right: 12,
      child: GestureDetector(
        onTap: _advance,
        child: FadeTransition(
          opacity: _opacity,
          child: _DialoguePanel(
            line: _currentLine,
            isLast: _isLastLine,
            lineIndex: _lineIndex,
            totalLines: widget.sequence.lines.length,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DialoguePanel extends StatelessWidget {
  const _DialoguePanel({
    required this.line,
    required this.isLast,
    required this.lineIndex,
    required this.totalLines,
  });

  final DialogueLine line;
  final bool isLast;
  final int lineIndex;
  final int totalLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        // Stone-dark background, semi-transparent so the world shows through.
        color: const Color(0xEE1A120A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ancientGold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: speaker name + progress ──────────────────────
          Row(
            children: [
              // Gold diamond accent
              const Text(
                '◆ ',
                style: TextStyle(
                  color: AppColors.ancientGold,
                  fontSize: 10,
                ),
              ),
              // Speaker name
              Expanded(
                child: Text(
                  line.speaker.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.ancientGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              // Line progress
              Text(
                '${lineIndex + 1} / $totalLines',
                style: const TextStyle(
                  color: AppColors.mutedParchment,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Divider(
            color: AppColors.stoneBrown,
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 10),

          // ── Dialogue text ─────────────────────────────────────────
          Text(
            line.text,
            style: const TextStyle(
              color: AppColors.parchment,
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          // ── Tap hint ──────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isLast ? 'Tap to close  ▶▶' : 'Tap to continue  ▶',
              style: const TextStyle(
                color: AppColors.fadedGold,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
