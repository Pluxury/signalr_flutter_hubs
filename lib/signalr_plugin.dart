import 'package:flutter/services.dart';

class SignalrPlugin {
  static const MethodChannel channel = const MethodChannel('signalR');

  static const String CONNECTION_STATUS = "ConnectionStatus";
  static const String NEW_MESSAGE = "NewMessage";

  static final hubCallbacks = <String, Function(String?, dynamic)?>{};

  static final statusChangeCallbacks = <String, Function(dynamic)?>{};

  static void addHubCallback(String hubName, Function(String?, dynamic)? hubCallback) {
    hubCallbacks[hubName] = hubCallback;
  }

  static void addStatusChangeCallback(String hubName, Function(dynamic)? statusChangeCallback) {
    statusChangeCallbacks[hubName] = statusChangeCallback;
  }

  static void listenHubMessage() {
    channel.setMethodCallHandler((call) {
      switch (call.method) {
        case CONNECTION_STATUS:
          if (call.arguments is List) {
            final hubName = call.arguments[0] as String;
            statusChangeCallbacks[hubName]!(call.arguments[1]);
          }
          break;
        case NEW_MESSAGE:
          if (call.arguments is List) {
            final hubName = call.arguments[0] as String;
            hubCallbacks[hubName]!(call.arguments[1], call.arguments[2]);
          }
          break;
        default:
      }
      return Future.value();
    });
  }
}
