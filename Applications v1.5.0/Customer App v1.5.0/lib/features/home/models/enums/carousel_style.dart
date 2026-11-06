enum CarouselStyle {
  fullWidth,
  peek,
  card,
  story,
  spotLight;

  static CarouselStyle fromRaw(String? raw) {
    switch (raw) {
      case 'full_width':
        return CarouselStyle.fullWidth;
      case 'peek':
        return CarouselStyle.peek;
      case 'card':
        return CarouselStyle.card;
      case 'story':
        return CarouselStyle.story;
      case 'spotlight':
        return CarouselStyle.spotLight;
      default:
        return CarouselStyle.fullWidth;
    }
  }
}
