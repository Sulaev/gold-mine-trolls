import 'dart:ui';

/// European roulette bet types and their payout multipliers
enum RouletteBetType {
  zero(35),
  number(35),
  column1(2),
  column2(2),
  column3(2),
  dozen1(2),
  dozen2(2),
  dozen3(2),
  low(1),
  even(1),
  red(1),
  black(1),
  odd(1),
  high(1);

  const RouletteBetType(this.payoutMultiplier);
  final int payoutMultiplier;
}

/// Bet zone with Rect in SVG viewBox coordinates (290x156)
class RouletteBetZone {
  const RouletteBetZone({
    required this.type,
    required this.rect,
    this.number,
  });
  final RouletteBetType type;
  final Rect rect;
  final int? number;
}

/// Zone definitions extracted from pole.svg viewBox "0 0 290 156"
/// Rects are in SVG coordinates
class RoulettePoleZones {
  RoulettePoleZones._();

  static const double viewWidth = 290;
  static const double viewHeight = 156;

  static final List<RouletteBetZone> zones = _buildZones();

  static List<RouletteBetZone> _buildZones() {
    final z = <RouletteBetZone>[];

    // Number grid: 12 cols x 3 rows (includes 3/2/1 in first column)
    // SVG exact coordinates to avoid horizontal drift
    const colLefts = [
      24.15, 44.41, 64.68, 84.94, 105.2, 125.47, 145.73, 165.99, 186.26,
      206.53, 226.79, 247.06,
    ];
    const cellW = 21.71;
    const cellH = 35.8;
    const rowTops = [0.0, 34.09, 68.18];
    const numbers = [
      [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36],
      [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35],
      [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34],
    ];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 12; col++) {
        z.add(RouletteBetZone(
          type: RouletteBetType.number,
          number: numbers[row][col],
          rect: Rect.fromLTWH(
            colLefts[col],
            rowTops[row],
            cellW,
            cellH,
          ),
        ));
      }
    }

    // 2 to 1 columns (right of grid)
    z.add(RouletteBetZone(
      type: RouletteBetType.column3,
      rect: const Rect.fromLTWH(267.32, 0, 21.71, 34.09),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.column2,
      rect: const Rect.fromLTWH(267.32, 35.8, 21.71, 34.09),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.column1,
      rect: const Rect.fromLTWH(267.32, 69.89, 21.71, 34.09),
    ));

    // Dozens
    z.add(RouletteBetZone(
      type: RouletteBetType.dozen1,
      rect: const Rect.fromLTWH(24.15, 102.28, 82.5, 28.12),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.dozen2,
      rect: const Rect.fromLTWH(105.2, 102.28, 82.51, 28.12),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.dozen3,
      rect: const Rect.fromLTWH(186.26, 102.28, 82.51, 28.12),
    ));

    // Simple chances
    z.add(RouletteBetZone(
      type: RouletteBetType.low,
      rect: const Rect.fromLTWH(24.15, 128.7, 41.97, 27.27),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.even,
      rect: const Rect.fromLTWH(64.68, 128.7, 41.97, 27.27),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.red,
      rect: const Rect.fromLTWH(105.2, 128.7, 41.98, 27.27),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.black,
      rect: const Rect.fromLTWH(145.73, 128.7, 41.98, 27.27),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.odd,
      rect: const Rect.fromLTWH(186.26, 128.7, 41.98, 27.27),
    ));
    z.add(RouletteBetZone(
      type: RouletteBetType.high,
      rect: const Rect.fromLTWH(226.79, 128.7, 41.98, 27.27),
    ));

    // 0 zone last so it's on top for hit testing; 25x52 with skewed corners on left
    z.add(RouletteBetZone(
      type: RouletteBetType.zero,
      rect: const Rect.fromLTWH(0, 26, 25, 52),
    ));

    return z;
  }
}

/// Red numbers in European roulette
const redNumbers = {
  1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36,
};

/// Unique key for a placed bet (for numbers: type+number, for others: type)
class RouletteBetKey {
  const RouletteBetKey(this.type, [this.number]);
  final RouletteBetType type;
  final int? number;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouletteBetKey &&
          type == other.type &&
          number == other.number;

  @override
  int get hashCode => Object.hash(type, number);
}

/// Calculate payout for a bet given the winning number (0-36)
int calculateBetPayout(RouletteBetKey key, int betAmount, int winningNumber) {
  final mult = key.type.payoutMultiplier;
  switch (key.type) {
    case RouletteBetType.zero:
      return winningNumber == 0 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.number:
      return key.number == winningNumber ? betAmount * (mult + 1) : 0;
    case RouletteBetType.column1:
      return _column1.contains(winningNumber) ? betAmount * (mult + 1) : 0;
    case RouletteBetType.column2:
      return _column2.contains(winningNumber) ? betAmount * (mult + 1) : 0;
    case RouletteBetType.column3:
      return _column3.contains(winningNumber) ? betAmount * (mult + 1) : 0;
    case RouletteBetType.dozen1:
      return winningNumber >= 1 && winningNumber <= 12 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.dozen2:
      return winningNumber >= 13 && winningNumber <= 24 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.dozen3:
      return winningNumber >= 25 && winningNumber <= 36 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.low:
      return winningNumber >= 1 && winningNumber <= 18 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.high:
      return winningNumber >= 19 && winningNumber <= 36 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.even:
      return winningNumber != 0 && winningNumber % 2 == 0 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.odd:
      return winningNumber % 2 == 1 ? betAmount * (mult + 1) : 0;
    case RouletteBetType.red:
      return redNumbers.contains(winningNumber) ? betAmount * (mult + 1) : 0;
    case RouletteBetType.black:
      return winningNumber != 0 && !redNumbers.contains(winningNumber)
          ? betAmount * (mult + 1)
          : 0;
  }
}

const _column1 = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34];
const _column2 = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35];
const _column3 = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36];

/// Returns true if [zone] should be highlighted when [selection] is active.
/// Special bets (dozens, columns, red/black, etc.) highlight all matching number cells.
bool zoneMatchesSelection(RouletteBetZone zone, RouletteBetKey? selection) {
  if (selection == null) return false;
  final key = RouletteBetKey(zone.type, zone.number);
  if (selection == key) return true;

  switch (selection.type) {
    case RouletteBetType.dozen1:
      return zone.number != null && zone.number! >= 1 && zone.number! <= 12;
    case RouletteBetType.dozen2:
      return zone.number != null && zone.number! >= 13 && zone.number! <= 24;
    case RouletteBetType.dozen3:
      return zone.number != null && zone.number! >= 25 && zone.number! <= 36;
    case RouletteBetType.column1:
      return zone.number != null && _column1.contains(zone.number!);
    case RouletteBetType.column2:
      return zone.number != null && _column2.contains(zone.number!);
    case RouletteBetType.column3:
      return zone.number != null && _column3.contains(zone.number!);
    case RouletteBetType.low:
      return zone.number != null && zone.number! >= 1 && zone.number! <= 18;
    case RouletteBetType.high:
      return zone.number != null && zone.number! >= 19 && zone.number! <= 36;
    case RouletteBetType.even:
      return zone.number != null && zone.number! != 0 && zone.number! % 2 == 0;
    case RouletteBetType.odd:
      return zone.number != null && zone.number! % 2 == 1;
    case RouletteBetType.red:
      return zone.number != null && redNumbers.contains(zone.number!);
    case RouletteBetType.black:
      return zone.number != null &&
          zone.number! != 0 &&
          !redNumbers.contains(zone.number!);
    case RouletteBetType.zero:
    case RouletteBetType.number:
      return false;
  }
}
