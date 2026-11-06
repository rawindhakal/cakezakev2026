enum GridLayoutType {
  scroll,
  grid;

  static GridLayoutType fromRaw(String? raw) {
    switch (raw) {
      case 'scroll':
        return GridLayoutType.scroll;
      default:
        return GridLayoutType.grid;
    }
  }
}
