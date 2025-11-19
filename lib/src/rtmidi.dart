import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:code_assets/code_assets.dart';

import 'bindings.dart';
import 'midi_device.dart';

class RtMidi {
  final RtMidiFFI _bindings;

  RtMidi() : _bindings = RtMidiFFI(_loadLibrary());

  static DynamicLibrary _loadLibrary() {
    // Универсальное имя — Dart/Flutter сам подставит расширение и префикс
    // Работает на всех платформах без if/else
    final libraryName = Platform.isWindows || Platform.isAndroid ? 'rtmidi' : 'librtmidi';
    
    try {
      return DynamicLibrary.open(libraryName);
    } catch (e) {
      throw StateError(
        'Не удалось загрузить RtMidi библиотеку ($libraryName).\n'
        'Убедитесь, что flutter pub get выполнен, и нативная библиотека собрана.\n'
        'Ошибка: $e',
      );
    }
  }

  RtMidiFFI get bindings => _bindings;

  Future<List<MidiDevice>> get devices async {
    final inPtr = _bindings.rtmidi_in_create_default();
    final outPtr = _bindings.rtmidi_out_create_default();

    final inCount = _bindings.rtmidi_get_port_count(inPtr);
    final outCount = _bindings.rtmidi_get_port_count(outPtr);

    // Карта: нормализованное имя → MidiDeviceInfo
    final Map<String, MidiDeviceInfo> grouped = {};

    // Собираем все входы
    for (var i = 0; i < inCount; i++) {
      final rawName = _getPortName(inPtr, i);
      if (rawName.isEmpty) continue;

      final normalized = _normalizeDeviceName(rawName);
      final info =
          grouped.putIfAbsent(normalized, () => MidiDeviceInfo(name: rawName));
      info.inputPort = i;
    }

    // Собираем все выходы
    for (var i = 0; i < outCount; i++) {
      final rawName = _getPortName(outPtr, i);
      if (rawName.isEmpty) continue;

      final normalized = _normalizeDeviceName(rawName);
      final info =
          grouped.putIfAbsent(normalized, () => MidiDeviceInfo(name: rawName));
      info.outputPort = i;
    }

    _bindings.rtmidi_in_free(inPtr);
    _bindings.rtmidi_out_free(outPtr);

    // Возвращаем только устройства с хотя бы одним портом
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
            '') // "Launchpad Pro (Port 1)" → "Launchpad Pro"
        .trim();
  }
}
