import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _statusController = StreamController<bool>.broadcast();

  /// Emits only on *change*. Late subscribers (the cubit is built after
  /// [initialize] has already run) miss the first value, so they must seed
  /// themselves from [isConnected] rather than waiting on this stream.
  Stream<bool> get statusStream => _statusController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  Future<void> initialize() async {
    // Check initial connectivity
    await _checkConnectivity();

    // Guard against a second initialize() leaking the first subscription.
    if (_subscription != null) return;

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _handleConnectivityChange(result);
    });
  }

  /// Re-reads the platform's current connectivity — used by the retry button
  /// on the no-internet screen. Emits on [statusStream] only if the status
  /// actually changed, so a still-offline retry simply leaves the UI as is.
  Future<void> recheck() => _checkConnectivity();

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChange(result);
    } catch (_) {
      // Platform channel can throw on some devices; fail open so a probe
      // error never locks the whole app behind the no-internet screen.
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    // Check if any connection is available
    final isConnected =
        result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet) ||
        result.contains(ConnectivityResult.vpn);

    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _statusController.add(isConnected);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _statusController.close();
  }
}
