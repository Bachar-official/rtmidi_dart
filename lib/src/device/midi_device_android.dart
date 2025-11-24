// lib/src/device/midi_device_android.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'midi_device.dart';

class MidiDeviceAndroid implements MidiDevice {
  @override
  final String name;
  @override
  final bool hasInput;
  @override
  final bool hasOutput;
  final String id;

  // Статические каналы — одни на все экземпляры
  static const MethodChannel methodChannel = MethodChannel('rtmidi_dart');
  static const EventChannel eventChannel = EventChannel('rtmidi_dart/stream');

  // Один стрим на все устройства
  static final Stream<Map<String, dynamic>> _rawEvents = eventChannel
      .receiveBroadcastStream()
      .cast<Map<String, dynamic>>();

  MidiDeviceAndroid({
    required this.id,
    required this.name,
    required this.hasInput,
    required this.hasOutput,
  });

  @override
  Future<void> open() => methodChannel.invokeMethod('openDevice', id);

  @override
  Future<void> close() => methodChannel.invokeMethod('closeDevice', id);

  @override
  void send(List<int> message) {
    methodChannel.invokeMethod('sendMessage', {
      'deviceId': id,
      'message': message,
    });
  }

  @override
  Stream<List<int>> get messages => _rawEvents
      .where((event) => event['deviceId'] == id)
      .map((event) => List<int>.from(event['message'] as List));
}