import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: IpInputScreen(),
    );
  }
}

// Screen for user to input the server IP address
class IpInputScreen extends StatefulWidget {
  const IpInputScreen({super.key});

  @override
  _IpInputScreenState createState() => _IpInputScreenState();
}

class _IpInputScreenState extends State<IpInputScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Server'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter Server IP Address',
                hintText: 'e.g., 192.168.1.10',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SensorStreamScreen(ipAddress: _controller.text),
                    ),
                  );
                }
              },
              child: const Text('Connect and Stream Data'),
            ),
          ],
        ),
      ),
    );
  }
}

// Screen to stream sensor data
class SensorStreamScreen extends StatefulWidget {
  final String ipAddress;
  const SensorStreamScreen({super.key, required this.ipAddress});

  @override
  _SensorStreamScreenState createState() => _SensorStreamScreenState();
}

class _SensorStreamScreenState extends State<SensorStreamScreen> {
  late final IOWebSocketChannel channel;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    // Establish WebSocket connection with the user-provided IP
    channel = IOWebSocketChannel.connect('ws://${widget.ipAddress}:8765');

    // Start listening to sensor events and sending data
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      channel.sink.add('A,${event.x},${event.y},${event.z}');
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      channel.sink.add('G,${event.x},${event.y},${event.z}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Stream'),
      ),
      body: const Center(
        child: Text('✅ Streaming sensor data...'),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel the streams and close the connection
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    channel.sink.close();
    super.dispose();
  }
}