import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';


class MySensors extends StatefulWidget {
  const MySensors({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MySensors> createState() => _MySensorsState();
}

class _MySensorsState extends State<MySensors> {
  List<double>? _accelerometerValues;
  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  double lastX = 0, lastZ = 0;

  bool hasGotShaking = false;

  @override
  Widget build(BuildContext context) {
    final accelerometer = _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope = _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        .toList();
    final magnetometer = _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Example'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(width: 1.0, color: Colors.black38),
              ),
              child: const Text('here was snake'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Accelerometer: $accelerometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('UserAccelerometer: $userAccelerometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Gyroscope: $gyroscope'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Magnetometer: $magnetometer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen(
            (AccelerometerEvent event) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen((GyroscopeEvent event) {
          if (hasGotShaking) {
            return;
          }
          double xm = event.x>0? event.x:-event.x;
          double ym = event.y>0? event.y:-event.y;
          double zm = event.z>0? event.z:-event.z;
          if (xm < 0.2 && ym < 0.2 && zm < 0.2) {
            return;
          }
          print('event gyr x ${event.x.toStringAsFixed(1)} y ${event.y.toStringAsFixed(1)} z ${event.z.toStringAsFixed(1)}');
          double limit = 0.6;
          if ((lastX > limit && event.x < limit*(-1)) || (lastX < limit*(-1) && event.x > limit)
            || (lastZ > limit && event.z < limit*(-1)) || (lastZ < limit*(-1) && event.z > limit)
          ) {
            print('got shaking');
            hasGotShaking = true;
            Future.delayed(const Duration(seconds: 2), (){
              hasGotShaking = false;
            });
          } else {
            if (xm > limit) {
              Future.delayed(const Duration(milliseconds: 500), (){
                lastX = 0;
              });
            }
            if (zm > limit) {
              Future.delayed(const Duration(milliseconds: 500), (){
                lastZ = 0;
              });
            }
          }

          lastX = event.x;
          lastZ = event.z;
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      userAccelerometerEvents.listen(
            (UserAccelerometerEvent event) {
          setState(() {
            _userAccelerometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen(
            (MagnetometerEvent event) {
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        },
      ),
    );
  }
}