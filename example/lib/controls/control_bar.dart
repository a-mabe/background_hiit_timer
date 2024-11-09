import 'package:example/controls/volume_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlBar extends StatefulWidget {
  final VoidCallback onRestart;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onAdjustVolume;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final bool paused;
  final bool changeVolume;
  final double volume;

  const ControlBar({
    super.key,
    required this.onRestart,
    required this.onTogglePlayPause,
    required this.onAdjustVolume,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.paused,
    required this.changeVolume,
    required this.volume,
  });

  @override
  ControlBarState createState() => ControlBarState();
}

class ControlBarState extends State<ControlBar> {
  double _currentSliderValue = .8;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSliderValue = (prefs.getDouble('volume') ?? 80) / 100;
    });
  }

  Future<void> _saveVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', value * 100);
  }

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
                  widget.changeVolume ? Icons.close : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: widget.onAdjustVolume,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: widget.onSkipPrevious,
              ),
              IconButton(
                icon: Icon(
                  widget.paused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                ),
                onPressed: widget.onTogglePlayPause,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: widget.onSkipNext,
              ),
              IconButton(
                tooltip: 'Restart',
                icon: const Icon(Icons.restart_alt, color: Colors.white),
                onPressed: widget.onRestart,
              ),
            ],
          ),
          if (widget.changeVolume)
            VolumeBar(
              volume: _currentSliderValue,
              onVolumeChanged: (double value) {
                setState(() {
                  _currentSliderValue = value;
                });
                _saveVolume(value);
              },
            ),
        ],
      ),
    );
  }
}
