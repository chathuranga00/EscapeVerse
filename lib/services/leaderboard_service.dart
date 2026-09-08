import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Firestore collection name for leaderboard entries.
const String _kLeaderboardCollection = 'leaderboard';

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardEntry  (lightweight DTO)
// ─────────────────────────────────────────────────────────────────────────────

/// A single player's leaderboard record.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.worldsCompleted,
    required this.totalTimeSeconds,
    required this.updatedAt,
  });

  final String   uid;

  /// Player-chosen display name; defaults to "Adventurer" for anonymous users.
  final String   displayName;

  /// How many worlds this player has completed in total.
  final int      worldsCompleted;

  /// Cumulative in-game seconds across all completed worlds.
  final int      totalTimeSeconds;

  final DateTime updatedAt;

  // ── JSON ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'uid':               uid,
        'displayName':       displayName,
        'worldsCompleted':   worldsCompleted,
        'totalTimeSeconds':  totalTimeSeconds,
        'updatedAt':         FieldValue.serverTimestamp(),
      };

  factory LeaderboardEntry.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final ts = data['updatedAt'];
    return LeaderboardEntry(
      uid:              docId,
      displayName:      (data['displayName'] as String?) ?? 'Adventurer',
      worldsCompleted:  (data['worldsCompleted'] as num?)?.toInt() ?? 0,
      totalTimeSeconds: (data['totalTimeSeconds'] as num?)?.toInt() ?? 0,
      updatedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardService
// ─────────────────────────────────────────────────────────────────────────────

/// Reads and writes leaderboard data in Firestore.
///
/// ## Document structure
/// ```
/// leaderboard/{uid}  →  LeaderboardEntry.toJson()
/// ```
/// Each uid has exactly one document; [upsertEntry] merges updates so the
/// document is created on first call and updated thereafter.
///
/// ## Ranking
/// Entries are ranked by [LeaderboardEntry.worldsCompleted] descending,
/// then by [LeaderboardEntry.totalTimeSeconds] ascending (fewer seconds
/// is faster). Firestore compound queries require a composite index on
/// (worldsCompleted DESC, totalTimeSeconds ASC) — add it in the Firebase
/// console or via firestore.indexes.json.
class LeaderboardService {
  LeaderboardService({
    required AuthService auth,
    FirebaseFirestore? firestore,
  })  : _auth      = auth, // ignore: prefer_initializing_formals
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService       _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(_kLeaderboardCollection);

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Creates or updates this player's leaderboard entry.
  ///
  /// Safe to call fire-and-forget from game code — all errors are swallowed.
  Future<void> upsertEntry({
    required String displayName,
    required int    worldsCompleted,
    required int    totalTimeSeconds,
  }) async {
    final uid = _auth.uid;
    if (uid == null) return; // not signed in yet

    try {
      await _col.doc(uid).set(
        {
          'uid':              uid,
          'displayName':      displayName,
          'worldsCompleted':  worldsCompleted,
          'totalTimeSeconds': totalTimeSeconds,
          'updatedAt':        FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('LeaderboardService: upsert failed — $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetches the top [limit] leaderboard entries, ranked by most worlds
  /// completed then fastest total time.
  ///
  /// Returns an empty list on any error (network, missing index, etc.).
  Future<List<LeaderboardEntry>> fetchTop({int limit = 10}) async {
    try {
      final snap = await _col
          .orderBy('worldsCompleted', descending: true)
          .orderBy('totalTimeSeconds')
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));

      return snap.docs
          .map((d) => LeaderboardEntry.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('LeaderboardService: fetchTop failed — $e');
      return [];
    }
  }
}
