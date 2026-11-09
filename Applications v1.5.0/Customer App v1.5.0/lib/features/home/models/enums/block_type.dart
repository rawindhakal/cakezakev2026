enum BlockType {
  bannerSlider,
  categorySection,
  productSlider,
  brandSection,
  gridBanner,
  titleImage,
  textSection,
  productTabs,
  occasionSection,
  relationshipSection,
  unknown;

  static BlockType fromRaw(String? raw) {
    switch (raw) {
      case 'banner_slider':
        return BlockType.bannerSlider;
      case 'category_section':
        return BlockType.categorySection;
      case 'product_slider':
        return BlockType.productSlider;
      case 'brand_section':
        return BlockType.brandSection;
      case 'grid_banner':
        return BlockType.gridBanner;
      case 'title_image':
        return BlockType.titleImage;
      case 'text_section':
        return BlockType.textSection;
      case 'product_tabs':
        return BlockType.productTabs;
      case 'occasion_section':
        return BlockType.occasionSection;
      case 'relationship_section':
        return BlockType.relationshipSection;
      default:
        return BlockType.unknown;
    }
  }
}
