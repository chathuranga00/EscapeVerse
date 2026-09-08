import 'package:flutter/material.dart';

import '../game/services/audio_service.dart';
import '../game/systems/save_manager.dart';
import '../routes.dart';
import '../screens/world_select_screen.dart';
import '../theme/app_theme.dart';

// ── Character data ────────────────────────────────────────────────────────────

class _CharacterData {
  const _CharacterData({
    required this.name,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final Color color;
  final IconData icon;
}

const List<_CharacterData> _characters = [
  _CharacterData(
    name: 'Kael',
    subtitle: 'The Scout',
    color: Color(0xFF2E6B3E),
    icon: Icons.hiking,
  ),
  _CharacterData(
    name: 'Zara',
    subtitle: 'The Archaeologist',
    color: Color(0xFF7A5230),
    icon: Icons.search,
  ),
  _CharacterData(
    name: 'Dax',
    subtitle: 'The Engineer',
    color: Color(0xFF3B5068),
    icon: Icons.build,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  int _selectedIndex = 0;

  /// Loaded once in [initState] — non-null means a save exists.
  SaveData? _existingSave;
  bool _saveChecked = false;

  @override
  void initState() {
    super.initState();
    _checkForSave();
  }

  Future<void> _checkForSave() async {
    final save = await SaveManager.load();
    if (!mounted) return;
    setState(() {
      _existingSave = save;
      _saveChecked = true;
    });
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _startNewGame() {
    final selected = _characters[_selectedIndex];
    Navigator.pushNamed(
      context,
      AppRoutes.worldSelect,
      arguments: WorldSelectArgs(
        characterName:     selected.name,
        unlockedWorldIds:  ['world1'],
        existingSave:      null,
      ),
    );
  }

  void _continueGame() {
    final save = _existingSave!;
    Navigator.pushNamed(
      context,
      AppRoutes.worldSelect,
      arguments: WorldSelectArgs(
        characterName:    save.characterName,
        unlockedWorldIds: save.unlockedWorldIds,
        existingSave:     save,
      ),
    );
  }

  Future<void> _confirmNewGame() async {
    if (_existingSave == null) {
      _startNewGame();
      return;
    }

    // Ask the player before overwriting the existing save.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkMoss,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.stoneBrown),
        ),
        title: const Text(
          'Start New Game?',
          style: TextStyle(color: AppColors.ancientGold),
        ),
        content: const Text(
          'Your existing save will be deleted. This cannot be undone.',
          style: TextStyle(color: AppColors.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.mutedParchment),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('New Game'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SaveManager.deleteSave();
      setState(() => _existingSave = null);
      _startNewGame();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Character')),
      body: !_saveChecked
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.ancientGold),
            )
          : Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Continue banner ─────────────────────────────────────
                  if (_existingSave != null) ...[
                    _ContinueBanner(
                      save: _existingSave!,
                      onContinue: _continueGame,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.stoneBrown)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'OR START FRESH',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.mutedParchment,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.stoneBrown)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    'Who enters the verse?',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Character cards ─────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      itemCount: _characters.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final character = _characters[index];
                        final isSelected = index == _selectedIndex;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 110,
                            decoration: BoxDecoration(
                              color: character.color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.ancientGold
                                    : AppColors.stoneBrown,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.ancientGold
                                            .withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 110,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: character.color,
                                    borderRadius:
                                        const BorderRadius.horizontal(
                                      left: Radius.circular(7),
                                    ),
                                  ),
                                  child: Icon(
                                    character.icon,
                                    size: 48,
                                    color: Colors.white
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        character.name,
                                        style: textTheme.headlineMedium
                                            ?.copyWith(
                                          color: AppColors.parchment,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        character.subtitle,
                                        style: textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 16),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? AppColors.ancientGold
                                        : AppColors.lightStone,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── New game button ─────────────────────────────────────
                  ElevatedButton(
                    onPressed: () {
                      AudioService().playMenuTap();
                      _confirmNewGame();
                    },
                    child: Text(
                      'PLAY AS '
                      '${_characters[_selectedIndex].name.toUpperCase()}',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContinueBanner
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueBanner extends StatelessWidget {
  const _ContinueBanner({
    required this.save,
    required this.onContinue,
  });

  final SaveData save;
  final VoidCallback onContinue;

  String get _formattedDate {
    final d = save.savedAt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onContinue,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.darkMoss.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.ancientGold, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.ancientGold.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              color: AppColors.ancientGold,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTINUE',
                    style: TextStyle(
                      color: AppColors.ancientGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${save.characterName}  •  World ${save.currentWorldId.replaceAll('world', '')}',
                    style: const TextStyle(
                      color: AppColors.parchment,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formattedDate,
                    style: const TextStyle(
                      color: AppColors.mutedParchment,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.ancientGold,
            ),
          ],
        ),
      ),
    );
  }
}
