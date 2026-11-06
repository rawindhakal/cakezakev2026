enum TransactionStatus {
  success,
  failed,
  pending,
  unknown;

  static TransactionStatus fromRaw(String status) {
    final s = status.trim().toLowerCase();
    if (s == '1' ||
        s.contains('success') ||
        s.contains('complete') ||
        s.contains('captur')) {
      return TransactionStatus.success;
    }
    if (s == '2' || s.contains('fail') || s.contains('decline')) {
      return TransactionStatus.failed;
    }
    if (s == '0' || s.contains('pending')) {
      return TransactionStatus.pending;
    }
    return TransactionStatus.unknown;
  }
}
