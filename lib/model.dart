// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// This is the model that contains the customization options for the clock.
///
/// It is a [ChangeNotifier], so use [ChangeNotifier.addListener] to listen to
/// changes to the model. Be sure to call [ChangeNotifier.removeListener] in
/// your `dispose` method.
///
/// Contestants: Do not edit this.  << But I want  to use some settings??
///
/// Settings:
///  1. Option to show clock time as 24-hour format
///  2. Use the Light Sensor (not available on iOS) to determine to show either Day or Night Clock
///     a. Set Light Sensor Max value, above which Clock will change to Day Clock (if so permitted)
///     b. Set Light Sensor Min value, below which Clock will change to Night Clock (if so permitted)
///  3. Set Day or Night Clock. If Light Sensor is allowed to set Clock, the Light Sensor may change back!
///
/// saving and getting settings to/from SharedPreferences should be part of Phase 2
class ClockModel extends ChangeNotifier {
  get is24HourFormat => _is24HourFormat;
  bool _is24HourFormat = false; //default time
  set is24HourFormat(bool is24HourFormat) {
    if (_is24HourFormat != is24HourFormat) {
      _is24HourFormat = is24HourFormat;
      notifyListeners();
    }
  }

  get lightSensorCanSetClockType => _lightSensorCanSetClockType;
  bool _lightSensorCanSetClockType = true;
  set lightSensorCanSetClockType(bool lightSensorCanSetClockType) {
    if (_lightSensorCanSetClockType != lightSensorCanSetClockType) {
      _lightSensorCanSetClockType = lightSensorCanSetClockType;
      notifyListeners();
    }
  }

  /// Light Sensor Change Max Value string, for example '12'.  <<< MAYBE stored as num????
  /// When light sensor reading goes below Min, change to NightTime Clock BUT..
  /// .. have to go up to MAX before Clock changes back to Day Time Mode
  get lightSensorMax => _lightSensorMax;
  int _lightSensorMax = 8;
  set lightSensorMax(int lightSensorMax) {
    if (lightSensorMax != _lightSensorMax) { //if a change was made
      _lightSensorMax = lightSensorMax;
      //should do a test to be in range, 0,...400
      if (_lightSensorMax < 3) _lightSensorMax = 3;
      if (_lightSensorMax <= _lightSensorMin + 2) _lightSensorMax = _lightSensorMin + 3;
      if (_lightSensorMax > 400) _lightSensorMax = 400; //random large number
    }
    notifyListeners(); //Placed here, as have to say change so system bars are removed
  }

  /// Light Sensor Change Min Value string, for example '2'.
  /// When light sensor reading goes above Max value, change to DayTime Clock BUT..
  /// .. have to go down to MIN before Clock changes back to Night Time Mode
  get lightSensorMin => _lightSensorMin;
  int _lightSensorMin = 1;
  set lightSensorMin(int lightSensorMin) {
    if (lightSensorMin != _lightSensorMin) { //if a change was made
      _lightSensorMin = lightSensorMin;
      if (_lightSensorMin >= _lightSensorMax - 2) _lightSensorMin = _lightSensorMax - 3;
      if (_lightSensorMin < 0) _lightSensorMin = 0;
    }
    notifyListeners(); //placed here, as always say change so system bars are removed
  }

  /// MyClockType text for the current MyClockType: 'Day, Night'.
  MyClockType get myClockType => _myClockType;
  MyClockType _myClockType = MyClockType.Day; //default
  set myClockType(MyClockType myClockType) {
    if (myClockType != _myClockType) {
      _myClockType = myClockType;
      notifyListeners(); //only notify listeners if a change was made
    }
  }

  /// [MyClockType] value without the enum type.
  String get myClockTypeString => enumToString(myClockType);

} //class ClockModel

//if save int to sharedPrefs, recover with: value = MyClockType.value[index];
//myClockType - eg depend on light sensor, or always Day or Night Clocks
enum MyClockType {
  Day,
  Night,
}

/// Removes the enum type and returns the value as a String.
String enumToString(Object e) => e.toString().split('.').last;
