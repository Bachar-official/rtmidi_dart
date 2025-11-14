import 'package:rtmidi_dart/rtmidi_dart.dart';

void main() async {
  // Initialize library
  final midi = RtMidi();

  // Get devices
  final List<MidiDevice> devices = await midi.devices;

  // Get first device and open it
  final firstDevice = devices.first..open();

  // Send message to device
  firstDevice.send([144, 25, 90]);

  // Listen for messages
  firstDevice.messages.listen((data) => print(data));

  // Close device
  firstDevice.close();
}
