# T0.5 Shopping List

A World of Warcraft addon for **WoW Forever** (Interface 16001) that turns the Tier 0.5
(Dungeon Set 2) upgrade chain into one in-game checklist: every gold fee, Auction House
mat and farm item, what you already carry, and how much gold is still left to spend.
It also has a step-by-step quest guide for the whole chain, filtered to your class and faction.

Type `/t05` to open it.

## What it does

### Shopping list window

Three sections, one row per item:

| Section | What's in it | How a row gets ticked off |
|---|---|---|
| **Auction House** | 11 crafted mats you buy | Bags + bank hold enough |
| **Quest fees & vendor** | 4 gold costs | Manual checkbox ("Paid"), saved per character |
| **Farm** | 5 drops/gatherables (6 rows, 1 is faction-specific) | Bags + bank hold enough |

Each row shows the icon, name, `have/need`, price each, row total and the quest it is for.
Once that quest is turned in, the row shows **Turned in** and stops counting, since the mats
are gone from your bags but no longer needed. Done rows go green, fade, and drop to the
bottom of their section.

The header shows where you are in the chain: `Step N/29: <next quest>`. The footer shows
**Still to spend**, a progress bar, and `X/20 done · Y% of gold spent`.

### Pricing

For each AH item the addon picks the freshest of:

1. **Its own scan.** With the AH open, press **Scan prices**. It searches each AH item and
   saves the cheapest buyable unit price, per realm and faction (`T05ShoppingPrices`).
   Any AH search you do yourself for one of these items is recorded too.
2. **Auctionator**, if installed (optional dependency), via `Auctionator.API.v1`.
3. **The spreadsheet price** (AH prices from 21/11) as a fallback, shown in grey with `(sheet)`.

Prices older than 3 days are marked stale in orange (`4d old`). While any fallback price
is in the sum, the footer shows a low-to-high range instead of a single number.

### Buying

With the AH open, click an AH row to jump to Blizzard's buy page for that item with the
missing quantity already filled in. You still press Buy Now yourself.
Shift-click links the item in chat.

### Quest guide

