// Number of microseconds in a second, used to convert between seconds and microseconds for timer calculations.
const int secondsFactor = 1000000;

// The interval at which the timer ticks and updates the state. Set to 100 milliseconds (100,000 microseconds) for smooth updates.
const Duration tickInterval = Duration(microseconds: 100000);

// The filename for a blank sound, used to trigger the audio system without playing an actual sound.
String blankSoundFile = "blank";

// Microsecond marks at which countdown beeps fire (3s, 2.5s, 1.5s before end)
const List<int> countdownBeepMarks = [3500000, 2500000, 1500000];

// How far before interval end we look ahead to play the next interval's start sound
const int startSoundLookaheadMicros = 700000;
