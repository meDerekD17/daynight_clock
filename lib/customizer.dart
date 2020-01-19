// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; //for set pref orientation

import 'model.dart';

/// Returns a clock [Widget] with [ClockModel].
///
/// Example:
///   final myClockBuilder = (ClockModel model) => AnalogClock(model);
///
/// Contestants: Do not edit this.   <<<Does this mean do not edit whole file, or just following line???
typedef Widget ClockBuilder(ClockModel model);

/// Wrapper for clock widget to allow for customizations.
///
/// Puts the clock in landscape orientation with an aspect ratio of 5:3.
/// Provides a drawer where users can customize the data that is sent to the
/// clock. To show/hide the drawer, double-tap the clock.
///
/// To use the [ClockCustomizer], pass your clock into it, using a ClockBuilder.
///
/// ```
///   final myClockBuilder = (ClockModel model) => AnalogClock(model);
///   return ClockCustomizer(myClockBuilder);
/// ```
/// Contestants: Do not edit this. <<< But I wanted to reduce settings
class ClockCustomizer extends StatefulWidget {
  const ClockCustomizer(this._clock);

  /// The clock widget with [ClockModel], to update and display.
  final ClockBuilder _clock;

  @override
  _ClockCustomizerState createState() => _ClockCustomizerState();
}

class _ClockCustomizerState extends State<ClockCustomizer> {  //with TickerProviderStateMixin{
  final _model = ClockModel();
  //ThemeMode _themeMode = ThemeMode.light;  //is used for Menu
  bool _configButtonShown = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    //This removes Android (system) bar, but allows bar at bottom (side if landscape) to get out of App
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);

    _model.addListener(_handleModelChange);
  }

  @override
  void dispose() {
    _model.removeListener(_handleModelChange);
    _model.dispose();
    super.dispose();
  }

  void _handleModelChange() {
    setState(() {});
  }

    Widget _enumMenu<T>(
        String label, T value, List<T> items, ValueChanged<T> onChanged) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            onChanged: onChanged,
            items: items.map((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(enumToString(item)),
              );
            }).toList(),
          ),
        ),
      );
    }

    Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
      return Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      );
    }

    Widget _textField(
        String currentValue, String label, ValueChanged<Null> onChanged) {
      return TextField(
        decoration: InputDecoration(
          hintText: currentValue,
          helperText: label,
        ),
        onChanged: onChanged,   //for light sensor value, only numeric values
        keyboardType: TextInputType.numberWithOptions(signed:false, decimal: false),
        inputFormatters: [WhitelistingTextInputFormatter.digitsOnly],

      );
    }


    // moved text input to top so they are not overlaid by keyboard. Not best solution.
  //look into: setting input area shows with keyboard, or select numbers ( relatively small range)
  //from dropdown list. This for Phase 2 of this project!!!
    Widget _configDrawer(BuildContext context) {
      return SafeArea(
        child: Drawer(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[

                  _textField(_model.lightSensorMax.toString(), 'Light Sensor for Clock Change Maximum',
                          (String lightSensorMax) {
                        setState(() {
                          var test = int.tryParse(lightSensorMax); // gets int or null
                          _model.lightSensorMax = test != null ? test: 8;
                        });
                      }),

                  _textField(_model.lightSensorMin.toString(), 'Light Sensor for Clock Change Minimum',
                          (String lightSensorMin) {
                        setState(() {
                          var test = int.tryParse(lightSensorMin);
                          _model.lightSensorMin = test != null ? test : 1;
                        });
                      }),

                  _switch('Light Sensor Can Set Clock Type', _model.lightSensorCanSetClockType, (bool value) {
                    setState(() {
                      _model.lightSensorCanSetClockType = value;
                    });
                  }),

                  _enumMenu(
                      'Clock Type', _model.myClockType, MyClockType.values,
                          (MyClockType clockType) {
                        setState(() {
                          _model.myClockType = clockType;
                        });
                      }),

                  _switch('24-hour format', _model.is24HourFormat, (bool value) {
                    setState(() {
                      _model.is24HourFormat = value;
                    });
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget _configButton() {
      return Builder(
        builder: (BuildContext context) {
          return IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Configure clock',
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
              setState(() {
                _configButtonShown = false;
              });
            },
          );
        },
      );
    }

    @override
    Widget build(BuildContext context) {
      final clock = Center(
        child: AspectRatio(
          aspectRatio: 5 / 3,
          child: Container(
            decoration: BoxDecoration(

            ),
            child: widget._clock(_model),
          ),
        ),
      );

      // this appears to be the main.or 1st, window screen shown
      return MaterialApp(
        debugShowCheckedModeBanner: false, //false, does debug banner show when make changes?

        home: Scaffold(
          resizeToAvoidBottomPadding: false, // i tried true, but no difference dd
          endDrawer: _configDrawer(context),
          body: Container(    //SafeArea( //Changed so can get whole screen
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _configButtonShown = !_configButtonShown;

                });
              },
              child: Stack(
                children: [
                  clock,
                  if (_configButtonShown)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Opacity(
                        opacity: 0.7,
                        child: _configButton(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
