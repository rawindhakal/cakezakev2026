enum HomeType {
  single,
  categoryWise,
  unknown;

  static HomeType fromRaw(String? raw) {
    switch (raw) {
      case 'single':
        return HomeType.single;
      case 'category_wise':
        return HomeType.categoryWise;
      default:
        return HomeType.unknown;
    }
  }
}
