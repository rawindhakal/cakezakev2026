enum SectionLayout {
  horizontal,
  circular,
  grid;

  static SectionLayout fromRaw(String? raw) {
    switch (raw) {
      case 'horizontal':
        return SectionLayout.horizontal;
      case 'circular':
        return SectionLayout.circular;
      default:
        return SectionLayout.grid;
    }
  }
}
