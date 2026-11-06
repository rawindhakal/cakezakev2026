import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import '../models/address_model.dart';
import '../repositories/address_repository.dart';

class AddressCubit extends BasePaginationCubit<AddressData> {
  final AddressRepository _repository;

  AddressCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository();

  @override
  PaginationFetcher<AddressData> get fetcher => (offset) async {
    final result = await _repository.getAddresses(offset: offset);
    return PaginatedResponse<AddressData>(
      data: result.data ?? [],
      total: int.tryParse(result.total ?? '0') ?? 0,
    );
  };

  /// Insert a newly added address locally — avoids a refetch.
  void addLocally(AddressData address) {
    final current = state;
    if (current is! PaginationLoaded<AddressData>) return;
    final list = _applyDefault(current.data, address);
    emit(current.copyWith(data: [address, ...list], total: current.total + 1));
  }

  /// Replace an edited address locally — avoids a refetch.
  void updateLocally(AddressData address) {
    final current = state;
    if (current is! PaginationLoaded<AddressData>) return;
    final list = _applyDefault(
      current.data,
      address,
    ).map((a) => a.id == address.id ? address : a).toList();
    emit(current.copyWith(data: list));
  }

  /// Remove an address locally — avoids a refetch.
  void removeLocally(String id) {
    final current = state;
    if (current is! PaginationLoaded<AddressData>) return;
    final list = current.data.where((a) => a.id != id).toList();
    emit(
      current.copyWith(
        data: list,
        total: (current.total - 1).clamp(0, current.total),
      ),
    );
  }

  /// If [saved] is the new default, clear the flag on every other address.
  List<AddressData> _applyDefault(List<AddressData> list, AddressData saved) {
    if (saved.isDefault != '1') return list;
    return list
        .map((a) => a.id == saved.id ? a : (a..isDefault = '0'))
        .toList();
  }
}
