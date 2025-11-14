import 'midi_device.dart';

class MidiMessage {
  final MidiDevice device;
  final List<int> data;
  final int timestamp;

  MidiMessage({required this.device, required this.data, required this.timestamp});
}