import 'package:example/controls/volume_bar.dart';
import 'package:flutter/material.dart';

class ControlBar extends StatelessWidget {
  final VoidCallback onRestart;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onAdjustVolume;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final Function(double) onVolumeChanged;
  final bool paused;
  final bool changeVolume;
  final double volume; // 0.0–1.0

  const ControlBar({
    super.key,
    required this.onRestart,
    required this.onTogglePlayPause,
    required this.onAdjustVolume,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onVolumeChanged,
    required this.paused,
    required this.changeVolume,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  changeVolume ? Icons.close : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: onAdjustVolume,
              ),
              IconButton(
                tooltip: 'Skip Previous',
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: onSkipPrevious,
              ),
              IconButton(
                tooltip: paused ? 'Play' : 'Pause',
                icon: Icon(
                  paused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                ),
                onPressed: onTogglePlayPause,
              ),
              IconButton(
                tooltip: 'Skip Next',
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: onSkipNext,
              ),
              IconButton(
                tooltip: 'Restart',
                icon: const Icon(Icons.restart_alt, color: Colors.white),
                onPressed: onRestart,
              ),
            ],
          ),
          if (changeVolume)
            VolumeBar(volume: volume, onVolumeChanged: onVolumeChanged),
        ],
      ),
    );
  }
}
