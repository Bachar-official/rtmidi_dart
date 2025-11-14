import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'midi_device.dart';

class RtMidi {
  final RtMidiFFI _bindings;

  RtMidi() : _bindings = RtMidiFFI(_loadLibrary());

  static DynamicLibrary _loadLibrary() {
    if (Platform.isLinux || Platform.isAndroid) return DynamicLibrary.open('librtmidi.so');
    if (Platform.isWindows) return DynamicLibrary.open('rtmidi.dll');
    if (Platform.isMacOS || Platform.isIOS) return DynamicLibrary.open('librtmidi.dylib');
    throw UnsupportedError('Platform not supported');
  }

  RtMidiFFI get bindings => _bindings;

  Future<List<MidiDevice>> get devices async {
    final inPtr = _bindings.rtmidi_in_create_default();
    final outPtr = _bindings.rtmidi_out_create_default();
    final count = _bindings.rtmidi_get_port_count(inPtr);

    final devices = <MidiDevice>[];
    for (var i = 0; i < count; i++) {
      final name = _getPortName(inPtr, i);
      if (name.isNotEmpty) {
        devices.add(MidiDevice(
          name: name,
          inPtr: inPtr,
          outPtr: outPtr,
          bindings: _bindings,
        ));
      }
    }
    return devices;
  }

  String _getPortName(Pointer<RtMidiWrapper> device, int port) {
    final lenPtr = calloc<Int>();
    _bindings.rtmidi_get_port_name(device, port, nullptr, lenPtr);
    final len = lenPtr.value;
    calloc.free(lenPtr);
    if (len <= 1) return '';

    final buf = calloc<Char>(len);
    final lenPtr2 = calloc<Int>()..value = len;
    _bindings.rtmidi_get_port_name(device, port, buf, lenPtr2);
    final name = buf.cast<Utf8>().toDartString(length: len - 1);
    calloc.free(buf);
    calloc.free(lenPtr2);
    return name;
  }
}
