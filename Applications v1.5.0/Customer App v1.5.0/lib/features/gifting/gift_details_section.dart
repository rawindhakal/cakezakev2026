import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/features/gifting/gift_store.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Recipient, delivery date/slot, card message and personalisation, kept in
/// [GiftStore.fields] and sent with the order.
class GiftDetailsSection extends StatefulWidget {
  const GiftDetailsSection({super.key});

  @override
  State<GiftDetailsSection> createState() => _GiftDetailsSectionState();
}

class _GiftDetailsSectionState extends State<GiftDetailsSection> {
  final _store = GiftStore.instance;
  List<Map<String, dynamic>> _slotList = const [];
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_rebuild);
    _store.loadMeta();
    _store.loadSchedule();
    final d = _store.fields['delivery_date'];
    if (d != null) _loadSlots(d);
  }

  @override
  void dispose() {
    _store.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => mounted ? setState(() {}) : null;

  Widget _text(String key, String label,
      {TextInputType? type, int lines = 1, int? max}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: _store.fields[key],
        keyboardType: type,
        minLines: lines,
        maxLines: lines,
        maxLength: max,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), counterText: ''),
        onChanged: (v) => _store.setField(key, v.trim()),
      ),
    );
  }

  Widget _drop(String key, String label, List<(String, String)> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: items.any((e) => e.$1 == _store.fields[key]) ? _store.fields[key] : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [for (final i in items) DropdownMenuItem(value: i.$1, child: Text(i.$2))],
        onChanged: (v) => setState(() => _store.setField(key, v ?? '')),
      ),
    );
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadSlots(String date) async {
    setState(() => _loadingSlots = true);
    final list = await _store.slotsFor(date);
    if (!mounted) return;
    setState(() {
      _slotList = list;
      _loadingSlots = false;
    });
  }

  Future<void> _pickDate() async {
    final cfg = _store.schedule;
    final now = DateTime.now();
    final first = DateTime.tryParse('${cfg?['min_date']}') ?? now;
    final last = DateTime.tryParse('${cfg?['max_date']}') ?? now.add(const Duration(days: 60));
    final closed = ((cfg?['closed_dates'] as List?) ?? const []).map((e) => '$e').toSet();
    final d = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (day) => !closed.contains(_iso(day)),
      helpText: 'Choose delivery date',
    );
    if (d != null) {
      setState(() {
        _store.setField('delivery_date', _iso(d));
        _store.setField('delivery_slot_id', '');
      });
      _loadSlots(_iso(d));
    }
  }

  void _pickType(String? slug) {
    setState(() {
      _store.setField('gift_delivery_type', slug ?? '');
      _store.setField('delivery_slot_id', '');
      if (slug == 'express') {
        final today = '${_store.schedule?['today'] ?? _iso(DateTime.now())}';
        _store.setField('delivery_date', today);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dt = _store.fields['gift_delivery_type'];
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('🎁 Gift details',
              style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _text('recipient_name', 'Recipient name'),
          _text('recipient_phone', 'Recipient phone', type: TextInputType.phone),
          _drop('recipient_relationship', 'Your relationship',
              [for (final r in _store.relationships) (r.name, r.name)]),
          _drop('occasion', 'Occasion', [for (final o in _store.occasions) (o.name, o.name)]),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: context.cs.primary.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('When should it arrive? *', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _store.fields['gift_delivery_type']?.isNotEmpty == true ? _store.fields['gift_delivery_type'] : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Delivery type', border: OutlineInputBorder()),
                  items: [
                    for (final d in _store.deliveryTypes.where((d) => d.slug != 'standard'))
                      DropdownMenuItem(
                        value: d.slug,
                        child: Text('${d.name}${d.timeWindow != null ? ' (${d.timeWindow})' : ''}${d.extraCharge > 0 ? ' +Rs ${d.extraCharge.toStringAsFixed(0)}' : ''}'),
                      ),
                  ],
                  onChanged: _pickType,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: dt == 'express' ? null : _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(_store.fields['delivery_date'] ?? 'Choose delivery date'),
                ),
                if (dt == 'express')
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Express orders arrive today, so no time slot is needed.', style: TextStyle(fontSize: 12)),
                  ),
                if (dt == 'midnight' && _store.fields['delivery_date'] != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Delivered at midnight on the chosen date.', style: TextStyle(fontSize: 12)),
                  ),
                if (dt != 'express' && dt != 'midnight' && _store.fields['delivery_date'] != null) ...[
                  const SizedBox(height: 10),
                  const Text('Time slot', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (_loadingSlots)
                    const Text('Checking availability…')
                  else if (_slotList.isEmpty)
                    const Text('No time slots are available on this date.', style: TextStyle(color: Colors.red))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sl in _slotList)
                          ChoiceChip(
                            label: Text(
                              '${sl['label']}  ${sl['available'] == true ? ((sl['extra_charge'] ?? 0) > 0 ? '+Rs ${sl['extra_charge']}' : '') : '(${sl['unavailable_reason'] == 'full' ? 'Full' : sl['unavailable_reason'] == 'too_late' ? 'Too soon' : 'Closed'})'}',
                            ),
                            selected: _store.fields['delivery_slot_id'] == '${sl['id']}',
                            onSelected: sl['available'] == true
                                ? (_) => setState(() => _store.setField('delivery_slot_id', '${sl['id']}'))
                                : null,
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
          _text('sender_name', 'From (sender name)'),
          _text('personalization', 'Name / text to print on the gift', max: 500),
          _text('gift_message', 'Message on the card', lines: 3, max: 500),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Keep it a surprise (don't reveal sender or price)"),
            value: _store.fields['is_surprise'] == '1',
            onChanged: (v) => setState(() => _store.setField('is_surprise', v ? '1' : '')),
          ),
        ],
      ),
    );
  }
}
