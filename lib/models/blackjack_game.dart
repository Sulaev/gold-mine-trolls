import 'dart:math';
import 'blackjack_card.dart';

enum BlackjackPhase {
  dealing,
  playerTurn,
  dealerTurn,
  playerBust,
  dealerBust,
  playerWin,
  dealerWin,
  push,
}

class BlackjackGame {
  BlackjackGame() {
    _newRound();
  }

  final List<BlackjackCard> _deck = [];
  final List<BlackjackCard> dealerHand = [];
  final List<BlackjackCard> playerHand = [];
  BlackjackPhase phase = BlackjackPhase.dealing;
  final Random _rng = Random();

  static int _handValue(List<BlackjackCard> hand) {
    int total = 0;
    int aces = 0;
    for (final c in hand) {
      if (c.rank == 'a') {
        aces++;
        total += 11;
      } else {
        total += c.value;
      }
    }
    while (total > 21 && aces > 0) {
      total -= 10;
      aces--;
    }
    return total;
  }

  int get dealerValue => _handValue(dealerHand);
  int get playerValue => _handValue(playerHand);

  BlackjackCard _draw() {
    if (_deck.isEmpty) {
      _deck.addAll(BlackjackCard.createDeck());
      _deck.shuffle(_rng);
    }
    return _deck.removeLast();
  }

  /// Draws a card for initial 2-card hand. Puts back any card that would bust.
  BlackjackCard _drawForInitialHand(List<BlackjackCard> hand) {
    assert(hand.length == 1);
    while (true) {
      final c = _draw();
      final testHand = [hand[0], c];
      if (_handValue(testHand) <= 21) return c;
      _deck.insert(0, c);
    }
  }

  void _newRound() {
    _deck.clear();
    dealerHand.clear();
    playerHand.clear();
    _deck.addAll(BlackjackCard.createDeck());
    _deck.shuffle(_rng);
    phase = BlackjackPhase.dealing;
  }

  void dealInitial() {
    dealerHand.clear();
    playerHand.clear();
    dealerHand.add(_draw());
    dealerHand.add(_drawForInitialHand(dealerHand));
    playerHand.add(_draw());
    playerHand.add(_drawForInitialHand(playerHand));
    phase = BlackjackPhase.playerTurn;

    // Blackjack check
    if (playerValue == 21 && dealerValue == 21) {
      phase = BlackjackPhase.push;
    } else if (playerValue == 21) {
      phase = BlackjackPhase.playerWin;
    }
    // Dealer 21: let player try to hit 21 before resolving
  }

  /// Deal 2 cards to dealer only (for pre-start display).
  void dealDealerOnly() {
    dealerHand.clear();
    playerHand.clear();
    dealerHand.add(_draw());
    dealerHand.add(_drawForInitialHand(dealerHand));
    phase = BlackjackPhase.dealing;
  }

  /// Deal 2 cards to player (dealer already has 2). Completes initial deal.
  void dealPlayerOnly() {
    assert(dealerHand.length == 2 && playerHand.isEmpty);
    playerHand.add(_draw());
    playerHand.add(_drawForInitialHand(playerHand));
    phase = BlackjackPhase.playerTurn;

    if (playerValue == 21 && dealerValue == 21) {
      phase = BlackjackPhase.push;
    } else if (playerValue == 21) {
      phase = BlackjackPhase.playerWin;
    }
  }

  void hit() {
    if (phase != BlackjackPhase.playerTurn) return;
    playerHand.add(_draw());
    if (playerValue > 21) {
      phase = BlackjackPhase.playerBust;
    } else if (playerValue == 21) {
      phase = dealerValue == 21 ? BlackjackPhase.push : BlackjackPhase.playerWin;
    }
  }

  void stand() {
    if (phase != BlackjackPhase.playerTurn) return;
    phase = BlackjackPhase.dealerTurn;
    if (dealerValue >= 17) {
      _resolveDealer();
    }
  }

  void dealerDrawOne() {
    if (phase != BlackjackPhase.dealerTurn || dealerValue >= 17) return;
    dealerHand.add(_draw());
    if (dealerValue > 21) {
      phase = BlackjackPhase.dealerBust;
    } else if (dealerValue >= 17) {
      _resolveDealer();
    }
  }

  void _resolveDealer() {
    if (dealerValue > playerValue) {
      phase = BlackjackPhase.dealerWin;
    } else if (dealerValue < playerValue) {
      phase = BlackjackPhase.playerWin;
    } else {
      phase = BlackjackPhase.push;
    }
  }

  bool get dealerNeedsToDraw =>
      phase == BlackjackPhase.dealerTurn && dealerValue < 17;

  /// Reset to empty hands with fresh deck, ready for deal.
  void resetForNewGame() {
    _newRound();
  }

  void startNewRound() {
    _newRound();
    dealInitial();
  }

  bool get canHit => phase == BlackjackPhase.playerTurn;
  bool get canStand => phase == BlackjackPhase.playerTurn;
  bool get isGameOver =>
      phase != BlackjackPhase.dealing &&
      phase != BlackjackPhase.playerTurn &&
      phase != BlackjackPhase.dealerTurn;

  /// Serialize state for persistence. Returns null if game is over (nothing to save).
  Map<String, dynamic>? saveState() {
    if (isGameOver) return null;
    return {
      'dealerHand': dealerHand.map((c) => {'suit': c.suit, 'rank': c.rank}).toList(),
      'playerHand': playerHand.map((c) => {'suit': c.suit, 'rank': c.rank}).toList(),
      'deck': _deck.map((c) => {'suit': c.suit, 'rank': c.rank}).toList(),
      'phase': phase.name,
    };
  }

  /// Restore state from persistence.
  void restoreState(Map<String, dynamic> data) {
    dealerHand.clear();
    playerHand.clear();
    _deck.clear();
    for (final m in data['dealerHand'] as List) {
      dealerHand.add(BlackjackCard(suit: m['suit'] as String, rank: m['rank'] as String));
    }
    for (final m in data['playerHand'] as List) {
      playerHand.add(BlackjackCard(suit: m['suit'] as String, rank: m['rank'] as String));
    }
    for (final m in data['deck'] as List) {
      _deck.add(BlackjackCard(suit: m['suit'] as String, rank: m['rank'] as String));
    }
    phase = BlackjackPhase.values.firstWhere(
      (p) => p.name == data['phase'],
      orElse: () => BlackjackPhase.dealing,
    );
  }
}
