import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late MqttServerClient client;

  Future<void> connect(String brokerIp) async {
    client = MqttServerClient(
      brokerIp,
      'scooter_phone_client',
    );

    client.port = 1883;

    client.keepAlivePeriod = 20;

    client.logging(on: false);

    client.onConnected = () {
      print("MQTT Connected");
    };

    client.onDisconnected = () {
      print("MQTT Disconnected");
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
          'scooter_phone_client',
        )
        .startClean();

    client.connectionMessage =
        connMessage;

    await client.connect();

    if (client.connectionStatus?.state !=
        MqttConnectionState.connected) {
      throw Exception(
        "Unable to connect to MQTT Broker",
      );
    }
  }

  void publish(
    String topic,
    Map<String, dynamic> payload,
  ) {
    final builder =
        MqttClientPayloadBuilder();

    builder.addString(
      jsonEncode(payload),
    );

    client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    client.disconnect();
  }
}