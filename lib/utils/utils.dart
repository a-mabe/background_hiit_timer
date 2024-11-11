import 'package:background_hiit_timer/utils/log.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpool/soundpool.dart';

Future<int> loadSound(String sound, Soundpool pool) async {
  if (sound.isNotEmpty) {
    logger.d('Loading sound $sound');
    return await rootBundle
        .load("packages/background_hiit_timer/lib/assets/audio/$sound.mp3")
        .then((ByteData soundData) {
      return pool.load(soundData);
    });
  }
  return -1;
}

Future playSound(
    int soundID, Soundpool pool, SharedPreferences preferences) async {
  if (soundID != -1) {
    logger.d('Playing sound $soundID');
    await pool.setVolume(
        soundId: soundID,
        volume: ((preferences.getDouble('volume') ?? 80) / 100));
    await pool.play(soundID);
  }
}
