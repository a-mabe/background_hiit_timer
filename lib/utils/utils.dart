import 'package:audioplayers/audioplayers.dart';
import 'package:background_hiit_timer/utils/log.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future playSound(
    String sound, AudioPlayer player, SharedPreferences preferences) async {
  if (sound != "" && sound != "none") {
    logger.d('Playing sound $sound');
    try {
      await player.setVolume((preferences.getDouble('volume') ?? 80) / 100);
      print("playing sound");
      await Future.delayed(Duration(seconds: 100));
      await player.play(
        AssetSource("audio/$sound.mp3"),
        volume: (preferences.getDouble('volume') ?? 80) / 100,
      );
      // await player.stop();
      // await player.play(AssetSource("audio/$sound.mp3"),
      //     ctx: AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
      //         .build());
      // await player.setSourceAsset("audio/$sound.mp3");
      // await player
      //     .setAudioContext(
      //         AudioContextConfig(focus: AudioContextConfigFocus.gain).build())
      //     .then((value) => player.resume());
    } catch (e) {
      logger.e('Error playing sound $sound: $e');
    }
  } else {
    logger.d('Sound not set, skipping sound effect');
  }
}
