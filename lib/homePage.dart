import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'chart.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageView createState() {
    return HomePageView();
  }
}

class HomePageView extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _toggled = false; // toggle button value
  late final List<SensorValue> _data = []; // array to store the values
  CameraController? controller;

  final double _alpha = 0.3; // factor for the mean value
  late AnimationController _animationController;
  double _iconScale = 1;
  int _bpm = 0; // beats per minute
  final int _fs = 30; // sampling frequency (fps)
  final int _windowLen = 30 * 6; // window length to display - 6 seconds
  late CameraImage _image; // store the last camera image
  late double _avg; // store the average value during calculation
  late DateTime _now; // store the now Datetime
  late Timer _timer; // timer for image processing

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: Duration(milliseconds: 500), vsync: this);
    _animationController
      .addListener(() {
        setState(() {
          _iconScale = 1.0 + _animationController.value * 0.4;
        });
      });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _toggled = false;
    _disposeController();
    Wakelock.disable();
    _animationController?.stop();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CameraController? _controller = controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor:Colors.black12,
        //leading: Icon(Icons.menu),
        title: Text('Embebo Heart Rate Monitoring'),

      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                            Radius.circular(40),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: <Widget>[
                              _controller != null && _toggled
                                  ? AspectRatio(
                                      aspectRatio:
                                          _controller.value.aspectRatio,
                                      child: CameraPreview(_controller),
                                    )
                                  : Container(
                                      padding: EdgeInsets.all(1),
                                      alignment: Alignment.center,
                                      color: Colors.black,
                                    ),
                              Container(
                                alignment: Alignment.center,
                                padding: EdgeInsets.all(4),
                                child: Text(
                                  _toggled
                                      ? "Cover both the camera and the flash with your INDEX FINGER"

                                      : "",
                                  style: TextStyle(
                                      backgroundColor: _toggled
                                          ? Colors.transparent
                                          : Colors.transparent,color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,


                        children: <Widget>[
                          Text(

                            "Estimated BPM",
                            style: TextStyle(fontSize: 18, color: Colors.red),
                          ),
                          Text(
                            (_bpm > 30 && _bpm < 150 ? _bpm.toString() : "--"),
                            style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      )),
                    ),
                  ],
                )),
            Container(
              alignment: Alignment.center,
              margin: EdgeInsets.fromLTRB(12, 12, 12, 0),

              child: Text(
                _toggled
                    ? ""

                    : "Tap the Heart Button",

                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    backgroundColor: _toggled
                        ? Colors.transparent
                        : Colors.transparent,color: Colors.red),
                textAlign: TextAlign.center
              ),
            ),
            Expanded(

              flex: 1,
              child: Center(

                child: Transform.scale(
                  scale: _iconScale,

                  child: IconButton(
                    icon:
                        //heart icon Material UI
                        Icon(_toggled ? Icons.favorite : Icons.favorite_border),
                    color: Colors.red,
                    iconSize: 200,
                    onPressed: () {
                      if (_toggled) {
                        _untoggle();

                      } else {
                        _toggle();
                      }
                    },
                  ),
                ),

              ),

            ),

            Expanded(
              flex: 1,
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.circular(18),
                    ),
                    color: Colors.black),
                child: Chart(_data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearData() {
    // create array of 128 ~= 255/2
    _data.clear();
    int now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < _windowLen; i++) {
      _data.insert
        (
          0,
            SensorValue
            (
              DateTime.fromMillisecondsSinceEpoch(now - i * 1000 ~/ _fs), 128)
          );
    }
  }

  void _toggle() {

    _clearData();
    _initController().then((onValue) {

      Wakelock.enable();
      _animationController?.repeat(reverse: true);
      setState(() {
        _toggled = true;
      });
      // after is toggled
      _initTimer();
      _updateBPM();
    });
  }

  Future<void> _untoggle() async {
    //_controller?.setFlashMode(FlashMode.off);
    _disposeController();
    Wakelock.disable();
    _animationController?.stop();
    _animationController?.value = 0.0;
    setState(() {

      _toggled = false;
    });
  }

  void _disposeController() {
    CameraController? _controller = controller;
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initController() async {
    CameraController? _controller = controller;
    try {
      List _cameras = await availableCameras();

      _controller = CameraController(_cameras.first, ResolutionPreset.low);

      await _controller.initialize();
      Future.delayed(const Duration(milliseconds: 100)).then((onValue) {
        _controller?.setFlashMode(FlashMode.torch);

      });

      _controller.startImageStream((CameraImage image) {
        _image = image;

      });
      controller = _controller;
    } catch (Exception) {
      debugPrint(Exception.toString());
    }
  }

  void _initTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ _fs), (timer) {
      if (_toggled) {
        if (_image != null) _scanImage(_image);
      } else {
        timer.cancel();
      }
    });
  }

  void _scanImage(CameraImage image) {
    _now = DateTime.now();

    _avg =
        image.planes.first.bytes.reduce((value, element) => value + element) /
            image.planes.first.bytes.length;
    //data
    if (_data.length >= _windowLen) {
      _data.removeAt(0);
    }
    setState(() {
      _data.add(SensorValue(_now, 255 - _avg));
      //String debugStr =
      for (var element in _data) { print(element.value);}

      debugPrint("-----------------------{  -----------------------debugPrint----");

    });
  }

  void _updateBPM() async {
    // Bear in mind that the method used to calculate the BPM is very rudimentar
    // feel free to improve it :)

    // Since this function doesn't need to be so "exact" regarding the time it executes,
    // I only used the a Future.delay to repeat it from time to time.
    // Ofc you can also use a Timer object to time the callback of this function
    List<SensorValue> _values;
    double _avg;
    int _n;
    double _m;
    double _threshold;
    double _bpm;
    int _counter;
    int _previous;



    while (_toggled) {

      _values = List.from(_data); // create a copy of the current data array



      _avg = 0;
      _n = _values.length;
      _m = 0;
      for (var value in _values) {
        _avg += value.value / _n;
        if (value.value > _m) _m = value.value;
      }
      _threshold = (_m + _avg) / 2;
      _bpm = 0;
      _counter = 0;
      _previous = 0;
      for (int i = 1; i < _n; i++) {
        if (_values[i - 1].value < _threshold &&
            _values[i].value > _threshold) {
          if (_previous != 0) {
            _counter++;
            _bpm += 60 *
                1000 /
                (_values[i].time.millisecondsSinceEpoch - _previous);
          }
          _previous = _values[i].time.millisecondsSinceEpoch;
        }
      }
      if (_counter > 0) {
        _bpm = _bpm / _counter;
        print(_bpm);
        setState(() {
          this._bpm = ((1 - _alpha) * this._bpm + _alpha * _bpm).toInt();
        });
      }
      await Future.delayed(Duration(
          milliseconds:
              1000 * _windowLen ~/ _fs)); // wait for a new set of _data values
    }

//run for only 1 minute.
//     int runFor60Seconds = 0;
//     int currentSeconds = DateTime.now().second, endedWithSeconds;
//
//     debugPrint((runFor60Seconds+60).toString() + "-----------------------------------------------------------");
//     while (_toggled) {// while (_toggled && runFor60Seconds < runFor60Seconds+59) {
//
//       if(runFor60Seconds < 60)
//         {
//           break;
//         }
//       _values = List.from(_data); // create a copy of the current data array
//       _avg = 0;
//       _n = _values.length;
//       _m = 0;
//       for (var value in _values) {
//         _avg += value.value / _n;
//         if (value.value > _m) _m = value.value;
//       }
//       _threshold = (_m + _avg) / 2;
//       _bpm = 0;
//       _counter = 0;
//       _previous = 0;
//       for (int i = 1; i < _n; i++) {
//         if (_values[i - 1].value < _threshold &&
//             _values[i].value > _threshold) {
//           if (_previous != 0) {
//             _counter++;
//             _bpm += 60 *
//                 1000 /
//                 (_values[i].time.millisecondsSinceEpoch - _previous);
//           }
//           _previous = _values[i].time.millisecondsSinceEpoch;
//         }
//       }
//       if (_counter > 0) {
//         _bpm = _bpm / _counter;
//         print(_bpm);
//         setState(() {
//           this._bpm = ((1 - _alpha) * this._bpm + _alpha * _bpm).toInt();
//         });
//       }
//       await Future.delayed(Duration(
//           milliseconds:
//               1000 * _windowLen ~/ _fs)); // wait for a new set of _data values
//       endedWithSeconds = DateTime.now().second;
//       int diffSeconds = (currentSeconds - endedWithSeconds);
//       if(diffSeconds < 0)
//         diffSeconds = diffSeconds*-1;
//
//       runFor60Seconds = runFor60Seconds + diffSeconds;
//       //debugPrint(DateTime.now().second.toString() + "-----------------------------------------------------------");
//     }
//
  }
}
