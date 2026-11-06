import 'dart:async';

/// Collapses rapid repeated calls (e.g. search-field `onChanged`) into a
/// single [action] fired [delay] after the last call.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
