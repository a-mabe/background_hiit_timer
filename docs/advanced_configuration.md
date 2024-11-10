# Advanced Configuration - background_hiit_timer

---

## Table of Contents
1. [Background Service](#background-service)
    1. [Android Foreground Service Configuration](#Android-Foreground-Service-Configuration)
    1. [iOS Background Service Configuration](#iOS-Background-Service-Configuration)
1. [SQLite](#sqflite)
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

## Audio Session

This package currently uses the [soundpool](https://pub.dev/packages/soundpool) package to play audio. The package does not configure an audio session, leaving it up to the developer to set the audio session as they see fit. The [example](example) uses the [audio_session](https://pub.dev/packages/audio_session) package to configure the audio session so that audio from the service will play on both iOS and Android when the app is in the background. The session is also configured to not stop or duck audio from other apps.

1. You can create a function to initialize an audio session with your desired settings. The following function sets the session configuration for the behavior in the example app described above:

```
Future<void> initializeAudioSession() async {
    final session = await AudioSession.instance;

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        flags: AndroidAudioFlags.audibilityEnforced,
        usage: AndroidAudioUsage.notification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
}
```

Without managing the audio session, the timer background service may not play audio when the app is in the background.

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