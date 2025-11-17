import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'bindings.dart';

class MidiDevice {
  final String name;
  final int portIndex;
  final RtMidiFFI _bindings;

  Pointer<RtMidiWrapper>? _inPtr;
  Pointer<RtMidiWrapper>? _outPtr;
  StreamController<List<int>>? _controller;
  Timer? _pollTimer;

  MidiDevice({
    required this.name,
    required this.portIndex,
    required RtMidiFFI bindings,
  }) : _bindings = bindings;

  void open() {
    // Create per-device instances
    _inPtr = _bindings.rtmidi_in_create_default();
    _outPtr = _bindings.rtmidi_out_create_default();

    final portNameUtf8 = 'dart_rtmidi_$name'.toNativeUtf8();

    // Open ports with index
    _bindings.rtmidi_open_port(_inPtr!, portIndex, portNameUtf8.cast<Char>());
    _bindings.rtmidi_open_port(_outPtr!, portIndex, portNameUtf8.cast<Char>());
    malloc.free(portNameUtf8);

    // Ignore types
    _bindings.rtmidi_in_ignore_types(_inPtr!, false, false, false);

    // Setup stream
    _controller = StreamController<List<int>>.broadcast();

    // Start polling (5ms for low-latency)
    _startPolling();

    // Error check after open()
    if (!_inPtr!.ref.ok) {
      final errMsg = _inPtr!.ref.msg.cast<Utf8>().toDartString();
      print('Error opening device $name: $errMsg');
      close();  // Авто-close на ошибку
      return;
    }

    print('Opened MIDI device: $name on port $portIndex');
  }

  void _startPolling() {
    const interval = Duration(milliseconds: 5);  // 5ms ~200Hz
    _pollTimer = Timer.periodic(interval, (_) {
      final sizePtr = calloc<Size>()..value = 1024;  // Max MIDI msg ~1024 (sysex)
      final buf = calloc<UnsignedChar>(1024);
      _bindings.rtmidi_in_get_message(_inPtr!, buf, sizePtr);
      final size = sizePtr.value;
      if (size > 0) {
        final data = buf.cast<Uint8>().asTypedList(size).toList();
        _controller!.add(data);
      }
      calloc.free(buf);
      calloc.free(sizePtr);
    });
  }

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
  }

  void send(List<int> message) {
    if (_outPtr == null) throw StateError('Device not open');
    final msgPtr = calloc<UnsignedChar>(message.length);
    for (var i = 0; i < message.length; i++) {
      msgPtr[i] = (message[i] & 0xFF).toUnsigned(8);
    }
    final result = _bindings.rtmidi_out_send_message(_outPtr!, msgPtr, message.length);
    if (result < 0) print('Send error: $result');
    malloc.free(msgPtr);
  }

  Stream<List<int>> get messages {
    if (_controller == null) throw StateError('Device not open');
    return _controller!.stream;
  }
}