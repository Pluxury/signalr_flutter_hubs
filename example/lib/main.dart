import 'package:flutter/material.dart';
import 'dart:async';
import 'package:signalr_flutter/signalr_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _signalRStatus = 'Unknown';
  late SignalR signalR;
  final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // signalR = SignalR(
    //     '<Your server url here>',
    //     "<Your hub name here>",
    //     hubMethods: ["<Your Hub Method Names>"],
    //     statusChangeCallback: _onStatusChange,
    //     hubCallback: _onNewMessage);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SignalR Plugin Example App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Connection Status: $_signalRStatus\n', style: Theme.of(context).textTheme.bodyLarge),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(onPressed: _buttonTapped, child: Text("Invoke Method")),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.cast_connected),
          onPressed: () async {
            final isConnected = await signalR.isConnected ?? false;
            if (!isConnected) {
              await signalR.connect();
            } else {
              signalR.stop();
            }
          },
        ),
      ),
    );
  }

  _onStatusChange(dynamic status) {
    if (mounted) {
      setState(() {
        _signalRStatus = status as String;
      });
    }
  }

  _onNewMessage(String? methodName, dynamic message) {
    print('MethodName = $methodName, Message = $message');
  }

  _buttonTapped() async {
    final res = await signalR.invokeMethod<dynamic>("GetMessages", arguments: [186833, 0, 50]).catchError((error) {
      print(error.toString());
    });
    final snackBar = SnackBar(content: Text('SignalR Method Response: $res'));
    rootScaffoldMessengerKey.currentState!.showSnackBar(snackBar);
  }
}
