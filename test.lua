-- Offline check of the totals: lua test.lua (from the repo root)
-- Empty bags, no Auctionator: must equal the spreadsheet (553.50g to 612.10g).
local ns = {}
UnitFactionGroup = function() return "Alliance" end
local bags = {}
C_Item = { GetItemCount = function(id) return bags[id] or 0 end }
GetRealmName = function() return "Test" end
local completed, onQuest, objectives = {}, {}, {}
C_QuestLog = {
  IsQuestFlaggedCompleted = function(id) return completed[id] or false end,
  IsOnQuest = function(id) return onQuest[id] or false end,
  GetQuestObjectives = function(id) return objectives[id] end,
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
completed[84154] = true -- Alliance Warrior's An Earnest Proposition
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
completed[84154], completed[8947], onQuest[8948] = nil, nil, nil

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
assert(ns.QuestID("An Earnest Proposition") == 84154 and ns.QuestID("Three Kings of Flame") == 8961)
assert(ns.QuestLink("Three Kings of Flame") == "|cffffff00|Hquest:8961:60|h[Three Kings of Flame]|h|r")
assert(ns.QuestLink("Vendor item") == "Vendor item", "non-quests stay plain")
assert(text:find("|Hquest:84154:60|h[An Earnest Proposition]|h", 1, true), "guide turn-ins are quest links")
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
completed[84154] = true
local steps2, cur2 = ns.GuideSteps()
assert(cur2 > 1 and steps2[cur2 - 1].past and steps2[cur2].part == 2, "after Earnest: Part 2, got part " .. steps2[cur2].part)
completed[84154] = nil

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

-- Components of Importance: all four versions show until you pick one; then the
-- other three are hidden (here: the Brilliant Sword version in both rounds)
local function GuideText()
  local all = {}
  for _, st in ipairs(ns.GuideSteps()) do all[#all + 1] = st.text end
  return table.concat(all, "\n")
end
assert(GuideText():find("Hive'Regal", 1, true), "no version picked: all shown")
completed[8964], onQuest[8987] = true, true
local g = GuideText()
assert(g:find("Brilliant Sword of Zealotry", 1, true) and g:find("Jarien", 1, true), "own version shown")
assert(not g:find("Hive'Regal", 1, true) and not g:find("Isalien", 1, true) and not g:find("Kormok", 1, true), "other versions hidden")
completed[8964], onQuest[8987] = nil, nil
-- Just turned in Three Kings of Flame, on the Brilliant Sword version: next stop Tyr's Hand
completed[8961], onQuest[8964] = true, true
local steps, cur = ns.GuideSteps()
assert(steps[cur].text:find("Tyr's Hand", 1, true), "next step: " .. steps[cur].text)
completed[8961], onQuest[8964] = nil, nil

assert(ns.Money(25050) == "2|cffffd700g|r 50|cffc7c7cfs|r")
print("ok")

-- Forever renumbered the class quests (8912 -> 84154): being on the new one
-- ticks the accept step, and a Classic-era turn-in still counts for the chain
UnitFactionGroup = function() return "Alliance" end
onQuest[84154] = true
local gs = ns.GuideSteps()
assert(gs[3].done and gs[3].past, "on Forever's An Earnest Proposition")
onQuest[84154], completed[8912] = nil, true
assert(ns.Progress().n == 2, "Classic 8912 still counts as done")
completed[8912] = nil
print("ok")

-- Item steps tick off from the bags: 25 Volcanic Ash completes "Pick up 25 Volcanic Ash"
local function AshStep()
  for _, st in ipairs(ns.GuideSteps()) do if st.text:find("Volcanic Ash") then return st end end
end
bags[22338] = 24
assert(not AshStep().done, "24 ash is not enough")
bags[22338] = 25
assert(AshStep().done and AshStep().past, "25 ash ticks the step")
for _, st in ipairs(ns.GuideSteps()) do
  if st.text:find("Volcanic Ash") then break end
  assert(not st.past, "ash farmed early must not tick earlier steps: " .. st.text:sub(1, 40))
end
bags[22338] = nil

-- Objective steps tick off from the quest log: 2 of 3 ectoplasm types done
local function Step(name)
  for _, st in ipairs(ns.GuideSteps()) do if st.text:find("Collect 12 |cff00d1ff" .. name) then return st end end
end
objectives[8924] = { { finished = true }, { finished = true }, { finished = false } }
assert(not Step("Scorched").done, "objectives of a quest you're not on don't count")
onQuest[8924] = true
assert(Step("Scorched").done and Step("Frozen").done, "finished objectives tick")
assert(not Step("Stable").done, "unfinished objective stays open")
objectives[8924], onQuest[8924], completed[8924] = nil, nil, true
assert(Step("Stable").done, "turned in counts as done")
completed[8924] = nil

-- Every need names a real chain quest (a typo would never tick)
for _, s in ipairs(ns.GUIDE) do
  for _, name in ipairs(s.need or {}) do assert(ns.STEP[name], "unknown need: " .. name) end
end

-- On In Search of Anthion: the accept ticks, but Part 3 gear and mats you
-- don't have yet stay open, until the quest that uses them is turned in
onQuest[8929] = true
local function Find(pat)
  for _, st in ipairs(ns.GuideSteps()) do if st.text:find(pat, 1, true) then return st end end
end
assert(Find("In Search of Anthion").past, "accept ticks")
assert(not Find("Legplates of Valor").past and not Find("Spaulders of Valor").past, "gear stays open")
for _, st in ipairs(ns.GuideSteps()) do
  if st.part == 3 and st.text:find("You need") then assert(not st.past, "mats stay open") end
end
completed[8959] = true -- Alliance Warrior Anthion's Parting Words turned in
assert(Find("Legplates of Valor").past, "turned in: gear ticks")
onQuest[8929], completed[8959] = nil, nil
