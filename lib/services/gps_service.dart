import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'mqtt_service.dart';

class GPSService {
  Timer? timer;

  Future<void> start(
    MQTTService mqtt,
  ) async {

    bool serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        "Location Service Disabled",
      );
    }

    LocationPermission permission =
        await Geolocator
            .checkPermission();

    if (permission ==
        LocationPermission.denied) {

      permission =
          await Geolocator
              .requestPermission();

      if (permission ==
          LocationPermission.denied) {
        throw Exception(
          "Location Permission Denied",
        );
      }
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        "Location Permission Permanently Denied",
      );
    }

    timer = Timer.periodic(
      const Duration(
        seconds: 2,
      ),
      (_) async {

        try {

          Position position =
              await Geolocator
                  .getCurrentPosition(
            desiredAccuracy:
                LocationAccuracy.best,
          );

          mqtt.publish(
            "scooter/gps",
            {
              "lat":
                  position.latitude,
              "lng":
                  position.longitude,
            },
          );

          print(
            "GPS Sent: "
            "${position.latitude}, "
            "${position.longitude}",
          );

        } catch (e) {

          print(
            "GPS Error: $e",
          );

        }
      },
    );
  }

  void stop() {
    timer?.cancel();
  }
}