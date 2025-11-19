// lib/src/midi_device.dart
import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// Одно физическое MIDI-устройство (может иметь вход, выход или оба)
class MidiDevice {
  final String name;
  final int? inputPort;
  final int? outputPort;

  final RtMidiFFI _bindings;

  Pointer<RtMidiWrapper>? _inPtr;
  Pointer<RtMidiWrapper>? _outPtr;

  StreamController<List<int>>? _controller;
  Timer? _pollTimer;

  bool get hasInput => inputPort != null;
  bool get hasOutput => outputPort != null;
  bool get isOpen => _inPtr != null || _outPtr != null;

  MidiDevice._({
    required this.name,
    required this.inputPort,
    required this.outputPort,
    required RtMidiFFI bindings,
  }) : _bindings = bindings;

  /// Создаёт устройство из собранной информации
  factory MidiDevice.fromInfo(MidiDeviceInfo info, RtMidiFFI bindings) {
    return MidiDevice._(
      name: info.name,
      inputPort: info.inputPort,
      outputPort: info.outputPort,
      bindings: bindings,
    );
  }

  /// Открывает нужные порты (вход и/или выход)
  void open() {
    if (!hasInput && !hasOutput) {
      throw StateError('Устройство $name не имеет ни входа, ни выхода');
    }

    if (hasInput && _inPtr == null) {
      _inPtr = _bindings.rtmidi_in_create_default();
      final clientName = 'rtmidi_dart_in_$name'.toNativeUtf8();
      _bindings.rtmidi_open_port(
        _inPtr!,
        inputPort!,
        clientName.cast<Char>(),
      );
      malloc.free(clientName);

      // Игнорируем только SysEx, Timing и Active Sensing — всё остальное оставляем
      _bindings.rtmidi_in_ignore_types(_inPtr!, false, false, false);

      _startPolling();
    }

    if (hasOutput && _outPtr == null) {
      _outPtr = _bindings.rtmidi_out_create_default();
      final clientName = 'rtmidi_dart_out_$name'.toNativeUtf8();
      _bindings.rtmidi_open_port(
        _outPtr!,
        outputPort!,
        clientName.cast<Char>(),
      );
      malloc.free(clientName);
    }

    print(
        'MIDI устройство открыто: $name  →  IN: $inputPort  OUT: $outputPort');
  }

  void _startPolling() {
    _controller = StreamController<List<int>>.broadcast();

    // ОЧИЩАЕМ БУФЕР СРАЗУ ПОСЛЕ ОТКРЫТИЯ ПОРТА
    // Это решает проблему "первое нажатие игнорируется"
    () async {
      await Future.delayed(Duration.zero); // даём порту открыться
      final sizePtr = calloc<Size>()..value = 1024;
      final buffer = calloc<UnsignedChar>(1024);
      while (_bindings.rtmidi_in_get_message(_inPtr!, buffer, sizePtr) > 0) {
        // просто вычитываем всё старое и выбрасываем
      }
      calloc.free(buffer);
      calloc.free(sizePtr);
    }();

    const pollInterval = Duration(milliseconds: 2);

    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_inPtr == null) return;

      final sizePtr = calloc<Size>()..value = 1024;
      final buffer = calloc<UnsignedChar>(1024);

      while (true) {
        final read = _bindings.rtmidi_in_get_message(_inPtr!, buffer, sizePtr);
        final size = sizePtr.value;

        if (read <= 0 || size <= 0) break;

        final message = buffer.cast<Uint8>().asTypedList(size).toList();
        _controller!.add(message);
      }

      calloc.free(buffer);
      calloc.free(sizePtr);
    });
  }

  /// Отправить сырое MIDI-сообщение
  void send(List<int> message) {
    if (_outPtr == null) {
      throw StateError('Выходной порт не открыт для устройства $name');
    }

    final ptr = calloc<UnsignedChar>(message.length);
    for (var i = 0; i < message.length; i++) {
      ptr[i] = message[i] & 0xFF;
    }

    final result =
        _bindings.rtmidi_out_send_message(_outPtr!, ptr, message.length);
    calloc.free(ptr);

    if (result != 0) {
      print('Ошибка отправки MIDI на $name: $result');
    }
  }

  /// Поток входящих MIDI-сообщений (только если открыт вход)
  Stream<List<int>> get messages {
    if (_controller == null) {
      throw StateError('Входной порт не открыт для устройства $name');
    }
    return _controller!.stream;
  }

  /// Закрыть всё
  void close() {
    _pollTimer?.cancel();
    _pollTimer = null;

    if (_inPtr != null) {
      _bindings.rtmidi_close_port(_inPtr!);
      _bindings.rtmidi_in_free(_inPtr!);
      _inPtr = null;
    }
    if (_outPtr != null) {
      _bindings.rtmidi_close_port(_outPtr!);
      _bindings.rtmidi_out_free(_outPtr!);
      _outPtr = null;
    }

    _controller?.close();
    _controller = null;

    print('MIDI устройство закрыто: $name');
  }

  @override
  String toString() => 'MidiDevice("$name", in: $inputPort, out: $outputPort)';
}

/// Вспомогательный класс для группировки портов по имени
class MidiDeviceInfo {
  final String name;
  int? inputPort;
  int? outputPort;

  MidiDeviceInfo({required this.name});

  bool get hasInput => inputPort != null;
  bool get hasOutput => outputPort != null;
}
