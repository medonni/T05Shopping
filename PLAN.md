# T05Shopping: plan

A WoW Forever addon that turns `wow_forever_t0.5_shopping_list.xlsx` into an in-game
checklist for the Tier 0.5 (Dungeon Set 2) upgrade chain. It shows what to buy, what
to farm, what you already have, and how much gold is still needed. Prices come from
Auctionator's last scan.

## Scope

In:
- A `/t05` window with three sections: Auction House, Quest fees & vendor, Farm.
- Each row shows the icon, the name, have/need, price each, the row total and the
  quest it is for.
- Item rows tick off automatically when bags + bank hold enough
  (`GetItemCount(id, true)`).
- Rows without an item to count (quest fees, the Hallowed Brazier) get a manual
  checkbox, saved per character.
- Footer: gold still to spend, counting only rows that are not done. This is the same
  rule as the sheet's "STILL TO BUY".
- Only your own faction's version of the Blood/Venom row is shown.

- "Scan prices" button (AH open): searches each AH item via `C_AuctionHouse.SendSearchQuery`
  and stores the cheapest buyable unit price per realm and faction (`T05ShoppingPrices`).
  Any search result for our items is recorded too. The fresher of this and Auctionator wins.
- Clicking an AH row with the AH open opens Blizzard's buy page for it
  (`AuctionHouseFrame:SelectBrowseResult`) with the missing quantity set. You press Buy Now.

