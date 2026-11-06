import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_category_model.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/widgets/category_filter_bar.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockBlogCubit blogCubit;
  late MockBlogCategoryCubit categoryCubit;

  BlogCategory category(String id, String name) =>
      BlogCategory.fromJson({'id': id, 'name': name});

  setUp(() {
    blogCubit = MockBlogCubit();
    categoryCubit = MockBlogCategoryCubit();
    when(() => blogCubit.filterByCategory(any())).thenAnswer((_) async {});
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpBar(
    WidgetTester tester, {
    required BlogCategoryState categoryState,
    String? selectedId,
  }) async {
    when(() => blogCubit.currentFilters).thenReturn(selectedId);
    whenListen(
      blogCubit,
      const Stream<PaginationState<Blog>>.empty(),
      initialState: const PaginationLoading<Blog>(),
    );
    whenListen(
      categoryCubit,
      const Stream<BlogCategoryState>.empty(),
      initialState: categoryState,
    );

    await tester.pumpWidget(
      pumpTestWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<BlogCubit>.value(value: blogCubit),
            BlocProvider<BlogCategoryCubit>.value(value: categoryCubit),
          ],
          child: const CategoryFilterBar(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing while categories have not loaded yet', (
    tester,
  ) async {
    printTestDivider('renders nothing while categories have not loaded yet');
    await pumpBar(tester, categoryState: BlogCategoryInitial());

    printTestLog('"All" chip → expected: not found');
    expect(find.text(LanguageLabelKeys.filterAll), findsNothing);
  });

  testWidgets('renders nothing when loaded but the category list is empty', (
    tester,
  ) async {
    printTestDivider(
      'renders nothing when loaded but the category list is empty',
    );
    await pumpBar(tester, categoryState: BlogCategoryLoaded([]));

    printTestLog('"All" chip → expected: not found');
    expect(find.text(LanguageLabelKeys.filterAll), findsNothing);
  });

  testWidgets('renders an "All" chip plus one chip per category once loaded', (
    tester,
  ) async {
    printTestDivider(
      'renders an "All" chip plus one chip per category once loaded',
    );
    await pumpBar(
      tester,
      categoryState: BlogCategoryLoaded([
        category('1', 'Delivery'),
        category('2', 'Groceries'),
      ]),
    );

    printTestLog('"All" chip → expected: visible');
    expect(find.text(LanguageLabelKeys.filterAll), findsOneWidget);
    printTestLog('"Delivery" chip → expected: visible');
    expect(find.text('Delivery'), findsOneWidget);
    printTestLog('"Groceries" chip → expected: visible');
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('tapping "All" calls filterByCategory(null)', (tester) async {
    printTestDivider('tapping "All" calls filterByCategory(null)');
    await pumpBar(
      tester,
      categoryState: BlogCategoryLoaded([category('1', 'Delivery')]),
      selectedId: '1',
    );

    await tester.tap(find.text(LanguageLabelKeys.filterAll));
    await tester.pump();

    verify(() => blogCubit.filterByCategory(null)).called(1);
    printTestLog('filterByCategory(null) → verified');
  });

  testWidgets('tapping a category chip calls filterByCategory(cat.id)', (
    tester,
  ) async {
    printTestDivider('tapping a category chip calls filterByCategory(cat.id)');
    await pumpBar(
      tester,
      categoryState: BlogCategoryLoaded([category('1', 'Delivery')]),
    );

    await tester.tap(find.text('Delivery'));
    await tester.pump();

    verify(() => blogCubit.filterByCategory('1')).called(1);
    printTestLog('filterByCategory("1") → verified');
  });
}
