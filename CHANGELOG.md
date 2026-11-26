# Changelog

## v0.1.2 (2026-11-26)

### Fixed
- The quest guide no longer marks gear and materials as collected when you haven't got them.
  Accepting a quest (for example In Search of Anthion) used to tick every step above it,
  including the "Get ... of Valor" gear and the "You need:" materials lists.
  Those steps now stay open until you turn in the quest that uses them.
- Farming ahead (for example 25 Volcanic Ash before you reach that step) no longer ticks
  the steps before it.
- Quest objectives only count while the quest is in your quest log, so steps in parts
  you haven't reached can't show as done.

## v0.1.1 (2026-11-26)

### Added
- The quest guide now ticks off collect and loot steps as you go, not only when you turn
  the quest in:
  - From your bags and bank: Volcanic Ash, Winterspring Blood Samples, Silithus Venom
    Samples, Ogre Warbeads, Bloodkelp and Blackrock Bracers.
  - From your quest log: Scorched, Frozen and Stable Ectoplasm (one step each), Magma Core,
    saving Ysida, Jeering Spectre's Essence, Ember of Emberseer, Incendicite of Incendius
    and Lord Valthalak.

### Fixed
- The guide now recognises WoW Forever's own quest IDs for the four class quests
  (An Earnest Proposition, Just Compensation, Anthion's Parting Words, Saving the Best
  for Last). Old Classic turn-ins still count. Adds the Alliance Shaman and Horde Paladin
  versions.
- Fixed a crash when showing gold amounts on WoW Forever.

## v0.1.0 (2026-11-24)

First release.
- Shopping list for the whole Tier 0.5 chain: every Auction House material, gold fee and
  farm item, with what you already carry and how much gold is left to spend.
- Live prices from its own Auction House scan or from Auctionator.
- Step-by-step quest guide for all four parts, filtered to your class and faction, with
  map pins.
