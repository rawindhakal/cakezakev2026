import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/connectivity_service.dart';

// ── States ──────────────────────────────────────────────────────────────────
/// Base state for [ConnectivityCubit].
abstract class ConnectivityState {}

/// Emitted when the device has network connectivity.
class ConnectivityConnected extends ConnectivityState {}

/// Emitted when the device has no network connectivity.
class ConnectivityDisconnected extends ConnectivityState {}

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Exposes the device's live network connectivity state as a stream of cubit states.
class ConnectivityCubit extends Cubit<ConnectivityState> {
  final ConnectivityService _connectivityService;
  late StreamSubscription _subscription;

  ConnectivityCubit({ConnectivityService? service})
    : this._(service ?? ConnectivityService());

  /// Seeds the state from the service's already-known status instead of
  /// starting in a neutral state. [ConnectivityService.statusStream] is a
  /// broadcast stream that only fires on *change*, and the service is
  /// initialized in `main()` before this cubit exists — so on a cold start
  /// with no network the "went offline" event is emitted with no listener
  /// attached and lost, leaving the UI convinced it was online.
  ConnectivityCubit._(ConnectivityService service)
    : _connectivityService = service,
      super(
        service.isConnected
            ? ConnectivityConnected()
            : ConnectivityDisconnected(),
      ) {
    _initialize();
  }

  void _initialize() {
    _subscription = _connectivityService.statusStream.listen((isConnected) {
      if (isConnected) {
        emit(ConnectivityConnected());
      } else {
        emit(ConnectivityDisconnected());
      }
    });
  }

  bool get isConnected => _connectivityService.isConnected;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
