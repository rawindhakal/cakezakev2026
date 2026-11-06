import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/home/cubit/dashboard_cubit.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';

import '../../../helpers/mock_dashboard_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockDashboardRepository repository;

  final dashboard = DashboardModel.fromJson(const {
    'status': 1,
    'message': 'Success',
    'data': {
      'profile': {'id': 2, 'name': 'Alex Johnson'},
      'today': {'earnings': 120.5, 'delivered': 4},
    },
  });

  setUp(() => repository = MockDashboardRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  blocTest<DashboardCubit, DashboardState>(
    'emits [Loading, Loaded] with the dashboard on success',
    setUp: () {
      printTestDivider('emits [Loading, Loaded] with the dashboard on success');
      when(
        () => repository.getDashboard(trend: any(named: 'trend')),
      ).thenAnswer((_) async => dashboard);
    },
    build: () => DashboardCubit(repository: repository),
    act: (cubit) => cubit.getDashboard(),
    expect: () => [
      isA<DashboardLoading>(),
      isA<DashboardLoaded>().having(
        (s) => s.data.data?.profile?.name,
        'profile name',
        'Alex Johnson',
      ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'defaults the trend window to the last 7 days',
    setUp: () {
      printTestDivider('defaults the trend window to the last 7 days');
      when(
        () => repository.getDashboard(trend: any(named: 'trend')),
      ).thenAnswer((_) async => dashboard);
    },
    build: () => DashboardCubit(repository: repository),
    act: (cubit) => cubit.getDashboard(),
    verify: (_) => verify(() => repository.getDashboard(trend: '7')).called(1),
  );

  blocTest<DashboardCubit, DashboardState>(
    'forwards an explicit trend window to the repository',
    setUp: () {
      printTestDivider('forwards an explicit trend window to the repository');
      when(
        () => repository.getDashboard(trend: any(named: 'trend')),
      ).thenAnswer((_) async => dashboard);
    },
    build: () => DashboardCubit(repository: repository),
    act: (cubit) => cubit.getDashboard(trend: '12m'),
    verify: (_) => verify(() => repository.getDashboard(trend: '12m')).called(1),
  );

  blocTest<DashboardCubit, DashboardState>(
    'emits [Loading, Error] carrying the API message on failure',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] carrying the API message on failure',
      );
      when(
        () => repository.getDashboard(trend: any(named: 'trend')),
      ).thenThrow(const ApiException(message: 'Dashboard unavailable'));
    },
    build: () => DashboardCubit(repository: repository),
    act: (cubit) => cubit.getDashboard(),
    expect: () => [
      isA<DashboardLoading>(),
      isA<DashboardError>().having(
        (s) => s.message,
        'message',
        'Dashboard unavailable',
      ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'a refresh after an error emits Loading again before the new data',
    setUp: () {
      printTestDivider(
        'a refresh after an error emits Loading again before the new data',
      );
      var firstCall = true;
      when(() => repository.getDashboard(trend: any(named: 'trend'))).thenAnswer((
        _,
      ) async {
        if (firstCall) {
          firstCall = false;
          throw const ApiException(message: 'Dashboard unavailable');
        }
        return dashboard;
      });
    },
    build: () => DashboardCubit(repository: repository),
    act: (cubit) async {
      await cubit.getDashboard();
      await cubit.getDashboard();
    },
    expect: () => [
      isA<DashboardLoading>(),
      isA<DashboardError>(),
      isA<DashboardLoading>(),
      isA<DashboardLoaded>(),
    ],
  );
}
