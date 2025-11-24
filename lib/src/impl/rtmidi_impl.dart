import 'package:rtmidi_dart/src/device/midi_device.dart';

abstract class RtMidiImpl {
  Future<List<MidiDevice>> get devices;
}