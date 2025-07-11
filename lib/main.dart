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

class IpInputScreen extends StatefulWidget {
  const IpInputScreen({Key? key}) : super(key: key);

  @override
  _IpInputScreenState createState() => _IpInputScreenState();
}

class _IpInputScreenState extends State<IpInputScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isConnecting = false;

  Future<void> _connect() async {
    if (_controller.text.isEmpty) {
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // **Attempt to connect**
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://${_controller.text}:8765'),
        connectTimeout: const Duration(seconds: 5), // Add a timeout
      );

      // **Wait for the connection to be ready**
      await channel.ready;

      // **If successful, navigate to the next screen**
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SensorStreamScreen(channel: channel),
          ),
        );
      }
    } catch (e) {
      // **If connection fails, show an error message**
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // **Reset the loading state**
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

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
                hintText: 'e.g., 192.168.0.107',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _isConnecting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _connect,
                    child: const Text('Connect and Stream Data'),
                  ),
          ],
        ),
      ),
    );
  }
}


class SensorStreamScreen extends StatefulWidget {
  final IOWebSocketChannel channel;
  const SensorStreamScreen({Key? key, required this.channel}) : super(key: key);

  @override
  _SensorStreamScreenState createState() => _SensorStreamScreenState();
}

class _SensorStreamScreenState extends State<SensorStreamScreen> {
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    // Start listening to sensor events and sending data on the provided channel
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      widget.channel.sink.add('A,${event.x},${event.y},${event.z}');
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      widget.channel.sink.add('G,${event.x},${event.y},${event.z}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Stream'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('✅ Connected! Streaming sensor data...'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    widget.channel.sink.close();
    super.dispose();
  }
}