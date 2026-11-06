import 'package:customer/core/api/api_client.dart';
import 'package:flutter/foundation.dart';

/// One option from `GET gifting/meta` (occasion, relationship or delivery type).
class GiftOption {
  final String name;
  final String slug;
  final double extraCharge;
  final String? timeWindow;

  const GiftOption({
    required this.name,
    required this.slug,
    this.extraCharge = 0,
    this.timeWindow,
  });

  factory GiftOption.fromJson(Map<String, dynamic> j) => GiftOption(
    name: '${j['name'] ?? ''}',
    slug: '${j['slug'] ?? ''}',
    extraCharge: double.tryParse('${j['extra_charge'] ?? 0}') ?? 0,
    timeWindow: j['time_window']?.toString(),
  );
}

/// Gifting state shared across screens: the occasion / relationship /
/// delivery-type lookups, the gift details typed at checkout (sent with
/// place_order) and the filter a "shop by occasion" chip applies to the
/// product list while that list is open.
class GiftStore extends ChangeNotifier {
  GiftStore._();
  static final GiftStore instance = GiftStore._();

  List<GiftOption> occasions = const [];
  List<GiftOption> relationships = const [];
  List<GiftOption> deliveryTypes = const [];
  bool _loading = false;

  /// recipient_name, recipient_phone, recipient_relationship, occasion,
  /// delivery_date, delivery_slot, gift_delivery_type, sender_name,
  /// personalization, gift_message, is_surprise — empty values are omitted.
  final Map<String, String> fields = {};

  /// `occasion` / `relationship` / `delivery_type` → slug, applied by
  /// ProductRepository.getProducts while set.
  final Map<String, String> activeFilter = {};

  Future<void> loadMeta() async {
    if (_loading || occasions.isNotEmpty) return;
    _loading = true;
    try {
      final res = await ApiClient().get('gifting/meta');
      final data = (res as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      List<GiftOption> parse(dynamic v) => ((v as List?) ?? const [])
          .map((e) => GiftOption.fromJson(e as Map<String, dynamic>))
          .toList();
      occasions = parse(data?['occasions']);
      relationships = parse(data?['relationships']);
      deliveryTypes = parse(data?['delivery_types']);
      notifyListeners();
    } catch (_) {
      // Gifting extras are optional: the app works without them.
    } finally {
      _loading = false;
    }
  }

  /// Booking window from `GET gifting/schedule`: min_date, max_date, closed_dates, required...
  Map<String, dynamic>? schedule;

  Future<void> loadSchedule() async {
    if (schedule != null) return;
    try {
      final res = await ApiClient().get('gifting/schedule');
      schedule = ((res as Map<String, dynamic>)['data'] as Map<String, dynamic>?);
      notifyListeners();
    } catch (_) {}
  }

  /// Slots for [date] (yyyy-MM-dd) with availability and extra charge.
  Future<List<Map<String, dynamic>>> slotsFor(String date) async {
    try {
      final res = await ApiClient().get('gifting/slots', queryParameters: {'date': date});
      final list = ((res as Map<String, dynamic>)['data'] as List?) ?? const [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  void setField(String key, String value) {
    if (value.isEmpty) {
      fields.remove(key);
    } else {
      fields[key] = value;
    }
  }

  void clearOrder() => fields.clear();
}
