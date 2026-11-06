import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Singleton that tracks device network connectivity and broadcasts changes.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _statusController = StreamController<bool>.broadcast();

  Stream<bool> get statusStream => _statusController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  /// Checks the initial connectivity state and starts listening for changes.
  Future<void> initialize() async {
    // Idempotent — a second call would otherwise leak the first subscription.
    if (_subscription != null) return;

    // Check initial connectivity
    await _checkConnectivity();

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _handleConnectivityChange(result);
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _handleConnectivityChange(result);
  }

  /// Re-queries the platform for the current connectivity state and returns it.
  ///
  /// Backs the no-internet screen's Retry button: platform change events are
  /// occasionally missed (or arrive before any listener is attached), so an
  /// explicit poll is the only way for the user to recover without toggling
  /// their radio. Emits on [statusStream] only if the state actually changed,
  /// so calling it while still offline is a cheap no-op for listeners.
  Future<bool> recheck() async {
    await _checkConnectivity();
    return _isConnected;
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

  /// Cancels the connectivity subscription and closes the status stream.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _statusController.close();
  }
}
