package dev.bachar.rtmidi_dart

import android.content.Context
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * USB/NATIVE MIDI plugin based on core of FlutterMidiCommand (without BLE).
 *
 * Methods:
 *  - getDevices()
 *  - openDevice(deviceId)
 *  - sendMessage({deviceId, message})
 *  - closeDevice(deviceId)
 *
 * Events:
 *  - device MIDI messages → EventChannel "rtmidi_dart/stream"
 */
class RtMidiDartPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private lateinit var context: Context
    private lateinit var handler: Handler

    private var midiManager: MidiManager? = null

    private var eventSink: EventChannel.EventSink? = null

    // Active connected devices
    private val connectedDevices = mutableMapOf<String, ConnectedDevice>()

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        handler = Handler(Looper.getMainLooper())
        midiManager = context.getSystemService(Context.MIDI_SERVICE) as MidiManager

        methodChannel = MethodChannel(binding.binaryMessenger, "rtmidi_dart")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "rtmidi_dart/stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        teardown()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ================================
    // MethodChannel handler
    // ================================
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "getDevices" -> {
                result.success(listDevices())
            }

            "openDevice" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId == null) {
                    result.error("INVALID_ARG", "deviceId required", null)
                    return
                }
                openDevice(deviceId, result)
            }

            "sendMessage" -> {
                val map = call.arguments as? Map<*, *> ?: run {
                    result.error("INVALID_ARG", "Map required", null)
                    return
                }

                val deviceId = map["deviceId"] as? String
                val message = map["message"] as? List<*>

                if (deviceId == null || message == null) {
                    result.error("INVALID_ARG", "deviceId and message required", null)
                    return
                }

                val byteArray = message.map { (it as Number).toInt().toByte() }.toByteArray()

                sendToDevice(deviceId, byteArray, result)
            }

            "closeDevice" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId == null) {
                    result.error("INVALID_ARG", "deviceId required", null)
                    return
                }
                closeDevice(deviceId, result)
            }

            else -> result.notImplemented()
        }
    }

    // ================================
    // Device listing
    // ================================
    private fun listDevices(): List<Map<String, Any>> {
        val mm = midiManager ?: return emptyList()
        val devices = mm.devices
        val list = mutableListOf<Map<String, Any>>()

        for (info in devices) {
            val id = Device.deviceIdForInfo(info)
            val name = info.properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown"
            val manufacturer = info.properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER) ?: ""

            list.add(
                mapOf(
                    "id" to id,
                    "name" to name,
                    "manufacturer" to manufacturer,
                    "hasInput" to (info.inputPortCount > 0),
                    "hasOutput" to (info.outputPortCount > 0),
                    "type" to "native"
                )
            )
        }
        return list
    }

    // ================================
    // Device open/close
    // ================================
    private fun openDevice(deviceId: String, result: MethodChannel.Result) {
        val info = midiManager?.devices?.find { Device.deviceIdForInfo(it) == deviceId }
        if (info == null) {
            result.error("NOT_FOUND", "Device not found: $deviceId", null)
            return
        }

        midiManager?.openDevice(info, { device: MidiDevice? ->
            if (device == null) {
                result.error("OPEN_FAILED", "Failed to open device", null)
                return@openDevice
            }

            val rxHandler = object : FMCStreamHandler(handler) {
                override fun onDataReceived(data: ByteArray) {
                    handler.post {
                        eventSink?.success(
                            mapOf(
                                "deviceId" to deviceId,
                                "message" to data.map { it.toInt() and 0xFF }
                            )
                        )
                    }
                }
            }

            val cd = ConnectedDevice(device, rxHandler)
            connectedDevices[deviceId] = cd

            cd.connect()

            result.success(true)

        }, handler)
    }

    private fun sendToDevice(deviceId: String, data: ByteArray, result: MethodChannel.Result) {
        val dev = connectedDevices[deviceId]
        if (dev == null) {
            result.error("NOT_OPEN", "Device not opened", null)
            return
        }
        try {
            dev.send(data, null)
            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_FAILED", e.message, null)
        }
    }

    private fun closeDevice(deviceId: String, result: MethodChannel.Result) {
        connectedDevices[deviceId]?.close()
        connectedDevices.remove(deviceId)
        result.success(true)
    }

    private fun teardown() {
        connectedDevices.values.forEach { it.close() }
        connectedDevices.clear()
    }
}
