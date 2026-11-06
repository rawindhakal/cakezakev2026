import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/features/payment_method/models/payment_methods_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Instructions + proof upload for eSewa / bank transfer / QR payments.
/// The order is already placed; staff verify the payment in the admin panel.
/// Pops with `true` once the proof is sent, or when the customer skips.
class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({
    super.key,
    required this.orderId,
    required this.method,
    required this.amount,
  });

  final String orderId;
  final String method; // Esewa | BankTransfer | QrPayment
  final double amount;

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  final _reference = TextEditingController();
  XFile? _proof;
  bool _busy = false;

  Map<String, dynamic> get _cfg {
    final all = PaymentMethodsData.offlineConfig;
    final key = switch (widget.method) {
      'Esewa' => 'esewa',
      'BankTransfer' => 'bank',
      _ => 'qr',
    };
    final section = all[key];
    return section is Map ? Map<String, dynamic>.from(section) : {};
  }

  String get _title => switch (widget.method) {
    'Esewa' => 'Pay with eSewa',
    'BankTransfer' => 'Pay by bank transfer',
    _ => 'Pay by QR',
  };

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (f != null) setState(() => _proof = f);
  }

  Future<void> _submit() async {
    if (_proof == null) {
      _toast('Please attach your payment screenshot');
      return;
    }
    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'order_id': widget.orderId,
        'reference': _reference.text.trim(),
        'proof': await MultipartFile.fromFile(_proof!.path, filename: _proof!.name),
      });
      await ApiClient().upload(ApiEndpoints.paymentProof, formData: form);
      if (!mounted) return;
      _toast('Payment proof received. We will verify it shortly.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _toast('Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _row(String k, dynamic v) {
    final value = v?.toString() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final cs = Theme.of(context).colorScheme;
    final qr = (cfg['qr_image'] ?? '').toString();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your order #${widget.orderId} is placed. Pay the exact amount below, then upload the screenshot so we can verify it.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Amount to pay'),
                    Text(
                      'Rs ${widget.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (qr.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    color: Colors.white,
                    child: CachedNetworkImage(
                      imageUrl: qr,
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const Icon(Icons.qr_code_2, size: 80),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.method == 'Esewa') ...[
                _row('eSewa ID', cfg['esewa_id']),
                _row('Name', cfg['account_name']),
              ],
              if (widget.method == 'BankTransfer') ...[
                _row('Bank', cfg['bank_name']),
                _row('Branch', cfg['branch']),
                _row('Account name', cfg['account_name']),
                _row('Account number', cfg['account_number']),
              ],
              if ((cfg['instructions'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    cfg['instructions'].toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Transaction / reference no. (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _proof == null ? 'Upload payment screenshot' : _proof!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Uploading…' : 'Submit payment proof'),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('Skip for now - our team will contact you'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
