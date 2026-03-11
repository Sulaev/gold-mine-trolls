# Gold Mine Trolls

Mobile game app — vertical orientation, 8 mini-games, monetization via Adapty.

## Run

**From WSL/Linux:**
```bash
cd gold-mine-trolls
chmod +x run.sh   # first time only
./run.sh
```

**From Windows (PowerShell):**
```bash
cd gold-mine-trolls
flutter run
```

The `run.sh` script handles Flutter detection (native vs Windows fallback in WSL), device/emulator check, and broken APK recovery.

## Assets structure

PNG elements are organized by game/screen. Drop design assets into:

| Folder | Purpose |
|--------|---------|
| `assets/images/gold_vein/` | Gold Vein — slot |
| `assets/images/miners_wheel_of_fortune/` | Miner's Wheel of Fortune — roulette |
| `assets/images/mine_depth_tower/` | Mine Depth Tower — drilling game |
| `assets/images/golden_avalanche/` | Golden Avalanche — plinko |
| `assets/images/treasure_trail_ladder/` | Treasure Trail Ladder |
| `assets/images/chief_trolls_wheel/` | Chief Troll's Wheel — wheel of fortune |
| `assets/images/card_mine_21/` | Card Mine 21 — blackjack |
| `assets/images/cautious_miner/` | Cautious Miner — minefield |
| `assets/images/onboarding/` | Onboarding screens |
| `assets/images/welcome_bonus/` | Welcome bonus screen |
| `assets/images/tutorial/` | Tutorial screens |
| `assets/images/main_screen/` | Main screen |
| `assets/images/settings/` | Settings screen |
| `assets/images/paywall/` | Paywall (subscriptions) |
| `assets/images/shop/` | Shop (coins) |
| `assets/images/road_of_luck/` | Road of Luck |
| `assets/images/common/` | Shared UI elements |
| `assets/sounds/` | Music, SFX (tap, jackpot, win/lose, etc.) |

## Technical spec (summary)

- **Orientation**: portrait only
- **Localization**: English
- **Monetization**: Adapty (subscriptions + coins)
- **UX**: Press effect on buttons, vibration, music/SFX
- **Slots**: First 20 games with boosted win chance (retention)

### Screens flow

1. **Onboarding** → Loading slider → LET'S PLAY → Welcome bonus (18+ consent, Terms/Privacy)
2. **Welcome bonus** → 10k first, 1k/day (x4 with subscription) → GET FREE GOLD → Tutorial
3. **Tutorial** → Tap to next → Main screen
4. **Main screen** → Scrollable, SHOP, exclusive bonus, balance (+), settings, road of luck
5. **Games** → 8 games with back, balance add, info, bet controls (-/+ hold to accelerate)
6. **Settings** → Music, notifications, vibration, Terms/Privacy
7. **Paywall** → Subscriptions
8. **Shop** → Coins, Miner Pass
9. **Road of Luck** → Chain of rewards, free first, resets on completion

### Games

- **Gold Vein** — slot, spin, autospin, bet 50 step
- **Card Mine 21** — blackjack, hit/stand
- **Miner's Wheel of Fortune** — roulette
- **Cautious Miner** — minefield (gold/dynamite), 60/40 win
- **Golden Avalanche** — plinko, drop balls, normal/high/low chests
- **Chief Troll's Wheel** — wheel of fortune
- **Treasure Trail Ladder** — ladder levels
- **Mine Depth Tower** — drill down, 50/50 per level, lava at bottom
