import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'mqtt_service.dart';

class GPSService {
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastPublishedTime;

  Future<void> start(MQTTService mqtt) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location Service Disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location Permission Denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location Permission Permanently Denied");
    }

    // Clean up any stale streams before starting a new one
    await stop();

    // Stream native hardware ticks
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, 
      ),
    ).listen(
      (Position position) {
        final currentTime = DateTime.now();

        // Strict 2-second update window check
        if (_lastPublishedTime == null || 
            currentTime.difference(_lastPublishedTime!).inSeconds >= 2) {
          
          _lastPublishedTime = currentTime;

          mqtt.publish(
            "scooter/gps",
            {
              "lat": position.latitude,
              "lng": position.longitude,
            },
          );

          print("GPS Sent: ${position.latitude}, ${position.longitude}");
        }
      },
      onError: (error) {
        print("GPS Stream Error: $error");
      },
    );
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPublishedTime = null;
    print("GPS Stream Stopped");
  }
}