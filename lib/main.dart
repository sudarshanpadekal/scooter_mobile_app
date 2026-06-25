import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import 'services/mqtt_service.dart';
import 'services/gps_service.dart';

void main() {
  runApp(const ScooterApp());
}

class ScooterApp extends StatelessWidget {
  const ScooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scooter Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {

  final mqtt = MQTTService();

  final gps = GPSService();

  final TextEditingController
      destinationController =
      TextEditingController();

  bool connected = false;

  String brokerIp =
      "10.120.88.50";

  @override
  void initState() {
    super.initState();
  }

  Future<void> connectBroker() async {
    try {
      await mqtt.connect(
        brokerIp,
      );

      gps.start(
        mqtt,
      );

      setState(() {
        connected = true;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("MQTT Connected"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Connection Failed: $e",
          ),
        ),
      );
    }
  }

  void sendDestination() {
    if (!connected) return;

    mqtt.publish(
      "scooter/navigation",
      {
        "destination":
            destinationController.text
      },
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Destination Sent",
        ),
      ),
    );
  }

  Future<void> uploadDocument() async {

  if (!connected) {
    return;
  }

  FilePickerResult? result =
      await FilePicker.platform
          .pickFiles();

  if (result == null) {
    return;
  }

  File file = File(
    result.files.single.path!,
  );

  List<int> bytes =
      await file.readAsBytes();

  String encoded =
      base64Encode(bytes);

  mqtt.publish(
    "scooter/docs/upload",
    {
      "filename":
          result.files.single.name,

      "file":
          encoded,
    },
  );

  if (!mounted) return;

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content: Text(
        "${result.files.single.name} uploaded",
      ),
    ),
  );
}

  @override
  Widget build(
      BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scooter Companion",
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            const Text(
              "Pi MQTT Broker IP",
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            TextField(
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
              ),
              controller:
                  TextEditingController(
                text: brokerIp,
              ),
              onChanged: (value) {
                brokerIp = value;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            ElevatedButton(
              onPressed:
                  connectBroker,
              child: Text(
                connected
                    ? "Connected"
                    : "Connect",
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            Text(
              connected
                  ? "Status: Connected"
                  : "Status: Disconnected",
              style: TextStyle(
                color: connected
                    ? Colors.green
                    : Colors.red,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            const Text(
              "Destination",
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            TextField(
              controller:
                  destinationController,
              decoration:
                  const InputDecoration(
                hintText:
                    "Enter destination",
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            ElevatedButton(
              onPressed:
                  sendDestination,
              child: const Text(
                "Send Route",
              ),
            ),

            const SizedBox(
              height: 30,
            ),
            const SizedBox(
  height: 20,
),

ElevatedButton(
  onPressed:
      uploadDocument,
  child: const Text(
    "Upload Document",
  ),
),
            const Text(
              "GPS is automatically published every 2 seconds after connection.",
            ),
          ],
        ),
      ),
    );
  }
}