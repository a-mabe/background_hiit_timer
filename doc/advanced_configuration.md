# Advanced Configuration - background_hiit_timer

---

## Table of Contents
1. [Background Service](#background-service)
    1. [Android Foreground Service Configuration](#Android-Foreground-Service-Configuration)
    1. [iOS Background Service Configuration](#iOS-Background-Service-Configuration)
1. [SQLite](#sqflite)
1. [Audio](#audio)
    1. [Audio Assets](#audio-assets)
    1. [Audio Cues](#audio-cues)
    1. [Audio Session](#audio-session)
1. [Configuring the UI](#configuring-the-ui)
1. [iOS and Android Differences](#ios-and-android-differences)

---

## Background Service

This package relies on [flutter_background_service](https://pub.dev/packages/flutter_background_service). This documentation will walk through how the [example](example) app was configured. Refer to the `flutter_background_service` package for the most accurate information.

### Android Foreground Service Configuration

Outlined below is the configuration used in the [example](example) app to enable the timer to execute in the background and play audio on Android.

1. Add the following `<uses-permission>` and `<service>` to [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

```
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <application
        ...>

        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="mediaPlayback">
        </service>

        <activity
            ...>
        </activity>
        ...
    </application>
</manifest>
```

1. On a production release, you may need to request the `SCHEDULE_EXACT_ALARM` permission from the user. This was left out of the [example](example) as when and how to request permissions is left up to the developer. You can use the [permission_handler](https://pub.dev/packages/permission_handler) package:

```
if (Platform.isAndroid) {
    await Permission.scheduleExactAlarm.isDenied.then((value) {
        if (value) {
            Permission.scheduleExactAlarm.request();
        }
    });
}
```

### iOS Background Service Configuration

1. Add the following to `ios/Runner/Info.plist`:

```
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>dev.flutter.background.refresh</string>
</array>
```

2. The following background modes will also need to be added to `ios/Runner/Info.plist` (or check the boxes in XCode):

```
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>processing</string>
</array>
```

## SQLite

The timer uses a [sqflite](https://pub.dev/packages/sqflite) database to send data to the background service. Note that the frontend and the service cannot directly communicate - data must be passed through shared preferences, a database, etc. Stored in the database is the list of timer intervals for the service to iterate through. The database is cleared before storing the next set of data on service startup.

## Audio

### Audio Assets

This package ships with some copyright free audio assets located at [`lib/assets/audio`](../lib/assets/audio/)

Set what audio to use for an interval by specifying the asset file name (no need to include `.mp3`, leave blank for no audio):

```
IntervalType(
    ...
    startSound: "long-bell",
    halfwaySound: "short-halfway-beep",
    countdownSound: "countdown-beep",
    endSound: ""),
```

### Audio Cues

There are four configurable audio cues for intervals outlined below:

| Parameter Name | Description                                     |
|---------------|-------------------------------------------------|
| `startSound`     | Plays at the start of an interval |
| `halfwaySound`   | Plays at the halfway point of an interval.         |
| `countdownSound`    | Plays at the 3, 2, and 1 seconds marks to signify the interval is ending. |
| `endSound`  | Plays at the end of an interval. If intervals are back to back, the start sound of the next interval takes precedence over the end sound of the previous interval. |

### Audio Session

This package currently uses the [audioplayers](https://pub.dev/packages/audioplayers) package to play audio. The package does configure an audio session. By default, the session is configured so that audio from the service will play on both iOS and Android when the app is in the background. The session is also configured to not stop or duck audio from other apps.

```
    player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.none,
        usageType: AndroidUsageType.media,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
    ));
```

## Configuring the UI

The timer service will send back some data to the frontend:

| Variable Name | Type     | Description                                     |
|---------------|----------|-------------------------------------------------|
| `paused`     | Boolean  | Whether the timer is currently paused. Passed to the service via shared preferences. |
| `status`   | String  | Name of the current interval.         |
| `currentInterval`    | Integer   | Index of the current active interval, zero being the first and so on. |
| `currentMicroSeconds`  | Integer  | Time in microseconds that has currently passed for the active interval. |
| `currentMicroSeconds`  | Integer  | Full amount of time in microseconds for the active interval. |
| `volume`    | double   | The volume at which to play timer sound effects. Passed to the service via shared preferences. |
| `changeVolume`    | boolean   | Used to update the UI to show volume controls. Passed to the service via shared preferences. |

This data can then be used to determine what to show in the UI, for example showing the currentMicroSeconds:

```
build: (_, TimerState timerState) {
    Text(timerState.currentMicroSeconds.toString())
}
```

## iOS and Android Differences

### Background Service Life

On iOS, the background service will automatically be killed if sound has not played recently. To remediate this, the timer will play a blank audio file every second a sound effect does not play. On Android, this is not necessary to keep the service alive. However, the sound effects can have some delay on Android when the timer first starts. Playing blank audio eliminates this delay. Thus, the blank audio is fired on both iOS and Android for different reasons.