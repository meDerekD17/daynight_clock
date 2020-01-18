// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; //for set pref orientation

import 'package:flutter/widgets.dart'; // for mediaQuery to get screen size
import 'model.dart';
import 'package:light/light.dart'; //light sensor
import 'package:intl/intl.dart';
import 'package:vector_math/vector_math_64.dart' show radians;
import 'dart:math' as math;

/// A Day Night clock.
class DaynightClock extends StatefulWidget {
  const DaynightClock(this.model);

  final ClockModel model;

  @override
  _DaynightClockState createState() => _DaynightClockState();
}

class _DaynightClockState extends State<DaynightClock>
    with TickerProviderStateMixin {
  //[Single]TickerProviderStateMixin - for single or multiple animationControllers
  //Gave problems when tried SingleTickerProviderStateMixin. Even with stopAnimationController()
  DateTime _dateTime = DateTime.now();
  Timer _timer;

  int lightSensorValue; // save current light sensor value
  StreamSubscription<int>
      _lightSensorSubscription; //..works for Android.. NOT FOR IOS <<<
  Light _light; //..only
  //bool didLightChange =
  //false; //not needed as tests if eg Day, and below light level, so change

  //var animatedOpacity = 0.0; //presume double
  //var changingAngle = -math.pi / 2.0;
  //var changingAngle2 = 0.0;

  //var angleDelta = math.pi / 16.0; // = math.pi/2.0;

  //int animationNumber;
  AnimationController animController;

  MyClockType previousClockType;
  //bool isClockSetBySensor = true;  //should be in the model????

  double globalFontSize;
  //final
  TextStyle defaultStyle; // = TextStyle(
//    color: Color(0xFF38332D),
//    fontFamily: 'Teko',
//    fontWeight: FontWeight.w400,
//    //fontSize: globalFontSize * 0.5,
//    height: 1.35, //pushes digit up (and down) within 'text area'
//  );

  //There are 2 background Images, one for each clock type: Day or Night
  //Current image is loaded from assets in _updateModel() (and initState())
  Image backgroundImage;

  @override
  void initState() {
    super.initState();

    previousClockType = widget.model.myClockType;

    //strBackgroundFile = 'assets/daynight_day.png';

    //Default start Clock Type is Day. After here, is changed as needed in _updateModel()
    backgroundImage = Image.asset('assets/daynight_day.png', fit: BoxFit.fill);

    if (widget.model.myClockType == MyClockType.Day) {
      //Don't need to check as Day is default start
      //Clock Type using animationController ..
      startAnimController();
    } //if Day Clock, start animation
    widget.model.addListener(
        _updateModel); // _updateModel() can change ClockType after any change
    _light =
        new Light(); //for light sensor  SETUP LUX before call to _updateTime()
    lightSensorValue = widget
        .model.lightSensorMax; //value so something works at start = Day clock
    try {
      _lightSensorSubscription =
          _light.lightSensorStream.listen(onLightSensorData);
    } on LightException catch (exception) {
      //print(exception);
      widget.model.lightSensorCanSetClockType =
          false; //if problems, don't try to use
      _lightSensorSubscription?.cancel();
    }

    defaultStyle = TextStyle(
      color: Color(0xFF38332D),
      fontFamily: 'Teko',
      fontWeight: FontWeight.w400,
      //fontSize: globalFontSize * 0.5, //fontSize set when written
      height: 1.35, //pushes digit up (and down) within 'text area'
    );
    _updateModel(); //..as _updateModel() calls _updateTime()
  } // void initState()

  void startAnimController() {
    //animController?.dispose();  //maybe if removes, and use SingleTicker
    stopAnimationController();
    animController = new AnimationController(
      duration: Duration(milliseconds: 1000),
      value: 0.0,
      lowerBound: 0.0,
      upperBound: 1.0,
      vsync: this, // Scaffold.of(context),
    );

    animController.addListener(() {
      setState(() {
        // redraw (build()) for every animation cycle. Note: does NOT call updateTime()
      });
    });
    animController.repeat(); //start running this controller
  } //void startAnimController()

  stopAnimationController() {
    animController?.stop(canceled: true);
    animController?.dispose();
    animController = null;
  }

  @override
  void didUpdateWidget(DaynightClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  } //void didUpdateWidget

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    _lightSensorSubscription?.cancel(); //light sensor
    animController?.dispose();
    super.dispose();
  } //void dispose()

  void onLightSensorData(int luxValue) async {
    //Listener for changes in the light sensor - if big enough to change clock type
    //between day (more light) and night (gets darke)
    bool ifBigChange = didLightChangeEnough(lightSensorValue, luxValue);
    lightSensorValue =
        luxValue; //have to save this, after doing ifBigChange()
    if (ifBigChange)
      _updateTime(); //if light change is big enough, call _updateTime()..
    //..so ClockType can change in middle of minute
  } //void onLightSensorData

  bool didLightChangeEnough(int prevValue, int newValue) {
    //not needed
    bool ifEnough = false;
    if ((prevValue >= widget.model.lightSensorMin &&
            newValue < widget.model.lightSensorMin) ||
        (prevValue < widget.model.lightSensorMax &&
            newValue >= widget.model.lightSensorMax)) ifEnough = true;
    return ifEnough;
  } //bool didLightChangeEnough(

  void _updateModel() {
    // need to reset SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom])
    // if model change used a keyboard
    // above line to remove System Bar did not work if no text was changed, so..
    // ..had to place in Build()

    if (previousClockType != widget.model.myClockType) {
      //is there a Clock Type change
      if (previousClockType == MyClockType.Day) {
        //last screen mode used animation
        stopAnimationController();
      }
      previousClockType = widget.model.myClockType;
      String strBackgroundFile;

      if (widget.model.myClockType == MyClockType.Day) {
        startAnimController();
        strBackgroundFile = 'assets/daynight_day.png';
      } //if now Day Clock start animationController
      else {
        //current Clock Type is Night Clock
        strBackgroundFile = 'assets/daynight_night.png';
      }
      //There was a model change, so change the background image
      backgroundImage = Image.asset(strBackgroundFile, fit: BoxFit.fill);
    } //if(previous ClockType != widget.model.myClockType = Change in ClockType
    _updateTime(); //will start Timer, and do setState()
  } //void _updateModel()

  void _updateTime() {
    setState(() {
      //setStae() means: do a redraw, but run code below first
      _dateTime = DateTime.now();

      //DayClock needs animation between the Timer setting of 1 second, to allow
      //the juggling balls to collapse and mover over when carrying to the
      //digit to the left
      // Night Clock just comes back in 1 minute with the Timer

      //check if lightSensor Can Change Clock, and, if so, check value of lux to set Day or Night Clock
      if (widget.model.lightSensorCanSetClockType) {
        if (lightSensorValue <= widget.model.lightSensorMin &&
            ( // if a low light value, and..
                widget.model.myClockType == MyClockType.Day)) {
          //change to Night Clock
          stopAnimationController();
          widget.model.myClockType = MyClockType.Night;
        } //if light value is high, and we were in NightClock < only changeif in NightClock
        else if (lightSensorValue >= widget.model.lightSensorMax &&
            widget.model.myClockType == MyClockType.Night) {
          //change to Day Clock
          startAnimController();
          widget.model.myClockType = MyClockType.Day;
        } //if/else low light value=NightClcok; High light value=day clock
      } //if(widget.model.lightSensorCanSetClockType

      //Day Clock: Update once per second, but make sure to do it at the beginning of each
      // new second, so that the clock is accurate. And AnimationController is
      // on the same sync cycle
      // Day Clock needs Timer for 1 second to do Juggling balls
      Duration duration;
      if (widget.model.myClockType == MyClockType.Day) {
        duration = Duration(seconds: 1) - //come back on tick of next second
            Duration(milliseconds: _dateTime.millisecond);
      } else {
        //Must Be: (widget.model.myClockType == MyClockType.Night) {
        duration = Duration(minutes: 1) -
            Duration(seconds: _dateTime.second) -
            Duration(milliseconds: _dateTime.millisecond);
      }
      _timer = Timer(
        duration,
        _updateTime, //callback: in 1 second (for Day Clock) or 1 minute (Night Clock)
      );

      if (widget.model.myClockType == MyClockType.Day) {
        animController.value =
            (_dateTime.millisecond / 1000); //sync animation with Timer
        animController.repeat();
      }
    }); //setState() for 1 second Timer - will check Screen mode for Timer
  } //void updateTime()

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren =
        []; //images and overlays to display on the screen

