import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'bindings.dart';

class MidiDevice {
  final String name;
  final Pointer<RtMidiWrapper> _inPtr;
  final Pointer<RtMidiWrapper> _outPtr;
  final RtMidiFFI _bindings;

  StreamController<List<int>>? _controller;
  Timer? _pollTimer;

  MidiDevice({
    required this.name,
    required Pointer<RtMidiWrapper> inPtr,
    required Pointer<RtMidiWrapper> outPtr,
    required RtMidiFFI bindings,
  })  : _inPtr = inPtr,
        _outPtr = outPtr,
        _bindings = bindings;

  void open() {
    final portNameUtf8 = 'dart_rtmidi'.toNativeUtf8();
    _bindings.rtmidi_open_port(_inPtr, 0, portNameUtf8.cast<Char>());
    _bindings.rtmidi_open_port(_outPtr, 0, portNameUtf8.cast<Char>());
    calloc.free(portNameUtf8);

    _controller = StreamController<List<int>>.broadcast();
    _startPolling();
  }

  void close() {
    _pollTimer?.cancel();
    _controller?.close();
    _bindings.rtmidi_close_port(_inPtr);
    _bindings.rtmidi_close_port(_outPtr);
  }

  void send(List<int> message) {
    final msgPtr = calloc<UnsignedChar>(message.length);
    for (var i = 0; i < message.length; i++) msgPtr[i] = message[i] & 0xFF;
    _bindings.rtmidi_out_send_message(_outPtr.cast(), msgPtr, message.length);
    calloc.free(msgPtr);
  }

  Stream<List<int>> get messages => _controller!.stream;

  void _startPolling() {
    const interval = Duration(milliseconds: 1);
    _pollTimer = Timer.periodic(interval, (_) {
      final sizePtr = calloc<Size>()..value = 1024;
      final buf = calloc<UnsignedChar>(1024);
      _bindings.rtmidi_in_get_message(_inPtr.cast(), buf, sizePtr);
      final size = sizePtr.value;
      if (size > 0) {
        final data = buf.cast<Uint8>().asTypedList(size).toList();
        _controller?.add(data);
      }
      calloc.free(buf);
      calloc.free(sizePtr);
    });
  }
}
