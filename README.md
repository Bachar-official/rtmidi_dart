<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->
# rtmidi_dart

A Dart/Flutter package for working with MIDI devices using [RtMidi](https://github.com/thestk/rtmidi).  
It allows you to interact with input and output devices in a unified way, making it easy to send and receive MIDI messages.

## Features

- Unified `MidiDevice` representing both input and output of a MIDI device.  
- Simple API for sending and receiving MIDI messages.  
- Cross-platform support: Linux, ~~Windows~~, ~~macOS~~, ~~Android~~, ~~iOS~~ (via FFI and RtMidi).  
- Stream-based API for receiving MIDI messages asynchronously.  
- Low-latency polling for real-time MIDI interaction.  

## Getting started

### Prerequisites

- Install the RtMidi library on your system:
  - **Linux**: `sudo apt install librtmidi-dev`

## Usage

Basic getting devices and receive MIDI messages

```dart
import 'package:rtmidi_dart/rtmidi_dart.dart';

void main() async {
  // Initialize library
  final midi = RtMidi();

  // Get devices
  final List<MidiDevice> devices = await midi.devices;

  // Get first device and open it
  final firstDevice = devices.first..open();

  // Listen for messages
  firstDevice.messages.listen((data) => print(data));

  // Close device
  firstDevice.close();
}
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
