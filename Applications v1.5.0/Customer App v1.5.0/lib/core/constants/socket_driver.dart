/// Broadcast driver reported by the settings API's `broadcast_driver` field,
/// shared by every websocket service (chat, maintenance mode, ...).
enum SocketDriver {
  pusher('pusher'),
  reverb('reverb');

  const SocketDriver(this.value);

  final String value;

  /// [driver] should already be lowercased/trimmed by the caller.
  static SocketDriver? fromValue(String? driver) {
    for (final socketDriver in SocketDriver.values) {
      if (socketDriver.value == driver) return socketDriver;
    }
    return null;
  }
}
