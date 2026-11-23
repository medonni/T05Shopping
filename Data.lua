local _, ns = ...

-- From wow_forever_t0.5_shopping_list.xlsx. lo/hi = gold per unit (AH 21/11), only
-- used when Auctionator has no price. IDs checked against CraftersJournal and QuestieDB.
ns.SECTIONS = {
  { key = "ah", title = "Auction House" },
  { key = "fee", title = "Quest fees & vendor" },
  { key = "farm", title = "Farm" },
}

ns.ITEMS = {
  { sec = "ah", id = 16006, qty = 1, lo = 40, hi = 45, quest = "The Ectoplasmic Distiller" },
  { sec = "ah", id = 16203, qty = 4, lo = 2, hi = 3, quest = "The Ectoplasmic Distiller" },
  { sec = "ah", id = 13423, qty = 10, lo = 0, hi = 0, quest = "The Ectoplasmic Distiller" },
  { sec = "ah", id = 11371, qty = 3, lo = 1, hi = 1.2, quest = "Anthion's Strange Request" },
  { sec = "ah", id = 12810, qty = 20, lo = 1, hi = 1.5, quest = "Anthion's Strange Request" },
  { sec = "ah", id = 14342, qty = 3, lo = 35, hi = 40, quest = "Anthion's Strange Request" },
  { sec = "ah", id = 15407, qty = 4, lo = 25, hi = 30, quest = "Anthion's Strange Request" },
  { sec = "ah", id = 20520, qty = 4, lo = 2, hi = 2, quest = "The Instigator's Enchantment" },
  { sec = "ah", id = 14344, qty = 8, lo = 2.5, hi = 3, quest = "The Instigator's Enchantment" },
  { sec = "ah", id = 13512, qty = 1, lo = 20, hi = 20, quest = "Final Preparations" },
  -- ponytail: worst case 10; the previous quest gives up to 8 free
  { sec = "ah", id = 9061, qty = 10, lo = 0.25, hi = 0.25, quest = "Hunting for Ectoplasm", note = "3 to 10 needed; up to 8 come free from the previous quest" },

  { sec = "fee", key = "earnest", name = "An Earnest Proposition", lo = 20, hi = 20, quest = "An Earnest Proposition", where = "Deliana (Ironforge) / Mokvar (Orgrimmar)" },
  { sec = "fee", key = "distiller", name = "The Ectoplasmic Distiller", lo = 40, hi = 40, quest = "The Ectoplasmic Distiller", where = "Mux Manascrambler, Gadgetzan" },
  { sec = "fee", key = "rod", id = 21939, name = "Fel Elemental Rod", lo = 40, hi = 40, quest = "A Shifty Merchant", where = "Vi'el, Darkwhisper Gorge" },
  { sec = "fee", key = "brazier", id = 22014, name = "Hallowed Brazier", lo = 127, hi = 127, quest = "Three Kings of Flame", where = "Argent Dawn QM, Honored", note = "Guides disagree: 120g (RestedXP, Warcraft Tavern) or about 127g (ConquestCapped). Check the vendor." },

  { sec = "farm", id = 21928, qty = 15, faction = "Alliance", quest = "An Earnest Proposition", where = "Winterspring" },
  { sec = "farm", id = 22381, qty = 15, faction = "Horde", quest = "An Earnest Proposition", where = "Silithus" },
  { sec = "farm", id = 22338, qty = 25, quest = "The Ectoplasmic Distiller", where = "Burning Steppes lava pools" },
  { sec = "farm", id = 21982, qty = 25, quest = "Falrin's Vendetta", where = "Dire Maul / BRS ogres" },
  { sec = "farm", id = 22094, qty = 20, quest = "I See Alcaz Island In Your Future...", where = "Alcaz Island naga" },
  { sec = "farm", id = 22138, qty = 40, quest = "Final Preparations", where = "BRS orcs" },
}

-- (The quest chain, ns.CHAIN / ns.STEP, is generated into Guide.lua by tools/yoink_rxp.py)
ns.PART_NAMES = { "Bracers", "Belt & Gloves", "Pants, Shoulders & Boots", "Helm & Chest" }
