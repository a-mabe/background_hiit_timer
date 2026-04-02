import 'package:flutter/widgets.dart';

/// Controller for the [Countdown] widget.
///
/// Provides start / stop / pause / resume / restart / skip controls.
class CountdownController {
  VoidCallback? onPause;
  VoidCallback? onResume;
  VoidCallback? onRestart;
  VoidCallback? onStart;
  VoidCallback? onStop;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;

  /// `false` while the timer is running, `true` once it finishes.
  bool? isCompleted;

  /// Whether the timer should start automatically when the widget mounts.
  final bool autoStart;

  CountdownController({this.autoStart = false});

  // ── actions ──────────────────────────────────────────────────────────────

  void start() => onStart?.call();
  void stop() => onStop?.call();
  void pause() => onPause?.call();
  void resume() => onResume?.call();
  void restart() => onRestart?.call();
  void skipNext() => onSkipNext?.call();
  void skipPrevious() => onSkipPrevious?.call();

  // ── internal setters called by CountdownState ─────────────────────────

  void setOnStart(VoidCallback cb) => onStart = cb;
  void setOnStop(VoidCallback cb) => onStop = cb;
  void setOnPause(VoidCallback cb) => onPause = cb;
  void setOnResume(VoidCallback cb) => onResume = cb;
  void setOnRestart(VoidCallback cb) => onRestart = cb;
  void setOnSkipNext(VoidCallback cb) => onSkipNext = cb;
  void setOnSkipPrevious(VoidCallback cb) => onSkipPrevious = cb;
}
