enum BackgroundThemeType {
  image,
  color,
  none;

  static BackgroundThemeType fromRaw(String? raw) {
    switch (raw) {
      case 'image':
        return BackgroundThemeType.image;
      case 'color':
        return BackgroundThemeType.color;
      default:
        return BackgroundThemeType.none;
    }
  }
}
