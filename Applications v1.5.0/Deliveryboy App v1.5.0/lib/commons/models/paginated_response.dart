/// Generic wrapper for any paginated API response.
/// All paginated repositories must return this instead of their own typed model.
class PaginatedResponse<T> {
  final List<T> data;
  final int total;

  /// Optional extra payload carried alongside the list (e.g. summary totals
  /// like cash-in-hand or wallet balance) that don't fit the generic
  /// list/total shape. Defaults to null and is ignored by cubits that don't
  /// need it.
  final Object? meta;

  const PaginatedResponse({required this.data, required this.total, this.meta});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawData = json['data'];
    final data = rawData is List
        ? rawData
              .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
        : <T>[];
    final total = int.tryParse(json['total']?.toString() ?? '0') ?? 0;
    return PaginatedResponse(data: data, total: total);
  }
}
