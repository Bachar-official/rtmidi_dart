/// FFI wrapper for RtMidi library
///
library;

import 'dart:io';

import 'package:rtmidi_dart/rtmidi_dart.dart';
import 'package:rtmidi_dart/src/impl/rtmidi_android.dart';
import 'package:rtmidi_dart/src/impl/rtmidi_desktop.dart';
import 'package:rtmidi_dart/src/impl/rtmidi_impl.dart';

export 'src/device/midi_device.dart';

class RtMidi {
  RtMidi._();

  static Future<List<MidiDevice>> get devices => _impl.devices;

  static final RtMidiImpl _impl = Platform.isAndroid
      ? RtMidiAndroid()
      : RtMidiDesktop();
}