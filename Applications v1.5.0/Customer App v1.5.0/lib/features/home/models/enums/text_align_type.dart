enum TextAlignType {
  left,
  center,
  right;

  static TextAlignType fromRaw(String? raw) {
    switch (raw) {
      case 'center':
        return TextAlignType.center;
      case 'right':
        return TextAlignType.right;
      default:
        return TextAlignType.left;
    }
  }
}
