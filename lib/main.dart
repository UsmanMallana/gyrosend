import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
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
  String _statusMessage = '';

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    final ip = _controller.text.trim();
    if (ip.isEmpty || InternetAddress.tryParse(ip) == null) {
      return _showError('Please enter a valid IP address');
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to ws://$ip:8765...';
    });

    try {
      final uri = Uri.parse('ws://$ip:8765');
      // Use dart:io WebSocket for a Future-based connect
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 5));
      final channel = IOWebSocketChannel(socket);

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Connected! Navigating...';
      });
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => SensorStreamScreen(channel: channel),
        ),
      );
    } on TimeoutException {
      await _showError('Connection timed out. Please check the IP and try again.');
    } on SocketException catch (e) {
      await _showError('Socket error: ${e.message}');
    } catch (e) {
      await _showError('Connection failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Connect to Server'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoTextField(
                controller: _controller,
                placeholder: 'Server IP (e.g., 192.168.0.107)',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 20),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                ),
              const SizedBox(height: 20),
              _isConnecting
                  ? const CupertinoActivityIndicator()
                  : CupertinoButton.filled(
                      onPressed: _connect,
                      child: const Text('Connect and Stream Data'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class SensorStreamScreen extends StatefulWidget {
  final WebSocketChannel channel;
  const SensorStreamScreen({Key? key, required this.channel}) : super(key: key);

  @override
  _SensorStreamScreenState createState() => _SensorStreamScreenState();
}

class _SensorStreamScreenState extends State<SensorStreamScreen> {
  late final StreamSubscription _accelSub;
  late final StreamSubscription _gyroSub;
  String _connectionStatus = 'Connecting...';
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  @override
  void initState() {
    super.initState();
    widget.channel.stream.listen(
      (msg) => setState(() => _connectionStatus = 'Server: $msg'),
      onDone: () => setState(() => _connectionStatus = 'Disconnected'),
      onError: (e) => setState(() => _connectionStatus = 'Error: $e'),
    );

    _accelSub = accelerometerEvents.listen((e) {
      widget.channel.sink.add('A,${e.x},${e.y},${e.z}');
      setState(() { _ax = e.x; _ay = e.y; _az = e.z; });
    });
    _gyroSub = gyroscopeEvents.listen((e) {
      widget.channel.sink.add('G,${e.x},${e.y},${e.z}');
      setState(() { _gx = e.x; _gy = e.y; _gz = e.z; });
    });
  }

  void _disconnect() {
    _accelSub.cancel();
    _gyroSub.cancel();
    widget.channel.sink.close();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sensor Stream'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _disconnect,
          child: const Text('Disconnect'),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_connectionStatus', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              const Text('Accelerometer:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  x: ${_ax.toStringAsFixed(2)}'),
              Text('  y: ${_ay.toStringAsFixed(2)}'),
              Text('  z: ${_az.toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              const Text('Gyroscope:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  x: ${_gx.toStringAsFixed(2)}'),
              Text('  y: ${_gy.toStringAsFixed(2)}'),
              Text('  z: ${_gz.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accelSub.cancel();
    _gyroSub.cancel();
    super.dispose();
  }
}
