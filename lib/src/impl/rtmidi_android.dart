import 'package:rtmidi_dart/src/device/midi_device_android.dart';
import 'package:rtmidi_dart/src/device/midi_device.dart';
import 'rtmidi_impl.dart';

class RtMidiAndroid implements RtMidiImpl {
  @override
  Future<List<MidiDevice>> get devices async {
    try {
      final List<dynamic> result = await MidiDeviceAndroid.methodChannel.invokeMethod('getDevices');

      return result.map((e) {
        final map = e as Map;
        return MidiDeviceAndroid(
          id: map['id'] as String,
          name: map['name'] as String? ?? 'Unknown Device',
          hasInput: map['hasInput'] == true,
          hasOutput: map['hasOutput'] == true,
        );
      }).toList();
    } catch (e) {
      print('RtMidiAndroid.get devices error: $e');
      return <MidiDevice>[];
    }
  }
}