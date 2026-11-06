import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/notifications/notification/models/notification_model.dart';
import 'package:customer/features/notifications/notification/repositories/notification_repository.dart';

class NotificationsCubit extends BasePaginationCubit<NotificationModelData> {
  final NotificationRepository _repo;

  NotificationsCubit({NotificationRepository? repository})
    : _repo = repository ?? NotificationRepository();

  @override
  PaginationFetcher<NotificationModelData> get fetcher =>
      (offset) =>
          _repo.getNotifications(offset: offset, limit: AppConfig.pageLimit);

  void loadNotifications() => fetchInitial();
  Future<void> loadMore() => fetchMore();
}
