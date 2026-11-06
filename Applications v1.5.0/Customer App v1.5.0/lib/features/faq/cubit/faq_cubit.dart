import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import '../models/faq_model.dart';
import '../repositories/faq_repository.dart';

class FaqCubit extends BasePaginationCubit<FaqData> {
  final FaqRepository _repository;

  FaqCubit({FaqRepository? repository})
    : _repository = repository ?? FaqRepository();

  @override
  PaginationFetcher<FaqData> get fetcher => (offset) async {
    final response = await _repository.getFaqs(offset: offset);
    return PaginatedResponse<FaqData>(
      data: response.data ?? [],
      total: int.tryParse(response.total ?? '0') ?? 0,
    );
  };
}
