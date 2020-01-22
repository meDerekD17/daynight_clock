# Day Night Clock

A Clock App. Created for the [Flutter Clock Challenge](https://flutter.dev/clock)

## Getting Started

```
flutter run
```

## Notes

- After submitting to Clock Challenge I noticed a 'feature' where time digits and their animation were not nicely handled after a pause. Resolved by having SystemChannels.lifecycle.setMessageHandler calling _updateTime(), where current time, and the current animation are updated and made to sync with each other.

- Run on Android device
- Screen size 800w x 480h 5/3 ratio
- Light sensor will automatically switch from Day Clock to Night Clock
- Light Sensor not available in iOS, or (sometimes) AVDs
- Light sensor can be disabled
- Can set time to 24-hour format 