import 'package:rtmidi_dart/rtmidi_dart.dart';

void main() async {
  // Initialize library and get devices
  final devices = await RtMidi.devices;

  // Get devices 
  devices.forEach(print);

  // Get first device and open it
  final firstDevice = devices.first..open();

  // Send message to device
  // firstDevice.send([144, 25, 90]);

  // Listen for messages
  firstDevice.messages.listen((data) => firstDevice.send(data));

  // Close device
  // firstDevice.close();
}
