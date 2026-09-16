import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spielt die Klaenge der App; Tests ersetzen ihn durch eine Attrappe.
abstract interface class SoundPlayer {
  /// Jubel, wenn der Mensch eine Partie gewinnt.
  Future<void> playWin();
}

/// Spielt die Klaenge aus `assets/sounds/` ueber audioplayers.
final class AssetSoundPlayer implements SoundPlayer {
  AudioPlayer? _player;

  @override
  Future<void> playWin() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource('sounds/uuh_yeah.m4a'));
    } on Object {
      // Kein Ton ist kein Grund, das Spiel zu stoeren (etwa ein Browser ohne Freigabe).
    }
  }
}

final soundPlayerProvider = Provider<SoundPlayer>((ref) => AssetSoundPlayer());
