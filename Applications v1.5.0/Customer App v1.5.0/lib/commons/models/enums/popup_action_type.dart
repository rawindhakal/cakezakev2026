enum PopupActionType {
  product,
  category,
  brand,
  popupUrl,
  none;

  static PopupActionType fromRaw(String? raw) {
    switch (raw) {
      case 'product':
        return PopupActionType.product;
      case 'category':
        return PopupActionType.category;
      case 'brand':
        return PopupActionType.brand;
      case 'popup_url':
        return PopupActionType.popupUrl;
      default:
        return PopupActionType.none;
    }
  }
}
