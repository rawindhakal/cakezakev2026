import 'dart:convert';

/// Hosted-checkout form from initiate_transaction's `data.payload` (PayU) —
/// the app auto-submits [fields] to [action] inside the payment webview.
/// Backend signs the hash over these exact values, so every field must be
/// posted exactly as received (including empty udf4/udf5). `payload.sdk` is
/// for web and ignored here.
class PaymentFormPayload {
  const PaymentFormPayload({
    required this.method,
    required this.action,
    required this.fields,
  });

  final String method;
  final String action;
  final Map<String, String> fields;

  /// Null when `data` doesn't carry a usable form payload.
  static PaymentFormPayload? fromInitiateData(Map<String, dynamic> data) {
    final payload = data['payload'];
    if (payload is! Map) return null;
    final action = payload['action']?.toString() ?? '';
    final fields = payload['fields'];
    if (action.isEmpty || fields is! Map) return null;
    final method = payload['method']?.toString() ?? '';
    return PaymentFormPayload(
      method: method.isEmpty ? 'POST' : method.toUpperCase(),
      action: action,
      fields: fields.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
    );
  }

  /// Hidden self-submitting form — loaded with loadHtmlString
  /// (loadDataWithBaseURL on Android).
  String toAutoSubmitHtml() {
    const esc = HtmlEscape();
    final inputs = fields.entries
        .map(
          (e) =>
              '<input type="hidden" name="${esc.convert(e.key)}" '
              'value="${esc.convert(e.value)}">',
        )
        .join();
    return '<html><head><meta name="viewport" '
        'content="width=device-width, initial-scale=1"></head>'
        '<body onload="document.f.submit()">'
        '<form name="f" method="${esc.convert(method)}" '
        'action="${esc.convert(action)}">$inputs</form>'
        '</body></html>';
  }
}
