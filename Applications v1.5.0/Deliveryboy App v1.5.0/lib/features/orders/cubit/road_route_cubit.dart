import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../repositories/order_repository.dart';

sealed class RoadRouteState {}

final class RoadRouteInitial extends RoadRouteState {}

final class RoadRouteLoaded extends RoadRouteState {
  final List<LatLng>? points;
  RoadRouteLoaded(this.points);
}

/// Fetches a road-snapped polyline between two points via OSRM, through
/// [OrderRepository]. Emits null points on failure so callers fall back to
/// a direct line — this is a decorative route overlay, not critical data,
/// so there's no separate error state to react to.
class RoadRouteCubit extends Cubit<RoadRouteState> {
  final OrderRepository _repository;

  RoadRouteCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(RoadRouteInitial());

  /// Bumped per request so a slow, older response can't overwrite the
  /// route fetched for a newer location.
  int _requestId = 0;

  Future<void> fetchRoute(LatLng from, LatLng to) async {
    final requestId = ++_requestId;
    final points = await _repository.getRoadRoute(from, to);
    if (isClosed || requestId != _requestId) return;
    emit(RoadRouteLoaded(points));
  }
}
