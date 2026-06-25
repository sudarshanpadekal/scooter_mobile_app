import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService extends ChangeNotifier {
  MqttServerClient? _client;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<bool> connect(String brokerIp) async {
    if (_isConnected) return true;

    // Use the exact client ID specified in your architecture
    _client = MqttServerClient(brokerIp, 'scooter_phone_client');
    _client!.port = 1883;
    _client!.keepAlivePeriod = 20;
    _client!.logging(on: false);

    _client!.onConnected = () {
      _isConnected = true;
      notifyListeners();
      print("MQTT Connected");
    };

    _client!.onDisconnected = () {
      _isConnected = false;
      notifyListeners();
      print("MQTT Disconnected");
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('scooter_phone_client')
        .startClean();

    _client!.connectionMessage = connMessage;

    try {
      // 5-second timeout avoids app hanging if the Pi IP is wrong
      await _client!.connect().timeout(const Duration(seconds: 5));
    } catch (e) {
      print("MQTT Connection Exception: $e");
      disconnect();
      return false;
    }

    if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
      disconnect();
      return false;
    }

    return true;
  }

  void publish(String topic, Map<String, dynamic> payload) {
    if (_client == null || !_isConnected) {
      print("Cannot publish. MQTT client is not connected.");
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));

    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    print("Published to $topic");
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    notifyListeners();
  }
}