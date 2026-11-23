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

-- The quest chain in RestedXP's order (RXPGuides/Guides/Classic-0.5.lua, "Set Guide"
-- Parts 1-4). ids = every class/faction variant; a step counts as done when any of
-- them is turned in. Items above link to a step by their `quest` name.
-- (Left out: the guide's optional Aurel Goldleaf / Dukes of the Council / Medallion of
-- Station, which unrelated play can complete.)
ns.CHAIN = {
  { part = 1, name = "An Earnest Proposition", ids = { 8905, 8906, 8907, 8908, 8909, 8910, 8911, 8912, 8913, 8914, 8915, 8916, 8917, 8918, 8919, 8920 } },
  { part = 2, name = "A Supernatural Device", ids = { 8922, 8923 } },
  { part = 2, name = "The Ectoplasmic Distiller", ids = { 8921 } },
  { part = 2, name = "Hunting for Ectoplasm", ids = { 8924 } },
  { part = 2, name = "A Portable Power Source", ids = { 8925 } },
  { part = 2, name = "A Shifty Merchant", ids = { 8928 } },
  { part = 2, name = "Return to Deliana", ids = { 8977 }, faction = "Alliance" },
  { part = 2, name = "Return to Mokvar", ids = { 8978 }, faction = "Horde" },
  { part = 2, name = "Just Compensation", ids = { 8926, 8927, 8931, 8932, 8933, 8934, 8935, 8936, 8937, 8938, 8939, 8940, 8941, 8942, 8943, 8944 } },
  { part = 3, name = "In Search of Anthion", ids = { 8929, 8930 } },
  { part = 3, name = "Dead Man's Plea", ids = { 8945 } },
  { part = 3, name = "Proof of Life", ids = { 8946 } },
  { part = 3, name = "Anthion's Strange Request", ids = { 8947 } },
  { part = 3, name = "Anthion's Old Friend", ids = { 8948 } },
  { part = 3, name = "Falrin's Vendetta", ids = { 8949 } },
  { part = 3, name = "The Instigator's Enchantment", ids = { 8950 } },
  { part = 3, name = "The Challenge", ids = { 9015 } },
  { part = 3, name = "Anthion's Parting Words", ids = { 8951, 8952, 8953, 8954, 8955, 8956, 8957, 8958, 8959, 9016, 9017, 9018, 9019, 9020, 9021, 9022 } },
  { part = 4, name = "Bodley's Unfortunate Fate", ids = { 8960 } },
  { part = 4, name = "Three Kings of Flame", ids = { 8961 } },
  { part = 4, name = "Components of Importance", ids = { 8962, 8963, 8964, 8965 } },
  { part = 4, name = "The Left Piece of Lord Valthalak's Amulet", ids = { 8966, 8967, 8968, 8969 } },
  { part = 4, name = "I See Alcaz Island In Your Future...", ids = { 8970 } },
  { part = 4, name = "More Components of Importance", ids = { 8985, 8986, 8987, 8988 } },
  { part = 4, name = "The Right Piece of Lord Valthalak's Amulet", ids = { 8989, 8990, 8991, 8992 } },
  { part = 4, name = "Final Preparations", ids = { 8994 } },
  { part = 4, name = "Mea Culpa, Lord Valthalak", ids = { 8995 } },
  { part = 4, name = "Return to Bodley", ids = { 8996 } },
  { part = 4, name = "Back to the Beginning", ids = { 8997, 8998 } },
  { part = 4, name = "Saving the Best for Last", ids = { 8999, 9000, 9001, 9002, 9003, 9004, 9005, 9006, 9007, 9008, 9009, 9010, 9011, 9012, 9013, 9014 } },
}
ns.PART_NAMES = { "Bracers", "Belt & Gloves", "Pants, Shoulders & Boots", "Helm & Chest" }
ns.STEP = {}
for i, s in ipairs(ns.CHAIN) do s.index = i; ns.STEP[s.name] = s end
