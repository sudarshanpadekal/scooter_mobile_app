import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// Explicit relative paths to match your folder structure exactly
import './services/mqtt_service.dart';
import './services/gps_service.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal, 
          brightness: Brightness.dark
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final mqtt = MQTTService();
  final gps = GPSService();

  late final TextEditingController ipController;
  final TextEditingController destinationController = TextEditingController();

  // Tracks uploaded file names in the session to execute delete requests easily
  final List<String> _sessionDocuments = [];

  @override
  void initState() {
    super.initState();
    // Initialize controller once to prevent typing refresh glitches
    ipController = TextEditingController(text: "10.120.88.50");

    // Rebuild UI dynamically whenever MQTT connection status flags change
    mqtt.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ipController.dispose();
    destinationController.dispose();
    gps.stop();
    mqtt.dispose();
    super.dispose();
  }

  Future<void> toggleBrokerConnection() async {
    if (mqtt.isConnected) {
      await gps.stop();
      mqtt.disconnect();
      return;
    }

    try {
      bool success = await mqtt.connect(ipController.text.trim());

      if (success) {
        await gps.start(mqtt);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("MQTT Connected & GPS Streaming")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection Failed: $e")),
      );
    }
  }

  void sendDestination() {
    if (!mqtt.isConnected) return;

    // Matches specification topic: scooter/destination
    mqtt.publish(
      "scooter/destination",
      {"destination": destinationController.text.trim()},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Destination route payload sent")),
    );
  }

  Future<void> uploadDocument() async {
    if (!mqtt.isConnected) return;

    // Filter to accept precisely what your Pi backend expects
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'txt'],
    );

    if (result == null || result.files.single.path == null) return;

    File file = File(result.files.single.path!);
    List<int> bytes = await file.readAsBytes();
    String encoded = base64Encode(bytes);
    String filename = result.files.single.name;

    // Matches specification payload: scooter/docs/upload
    mqtt.publish(
      "scooter/docs/upload",
      {
        "filename": filename,
        "file": encoded,
      },
    );

    setState(() {
      if (!_sessionDocuments.contains(filename)) {
        _sessionDocuments.add(filename);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$filename converted to Base64 and uploaded")),
    );
  }

  void deleteDocument(String filename, int index) {
    if (!mqtt.isConnected) return;

    // Matches specification payload: scooter/docs/delete
    mqtt.publish(
      "scooter/docs/delete",
      {"filename": filename},
    );

    setState(() {
      _sessionDocuments.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Deletion request sent for $filename")),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool connected = mqtt.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scooter Companion Hub"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pi MQTT Broker IP", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(), 
                hintText: "e.g. 10.120.88.50"
              ),
              enabled: !connected,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: toggleBrokerConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: connected ? Colors.redAccent : Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text(connected ? "Disconnect Broker" : "Connect to Pi"),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  connected ? Icons.radar : Icons.gpp_bad, 
                  color: connected ? Colors.greenAccent : Colors.redAccent
                ),
                const SizedBox(width: 8),
                Text(
                  connected ? "Status: Live (GPS streaming every 2s)" : "Status: Disconnected",
                  style: TextStyle(color: connected ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 40),
            const Text("Navigation Target Sync", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                hintText: "Enter destination (e.g. Puttur)", 
                border: OutlineInputBorder()
              ),
              enabled: connected,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: connected ? sendDestination : null,
              icon: const Icon(Icons.send),
              label: const Text("Send Route Destination"),
            ),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Document Sync Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: connected ? uploadDocument : null,
                  icon: const Icon(Icons.file_upload),
                  label: const Text("Upload File"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sessionDocuments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("No files transferred during this session.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessionDocuments.length,
                    itemBuilder: (context, index) {
                      final file = _sessionDocuments[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.file_present, color: Colors.tealAccent),
                          title: Text(file, style: const TextStyle(fontSize: 14)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: connected ? () => deleteDocument(file, index) : null,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}