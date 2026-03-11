/// Playing card for blackjack.
class BlackjackCard {
  const BlackjackCard({
    required this.suit,
    required this.rank,
  });

  final String suit; // spades, hearts, diamonds, clubs
  final String rank; // 2-10, j, q, k, a

  int get value {
    switch (rank) {
      case 'a':
        return 11; // Ace, can be 1 in soft hand
      case 'k':
      case 'q':
      case 'j':
        return 10;
      default:
        return int.parse(rank);
    }
  }

  String get assetPath =>
      'assets/images/card_mine_21/card/${suit}_$rank.png';

  static const List<String> suits = ['spades', 'hearts', 'diamonds', 'clubs'];
  static const List<String> ranks = [
    '2', '3', '4', '5', '6', '7', '8', '9', '10', 'j', 'q', 'k', 'a'
  ];

  static List<BlackjackCard> createDeck() {
    final deck = <BlackjackCard>[];
    for (final s in suits) {
      for (final r in ranks) {
        deck.add(BlackjackCard(suit: s, rank: r));
      }
    }
    return deck;
  }
}
