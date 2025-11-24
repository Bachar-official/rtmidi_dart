import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'midi_device.dart';

class RtMidi {
  final RtMidiFFI _bindings;

  RtMidi() : _bindings = RtMidiFFI(_loadLibrary());

  static DynamicLibrary _loadLibrary() {
    final libraryName = Platform.isWindows ? 'rtmidi' : 'librtmidi.so';

    try {
      return DynamicLibrary.open(libraryName);
    } catch (e) {
      throw StateError(
        'Unable to load RtMidi library ($libraryName).\n'
        'Please make sure flutter pub get executed.\n'
        'Error: $e',
      );
    }
  }

  RtMidiFFI get bindings => _bindings;

  Future<List<MidiDevice>> get devices async {
  final inPtr = _bindings.rtmidi_in_create_default();
  final outPtr = _bindings.rtmidi_out_create_default();

  final bool hasIn = inPtr.address != 0;
  final bool hasOut = outPtr.address != 0;

  if (!hasIn && !hasOut) {
    return <MidiDevice>[];
  }

  final int inCount = hasIn ? _bindings.rtmidi_get_port_count(inPtr) : 0;
  final int outCount = hasOut ? _bindings.rtmidi_get_port_count(outPtr) : 0;

  final Map<String, MidiDeviceInfo> grouped = {};

  if (hasIn) {
    for (int i = 0; i < inCount; i++) {
      final rawName = _getPortName(inPtr, i);
      if (rawName.isEmpty) continue;
      final normalized = _normalizeDeviceName(rawName);
      final info = grouped.putIfAbsent(normalized, () => MidiDeviceInfo(name: rawName));
      info.inputPort = i;
      info.inputPtr = inPtr; // Save for freeing later
    }
  }

  if (hasOut) {
    for (int i = 0; i < outCount; i++) {
      final rawName = _getPortName(outPtr, i);
      if (rawName.isEmpty) continue;
      final normalized = _normalizeDeviceName(rawName);
      final info = grouped.putIfAbsent(normalized, () => MidiDeviceInfo(name: rawName));
      info.outputPort = i;
      info.outputPtr = outPtr;
    }
  }

  // Free parent pointers
  if (hasIn) _bindings.rtmidi_in_free(inPtr);
  if (hasOut) _bindings.rtmidi_out_free(outPtr);

  return grouped.values
      .where((info) => info.hasInput || info.hasOutput)
      .map((info) => MidiDevice.fromInfo(info, _bindings))
      .toList();
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

  String _normalizeDeviceName(String name) {
    return name
        .replaceAll(RegExp(r'\s*(IN|OUT|\d+|:.*|Port \d+|\s+\d+)$'), '')
        .replaceAll(RegExp(r'\s+-\s+.*'), '')
        .replaceAll(RegExp(r'\s+\(.*\)$'),
            '') // Example: "Launchpad Pro (Port 1)" → "Launchpad Pro"
        .trim();
  }
}
