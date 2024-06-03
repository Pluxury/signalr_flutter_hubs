import 'dart:async';
import 'package:flutter/services.dart';
import 'package:signalr_flutter/signalr_plugin.dart';

//Joe's CHANGES
/// Transport method of the signalr connection.
enum Transport { Auto, ServerSentEvents, LongPolling }

/// A .Net SignalR Client for Flutter.
class SignalR {
  final String baseUrl;
  final String? queryString;
  final String hubName;

  /// [Transport.Auto] is default.
  final Transport transport;
  final Map<String, String>? headers;

  /// List of Hub method names you want to subscribe. Every subsequent message from server gets called on [hubCallback].
  final List<String>? hubMethods;

  /// This callback gets called whenever SignalR connection status with server changes.
  final Function(dynamic)? statusChangeCallback;

  /// This callback gets called whenever SignalR server sends some message to client.
  final Function(String?, dynamic)? hubCallback;

  final String connectionId;

  SignalR(this.connectionId, this.baseUrl, this.hubName,
      {this.queryString,
      this.headers,
      this.hubMethods,
      this.transport = Transport.Auto,
      this.statusChangeCallback,
      this.hubCallback})
      : assert(baseUrl != ''),
        assert(hubName != '');

  /// Connect to the SignalR Server with given [baseUrl] & [hubName].
  ///
  /// [queryString] is a optional field to send query to server.
  Future<bool?> connect() async {
    try {
      final result = await SignalrPlugin.channel.invokeMethod<bool>("connectToServer", <String, dynamic>{
        'Id': connectionId,
        'baseUrl': baseUrl,
        'hubName': hubName,
        'queryString': queryString ?? "",
        'headers': headers ?? {},
        'hubMethods': hubMethods ?? [],
        'transport': transport.index
      });

      SignalrPlugin.addHubCallback(hubName, hubCallback);
      SignalrPlugin.addStatusChangeCallback(hubName, statusChangeCallback);

      SignalrPlugin.listenHubMessage();

      return result;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Try to Reconnect SignalR connection if it gets disconnected.
  void reconnect() async {
    try {
      await SignalrPlugin.channel.invokeMethod("reconnect", <String, dynamic>{'Id': connectionId});
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Stop SignalR connection
  void stop() async {
    try {
      await SignalrPlugin.channel.invokeMethod("stop", <String, dynamic>{'Id': connectionId});
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  Future<bool?> get isConnected async {
    try {
      return await SignalrPlugin.channel.invokeMethod<bool>("isConnected", <String, dynamic>{'Id': connectionId});
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  @Deprecated(
      "This method no longer works on iOS. For now it may work on Android but this will be removed later. Consider using constructor parameter [hubMethods]")

  /// Subscribe to a Hub method. Every subsequent message from server gets called on [hubCallback].
  void subscribeToHubMethod(String methodName) async {
    try {
      await SignalrPlugin.channel
          .invokeMethod("listenToHubMethod", <String, dynamic>{'Id': connectionId, 'methodName': methodName});
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Invoke any server method with optional [arguments].
  Future<T?> invokeMethod<T>(String methodName, {List<dynamic>? arguments}) async {
    try {
      final result = await SignalrPlugin.channel.invokeMethod<T>("invokeServerMethod",
          <String, dynamic>{'Id': connectionId, 'methodName': methodName, 'arguments': arguments ?? List.empty()});
      return result;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }
}
