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
It provides a unified API for sending and receiving MIDI messages across multiple platforms.

## Features

- Unified MidiDevice representing both input and output ports of a MIDI device.
- Simple API for sending and receiving MIDI messages.
- Cross-platform support: Linux and Windows (via FFI + RtMidi).
- Stream-based asynchronous receiving of MIDI messages.
- Low-latency native backend (RtMidi).
- Automatic native library building using native_toolchain_c.

## Platform Support

| Platform | Status | Backend |
|----------|--------|---------|
| Linux | ✅ Supported | ALSA |
| Windows | ✅ Supported | WinMM |
| macOS | ⚠️ Not tested yet | CoreMIDI |
| Android | ❌ Not supported | - |
| iOS | ❌ Not supported | - |


## Getting started

### Prerequisites

#### Linux

You need to install following packages:

- `libasound2-dev`
- `build-essential`

Optional (only if Flutter reports missing `ld.lld`)

- `clang`
- `lld`

To verify everything works:

```bash
flutter build linux --verbose
```

#### Windows

No additional OS libraries are required.

RtMidi uses the built-in WinMM subsystem.

Make sure you have:
- Microsoft C++ Build Tools
- Windows 10/11 SDK

## Usage

Basic getting devices and receive MIDI messages

```dart
import 'package:rtmidi_dart/rtmidi_dart.dart';

void main() async {
  final midi = RtMidi();

  // Get all devices
  final devices = await midi.devices;

  final device = devices.first..open();

  // Receive messages
  device.messages.listen((msg) {
    print('MIDI message: $msg');
  });

  // Send Note On
  device.send([0x90, 60, 127]);

  // Send Note Off
  device.send([0x80, 60, 0]);
}

```

## Notes

- The plugin builds the RtMidi native library automatically using `native_toolchain_c`.
- Plugin **not tested yet** on MacOS, iOS and Android.
- On Linux, ALSA development headers are mandatory.

## Licence
MIT