The **Guide** button docks a panel to the right with every step of the chain, split into
four parts (Bracers; Belt & Gloves; Pants, Shoulders & Boots; Helm & Chest). It opens at
the step you're on, ticks off steps your quest log proves done, and each step with a
location has a map-pin button (TomTom waypoint if installed, otherwise the game's own map pin).

Quest names anywhere in the addon are real quest links: hover for the tooltip and your
status, shift-click to link in chat, click for a copyable Wowhead URL.

### Other

- Minimap button (drag to move) and an entry in Blizzard's addon compartment menu.
- Esc closes the window; its position is remembered.

## The numbers

Full chain cost for a fresh character, with spreadsheet prices:

| Section | Low | High |
|---|---:|---:|
| Auction House | 326.50g | 385.10g |
| Quest fees & vendor | 227.00g | 227.00g |
| **Total** | **553.50g** | **612.10g** |

Auction House items:

| Item | Qty | Price each (sheet) | For |
|---|---:|---|---|
| Delicate Arcanite Converter | 1 | 40 to 45g | The Ectoplasmic Distiller |
| Greater Eternal Essence | 4 | 2 to 3g | The Ectoplasmic Distiller |
| Stonescale Oil | 10 | under 1g | The Ectoplasmic Distiller |
| Dark Iron Bar | 3 | 1 to 1.20g | Anthion's Strange Request |
| Enchanted Leather | 20 | 1 to 1.50g | Anthion's Strange Request |
| Mooncloth | 3 | 35 to 40g | Anthion's Strange Request |
| Cured Rugged Hide | 4 | 25 to 30g | Anthion's Strange Request |
| Dark Rune | 4 | 2g | The Instigator's Enchantment |
| Large Brilliant Shard | 8 | 2.50 to 3g | The Instigator's Enchantment |
| Flask of Supreme Power | 1 | 20g | Final Preparations |
| Goblin Rocket Fuel | 10 | 25s | Hunting for Ectoplasm |

Fees:

| Fee | Cost | Where |
|---|---:|---|
| An Earnest Proposition | 20g | Deliana (Ironforge) / Mokvar (Orgrimmar) |
| The Ectoplasmic Distiller | 40g | Mux Manascrambler, Gadgetzan |
| Fel Elemental Rod | 40g | Vi'el, Darkwhisper Gorge |
| Hallowed Brazier | 127g | Argent Dawn QM, Honored |

Farm:

| Item | Qty | Where |
|---|---:|---|
| Winterspring Blood Sample (Alliance) / Silithus Venom Sample (Horde) | 15 | Winterspring / Silithus |
| Volcanic Ash | 25 | Burning Steppes lava pools |
| Ogre Warbeads | 25 | Dire Maul / BRS ogres |
| Bloodkelp | 20 | Alcaz Island naga |
| Blackrock Bracer | 40 | BRS orcs |

Notes:
- Goblin Rocket Fuel counts the worst case of 10. You need 3 to 10, and up to 8 come free from the previous quest.
- Guides disagree on the Hallowed Brazier price (120g or about 127g). Check the vendor.
- The guide holds 225 steps; the quest chain is 29 tracked quests per faction.

## Install

1. Download the repo (Code > Download ZIP on GitHub, or `git clone https://github.com/medonni/T05Shopping.git`).
2. Put the folder in your AddOns directory and make sure it is named exactly `T05Shopping`
   (a GitHub ZIP unpacks as `T05Shopping-main`, so rename it):
   ```
   World of Warcraft/_forever_/Interface/AddOns/T05Shopping/T05Shopping.toc
   ```
3. Restart the game or `/reload`, and check that **T0.5 Shopping List** is enabled in the AddOns list.
4. Optional: install **Auctionator** for extra price data and **TomTom** for waypoints.

For development on Linux, symlink the repo instead so edits show up after `/reload`:

```sh
ln -s ~/Documents/T05Shopping \
  "$HOME/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/T05Shopping"
```

## Commands

| Command | What it does |
|---|---|
| `/t05` | Open or close the window |
| `/t05 dump` | Print the totals to chat |
| `/t05 minimap` | Hide or show the minimap button |

## Files

| File | What it is |
|---|---|
| `T05Shopping.toc` | Addon manifest (saved variables, optional deps, compartment hooks) |
| `Data.lua` | The shopping list: sections, items, quantities, sheet prices |
| `Guide.lua` | Guide steps (`ns.GUIDE`) and the quest chain (`ns.CHAIN`), hand-maintained |
| `T05Shopping.lua` | Counting, pricing, AH scan/buy, the window, guide panel, minimap button, slash command |
| `test.lua` | Offline check of the totals and chain logic |
| `test_ui.lua` | Offline smoke test of the UI code with stubbed frames |

Saved data: `T05ShoppingDB` (per character: paid checkboxes, minimap angle) and
`T05ShoppingPrices` (account-wide: scanned prices per realm and faction).

## Tests

Run from the repo root, outside the game:

```sh
lua test.lua      # empty character must total 553.50g to 612.10g
lua5.1 test_ui.lua
```

Both print `ok`. The UI test catches nil errors and typos, not layout; layout still needs a look in game.

## Releasing

Push a version tag (`git tag v0.2.0 && git push --tags`). GitHub Actions runs the tests,
then the [BigWigs packager](https://github.com/BigWigsMods/packager) builds a
`T05Shopping/` zip (without the tests, plans and logo), and uploads it to GitHub Releases,
plus CurseForge when the `.toc` has `## X-Curse-Project-ID` and the repo has a
`CF_API_TOKEN` secret.

## License

[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/): free to share and change with credit, not for commercial use, changes under the same license. See `LICENSE` and `NOTICE`.
