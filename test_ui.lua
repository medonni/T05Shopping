-- Offline smoke test of the window: lua5.1 test_ui.lua (from the repo root)
-- Fake frames accept any method, so this catches nil errors and typos in the UI code
-- paths, not layout. Layout still needs a look in game.
local ns = {}
local Stub
local function New(name)
  local o = { _scripts = {}, _shown = true, _name = name }
  return setmetatable(o, Stub)
end
Stub = { __index = function(o, k)
  local m = rawget(Stub, k)
  if m ~= nil then return m end
  if k:find("^%u") then return function() return New() end end -- any other method: returns a fresh stub
  -- (lowercase: a field the addon sets itself, nil until then, like on real frames)
end }
function Stub.SetScript(o, e, fn) o._scripts[e] = fn end
function Stub.GetScript(o, e) return o._scripts[e] end
function Stub.Show(o) local was = o._shown; o._shown = true; if not was and o._scripts.OnShow then o._scripts.OnShow(o) end end
function Stub.Hide(o) o._shown = false end
function Stub.IsShown(o) return o._shown end
function Stub.SetShown(o, v) if v then o:Show() else o:Hide() end end
function Stub.GetName(o) return o._name end
function Stub.SetText(o, t) o._text = t end
function Stub.GetText(o) return o._text end
function Stub.RegisterEvent() end
Stub.TitleText = false -- (a field on real frames, not a method)
function Stub.GetStringHeight() return 26 end
function Stub.GetVerticalScrollRange() return 400 end

local frames = {}
CreateFrame = function(_, name) local o = New(name); frames[#frames + 1] = o; return o end
UIParent, GameTooltip, Minimap = New(), New(), New()
Minimap.GetCenter = function() return 100, 100 end
Minimap.GetEffectiveScale = function() return 1 end
GetCursorPosition = function() return 100, 180 end -- straight above the minimap
UISpecialFrames, SlashCmdList = {}, {}
tinsert = table.insert
UnitFactionGroup = function() return "Horde" end
GetItemCount = function(id) return id == 20520 and 4 or 0 end -- Dark Runes done
GetItemInfo = function(id) if id ~= 22138 then return "Item" .. id, "|Hitem:" .. id .. "|h", 2 end end -- one not loaded
GetItemIcon = function() return 134400 end
GetCoinTextureString = function(c) return "C" .. c end
ITEM_QUALITY_COLORS = { [2] = { hex = "|cff1eff00" } }
IsModifiedClick = function() return true end
local linked
HandleModifiedItemClick = function(l) linked = l end
GameTooltip_Hide = function() end
StaticPopupDialogs, CLOSE = {}, "Close"
local popup
StaticPopup_Show = function(name, _, _, data) popup = { name = name, data = data } end
local chatLink
ChatEdit_InsertLink = function(l) chatLink = l; return true end
C_Timer = { After = function(_, fn) fn() end }
GetRealmName = function() return "Test" end
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return id == 8920 end, IsOnQuest = function() return false end }
UnitClass = function() return "Warrior", "WARRIOR" end
local pinned
TomTom = { AddWaypoint = function(_, map, x, y) pinned = { map, x, y } end }
time = os.time
Enum = { AuctionHouseSortOrder = { Price = 0 } }
local fire -- set once the addon frame exists
local listed = { [14342] = { { unitPrice = 330000, quantity = 5, numOwnerItems = 5 }, { unitPrice = 360000, quantity = 2 } } }
local queries = 0
C_AuctionHouse = {
  MakeItemKey = function(id) return { itemID = id } end,
  IsThrottledMessageSystemReady = function() return true end,
  SendSearchQuery = function(key) queries = queries + 1; fire("COMMODITY_SEARCH_RESULTS_UPDATED", key.itemID) end,
  GetNumCommoditySearchResults = function(id) return listed[id] and #listed[id] or 0 end,
  GetCommoditySearchResultInfo = function(id, i) return listed[id][i] end,
  GetNumItemSearchResults = function() return 0 end,
}
local selected, qtySet
AuctionHouseFrame = New("AuctionHouseFrame")
AuctionHouseFrame._shown = false
AuctionHouseFrame.SelectBrowseResult = function(_, r) selected = r.itemKey.itemID; fire("COMMODITY_SEARCH_RESULTS_UPDATED", selected) end
AuctionHouseFrame.CommoditiesBuyFrame = New()
AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay = { SetQuantitySelected = function(_, q) qtySet = q end }

