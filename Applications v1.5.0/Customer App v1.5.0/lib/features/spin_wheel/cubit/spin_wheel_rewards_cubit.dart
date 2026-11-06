import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import 'package:flutter/foundation.dart';
import '../models/spin_reward_filter_type.dart';
import '../models/spin_wheel_model.dart';
import '../repositories/spin_wheel_repository.dart';

class SpinWheelRewardsCubit
    extends FilteredPaginationCubit<SpinReward, SpinRewardFilterType> {
  final SpinWheelRepository _repository;

  /// Summary block from the same `rewards` response — kept outside the
  /// paginated [PaginationState] (which only models the list itself) so
  /// the stats header can rebuild independently of the list.
  final ValueNotifier<SpinRewardsSummary?> summary = ValueNotifier(null);

  SpinWheelRewardsCubit({SpinWheelRepository? repository})
    : _repository = repository ?? SpinWheelRepository(),
      super(SpinRewardFilterType.all);

  @override
  PaginationFetcher<SpinReward> buildFetcher(SpinRewardFilterType filters) {
    return (offset) async {
      final response = await _repository.getRewards(
        offset: offset,
        rewardType: filters.apiValue,
      );
      if (offset == 0) summary.value = response.data?.summary;
      return PaginatedResponse<SpinReward>(
        data: response.data?.rewards ?? [],
        total: response.total ?? 0,
      );
    };
  }

  @override
  Future<void> close() {
    summary.dispose();
    return super.close();
  }
}
