import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../repositories/order_repository.dart';

sealed class RoadRouteState {}

final class RoadRouteInitial extends RoadRouteState {}

final class RoadRouteLoaded extends RoadRouteState {
  /// Origin this route was requested from, so a slow response for an older
  /// rider position can be told apart from the latest one.
  final LatLng from;
  final List<LatLng>? points;
  RoadRouteLoaded(this.from, this.points);
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

  Future<void> fetchRoute(LatLng from, LatLng to) async {
    final points = await _repository.getRoadRoute(from, to);
    if (!isClosed) emit(RoadRouteLoaded(from, points));
  }
}
