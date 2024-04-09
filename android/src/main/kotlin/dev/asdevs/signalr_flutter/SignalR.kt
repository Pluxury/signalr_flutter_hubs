package dev.asdevs.signalr_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import microsoft.aspnet.signalr.client.*
import microsoft.aspnet.signalr.client.hubs.HubConnection
import microsoft.aspnet.signalr.client.hubs.HubProxy
import microsoft.aspnet.signalr.client.transport.LongPollingTransport
import microsoft.aspnet.signalr.client.transport.ServerSentEventsTransport
import android.util.Log


enum class CallMethod(val value: String) {
    ConnectToServer("connectToServer"),
    Reconnect("reconnect"),
    Stop("stop"),
    IsConnected("isConnected"),
    ListenToHubMethod("listenToHubMethod"),
    InvokeServerMethod("invokeServerMethod")
}

object SignalR {
    private val connections: MutableMap<String, HubConnection> = mutableMapOf()
    private val hubs: MutableMap<String, HubProxy> = mutableMapOf()
    val channels = mutableMapOf<String, MethodChannel>()

    fun connectToServer(id: String, url: String, hubName: String, queryString: String, headers: Map<String, String>, transport: Int, hubMethods: List<String>, result: Result) {

        if(connections.containsKey(id)) {
            result.error("Error", "Connection with this ID already exists.", null)
            return
        }


        try {
            val connection: HubConnection = if (queryString.isEmpty()) {
                HubConnection(url)
            } else {
                HubConnection(url, queryString, true, Logger { _: String, _: LogLevel -> })
            }

            if (headers.isNotEmpty()) {
                val cred = Credentials() { request ->
                    request.headers = headers
                }
                connection?.credentials = cred
            }
            val hub = connection!!.createHubProxy(hubName)!!

            hubMethods.forEach { methodName ->
                hub?.on(methodName, { res ->
                    Handler(Looper.getMainLooper()).post {
                        Log.d("SignalR2", "SignalR2 NewMsg")

                        SignalRFlutterPlugin.channel.invokeMethod("NewMessage", listOf(methodName, res))
                    }
                }, Any::class.java)
            }

            connection?.connected {
                Handler(Looper.getMainLooper()).post {
                    if(connection != null) {
                        Log.d("SignalR2", "SignalR2 Connected")
                        SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", "Connected")
                    }
                }
            }

            connection?.reconnected {
                Handler(Looper.getMainLooper()).post {
                    if(connection != null) {
                        Log.d("SignalR2", "SignalR2 Reconnected")

                        SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", "Reconnected")
                    }
                }
            }

            connection?.reconnecting {
                Handler(Looper.getMainLooper()).post {
                    if(connection != null) {
                        Log.d("SignalR2", "SignalR2 Reconnecting")

                        SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", "Reconnecting")
                    }
                }
            }

            connection?.closed {
                Handler(Looper.getMainLooper()).post {
                    if(connection != null) {
                        Log.d("SignalR2", "SignalR2 Closed")

                        SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", "Disconnected")
                    }
                }
            }

            connection?.connectionSlow {
                Handler(Looper.getMainLooper()).post {
                    Log.d("SignalR2", "SignalR2 Slow")

                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", "Slow")
                }
            }

            connection?.error { handler ->
                Handler(Looper.getMainLooper()).post {
                    Log.d("SignalR2", "SignalR2 Error " + handler.localizedMessage)

                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", "Error: " + handler.localizedMessage)
                }
            }

            when (transport) {
                1 -> connection?.start(ServerSentEventsTransport(connection?.logger))
                2 -> connection?.start(LongPollingTransport(connection?.logger))
                else -> {
                    connection?.start()
                }
            }

            result.success(true)
            connections[id] = connection
            hubs[id] = hub
        } catch (ex: Exception) {
            Log.d("SignalR2", "SignalR2 Error " + ex.localizedMessage)

            result.error("SignalR2 Error", ex.localizedMessage, null)
        }
    }

    fun reconnect(connectionId: String,result: Result) {
        try {
            connections[connectionId]?.start()
        } catch (ex: Exception) {
            result.error(ex.localizedMessage, ex.stackTrace.toString(), null)
        }
    }

    fun stop(id: String, result: Result) {
        try {
            connections[id]?.stop()
            connections.remove(id)
            hubs.remove(id)
        } catch (ex: Exception) {
            result.error(ex.localizedMessage, ex.stackTrace.toString(), null)
        }
    }

    fun isConnected(id: String, result: Result) {
        try {
            val connection = connections[id]
            if (connection != null) {
                when (connection.state) {
                    ConnectionState.Connected -> result.success(true)
                    else -> result.success(false)
                }
            } else {
                result.success(false)
            }
        } catch (ex: Exception) {
            result.error("Error", ex.localizedMessage, null)
        }
    }

    fun listenToHubMethod(connectionId: String, methodName: String, result: Result) {
        try {
            hubs[connectionId]?.on(methodName, { res ->
                println("SignalR3 - " + methodName)
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("NewMessage", listOf(methodName, res))
                }
            }, Any::class.java)
        } catch (ex: Exception) {
            println("SignalR3 ERROR")
            result.error("Error", ex.localizedMessage, null)
        }
    }

    fun invokeServerMethod(connectionId: String, methodName: String, args: List<Any>, result: Result) {
        try {
            val res: SignalRFuture<Any>? = hubs[connectionId]?.invoke(Any::class.java, methodName, *args.toTypedArray())

            res?.done { msg: Any? ->
                Handler(Looper.getMainLooper()).post {
                    result.success(msg)
                }
            }

            res?.onError { throwable ->
                Handler(Looper.getMainLooper()).post {
                    result.error("Error", throwable.localizedMessage, null)
                }
            }
        } catch (ex: Exception) {
            result.error("Error", ex.localizedMessage, null)
        }
    }
}
