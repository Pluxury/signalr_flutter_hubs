//
//  SignalR.swift
//  signalR
//
//  Created by Ayon Das on 23/07/20.
//

import Foundation

enum CallMethod : String {
  case connectToServer, reconnect, stop, isConnected, invokeServerMethod, listenToHubMethod
}
class SignalRWrapper {

    private var hub: Hub!
    private var connection: SignalR!
    
    func connectToServer(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let baseUrl = arguments["baseUrl"] as? String,
              let hubName = arguments["hubName"] as? String else {
            result(FlutterError(code: "Invalid Argument", message: "baseUrl or hubName missing", details: nil))
            return
        }
        
        connection = SignalR(baseUrl)
        
        let queryString = arguments["queryString"] as? String ?? ""
        if !queryString.isEmpty {
            let qs = queryString.components(separatedBy: "=")
            connection.queryString = [qs[0]:qs[1]]
        }
        
        if let transport = arguments["transport"] as? Int {
            switch transport {
            case 1:
                connection.transport = Transport.serverSentEvents
            case 2:
                connection.transport = Transport.longPolling
            default:
                break
            }
        }
        
        if let headers = arguments["headers"] as? [String: String], headers.count > 0 {
            connection.headers = headers
        }
        
        hub = connection.createHubProxy(hubName)
        
        if let hubMethods = arguments["hubMethods"] as? [String] {
            hubMethods.forEach { (methodName) in
                hub.on(methodName) { (args) in
                    SwiftSignalRFlutterPlugin.channel.invokeMethod("NewMessage", arguments: [methodName, args?[0]])
                }
            }
        }
        
        configureConnectionCallbacks()
        
        connection.start()
        result(true)
    }

    func reconnect(result: @escaping FlutterResult) {
        if let connection = self.connection {
            connection.connect()
        } else {
            result(FlutterError(code: "Error", message: "SignalR Connection not found or null", details: "Start SignalR connection first"))
        }
    }

    func stop(result: @escaping FlutterResult) {
        if let connection = self.connection {
            connection.stop()
        } else {
            result(FlutterError(code: "Error", message: "SignalR Connection not found or null", details: "Start SignalR connection first"))
        }
    }

    func isConnected(result: @escaping FlutterResult) {
        if let connection = self.connection {
            switch connection.state {
            case .connected:
                result(true)
            default:
                result(false)
            }
        } else {
            result(false)
        }
    }

    func listenToHubMethod(methodName: String, result: @escaping FlutterResult) {
        if let hub = self.hub {
            hub.on(methodName) { (args) in
//                SwiftSignalRFlutterPlugin.channel.invokeMethod("NewMessage", arguments: [methodName, args?[0]])
                guard let args = args, !args.isEmpty else {
                    SwiftSignalRFlutterPlugin.channel.invokeMethod("NewMessage", arguments: [methodName, "null or empty"])
                    return
                }
                
                let jsonData = try? JSONSerialization.data(withJSONObject: args[0], options: [])
                let jsonString = String(data: jsonData!, encoding: .utf8)
                SwiftSignalRFlutterPlugin.channel.invokeMethod("NewMessage", arguments: [methodName, jsonString ?? ""])
            }
        } else {
            result(FlutterError(code: "Error", message: "SignalR Connection not found or null", details: "Connect SignalR before listening a Hub method"))
        }
    }
    
    func tryToGetJsonData(input: Any?) -> Data? {
        guard let input = input else {
            return nil
        }
  
        if !JSONSerialization.isValidJSONObject(input) {
            return nil
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: input, options: [])
            return jsonData
        } catch {
            return nil
        }
    }

    func invokeServerMethod(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let methodName = arguments["methodName"] as? String else {
            result(FlutterError(code: "Invalid Argument", message: "methodName missing", details: nil))
            return
        }
        
        do {
            if let hub = self.hub {
                try hub.invoke(methodName, arguments: arguments["arguments"] as? [Any], callback: { (res, error) in
                    if let error = error {
                        result(FlutterError(code: "Error", message: String(describing: error), details: nil))
                    } else {
                        let jsonData = self.tryToGetJsonData(input: res)

                        if jsonData == nil {
                            if res != nil {
                                let intResult = res as! Int
                                result(String(intResult))
                            } else {
                                result("")
                            }
                        } else {
                            let jsonString = String(data: jsonData!, encoding: .utf8)
                            result(jsonString ?? "")
                        }
                    }
                })
            } else {
                throw NSError.init(domain: "NullPointerException", code: 0, userInfo: [NSLocalizedDescriptionKey : "Hub is null. Initiate a connection first."])
            }
        } catch {
            result(FlutterError.init(code: "Error", message: error.localizedDescription, details: nil))
        }
    }
    
    private func configureConnectionCallbacks() {
        connection.starting = { [weak self] in
            print("SignalR Connecting. Current Status: \(String(describing: self?.connection.state.stringValue))")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Connecting")
        }

        connection.reconnecting = { [weak self] in
            print("SignalR Reconnecting. Current Status: \(String(describing: self?.connection.state.stringValue))")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Reconnecting")
        }

        connection.connected = { [weak self] in
            print("SignalR Connected. Connection ID: \(String(describing: self?.connection.connectionID))")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Connected")
        }

        connection.reconnected = { [weak self] in
            print("SignalR Reconnected...")
            print("Connection ID: \(String(describing: self?.connection.connectionID))")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Reconnected")
        }

        connection.disconnected = { [weak self] in
            print("SignalR Disconnected...")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Disconnected")
        }

        connection.connectionSlow = {
            print("Connection slow...")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Slow")
        }

        connection.error = { [weak self] error in
            print("Error: \(String(describing: error))")
            SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Error: \(String(describing: error))")
            if let source = error?["source"] as? String, source == "TimeoutException" {
                print("Connection timed out. Restarting...")
                self?.connection.start()
            }
        }
    }
}
