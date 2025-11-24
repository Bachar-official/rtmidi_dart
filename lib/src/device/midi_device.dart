abstract class MidiDevice {
  String get name;
  bool get hasInput;
  bool get hasOutput;

  Future<void> open();
  Future<void> close();
  void send(List<int> message);
  Stream<List<int>> get messages;
}