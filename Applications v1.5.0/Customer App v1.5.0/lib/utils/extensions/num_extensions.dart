extension NumFormatExtensions on num {
  /// Formats as fixed-decimal, dropping the decimal part when it's all zeros
  /// (e.g. 100.00 -> "100", 100.20 -> "100.20", 100.01 -> "100.01").
  String formatPrice([int decimalPoint = 2]) {
    final fixed = toStringAsFixed(decimalPoint);
    final dotIndex = fixed.indexOf('.');
    if (dotIndex == -1) return fixed;
    final decimalPart = fixed.substring(dotIndex + 1);
    if (decimalPart.contains(RegExp(r'[1-9]'))) return fixed;
    return fixed.substring(0, dotIndex);
  }
}