//    final hour =
//        DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
//    final minute =
//        DateFormat('mm').format(_dateTime); // WILL NOT BE USED ..<<<<<<
//    final second = DateFormat('ss').format(_dateTime); //dd 1221
//    final millisecond = _dateTime.millisecond; //   <<<<<<<<<<<<<<<<

    //remove system bar if editText keyboard left it showing. There must be a more efficient..
    //of doing this. I tried in updateModel() , but that would not work if no..
    //change was made to the EditText field
    SystemChrome.restoreSystemUIOverlays();

    MediaQueryData _mediaQueryData = MediaQuery.of(context);
    double width = _mediaQueryData.size.width;
    double height = _mediaQueryData.size.height;

    // ***** Will use global Font and size when the best font and size is determined. Fonts for
    // other size text will be relative to gloablFontSize
    globalFontSize = width * 0.46; //was /.5  //used my hour minute digits

    //Made Class global defined in initState(), but changed by Build() because screen dimensions

//    final defaultStyle = TextStyle(
//      color: Color(0xFF38332D),
//      fontFamily: 'Teko',
//      fontWeight: FontWeight.w400,
//      fontSize: globalFontSize * 0.5,
//      height: 1.35, //pushes digit up (and down) within 'text area'
//    );

    ///    defaultStyle.fontSize=globalFontSize;

    stackChildren.add(Positioned(
      left: 0.0,
      top: 0.0,
      width: width,
      height: height,
      child: backgroundImage,
    ));

    // DATETIME IS ONLY VALID WITH TIMER = 1 SECOND, not eg 54 sec, or 4 seconds
    //widget.model.
    if (widget.model.myClockType == MyClockType.Day) {
      addStackForDayClock(stackChildren, width, height);
    } else if (widget.model.myClockType == MyClockType.Night) {
      addStackForNightClock(stackChildren, width, height);
    }
    return Container(
      child: Center(
        child: DefaultTextStyle(
          style: defaultStyle,
          child: Stack(
            children: stackChildren,
          ),
        ),
      ),
    );
  } //Widget build(BuildContext context)

  void addStackForDayClock(List<Widget> ourStack, double width, double height) {
    String strHour =
        DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
    String strMinute =
        DateFormat('mm').format(_dateTime); //must return eg 04 for 4 minutes
    String strSecond = DateFormat('ss').format(_dateTime);
    int intHour =
        _dateTime.hour; //used to check if either of hour digits should animate
    int intMinute = _dateTime
        .minute; //used to see ig in 59th or 1st minute for hr,min digit animation
    int intSecond = _dateTime
        .second; //used to see if animation of hr, min digits should start

    String strHrLeftDigit = strHour.substring(0, 1);
    String strHrRightDigit = strHour.substring(1, 2);
    String strMinLeftDigit = strMinute.substring(0, 1);
    String strMinRightDigit = strMinute.substring(1, 2);
    String strSecleftDigit = strSecond.substring(0, 1);
    String strSecRightDigit = strSecond.substring(1, 2);

    int intSecLeftDigit = int.parse(strSecleftDigit);
    int intSecRightDigit = int.parse(strSecRightDigit);
    int intMinLeftDigit = int.parse(strMinLeftDigit);
    int intMinRightDigit = int.parse(strMinRightDigit);
    int intHrLeftDigit = int.parse(strHrLeftDigit);
    //int intHrRightDigit = int.parse(strHrRightDigit);

//    int iStartLoop = 0; //to give repeat draws of digits to give thickness in..
//    int iEndLoop = 0; //..the digits as they turn
//    int iLoopStep = 0;

    double angleToRotate = 0.0;

    bool bHrLeftDigRotates = false;
    bool bHrRightDigRotates = false;
    bool bMinLeftDigRotates = false;
    bool bMinRightDigRotates = false;

    bool bIn59thSecondOfMinute =
        false; //so easier to test for which digits change
    bool bIn1stSecondOfMinute = false;

    int intStartAnimation =
        59; //but we want to delay start of rotation so looks like..
    int intEndAnimation = 1; //carry-over ball starts the rotation
    //Now rotation starts half way through the 59th second, and ends
    //halfway through the 1st second of the next minute, so, for Phase 2..
    //..would change test for eg in 59th second and anim.value > 0.5
    //below still works, as angleToRotate() is only set if in that range

    if (intSecond >= intStartAnimation || intSecond < intEndAnimation) {
      //BUT still must check that in 2nd half of 59th second, ..
      angleToRotate = 0.0; // unless in part of second that has rotation
      if (intSecond >= intStartAnimation && animController.value > 0.5) {
        bIn59thSecondOfMinute = true;
        angleToRotate =
            math.pi * (animController.value - 0.5); //was 56 was /4 MUST BE 4
        //angleToRotate goes from zero to pi/2 , while anim.value goes from 0.5 to 1.0
      } else if (intSecond <= intEndAnimation && animController.value < 0.5) {
        // if in first half of 1st second of this minute
        bIn1stSecondOfMinute = true;
        angleToRotate =
            math.pi * (0.5 - animController.value); //was 4 - intSec /4
      }

      //maybe could do these IFs a bit different, so did not have to do IFs below if not
      //in the rotating parts of the seconds

      //we are in seconds = 59 or seconds = 0, with angleToRotate set to correct
      // value, or set to 0.0, if not in rotating part of the second
      bMinRightDigRotates = true;
      //so no need to set bMinRightDigitRotates, as angleToRotate is either 0.0 or set

      if ((bIn59thSecondOfMinute && intMinRightDigit == 9) ||
          (bIn1stSecondOfMinute && intMinRightDigit == 0)) {
        bMinLeftDigRotates = true;
        if (bIn59thSecondOfMinute && intMinute == 59 ||
            bIn1stSecondOfMinute && intMinute == 0) {
          bHrRightDigRotates = true;

          //19 only when 24 hr format
          //23 only when 24 hr format
          // if here, only need to test for one of bIn59thSecondOfMinute or bIn1stSecondOfMinute
          if ((bIn59thSecondOfMinute &&
                      ((intHour == 9 && intMinute == 59) ||
                          (intHour == 19 && intMinute == 59) ||
                          (intHour == 12 &&
                              intMinute == 59 &&
                              !widget.model.is24HourFormat) ||
                          (intHour == 23 && intMinute == 59))) ||
                  (bIn1stSecondOfMinute &&
                      ((intHour == 10 && intMinute == 0) ||
                          (intHour == 20 && intMinute == 0) ||
                          (intHour == 1 && intMinute == 0) ||
                          ((intHour == 24 || intHour == 0) &&
                              intMinute == 0))) //)
              ) {
            //Notes:
            //00 and 24 only possible in 24 hr format
            //note: military can have 24 00 for end of a day
            // but a clock would have that time 00 00 (really begin of next day)

            bHrLeftDigRotates = true;
          } // if Hour left digit rotates
          // **********************   /
        } //if Hour right digit rotates

      } //if Minute Left digit changes
    } // if intSecond 56, 57, ..0, 1, ..3 - where we know at least the rightDigit of Minute changes

    //Add Widgets for the time digits for hour and minute
    if (!(!widget.model.is24HourFormat && (intHrLeftDigit == 0))) {
      //do not draw the Zero if not 24-Hour format AND left Hour digit is a Zero
      ourStack.add(myRotateAboutY(
          //most of time angle to rotate is zero
          width * (intHrLeftDigit == 1 ? 0.075 : 0.045),

          ///0.066),   //1 ? 0.075 : 0.045
          height * 0.05,
          (bHrLeftDigRotates ? angleToRotate : 0.0),
          strHrLeftDigit));
    }

    ourStack.add(myRotateAboutY(
        width * 0.215, //0.1875
        height * 0.05,
        (bHrRightDigRotates ? angleToRotate : 0.0),
        strHrRightDigit));

    ourStack.add(myRotateAboutY(
        width * (intMinLeftDigit == 1 ? 0.47 : 0.44), //* 0.44,
        height * 0.05,
        (bMinLeftDigRotates ? angleToRotate : 0.0),
        strMinLeftDigit));

    ourStack.add(myRotateAboutY(
        width *
            (intMinRightDigit == 1
                ? 0.625
                : 0.61), //if 1, put it in centre // 0.615 :0.585 //0.595),
        height * 0.05,
        (bMinRightDigRotates ? angleToRotate : 0.0),
        strMinRightDigit));

    //Animation on right side of screen representing the second digits
    //A hammer pushes up a ball for each second. There is carry-over to the left
    //Hammer (sort of) - pushes up each ball
    if (animController.value <= 0.5) {
      //from pi*0.5 to 0.25*pi
      angleToRotate = math.pi * 0.5 - ((animController.value) * math.pi * 0.5);
    } else {
      //from 0.25 * pi to pi*0.5
      angleToRotate =
          math.pi * 0.25 + ((animController.value - 0.5) * math.pi * 0.5);
    }

    //Swinging the hammer
    ourStack.add(
      Positioned(
        left: width * 0.925,
        top: height * 0.735,
        child: Transform.rotate(
          angle: angleToRotate,
          origin: Offset(0.0, -height * 0.1),
          child: Container(
            child: SizedBox(
              //this is angled sideways so width is up/down -> proportional to height..
              // and height is left to right -> proportional to width..
              width: height * 0.055, //..so width = Function(height) is OK
              height: width * 0.165,
              child: Container(
                //color: Colors.blue,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(056, 051, 045, 1.0), //Colors.blue,
                  border: Border.all(
                    color: Color(0xFF38332D),
                    width: 0,
                  ),
                  //borderRadius: BorderRadius.circular(10.0),
                ),
                // color: Colors.red,)
              ),
            ),
          ),
        ),
      ),
    );

    //Jumping balls for the Second digits
    //Show second's digits with circles ( really squares with curved corners
    double bootedUpAmount = 0.0;
    double ballDimension = width * 0.0345; //(sort of) diameter of ball
    double ballSeparation = width * 0.003; //distance between each ball
    if (intSecRightDigit != 0) {
      //do NOT do a right digit if it is Zero, but will show collapsing balls (later below)
      if (animController.value >= 0.1 && animController.value < 0.6) {
        bootedUpAmount = height * 0.07;
      } else {
        bootedUpAmount = 0.0;
      } //if a booted Up amount for top ball
      for (int i = 1; i <= intSecRightDigit; i++) {
        ourStack.add(
          Positioned(
            left: width * 0.88, //86,
            top: height * 0.684 -
                ((i - 1) * (ballDimension + ballSeparation)) -
                (i == intSecRightDigit ? bootedUpAmount : 0.0),
            child: SizedBox(
              width: ballDimension, //width* 0.025,
              height: ballDimension, //width* 0.025,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFBA2C0F),
                  border: Border.all(
                    color: Color(0xFFBA2C0F),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(ballDimension), //20.0),
                ),
                // color: Colors.red,)
              ),
            ),
          ),
        );
      } //for (int i = 1; i <= intSecRightDigit; i++)

      //we start a carry over from right Second digit to Left digit if rightDigit = 9
      //..and last part of the second - animController > 0.5
      if (intSecRightDigit == 9 && animController.value > 0.5) {
        //start a carry over Note anim.value goes from .7 to .999, so multiply by 3.333..
        //but better if goes slower, 0.5 to .9999. But only go back half way, when Rtdigit=0
        //will go rest of way
        ourStack.add(
          Positioned(
            left: width * (0.88 - (0.06 * 0.5 * (animController.value - 0.5))),
            top: height * 0.684,
            child: SizedBox(
              width: ballDimension, //width* 0.025,
              height: ballDimension, //width* 0.025,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFBA2C0F),
                  border: Border.all(
                    color: Color(0xFFBA2C0F),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(ballDimension),
                ),
                // color: Colors.red,)
              ),
            ),
          ),
        );
      } //carry over starting at end of right digit =9

    } //if intSectRightDigit != 0
    else {
      //if right digit is zero, draw collapsing objects and carry to left
      int collapseLoop = (((1.0 - animController.value) * 10.0) - 1.0).toInt();
      // collapse loop will get smaller during second, as pile collapses
      double reduceHeight = animController.value;
      for (int i = 1; i <= collapseLoop; i++) {
        ourStack.add(
          Positioned(
            left: width * 0.88,
            //86,
            top:
                height * 0.684 - (((i - 1) * (ballDimension + ballSeparation))),
            child: SizedBox(
              width: ballDimension,
              height: ballDimension,
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                      186,
                      044,
                      015,
                      (animController.value < 0.3
                          ? 1.0
                          : (1.0 - animController.value))), //our red
                  border: Border.all(
                    color: Color.fromRGBO(186, 044, 015, 0.0), //our red
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(ballDimension),
                ),
                // color: Colors.red,)
              ),
            ),
          ),
        );
      } //loop to draw collapsing right=hand second digits

      //if (intSecLeftDigit != 0) { // then can carry over to left, as ..
      // now carry over even if Left digit = nothing = 0
      //.. BUT do 2nd half of carry over (first half done when RtDigit = 9

      //in first part of following second, when right digit = 0, do last half of carry over
      if (animController.value < 0.5) {
        ourStack.add(
          Positioned(
            left: width * (0.88 - 0.03 - (0.03 * 2.0 * (animController.value))),
            top: height * 0.684,
            child: SizedBox(
              width: ballDimension,
              height: ballDimension,
              child: Container(
                decoration: BoxDecoration(
//                  color: Color(0xFFBA2C0F), //our red
//                  border: Border.all(
//                    color: Color(0xFFBA2C0F), //our red
//                    width: 1,
//                  ),

                  //        //*
                  color: Color.fromRGBO(
                      186,
                      044,
                      015,
                      (animController.value < 0.3
                          ? 1.0
                          : (1.0 -
                              animController
                                  .value))), //our red, fades as carry-over
                  border: Border.all(
                    color: Color.fromRGBO(
                        186, 044, 015, 0.0), //our red, but transparent
                    width: 1,
                  ),
                  //          * /

                  borderRadius: BorderRadius.circular(ballDimension), //20.0),
                ),
                // color: Colors.red,)
              ),
            ),
          ),
        );
      } //if anim.value < 0.5 - just do carry over at first half second from halfway
    } //end of if/else rt second digit != 0, so this last part for when == 0

    //draw object representing Second left digit
    if (intSecLeftDigit != 0) {
      //dont draw anything for zero of tens of seconds,
      //boot up when just received from right hand digit ( rt hand digit == 0)
      if (intSecRightDigit == 0 &&
          animController.value >= 0.4 &&
          animController.value < 0.7) {
        bootedUpAmount = height * 0.07;
      } else {
        bootedUpAmount = 0.0;
      }

      for (int i = 1; i <= intSecLeftDigit; i++) {
        ourStack.add(
          Positioned(
            left: width * 0.801,
            top: height * 0.684 -
                ((i - 1) * (ballDimension + ballSeparation)) -
                (i == intSecLeftDigit ? bootedUpAmount : 0.0),
            child: SizedBox(
              width: ballDimension,
              height: ballDimension,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFBA2C0F),
                  border: Border.all(
                    color: Color(0xFFBA2C0F), //our red
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(ballDimension),
                ),
              ),
            ),
          ),
        );
      } //for loop to draw Sec Left digit

      //start a carry over from seconds ( when seconds ==59, and latter part of
      // that final second)
      if (intSecLeftDigit == 5 &&
          intSecRightDigit == 9 &&
          animController.value > 0.5) {
        ourStack.add(
          Positioned(
            left: width * (0.801 - (0.06 * 2.0 * (animController.value - 0.5))),
            top: height * 0.684,
            child: SizedBox(
              width: ballDimension,
              height: ballDimension,
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(186, 044, 015,
                      (1.0 - 2.0 * animController.value)), //our red, fades
                  border: Border.all(
                    color: Color.fromRGBO(186, 044, 015,
                        (1.0 - 2.0 * animController.value)), //Colors.red,
                    //(0.5 - animController.value)), //Colors.red,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(ballDimension), //20.0),
                ),
              ),
            ),
          ),
        );
      } //carry over starting at end of right digit =9

    } // if sec Left digit IS NOT zero == ie do not draw a zeroth ten digit

    else if (intSecRightDigit ==
        0) // and intSecLeftDigit == 0, as continues from previous if statement
    {
      //if Left digit is zero, draw collapsing objects
      int collapseLoop = (((1.0 - animController.value) * 6.0) - 1.0)
          .toInt(); //note: 60 minutes needs 6-1
      // collapse loop will get smaller during second, as pile collapses
      for (int i = 1; i < collapseLoop; i++) {
        ourStack.add(
          Positioned(
            left: width * 0.801,
            top:
                height * 0.686 - (((i - 1) * (ballDimension + ballSeparation))),
            child: SizedBox(
              width: ballDimension,
              height: ballDimension,
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                      186, 044, 015, (1 - animController.value)), //our red
                  border: Border.all(
                    color: Color.fromRGBO(
                        186, 044, 015, (1 - animController.value)), //our red
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(ballDimension), //20.0),
                ),
              ),
            ),
          ),
        );
      } //loop to draw collapsing digits

    } // else right digit is zero

    if (!widget.model.is24HourFormat) {
      //we need Am or PM
      int intHour24 = int.parse(DateFormat('HH').format(DateTime.now()));
      ourStack.add(
        Positioned(
            left: width * 0.62, //0.6, //0.63,
            top: height * 0.75,
            child: Text(
              (intHour24 >= 12 ? 'PM' : 'AM'),
              style: TextStyle(
                  fontSize: globalFontSize * 0.3,
                  color: Color(0xFF38332D),
                  fontWeight: FontWeight.w600),
            )),
      );
    } // if model is NOT 24 hour format
  } //void addStackForDayClock()

  Widget myRotateAboutY(
      double fromLeft, double fromTop, double angle, String strDigit) {
    //Rotate a Text around the Y-axis, to an angle
    //fromLeft, fromTop: coordinates of the Positioned Text
    //angle: angle to set the Text
    //strDigit: Text digit
    return Positioned(
      left: fromLeft,
      top: fromTop,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateY(angle),
        child: Text(
          strDigit,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: globalFontSize),
          //style: TextStyle(fontFamily: 'Teko', fontSize: globalFontSize),
        ),
      ),
    );
  } //method: Widget myRotateAboutY()

  void addStackForNightClock(
      List<Widget> ourStack, double width, double height) {
    //, DateTime _dateTime) {
    //load the Widget Stack for the Night Clock - a simple clock that clearly shows
    //time if user wakes at night and glances to the clock
    //Green triangle bottom left shows which way up ( no confusion eg 01 11 - 11 10)
    //ourStack: Stack on which to add Hour and Minute Widgets for current time
    //width, height: Width and Height of the screen
    //
    //Global to class variable _dateTime is used to give Hour, Minute

    //_dateTime = DateTime.now(); //as can get here directfrom build() and animation ,ie not
    // through updateTime()
    String strHour =
        DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
    String strMinute = DateFormat('mm').format(_dateTime);
    String strSecond = DateFormat('ss').format(_dateTime);
//    int intHour = _dateTime.hour;
//    int intMinute = _dateTime.minute;
//    int intSecond = _dateTime.second;

    String strHrleftDigit = strHour.substring(0, 1);
    String strHrRightDigit = strHour.substring(1, 2);
//    String strMinleftDigit = strMinute.substring(0, 1);
//    String strMinRightDigit = strMinute.substring(1, 2);
//    String strSecleftDigit = strSecond.substring(0, 1);
//    String strSecRightDigit = strSecond.substring(1, 2);

//    int intSecLeftDigit = int.parse(strSecleftDigit);
//    int intSecRightDigit = int.parse(strSecRightDigit);
//    int intMinLeftDigit = int.parse(strMinleftDigit);
//    int intMinRightDigit = int.parse(strMinRightDigit);
    int intHrLeftDigit = int.parse(strHrleftDigit);
//    int intHrRightDigit = int.parse(strHrRightDigit);

    ourStack.add(
      Positioned(
        left: width * 0.125,
        top: height * 0.05,
        child: Text(
            (!widget.model.is24HourFormat && (intHrLeftDigit == 0))
                ? ' $strHrRightDigit'
                : strHour,
            //do not draw any leading Zero of the hour, if not 24-hour format
            style: TextStyle(
                //fontFamily: 'Teko',
                fontSize: globalFontSize,
                color: Color(0xFFEFEEEA))),
      ),
    );

    ourStack.add(
      Positioned(
        left: width * 0.5,
        top: height * 0.05,
        child: Text(
          strMinute,
          style: TextStyle(
              //fontFamily: 'Teko',
              fontSize: globalFontSize,
              color: Color(0xFFEFEEEA)),
        ),
      ),
    );

    if (!widget.model.is24HourFormat) {
      //if not 24-hour format, we need Am or PM
      int intHour24 = int.parse(DateFormat('HH').format(_dateTime));
      //int intHour24 = int.parse(DateFormat('HH').format(DateTime.now()));
      ourStack.add(
        Positioned(
            left: width * 0.85, //45, //0.84,
            top: height * 0.725,
            child: Text(
              (intHour24 >= 12 ? 'PM' : 'AM'),
              style: TextStyle(
                  fontSize: globalFontSize * 0.26, //0.3,
                  color: Color(0xFFEFEEEA),
                  fontWeight: FontWeight.w600),
            )),
      );
    } // if model is NOT 24 hour format
  } //void addStackForNightClock(

} //class class _DigitalClockState extends State<DigitalClock> with TickerProviderStateMixin
