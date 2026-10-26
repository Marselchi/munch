package com.munchkin.munchkin_companion

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.munchkin.munchkin_companion/network"
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (connectivityManager == null) {
                result.error("UNAVAILABLE", "ConnectivityManager not available", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "bindToPhysicalWifi" -> {
                    try {
                        unbindCurrentNetwork(connectivityManager)

                        val request = NetworkRequest.Builder()
                            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                            .build()

                        val callback = object : ConnectivityManager.NetworkCallback() {
                            override fun onAvailable(network: Network) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    connectivityManager.bindProcessToNetwork(network)
                                } else {
                                    @Suppress("DEPRECATION")
                                    ConnectivityManager.setProcessDefaultNetwork(network)
                                }
                            }

                            override fun onLost(network: Network) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    connectivityManager.bindProcessToNetwork(null)
                                } else {
                                    @Suppress("DEPRECATION")
                                    ConnectivityManager.setProcessDefaultNetwork(null)
                                }
                            }
                        }

                        networkCallback = callback
                        connectivityManager.requestNetwork(request, callback)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "unbindFromNetwork" -> {
                    try {
                        unbindCurrentNetwork(connectivityManager)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "isVpnActive" -> {
                    try {
                        var isVpn = false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val activeNetwork = connectivityManager.activeNetwork
                            val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
                            isVpn = caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
                        }
                        result.success(isVpn)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun unbindCurrentNetwork(connectivityManager: ConnectivityManager) {
        try {
            networkCallback?.let {
                connectivityManager.unregisterNetworkCallback(it)
            }
        } catch (_: Exception) {}
        networkCallback = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.bindProcessToNetwork(null)
        } else {
            @Suppress("DEPRECATION")
            ConnectivityManager.setProcessDefaultNetwork(null)
        }
    }

    override fun onDestroy() {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        connectivityManager?.let { unbindCurrentNetwork(it) }
        super.onDestroy()
    }
}
