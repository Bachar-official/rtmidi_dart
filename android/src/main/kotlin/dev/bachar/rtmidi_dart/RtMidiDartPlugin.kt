package dev.bachar.rtmidi_dart

import android.content.Context
import android.media.midi.*
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RtMidiDartPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var midiManager: MidiManager? = null

    // deviceId → MidiDevice / Ports
    private val openedDevices = mutableMapOf<String, MidiDevice>()
    private val inputPorts = mutableMapOf<String, MidiInputPort>()    // Для отправки сообщений на устройство
    private val outputPorts = mutableMapOf<String, MidiOutputPort>()  // Для получения сообщений с устройства

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        midiManager = context.getSystemService(Context.MIDI_SERVICE) as MidiManager

        methodChannel = MethodChannel(binding.binaryMessenger, "rtmidi_dart")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "rtmidi_dart/stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        closeAllDevices()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDevices" -> result.success(getDevices())
            "openDevice" -> openDevice(call.argument("deviceId")!!, result)
            "sendMessage" -> {
                val map = call.arguments as Map<*, *>
                val deviceId = map["deviceId"] as String
                val msg = (map["message"] as List<*>).map { (it as Number).toByte() }.toByteArray()
                sendMessage(deviceId, msg, result)
            }
            "closeDevice" -> closeDevice(call.argument("deviceId")!!, result)
            else -> result.notImplemented()
        }
    }

    private fun getDevices(): List<Map<String, Any>> {
        return midiManager?.devices?.map { info ->
            mapOf(
                "id" to info.id.toString(),
                "name" to (info.properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown"),
                "manufacturer" to (info.properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER) ?: ""),
                "type" to when (info.type) {
                    MidiDeviceInfo.TYPE_USB -> "usb"
                    MidiDeviceInfo.TYPE_BLUETOOTH -> "ble"
                    else -> "other"
                },
                "hasInput" to (info.inputPortCount > 0),
                "hasOutput" to (info.outputPortCount > 0)
            )
        } ?: emptyList()
    }

    private fun openDevice(deviceId: String, result: MethodChannel.Result) {
        val info = midiManager?.devices?.find { it.id.toString() == deviceId }
            ?: return result.error("NOT_FOUND", "Device not found", null)

        midiManager?.openDevice(info, { device ->
            if (device == null) return@openDevice result.error("OPEN_FAILED", "Cannot open device", null)

            openedDevices[deviceId] = device

            // InputPort — для отправки данных на устройство
            if (info.inputPortCount > 0) {
                val inputPort: MidiInputPort? = device.openInputPort(0)
                if (inputPort != null) {
                    inputPorts[deviceId] = inputPort
                }
            }

            // OutputPort — для получения данных с устройства
            if (info.outputPortCount > 0) {
                val outputPort: MidiOutputPort? = device.openOutputPort(0)
                if (outputPort != null) {
                    outputPorts[deviceId] = outputPort

                    // MidiReceiver для EventChannel
                    val receiver = object : MidiReceiver() {
                        override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
                            if (msg == null || count == 0) return
                            val message = msg.copyOfRange(offset, offset + count).map { it.toInt() and 0xFF }
                            handler.post {
                                eventSink?.success(mapOf(
                                    "deviceId" to deviceId,
                                    "message" to message
                                ))
                            }
                        }
                    }

                    // Подключаем receiver через outputPort
                    outputPort.connect(receiver)
                }
            }

            result.success(true)
        }, handler)
    }

    private fun sendMessage(deviceId: String, data: ByteArray, result: MethodChannel.Result) {
        val inputPort: MidiInputPort? = inputPorts[deviceId]
        if (inputPort != null) {
            inputPort.send(data, 0, data.size)
            result.success(true)
        } else {
            result.error("NOT_OPEN", "Device not opened", null)
        }
    }

    private fun closeDevice(deviceId: String, result: MethodChannel.Result) {
        inputPorts.remove(deviceId)?.close()
        outputPorts.remove(deviceId)?.close()
        openedDevices.remove(deviceId)?.close()
        result.success(true)
    }

    private fun closeAllDevices() {
        inputPorts.values.forEach { it.close() }
        outputPorts.values.forEach { it.close() }
        openedDevices.values.forEach { it.close() }
        inputPorts.clear()
        outputPorts.clear()
        openedDevices.clear()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