assert(loadfile("Data.lua"))("T05Shopping", ns)
assert(loadfile("Guide.lua"))("T05Shopping", ns)
assert(loadfile("T05Shopping.lua"))("T05Shopping", ns)

local f = frames[1]
fire = function(e, a) f._scripts.OnEvent(f, e, a) end
assert(f:GetName() == "T05ShoppingFrame" and UISpecialFrames[1] == "T05ShoppingFrame")
f._scripts.OnEvent(f, "ADDON_LOADED", "T05Shopping")
SlashCmdList.T05SHOPPING("") -- open: runs Render
assert(f:IsShown(), "slash opens the window")

-- Find the rendered item rows (buttons that got a row assigned)
local rows = {}
for _, o in ipairs(frames) do if rawget(o, "r") then rows[#rows + 1] = o end end
assert(#rows == 20, "rows rendered: " .. #rows) -- Horde: Alliance-only row hidden

-- Hover every row (tooltips) and shift-click the item rows
for _, b in ipairs(rows) do
  b._scripts.OnEnter(b)
  if b.r.it.id then b._scripts.OnClick(b) end
end
assert(linked, "shift-click linked an item")

-- Click each fee once, wherever it sits now (paid rows re-sort to the bottom)
local function RowFor(key)
  for _, b in ipairs(rows) do if b.r.it.key == key then return b end end
end
for _, k in ipairs({ "earnest", "distiller" }) do
  local b = RowFor(k)
  b._scripts.OnClick(b)
  assert(T05ShoppingDB.done[k], "fee toggled: " .. k)
end
local b = RowFor("distiller")
b._scripts.OnClick(b) -- second click unpays
assert(not T05ShoppingDB.done.distiller, "fee untoggles")
-- Rod and brazier count from bags now: clicking them toggles nothing
b = RowFor("brazier")
b._scripts.OnClick(b)
assert(not T05ShoppingDB.done.brazier, "brazier is an item row")

-- Quest links on a row: hover tooltip, click = Wowhead popup, shift-click = chat;
-- and clicking the link must not also open the buy window
b = RowFor("brazier")
assert(b.sub._text:find("|Hquest:8961:60|h[Three Kings of Flame]|h", 1, true), "row quest is a link")
b._scripts.OnHyperlinkEnter(b, "quest:8961:60", "[Three Kings of Flame]")
assert(b.overLink, "hovering a link")
IsModifiedClick = function() return false end
b._scripts.OnHyperlinkClick(b, "quest:8961:60", "|cffffff00|Hquest:8961:60|h[Three Kings of Flame]|h|r")
assert(popup and popup.name == "T05SHOPPING_URL" and popup.data == "https://www.wowhead.com/forever/quest=8961", "wowhead popup")
local dlg = StaticPopupDialogs.T05SHOPPING_URL
local eb = New(); local box = { editBox = eb }
dlg.OnShow(box, popup.data)
assert(eb:GetText() == popup.data, "url in the box")
eb:SetText("typed"); dlg.EditBoxOnTextChanged(eb)
assert(eb:GetText() == popup.data, "box is read-only")
IsModifiedClick = function() return true end
b._scripts.OnHyperlinkClick(b, "quest:8961:60", "|cffffff00|Hquest:8961:60|h[Three Kings of Flame]|h|r")
assert(chatLink and chatLink:find("Hquest:8961"), "shift-click links in chat")
b._scripts.OnHyperlinkLeave(b)
assert(not b.overLink, "left the link")

-- Guide panel: opens at the current part (Horde Warrior turned in Earnest: Part 2),
-- pages between parts, and map pins go to TomTom
local guideButton, guide
for _, o in ipairs(frames) do
  if o._text == "Guide" then guideButton = o end
  if o:GetName() == "T05ShoppingGuideFrame" then guide = o end
end
guideButton._scripts.OnClick(guideButton)
assert(guide:IsShown() and guide.part == 2, "guide opens at Part 2")
local pins = 0
for _, o in ipairs(frames) do
  if rawget(o, "go") then
    pins = pins + 1
    o._scripts.OnEnter(o)
    o._scripts.OnClick(o)
  end
end
assert(pins > 0 and pinned and pinned[1] > 1000 and pinned[2] < 1, "waypoint sent to TomTom")
fire("QUEST_TURNED_IN", 8920) -- repaints both panels
guideButton._scripts.OnClick(guideButton)
assert(not guide:IsShown(), "guide toggles closed")

-- Events repaint without error; bag change shows up
f._scripts.OnEvent(f, "BAG_UPDATE_DELAYED")
f._scripts.OnEvent(f, "AUCTION_HOUSE_CLOSED")
-- Own scan: AH closed does nothing; open, it queries every AH item and stores the cheapest buyable price
local scanButton
for _, o in ipairs(frames) do if o._text == "Scan prices" then scanButton = o end end
scanButton._scripts.OnClick(scanButton)
assert(queries == 0, "no scan with the AH closed")
AuctionHouseFrame._shown = true
fire("AUCTION_HOUSE_SHOW")
scanButton._scripts.OnClick(scanButton)
assert(queries == 11, "queried every AH item: " .. queries)
local rec = T05ShoppingPrices["Test-Horde"][14342]
assert(rec and rec.p == 360000, "skipped own listing, kept cheapest buyable")
assert(select(5, ns.Price(ns.ITEMS[6])) == "scan", "scan price used")
assert(scanButton._text == "Scan prices", "button resets after the scan")

-- Plain click on an AH row opens Blizzard's buy page with the missing quantity
IsModifiedClick = function() return false end
for _, b in ipairs(rows) do
  if b.r.it.id == 14342 then b._scripts.OnClick(b) end
end
assert(selected == 14342 and qtySet == 3, "buy window for 3 Mooncloth, got " .. tostring(qtySet))
-- Minimap button: named Button on the Minimap (what EllesmereUI collects), toggles,
-- drags around the edge, /t05 minimap hides it; Blizzard addon menu toggles too
local mm
for _, o in ipairs(frames) do if o:GetName() == "T05ShoppingMinimapButton" then mm = o end end
assert(mm, "minimap button exists")
local was = f:IsShown()
mm._scripts.OnClick(mm)
assert(f:IsShown() ~= was, "minimap click toggles")
T05Shopping_OnAddonCompartmentClick()
assert(f:IsShown() == was, "compartment click toggles")
mm._scripts.OnEnter(mm)
T05Shopping_OnAddonCompartmentEnter("T05Shopping", New())
mm._scripts.OnDragStart(mm)
mm._scripts.OnUpdate(mm)
assert(math.abs(T05ShoppingDB.minimapAngle - 90) < 0.01, "dragged to the top: " .. T05ShoppingDB.minimapAngle)
mm._scripts.OnDragStop(mm)
SlashCmdList.T05SHOPPING("minimap")
assert(not mm:IsShown() and T05ShoppingDB.hideMinimap, "hidden")
SlashCmdList.T05SHOPPING("minimap")
assert(mm:IsShown() and not T05ShoppingDB.hideMinimap, "shown again")
SlashCmdList.T05SHOPPING("dump")
SlashCmdList.T05SHOPPING("")
assert(not f:IsShown(), "slash toggles closed")
print("ok")
