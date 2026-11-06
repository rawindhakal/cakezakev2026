import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/connectivity_service.dart';

// ── States ──────────────────────────────────────────────────────────────────
// There is deliberately no `initial` variant: the cubit seeds itself from the
// service's already-known status (see [ConnectivityCubit._seed]), so it is
// connected or disconnected from construction onward — never indeterminate.
sealed class ConnectivityState {}

final class ConnectivityConnected extends ConnectivityState {}

final class ConnectivityDisconnected extends ConnectivityState {}

// ── Cubit ────────────────────────────────────────────────────────────────────
class ConnectivityCubit extends Cubit<ConnectivityState> {
  final ConnectivityService _connectivityService;
  late StreamSubscription _subscription;

  // The service is initialized in main() *before* runApp, so its first status
  // is pushed onto a broadcast stream that has no listeners yet and is lost.
  // Seeding from the service's current value is what makes a cold start in
  // airplane mode actually show the no-internet screen. BlocListener doesn't
  // fire for the seed state, so this adds no extra fetches on a normal launch.
  static ConnectivityState _seed(ConnectivityService service) =>
      service.isConnected
      ? ConnectivityConnected()
      : ConnectivityDisconnected();

  ConnectivityCubit({ConnectivityService? service})
    : _connectivityService = service ?? ConnectivityService(),
      super(_seed(service ?? ConnectivityService())) {
    _initialize();
  }

  /// Re-probes the platform. Safe to call from UI (retry buttons).
  Future<void> recheck() => _connectivityService.recheck();

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
