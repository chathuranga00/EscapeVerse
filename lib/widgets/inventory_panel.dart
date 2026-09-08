import 'package:flutter/material.dart';

import '../game/escape_verse_game.dart';
import '../game/models/inventory_item.dart';
import '../game/systems/inventory_manager.dart';
import '../theme/app_theme.dart';

/// Overlay key for the inventory panel itself (the open grid).
// Defined in escape_verse_game.dart — imported above.

// ─────────────────────────────────────────────────────────────────────────────
// InventoryButton  — always-visible toggle (top-right HUD)
// ─────────────────────────────────────────────────────────────────────────────

/// A small bag icon pinned top-right that opens/closes the inventory panel.
///
/// Registered in [GameWidget.overlayBuilderMap] under [kInventoryButtonOverlay].
// Constant defined in escape_verse_game.dart — imported above.

class InventoryButton extends StatefulWidget {
  const InventoryButton({super.key, required this.game});

  final EscapeVerseGame game;

  @override
  State<InventoryButton> createState() => _InventoryButtonState();
}

class _InventoryButtonState extends State<InventoryButton> {
  bool _open = false;

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      widget.game.overlays.add(kInventoryPanelOverlay);
    } else {
      widget.game.overlays.remove(kInventoryPanelOverlay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 12,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _open
                ? AppColors.ancientGold.withValues(alpha: 0.9)
                : AppColors.darkMoss.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.ancientGold,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.backpack_outlined,
            color: _open ? AppColors.deepJungle : AppColors.ancientGold,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InventoryPanel  — the grid overlay
// ─────────────────────────────────────────────────────────────────────────────

/// Full inventory grid shown when the player taps the bag icon.
///
/// Listens to [InventoryManager.items] and rebuilds on changes.
/// Registered in [GameWidget.overlayBuilderMap] under [kInventoryPanelOverlay].
class InventoryPanel extends StatefulWidget {
  const InventoryPanel({
    super.key,
    required this.inventoryManager,
    required this.onClose,
  });

  final InventoryManager inventoryManager;
  final VoidCallback onClose;

  @override
  State<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<InventoryPanel> {
  @override
  void initState() {
    super.initState();
    widget.inventoryManager.items.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.inventoryManager.items.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.inventoryManager.items.value;
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPad + 56, // below the inventory button
      right: 12,
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
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
            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'INVENTORY',
                    style: TextStyle(
                      color: AppColors.ancientGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(
                    Icons.close,
                    color: AppColors.mutedParchment,
                    size: 16,
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

            // ── Grid or empty state ────────────────────────────────────
            if (items.isEmpty)
              const Text(
                'Nothing collected yet.',
                style: TextStyle(
                  color: AppColors.mutedParchment,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map((item) => _InventoryCell(item: item))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InventoryCell extends StatelessWidget {
  const _InventoryCell({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.name,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.stoneBrown.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.stoneBrown,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Icon / emoji
            Center(
              child: Text(
                String.fromCharCode(item.iconCodePoint),
                style: const TextStyle(fontSize: 26),
              ),
            ),
            // Count badge
            if (item.count > 1)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.deepJungle.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${item.count}',
                    style: const TextStyle(
                      color: AppColors.ancientGold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
