import Flutter
import UIKit

public class SwiftSignalRFlutterPlugin: NSObject, FlutterPlugin {

    static var channel: FlutterMethodChannel!
    private var signalRInstances: [String: SignalRWrapper] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "signalR", binaryMessenger: registrar.messenger())
        let instance = SwiftSignalRFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let id = args["Id"] as? String else {
            result(FlutterError(code: "Invalid Argument", message: "The 'Id' parameter is missing", details: nil))
            return
        }

        var instance: SignalRWrapper
        if let existingInstance = signalRInstances[id] {
            instance = existingInstance
        } else {
            instance = SignalRWrapper()
            signalRInstances[id] = instance
        }

        switch call.method {
        case CallMethod.connectToServer.rawValue:
            instance.connectToServer(arguments: args, result: result)

        case CallMethod.reconnect.rawValue:
            instance.reconnect(result: result)

        case CallMethod.stop.rawValue:
            instance.stop(result: result)
            signalRInstances[id] = nil

        case CallMethod.isConnected.rawValue:
            instance.isConnected(result: result)

        case CallMethod.listenToHubMethod.rawValue:
            if let methodName = args["methodName"] as? String {
                instance.listenToHubMethod(methodName: methodName, result: result)
            }

        case CallMethod.invokeServerMethod.rawValue:
            instance.invokeServerMethod(arguments: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
