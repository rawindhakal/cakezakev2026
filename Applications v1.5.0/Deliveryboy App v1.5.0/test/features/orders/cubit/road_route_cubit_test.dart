import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/features/orders/cubit/road_route_cubit.dart';

import '../../../helpers/mock_order_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockOrderRepository repository;

  final from = LatLng(23.03, 72.58);
  final to = LatLng(23.04, 72.59);

  setUp(() {
    repository = MockOrderRepository();
    registerFallbackValue(LatLng(0, 0));
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('RoadRouteCubit', () {
    blocTest<RoadRouteCubit, RoadRouteState>(
      'emits [Loaded] with the snapped points on success',
      setUp: () {
        printTestDivider('RoadRouteCubit emits [Loaded] with the snapped points on success');
        when(() => repository.getRoadRoute(any(), any())).thenAnswer(
          (_) async => [from, to],
        );
      },
      build: () => RoadRouteCubit(repository: repository),
      act: (cubit) => cubit.fetchRoute(from, to),
      expect: () => [
        isA<RoadRouteLoaded>().having((s) => s.points, 'points', [from, to]),
      ],
      verify: (_) => verify(() => repository.getRoadRoute(from, to)).called(1),
    );

    blocTest<RoadRouteCubit, RoadRouteState>(
      'emits [Loaded] with null points when the repository returns null '
      '(decorative overlay — falls back to a direct line, no error state)',
      setUp: () {
        printTestDivider('RoadRouteCubit emits [Loaded] with null points on failure');
        when(() => repository.getRoadRoute(any(), any())).thenAnswer((_) async => null);
      },
      build: () => RoadRouteCubit(repository: repository),
      act: (cubit) => cubit.fetchRoute(from, to),
      expect: () => [
        isA<RoadRouteLoaded>().having((s) => s.points, 'points', isNull),
      ],
    );
  });
}
