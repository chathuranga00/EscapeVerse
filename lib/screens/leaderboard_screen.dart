import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.leaderboard});

  final LeaderboardService leaderboard;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.leaderboard.fetchTop();
  }

  void _refresh() {
    setState(() => _future = widget.leaderboard.fetchTop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.ancientGold),
            );
          }

          if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.leaderboard_outlined,
                      color: AppColors.stoneBrown, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    snap.hasError
                        ? 'Could not load leaderboard.\nCheck your connection.'
                        : 'No entries yet.\nBe the first to complete a world!',
                    style: const TextStyle(color: AppColors.mutedParchment),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final entries = snap.data!;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _EntryRow(rank: index + 1, entry: entries[index]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.rank, required this.entry});

  final int              rank;
  final LeaderboardEntry entry;

  String get _formattedTime {
    final h = entry.totalTimeSeconds ~/ 3600;
    final m = (entry.totalTimeSeconds % 3600) ~/ 60;
    final s = entry.totalTimeSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Color get _rankColor {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => AppColors.mutedParchment,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: rank <= 3
            ? _rankColor.withValues(alpha: 0.08)
            : AppColors.darkMoss.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: rank <= 3 ? _rankColor.withValues(alpha: 0.5) : AppColors.stoneBrown,
          width: rank <= 3 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // ── Rank badge ──────────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: _rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),

          // ── Name ────────────────────────────────────────────────────
          Expanded(
            child: Text(
              entry.displayName,
              style: const TextStyle(
                color: AppColors.parchment,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Worlds completed ─────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.public,
                      color: AppColors.ancientGold, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.worldsCompleted} world${entry.worldsCompleted == 1 ? "" : "s"}',
                    style: const TextStyle(
                      color: AppColors.ancientGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formattedTime,
                style: const TextStyle(
                  color: AppColors.mutedParchment,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
