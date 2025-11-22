// lib/src/midi_device.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

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

      // ВАЖНО: сначала настраиваем игнорирование типов, потом открываем порт
      _bindings.rtmidi_in_ignore_types(_inPtr!, false, false, false);

      _bindings.rtmidi_open_port(
        _inPtr!,
        inputPort!,
        clientName.cast<Char>(),
      );
      malloc.free(clientName);

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

    // Wake-up call (не трогаем — это для некоторых устройств)
    if (hasOutput && Platform.isWindows) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_outPtr == null) return;
        print('Sending wake up call');
        send([240, 0, 32, 41, 2, 16, 11, 0, 247]);
      });
    }
  }

  void _startPolling() {
  _controller = StreamController<List<int>>.broadcast();

  const int bufferCapacity = 1024;
  const int idleThresholdMs = 10;
  const int maxFlushMs = 200;

  // --- Синхронный drain: читаем всё, ориентируясь ТОЛЬКО на sizePtr.value ---
  final sizePtr = calloc<Size>()..value = bufferCapacity;
  final buffer = calloc<UnsignedChar>(bufferCapacity);
  int totalDrained = 0;

  while (true) {
    // NOTE: binding должен возвращать double (timestamp) — но мы на него не опираемся
    _bindings.rtmidi_in_get_message(_inPtr!, buffer, sizePtr);
    final sizeNow = sizePtr.value;
    if (sizeNow <= 0) break;
    totalDrained++;
    // проигнорированные/сброшенные байты
  }

  // --- Активная стабилизация: ждём пока поток "успокоится" ---
  final watch = Stopwatch()..start();
  int lastActivityAt = watch.elapsedMilliseconds;
  int extraDrained = 0;

  while (watch.elapsedMilliseconds < maxFlushMs) {
    _bindings.rtmidi_in_get_message(_inPtr!, buffer, sizePtr);
    final sizeNow = sizePtr.value;
    if (sizeNow > 0) {
      extraDrained++;
      lastActivityAt = watch.elapsedMilliseconds;
      // прочитать сразу все подряд (внутренний цикл)
      while (true) {
        _bindings.rtmidi_in_get_message(_inPtr!, buffer, sizePtr);
        final s2 = sizePtr.value;
        if (s2 <= 0) break;
        extraDrained++;
      }
      continue;
    }

    if (watch.elapsedMilliseconds - lastActivityAt >= idleThresholdMs) {
      break;
    }
    // короткая блокирующая пауза ~1ms — даёт устройству время, но ограничена maxFlushMs
    final target = watch.elapsedMilliseconds + 1;
    while (watch.elapsedMilliseconds < target) {}
  }

  print('rtmidi: drained initial $totalDrained msgs + $extraDrained msgs during stabilization');

  // Освобождаем временные буферы
  calloc.free(buffer);
  calloc.free(sizePtr);
  watch.stop();

  // --- Polling timer: читаем все сообщения, опираясь ТОЛЬКО на sizePtr.value ---
  const pollInterval = Duration(milliseconds: 2);
  _pollTimer = Timer.periodic(pollInterval, (_) {
    if (_inPtr == null) return;

    final szPtr = calloc<Size>()..value = bufferCapacity;
    final buf = calloc<UnsignedChar>(bufferCapacity);

    while (true) {
      _bindings.rtmidi_in_get_message(_inPtr!, buf, szPtr);
      final size = szPtr.value;
      if (size <= 0) break;

      final message = buf.cast<Uint8>().asTypedList(size).toList();
      try {
        _controller?.add(message);
      } catch (e) {
        // на случай, если контроллер уже закрыт
      }
    }

    calloc.free(buf);
    calloc.free(szPtr);
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

  // ← ОБЯЗАТЕЛЬНО ДОБАВЬ ЭТИ ДВА ПОЛЯ
  Pointer<RtMidiWrapper>? inputPtr;
  Pointer<RtMidiWrapper>? outputPtr;

  MidiDeviceInfo({required this.name});

  bool get hasInput => inputPort != null;
  bool get hasOutput => outputPort != null;
}
