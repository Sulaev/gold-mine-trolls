/// Slot cell coordinates extracted from slots_back.svg viewBox "0 0 428 479"
/// Each cell rect: x, y, width=79, height=65
class GoldVeinSlotZones {
  GoldVeinSlotZones._();

  static const double viewWidth = 428;
  static const double viewHeight = 479;

  /// Center X of each column (x + 79/2)
  static const colCenters = [111.79, 213.79, 314.79];

  /// Per-column X offset: left -8 (3px left), center -8 (2px right), right -8 (2px right)
  static const colOffsetX = [-8.0, -8.0, -8.0];

  /// Center Y of each row (y + 65/2)
  static const rowCenters = [91.5, 164.5, 237.5, 312.5, 386.5];

  /// Cell dimensions in SVG coordinates
  static const cellWidth = 79.0;
  static const cellHeight = 65.0;

  /// Offset to align symbols with PNG frame (slots_back.png may differ from SVG)
  static const symbolOffsetX = 0.0;
  static const symbolOffsetY = 0.0;

  /// Global shift: move all columns right (positive = right)
  static const columnsShiftRight = 8.0;
}
