-- Offline check of the totals: lua test.lua (from the repo root)
-- Empty bags, no Auctionator: must equal the spreadsheet (553.50g to 612.10g).
local ns = {}
UnitFactionGroup = function() return "Alliance" end
local bags = {}
C_Item = { GetItemCount = function(id) return bags[id] or 0 end }
GetRealmName = function() return "Test" end
local completed, onQuest = {}, {}
C_QuestLog = {
  IsQuestFlaggedCompleted = function(id) return completed[id] or false end,
  IsOnQuest = function(id) return onQuest[id] or false end,
}
local now = 1700000000
time = function() return now end
UnitClass = function() return "Warrior", "WARRIOR" end
assert(loadfile("Data.lua"))("T05Shopping", ns)
assert(loadfile("Guide.lua"))("T05Shopping", ns)
assert(loadfile("T05Shopping.lua"))("T05Shopping", ns)

local _, t = ns.Compute({})
assert(t.leftLo == 5535000 and t.leftHi == 6121000, ("left %d / %d"):format(t.leftLo, t.leftHi))
assert(t.count == 20 and t.done == 0, "count " .. t.count) -- 21 rows, one is Horde-only
assert(t.sheet, "range shown while sheet prices are in the sum")

-- Have 2 of 3 Mooncloth (35g each) + a Hallowed Brazier in the bags (127g): 197g less left
bags[14342], bags[22014] = 2, 1
local _, t2 = ns.Compute({})
bags[22014] = nil
assert(t2.leftLo == 5535000 - 700000 - 1270000, "partial " .. t2.leftLo)

-- More than needed never goes negative; the row counts as done
bags[14342] = 9
local bySec, t3 = ns.Compute({})
assert(t3.done == 1 and bySec.ah[#bySec.ah].it.id == 14342, "done row sorted last")

-- Quests: a turned-in step's rows count as done even with empty bags
bags[14342] = 0
local p0 = ns.Progress()
assert(p0.n == 1 and p0.step.name == "An Earnest Proposition" and p0.total == 29, "start of chain")
completed[8912] = true -- Alliance Warrior's An Earnest Proposition
completed[8947] = true -- Anthion's Strange Request (skipped steps in between don't matter)
onQuest[8948] = true
local p1 = ns.Progress()
assert(p1.n == 13 and p1.step.name == "Anthion's Old Friend" and p1.active, "next step after last turn-in: " .. p1.n)
local bySecQ, tq = ns.Compute({})
-- Earnest: 20g fee; Strange Request mats: 3 + 20 + 105 + 100 = 228g
assert(tq.leftLo == 5535000 - 200000 - 2280000, "turned-in quests drop out of gold left: " .. tq.leftLo)
local blood
for _, r in ipairs(bySecQ.farm) do if r.it.id == 21928 then blood = r end end
assert(blood.turnedIn and blood.done and blood.missing == 0, "farm row for a turned-in quest")
completed[8912], completed[8947], onQuest[8948] = nil, nil, nil

-- Conditions
assert(ns.Cond("", "Horde", "Mage") and ns.Cond("Alliance Druid", "Alliance", "Druid"))
assert(not ns.Cond("Alliance Druid", "Horde", "Druid") and not ns.Cond("!Rogue", "Horde", "Rogue"))
assert(ns.Cond("Warrior/Paladin/Hunter", "Horde", "Hunter") and not ns.Cond("Warrior/Paladin", "Horde", "Mage"))

-- The guide data: all 4 parts, filtered to an Alliance Warrior, no other-faction NPCs
local steps, cur = ns.GuideSteps()
local parts, text = {}, {}
for _, st in ipairs(steps) do parts[st.part] = true; text[#text + 1] = st.text end
text = table.concat(text, "\n")
assert(parts[1] and parts[2] and parts[3] and parts[4], "all four parts")
assert(text:find("Deliana", 1, true) and not text:find("Mokvar", 1, true), "Alliance only")
assert(text:find("Bracers of Valor", 1, true) and not text:find("Wildheart Bracers", 1, true), "Warrior pieces only")
assert(not text:find("RXP_", 1, true) and not text:find("Tarnished Undermine", 1, true), "no raw color codes, no SoD lines")
assert(cur == 1 and not steps[1].past, "fresh character starts at step 1")
-- Quest IDs follow your class and faction (Alliance Warrior here)
assert(ns.QuestID("An Earnest Proposition") == 8912 and ns.QuestID("Three Kings of Flame") == 8961)
assert(ns.QuestLink("Three Kings of Flame") == "|cffffff00|Hquest:8961:60|h[Three Kings of Flame]|h|r")
assert(ns.QuestLink("Vendor item") == "Vendor item", "non-quests stay plain")
assert(text:find("|Hquest:8912:60|h[An Earnest Proposition]|h", 1, true), "guide turn-ins are quest links")
-- Vendor items aren't priced from the AH
assert(select(5, ns.Price({ sec = "fee", id = 22014, lo = 127, hi = 127 })) == "sheet")

-- WoW Forever: Three Kings of Flame uses the Ash of Asharell, no Silithus detour
assert(text:find("Executor Asharell", 1, true) and not text:find("Cinder of Cynders", 1, true), "Forever Three Kings")
assert(not text:find("Aurel Goldleaf", 1, true) and not text:find("Twilight Cultist", 1, true), "Silithus detour removed")
-- The Hallowed Brazier row ticks itself off once Three Kings of Flame is turned in
completed[8961] = true
local bySecB = ns.Compute({})
local brazier
for _, r in ipairs(bySecB.fee) do if r.it.key == "brazier" then brazier = r end end
assert(brazier.turnedIn and brazier.missing == 0, "brazier done with its quest")
completed[8961] = nil
-- Turning in An Earnest Proposition moves the guide past it
completed[8912] = true
local steps2, cur2 = ns.GuideSteps()
assert(cur2 > 1 and steps2[cur2 - 1].past and steps2[cur2].part == 2, "after Earnest: Part 2, got part " .. steps2[cur2].part)
completed[8912] = nil

-- Live Auctionator price wins over the sheet
Auctionator = { API = { v1 = {
  GetAuctionPriceByItemID = function(_, id) return id == 16006 and 300000 or nil end,
  GetAuctionAgeByItemID = function() return 5 end,
} } }
local lo, hi, kind, _, src = ns.Price(ns.ITEMS[1])
assert(lo == 300000 and hi == 300000 and kind == "stale" and src == "Auctionator", kind)

-- Our own scan, newer than Auctionator's 5-day-old price, wins
ns.Record(16006, 250000)
lo, _, kind, _, src = ns.Price(ns.ITEMS[1])
assert(lo == 250000 and kind == "live" and src == "scan", src)
-- ...until it is older than Auctionator's
now = now + 6 * 86400
lo, _, _, _, src = ns.Price(ns.ITEMS[1])
assert(lo == 300000 and src == "Auctionator", src)
-- No Auctionator at all: our scan alone, flagged stale after 3 days
Auctionator = nil
lo, _, kind, _, src = ns.Price(ns.ITEMS[1])
assert(lo == 250000 and kind == "stale" and src == "scan", kind)
-- Prices are per realm and faction
UnitFactionGroup = function() return "Horde" end
assert(select(5, ns.Price(ns.ITEMS[1])) == "sheet", "Horde has its own AH")

assert(ns.Money(25050) == "2|cffffd700g|r 50|cffc7c7cfs|r")
print("ok")