- Quest chain (`ns.CHAIN`, in Guide.lua, built from the guide's turn-ins):
  each row links to the quest that consumes it. Once turned in
  (`C_QuestLog.IsQuestFlaggedCompleted`), the row shows "Turned in" and stops counting.
  Rows for the quest you're on show "(on quest)".
- Header: "Step N/29: <next quest>", the step after the last one turned in.
- "Guide" button: a panel docked to the right with every step of the chain for your
  class and faction, opened at the step you're on, with map-pin buttons (TomTom if
  installed, else the game's own map pin). Data is `Guide.lua`, kept in this repo.
  Guide.lua is CC BY-NC-SA 4.0 (see its header); the panel shows the credit.

Out (add later only if needed):
- "Send to Auctionator" shopping-list export (`Auctionator.API.v1.CreateShoppingList`
  exists in the Forever build and is the cheap next step).
- Counting items still in the mailbox.
- The 8 Tier 0 pieces (the sheet leaves them out too).
- Minimap button, locales, options panel.

## Files

```
T05Shopping/
  T05Shopping.toc   ## Interface: 16001, SavedVariables: T05ShoppingDB, OptionalDeps: Auctionator
  Data.lua          the sheet as one Lua table
  T05Shopping.lua   counting, pricing, window, slash command
```

Install: symlink the repo into
`~/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/T05Shopping`
so edits show up after `/reload`.

## Data (Data.lua)

Prices are in gold, taken from the sheet (AH 21/11). They are only used when
Auctionator has no price.

| Section | Item | ID | Qty | Low | High | For |
|---|---|---|---|---|---|---|
| AH | Delicate Arcanite Converter | 16006 | 1 | 40 | 45 | The Ectoplasmic Distiller |
| AH | Greater Eternal Essence | 16203 | 4 | 2 | 3 | The Ectoplasmic Distiller |
| AH | Stonescale Oil | 13423 | 10 | 0 | 0 | The Ectoplasmic Distiller |
| AH | Dark Iron Bar | 11371 | 3 | 1 | 1.2 | Anthion's Strange Request |
| AH | Enchanted Leather | 12810 | 20 | 1 | 1.5 | Anthion's Strange Request |
| AH | Mooncloth | 14342 | 3 | 35 | 40 | Anthion's Strange Request |
| AH | Cured Rugged Hide | 15407 | 4 | 25 | 30 | Anthion's Strange Request |
| AH | Dark Rune | 20520 | 4 | 2 | 2 | The Instigator's Enchantment |
| AH | Large Brilliant Shard | 14344 | 8 | 2.5 | 3 | The Instigator's Enchantment |
| AH | Flask of Supreme Power | 13512 | 1 | 20 | 20 | Final Preparations |
| AH | Goblin Rocket Fuel | 9061 | 10 | 0.25 | 0.25 | Hunting for Ectoplasm (3 to 10 needed, 8 free from the previous quest) |
| Fee | An Earnest Proposition | none | 1 | 20 | 20 | Deliana / Mokvar |
| Fee | The Ectoplasmic Distiller | none | 1 | 40 | 40 | Mux Manascrambler, Gadgetzan |
| Fee | Fel Elemental Rod | none | 1 | 40 | 40 | Vi'el, Darkwhisper Gorge |
| Fee | Hallowed Brazier | none | 1 | 127 | 127 | Argent Dawn QM, Honored (guide estimate, unconfirmed) |
| Farm | Winterspring Blood Sample (Alliance) | 21928 | 15 | | | An Earnest Proposition |
| Farm | Silithus Venom Sample (Horde) | 22381 | 15 | | | An Earnest Proposition |
| Farm | Volcanic Ash | 22338 | 25 | | | The Ectoplasmic Distiller (Burning Steppes lava pools) |
| Farm | Ogre Warbeads | 21982 | 25 | | | Falrin's Vendetta (Dire Maul / BRS ogres) |
| Farm | Bloodkelp | 22094 | 20 | | | I See Alcaz Island In Your Future... |
| Farm | Blackrock Bracer | 22138 | 40 | | | Final Preparations (BRS orcs) |

Where the IDs came from: CraftersJournal `Data/` and QuestieDB `support/DropTables/`.
Note: 16000 is Thorium Tube, not the Converter (16006).

Row shape:
```lua
{ sec = "ah", id = 16006, qty = 1, lo = 40, hi = 45, quest = "The Ectoplasmic Distiller" },
{ sec = "fee", key = "brazier", name = "Hallowed Brazier", qty = 1, lo = 127, hi = 127, note = "..." },
{ sec = "farm", id = 21928, qty = 15, faction = "Alliance", quest = "An Earnest Proposition" },
```
Fee rows have no `id`, so they use `key` for the saved checkbox.

## Pricing

1. If `Auctionator.API.v1.GetAuctionPriceByItemID("T05Shopping", id)` returns a price,
   use it, with `GetAuctionAgeByItemID` shown as "(Nd old)".
2. Otherwise show the sheet's `lo` to `hi` range in grey.
3. Fee rows always use the sheet price.

Both API calls go through `pcall`, because Auctionator raises an error on bad input.
The Forever build of Auctionator has no `RegisterForDBUpdate` (the hook CraftSim uses
on retail), so the window re-renders on `OnShow`, `AUCTION_HOUSE_CLOSED` (after a scan)
and `BAG_UPDATE_DELAYED` while it is visible.

The footer shows a single number when every price is live, and a low to high range
when any sheet fallback is in the sum.

## Window

- One movable frame (`BasicFrameTemplateWithInset`) with a scroll frame, and its
  position saved in `T05ShoppingDB`.
- Rows are a pooled list of buttons: icon, name, `have/need`, price, total, quest text.
  Done rows are green and sorted to the bottom of their section.
- Hovering a row shows the item tooltip (`GameTooltip:SetItemByID`).
- Shift-clicking a row puts the item link into chat or the AH search box (default
  `HandleModifiedItemClick`), which is how you buy it quickly.
- Item names and icons load asynchronously (`Item:CreateFromItemID(id):ContinueOnItemLoad`),
  so rows fill in on first open.

## Saved variables

```lua
T05ShoppingDB = { pos = {...}, chars = { ["Name-Realm"] = { done = { brazier = true } } } }
```

## Steps

1. Write the `.toc`, `Data.lua` and the slash command printing "loaded". `/reload`
   and check it shows up in the AddOns list.
2. Pricing + counting logic, with the output printed to chat via `/t05 dump`.
   Compare it against the totals in "Check" below.
3. The window: sections, rows, footer.
4. Manual checkboxes + SavedVariables.
5. Events and refresh. Test by buying or moving an item and watching the row update.

## Check

`/t05 dump` is the runnable check: with an empty character and no Auctionator data it
must print 553.50g to 612.10g. Any difference means the data or the sum is wrong.
(The sheet says 552.25g for the low end because it counts 5 Rocket Fuel there; this
plan counts 10 on both ends.)

## Open questions

- Goblin Rocket Fuel: count it as 10 (the worst case) or 2 (10 minus the 8 free)?
  The plan uses 10.
- Should the Tier 0 pieces be listed as "have it / don't" rows, without prices?
