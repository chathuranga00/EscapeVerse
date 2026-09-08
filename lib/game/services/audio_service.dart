import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

// ── Asset path constants ──────────────────────────────────────────────────────

const String kBgmJungle   = 'bgm_jungle.mp3';
const String kBgmTemple   = 'bgm_temple.mp3';
const String kSfxCollect  = 'sfx_collect.mp3';
const String kSfxHit      = 'sfx_hit.mp3';
const String kSfxMenuTap  = 'sfx_menu_tap.mp3';
const String kSfxDialogue = 'sfx_dialogue.mp3';

const Map<String, String> _kWorldBgm = {
  'world1': kBgmJungle,
  'world2': kBgmTemple,
};

// ─────────────────────────────────────────────────────────────────────────────

/// Thin wrapper around [FlameAudio].
///
/// Automatically disabled on web (kIsWeb) because audioplayers' web backend
/// behaves differently and placeholder MP3s cause crashes before the first
/// Flutter frame on Chrome. Replace placeholder files with real audio and
/// remove the kIsWeb guard when you're ready for web audio.
///
/// Set [disabled] = true in unit tests to skip all audio I/O.
class AudioService {
  AudioService({bool disabled = false})
      // Force-disable on web so placeholder files never crash the browser.
      : disabled = disabled || kIsWeb {
    if (this.disabled) {
      debugPrint('AudioService: audio disabled (web or test mode).');
    }
  }

  final bool disabled;

  bool _muted = false;
  bool get isMuted => _muted;

  String? _currentBgm;

  void toggleMute() {
    if (disabled) return;
    _muted = !_muted;
    if (_muted) {
      try { FlameAudio.bgm.pause(); } catch (_) {}
    } else if (_currentBgm != null) {
      try { FlameAudio.bgm.resume(); } catch (_) {}
    }
  }

  Future<void> playBgmForWorld(String worldId) async {
    if (disabled || _muted) return;
    final track = _kWorldBgm[worldId];
    if (track == null || track == _currentBgm) return;
    await stopBgm();
    _currentBgm = track;
    try {
      await FlameAudio.bgm.play(track, volume: 0.5);
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    if (disabled) return;
    try { await FlameAudio.bgm.stop(); } catch (_) {}
    _currentBgm = null;
  }

  void pauseBgm() {
    if (disabled || _muted) return;
    try { FlameAudio.bgm.pause(); } catch (_) {}
  }

  void resumeBgm() {
    if (disabled || _muted || _currentBgm == null) return;
    try { FlameAudio.bgm.resume(); } catch (_) {}
  }

  Future<void> playSfx(String assetName, {double volume = 0.8}) async {
    if (disabled || _muted) return;
    try { await FlameAudio.play(assetName, volume: volume); } catch (_) {}
  }

  Future<void> playCollect()  => playSfx(kSfxCollect);
  Future<void> playHit()      => playSfx(kSfxHit);
  Future<void> playMenuTap()  => playSfx(kSfxMenuTap, volume: 0.6);
  Future<void> playDialogue() => playSfx(kSfxDialogue, volume: 0.5);

  Future<void> dispose() async => stopBgm();
}
