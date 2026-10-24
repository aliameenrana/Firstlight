# ReTimely

An ode to Timely, the legendary alarm clock.

Timely (Bitspin, 2013) set alarms on a vertical day timeline over a drifting, dreamy gradient, and woke you with Smart Rise: a quiet melody that began 30 minutes before the alarm and rose slowly. ReTimely rebuilds that for iOS 26.

## Features
- Dreamy background: a Metal shader with a warped gradient, drifting glows and rising bubbles. Its colors follow the time of day (night, dawn, day, dusk).
- Timeline picker: drag along the 0 to 24 hour rail to set an alarm.
- Smart Rise: a melody fades in over the 30 minutes before the alarm.
- Alarms ring through AlarmKit, so they work on a locked phone, in silent mode and during Focus.

## Build
Requires Xcode 26, xcodegen and ffmpeg.

```sh
# put the original Timely sounds (.m4a) in audio-source/
./scripts/prepare-audio.sh
xcodegen
open ReTimely.xcodeproj
```

Sound files are not included in this repository.
