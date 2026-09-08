import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/systems/save_manager.dart';
import 'auth_service.dart';

/// Firestore collection and field names.
///
/// Changing these strings is the only edit needed for a schema rename —
/// the rest of the codebase uses [CloudSaveService] exclusively.
const String _kCollection = 'saves';
const String _kLocalKey   = 'escapeverse_save_v1'; // must match SaveManager

// ─────────────────────────────────────────────────────────────────────────────

/// Mirrors [SaveData] into a Firestore document keyed by the player's uid.
///
/// ## Document structure
/// ```
/// saves/{uid}  →  SaveData.toJson()  +  { 'updatedAt': Timestamp }
/// ```
/// The JSON shape is identical to what [SaveManager] writes to
/// shared_preferences, so the two stores are always interchangeable.
///
/// ## Offline behaviour
/// Every write goes to local shared_preferences first (the existing
/// [SaveManager] path), then asynchronously to Firestore. Reads try
/// Firestore first; fall back to local if offline or unauthenticated.
///
/// ## Swapping to a different backend
/// Replace [_firestoreWrite] / [_firestoreRead] with calls to your new
/// backend. Everything else stays the same.
class CloudSaveService {
  CloudSaveService({
    required AuthService auth,
    FirebaseFirestore? firestore,
  })  : _auth      = auth, // ignore: prefer_initializing_formals
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService       _auth;
  final FirebaseFirestore _firestore;

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Saves [data] locally (shared_preferences) AND to Firestore.
  ///
  /// The local write always happens synchronously-ish; the Firestore write
  /// is fire-and-forget and never throws to the caller.
  Future<void> save(SaveData data) async {
    // 1. Local write — same path as original SaveManager so offline always works.
    await _localWrite(data);

    // 2. Cloud write — best-effort.
    if (_auth.uid != null) {
      await _firestoreWrite(data);
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Loads the most recent save, preferring Firestore over local.
  ///
  /// Falls back to local if:
  /// - The user is not signed in.
  /// - Firestore is unreachable (no network / project not configured).
  /// - The Firestore document doesn't exist yet.
  ///
  /// Returns null when no save exists anywhere.
  Future<SaveData?> load() async {
    if (_auth.uid != null) {
      final cloud = await _firestoreRead();
      if (cloud != null) return cloud;
    }
    return _localRead();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes the save locally and from Firestore (used by "New Game").
  Future<void> deleteSave() async {
    await _localDelete();
    if (_auth.uid != null) {
      await _firestoreDelete();
    }
  }

  // ── Firestore I/O ─────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(_kCollection).doc(_auth.uid!);

  Future<void> _firestoreWrite(SaveData data) async {
    try {
      final payload = data.toJson()
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await _doc.set(payload, SetOptions(merge: true));
    } catch (e) {
      // Firestore write failure is non-fatal — local copy is the safety net.
      debugPrint('CloudSaveService: Firestore write failed — $e');
    }
  }

  Future<SaveData?> _firestoreRead() async {
    try {
      final snap = await _doc.get(
        // Accept cached data when offline so we don't wait for a network timeout.
        const GetOptions(source: Source.serverAndCache),
      );
      if (!snap.exists || snap.data() == null) return null;
      final data = Map<String, dynamic>.from(snap.data()!);
      // Remove Firestore-only fields before handing to SaveData.fromJson.
      data.remove('updatedAt');
      return SaveData.fromJson(data);
    } catch (e) {
      debugPrint('CloudSaveService: Firestore read failed — $e');
      return null;
    }
  }

  Future<void> _firestoreDelete() async {
    try {
      await _doc.delete();
    } catch (e) {
      debugPrint('CloudSaveService: Firestore delete failed — $e');
    }
  }

  // ── Local I/O (shared_preferences) ───────────────────────────────────────

  Future<void> _localWrite(SaveData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalKey, jsonEncode(data.toJson()));
    } catch (_) {}
  }

  Future<SaveData?> _localRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalKey);
      if (raw == null) return null;
      return SaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _localDelete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocalKey);
    } catch (_) {}
  }
}
