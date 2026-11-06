enum TabStyle {
  iconTop,
  textOnly;

  static TabStyle fromRaw(String? raw) {
    switch (raw) {
      case 'text':
        return TabStyle.textOnly;
      case 'icon_top':
      default:
        return TabStyle.iconTop;
    }
  }
}

enum TabActiveIndicator {
  underline,
  fill,
  outline,
  none;

  static TabActiveIndicator fromRaw(String? raw) {
    switch (raw) {
      case 'fill':
        return TabActiveIndicator.fill;
      case 'outline':
        return TabActiveIndicator.outline;
      case 'none':
        return TabActiveIndicator.none;
      case 'underline':
      default:
        return TabActiveIndicator.underline;
    }
  }
}

enum TabActiveBgStyle {
  solid,
  image,
  gradient,
  none;

  static TabActiveBgStyle fromRaw(String? raw) {
    switch (raw) {
      case 'image':
        return TabActiveBgStyle.image;
      case 'gradient':
        return TabActiveBgStyle.gradient;
      case 'none':
        return TabActiveBgStyle.none;
      case 'solid':
      default:
        return TabActiveBgStyle.solid;
    }
  }
}

enum TabAnimation {
  slide,
  fade,
  none;

  static TabAnimation fromRaw(String? raw) {
    switch (raw) {
      case 'fade':
        return TabAnimation.fade;
      case 'none':
        return TabAnimation.none;
      case 'slide':
      default:
        return TabAnimation.slide;
    }
  }
}
