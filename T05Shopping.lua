local ADDON, ns = ...

---------------------------------------------------------------------------
-- Logic (no frames: test.lua runs this part outside the game)
---------------------------------------------------------------------------
local GOLD = 10000
local STALE_DAYS = 3 -- an Auctionator price older than this is shown as stale
local GetItemInfo, GetItemCount = C_Item.GetItemInfo, C_Item.GetItemCount

local function Round(x) return math.floor(x + 0.5) end

-- Our own scan results, per realm and faction (each faction has its own AH):
-- T05ShoppingPrices["Realm-Alliance"][itemID] = { p = copper per unit, t = time() }
function ns.PriceDB()
  T05ShoppingPrices = T05ShoppingPrices or {}
  local key = (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?")
  T05ShoppingPrices[key] = T05ShoppingPrices[key] or {}
  return T05ShoppingPrices[key]
end

function ns.Record(id, unit)
  if unit and unit > 0 then ns.PriceDB()[id] = { p = unit, t = time() } end
end

local function AuctionatorPrice(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not api then return nil end
  -- (pcall: Auctionator raises on bad input instead of returning nil)
  local ok, p = pcall(api.GetAuctionPriceByItemID, ADDON, id)
  if not (ok and type(p) == "number" and p > 0) then return nil end
  local okAge, age = pcall(api.GetAuctionAgeByItemID, ADDON, id)
  return p, okAge and type(age) == "number" and age or nil
end

-- Copper per unit: lo, hi, kind ("live" | "stale" | "sheet"), age in days, source
-- ("scan" | "Auctionator" | "sheet"). The fresher of our scan and Auctionator wins.
-- Farm rows: nil
function ns.Price(it)
  if it.sec == "farm" then return nil end
  if it.id and it.sec == "ah" then
    local own = ns.PriceDB()[it.id]
    local ownAge = own and math.floor((time() - own.t) / 86400)
    local p, age = AuctionatorPrice(it.id)
    local src = "Auctionator"
    if own and (not p or (age and ownAge <= age)) then p, age, src = own.p, ownAge, "scan" end
    if p then return p, p, (age and age > STALE_DAYS) and "stale" or "live", age, src end
  end
  return Round(it.lo * GOLD), Round(it.hi * GOLD), "sheet", nil, "sheet"
end

-- Quest state of a chain step: "done" (any variant turned in), "active" (in your
-- quest log) or nil
local IsCompleted, IsOnQuest = C_QuestLog.IsQuestFlaggedCompleted, C_QuestLog.IsOnQuest

function ns.QuestStatus(step)
  if not step then return nil end
  for _, id in ipairs(step.ids) do if IsCompleted(id) then return "done" end end
  for _, id in ipairs(step.ids) do if IsOnQuest(id) then return "active" end end
  return nil
end

-- Where you are in the chain: { step (next to do, nil when finished), n, total, active }.
-- "Next" = the step after the last one turned in, so optional steps you skipped
-- don't hold you back
function ns.Progress()
  local faction = UnitFactionGroup("player")
  local steps = {}
  for _, s in ipairs(ns.CHAIN) do
    if not s.faction or s.faction == faction then steps[#steps + 1] = s end
  end
  local last = 0
  for i, s in ipairs(steps) do
    if ns.QuestStatus(s) == "done" then last = i end
  end
  local nextStep = steps[last + 1]
  return { step = nextStep, n = last + 1, total = #steps, active = ns.QuestStatus(nextStep) == "active" }
end

-- Step condition ("Alliance Druid", "Warrior/Paladin", "!Rogue"): every
-- space-separated token must match; "/" means any of; "!" negates
function ns.Cond(cond, faction, class)
  if not cond or cond == "" then return true end
  for token in cond:gmatch("%S+") do
    local any = false
    for alt in token:gmatch("[^/]+") do
      local neg = alt:sub(1, 1) == "!"
      local name = neg and alt:sub(2) or alt
      if (name == faction or name == class) ~= neg then any = true end
    end
    if not any then return false end
  end
  return true
end

local function PlayerClass()
  local _, file = UnitClass("player")
  return file and (file:sub(1, 1) .. file:sub(2):lower()) or "" -- "WARRIOR" -> "Warrior"
end

-- ns.GUIDE (Guide.lua) filtered to your faction and class:
-- { { part, opt, text, go, done, past } }, index of the current step.
-- Current = the step after the last one your quest log proves done.
function ns.GuideSteps()
  local faction, class = UnitFactionGroup("player"), PlayerClass()
  local function Applies(c) return ns.Cond(c, faction, class) end
  local function IDs(list)
    local r = {}
    for _, q in ipairs(list or {}) do if Applies(q[2]) then r[#r + 1] = q[1] end end
    return r
  end
  -- picked[id] = the version of id's round you took (on it or turned in)
  local picked = {}
  for _, ids in ipairs(ns.VERSIONS or {}) do
    for _, id in ipairs(ids) do
      if IsCompleted(id) or IsOnQuest(id) then for _, j in ipairs(ids) do picked[j] = id end end
    end
  end
  local out, last = {}, 0
  for _, s in ipairs(ns.GUIDE or {}) do
    if Applies(s.cond) and not (s.q and picked[s.q] and picked[s.q] ~= s.q) then
      local lines = {}
      for _, l in ipairs(s.lines) do if Applies(l[2]) then lines[#lines + 1] = l[1] end end
      if #lines > 0 then
        local st = { part = s.part, opt = s.opt, text = table.concat(lines, "\n"),
          go = s.go and Applies(s.go[5]) and s.go or nil }
        local turnin, accept = IDs(s.turnin), IDs(s.accept)
        if #turnin > 0 then
          st.done = true
          for _, id in ipairs(turnin) do if not IsCompleted(id) then st.done = false end end
        elseif #accept > 0 then
          st.done = true
          for _, id in ipairs(accept) do if not (IsCompleted(id) or IsOnQuest(id)) then st.done = false end end
        end
        out[#out + 1] = st
        if st.done then last = #out end
      end
    end
  end
  for i, st in ipairs(out) do st.past = i <= last end
  return out, last + 1
end

-- The quest ID of a chain step for your class and faction (from the guide's
-- accept/turn-in lines), falling back to the first variant
local myQuests
function ns.QuestID(name)
  local step = ns.STEP[name]
  if not step then return nil end
  if not myQuests then
    local faction, class = UnitFactionGroup("player"), PlayerClass()
    myQuests = {}
    for _, s in ipairs(ns.GUIDE or {}) do
      if ns.Cond(s.cond, faction, class) then
        for _, list in ipairs({ s.accept or {}, s.turnin or {} }) do
          for _, q in ipairs(list) do if ns.Cond(q[2], faction, class) then myQuests[q[1]] = true end end
        end
      end
    end
  end
  for _, id in ipairs(step.ids) do if myQuests[id] then return id end end
  return step.ids[1]
end

-- "[Quest Name]" as a real quest link when it's a chain step, else plain text
function ns.QuestLink(name)
  local id = ns.QuestID(name)
  return id and string.format("|cffffff00|Hquest:%d:60|h[%s]|h|r", id, name) or name
end

-- Rows per section (done rows last) and the totals. done = { [fee key] = true }
function ns.Compute(done)
  local faction = UnitFactionGroup("player")
  local bySec, t = {}, { leftLo = 0, leftHi = 0, allLo = 0, allHi = 0, done = 0, count = 0, sheet = false }
  for _, sec in ipairs(ns.SECTIONS) do bySec[sec.key] = { left = 0, farm = 0 } end
  for i, it in ipairs(ns.ITEMS) do
    if not it.faction or it.faction == faction then
      local need = it.qty or 1
      local quest = ns.QuestStatus(ns.STEP[it.quest])
      local have = it.id and (GetItemCount(it.id, true) or 0) or (done[it.key] and 1 or 0)
      -- (turned in: the mats are gone from your bags but no longer needed)
      if quest == "done" then have = need end
      have = math.min(have, need)
      local r = { it = it, order = i, need = need, have = have, missing = need - have, done = have >= need,
        turnedIn = quest == "done", onQuest = quest == "active" }
      r.lo, r.hi, r.kind, r.age, r.src = ns.Price(it)
      local s = bySec[it.sec]
      s[#s + 1] = r
      t.count = t.count + 1
      if r.done then t.done = t.done + 1 end
      if r.lo then
        t.allLo, t.allHi = t.allLo + need * r.lo, t.allHi + need * r.hi
        t.leftLo, t.leftHi = t.leftLo + r.missing * r.lo, t.leftHi + r.missing * r.hi
        s.left = s.left + r.missing * r.lo
        if r.kind == "sheet" and r.missing > 0 and r.lo ~= r.hi then t.sheet = true end
      else
        s.farm = s.farm + r.missing
      end
    end
  end
  for _, s in pairs(bySec) do
    table.sort(s, function(a, b)
      if a.done ~= b.done then return b.done end
      return a.order < b.order
    end)
  end
  return bySec, t
end

-- "35g 50s" with Blizzard's coin colors, short enough for a column
function ns.Money(c)
  c = Round(c or 0)
  local g, s, cu = math.floor(c / GOLD), math.floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. "|cffffd700g|r" end
  if s > 0 then out[#out + 1] = s .. "|cffc7c7cfs|r" end
  if cu > 0 and g == 0 then out[#out + 1] = cu .. "|cffeda55fc|r" end
  return #out > 0 and table.concat(out, " ") or "0|cffc7c7cfs|r"
end

if not CreateFrame then return end -- (test.lua stops here)

-- Forever moved the global into C_CurrencyInfo; plain text if neither exists
local Coin = GetCoinTextureString or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or ns.Money

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local W, H = 560, 480
local ROW_H, HEAD_H = 36, 26
local CONTENT_W = W - 46
local GREY = { 0.62, 0.62, 0.62 }
local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local COIN = "Interface\\Icons\\INV_Misc_Coin_02"

local f = CreateFrame("Frame", "T05ShoppingFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(W, H)
f:SetPoint("CENTER")
f:SetFrameStrata("MEDIUM")
f:SetToplevel(true)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
-- (named + user-placed: the client remembers the position itself)
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); self:SetUserPlaced(true) end)
f:Hide()
tinsert(UISpecialFrames, f:GetName()) -- Esc closes it

local function Text(parent, font, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font)
  fs:SetWordWrap(false)
  return fs
end

f.TitleText:SetText("T0.5 Shopping List")

local subtitle = Text(f, "GameFontHighlight")
subtitle:SetPoint("TOPLEFT", 16, -34)
subtitle:SetJustifyH("LEFT")
local Render, OpenBuy, StartScan, AHOpen, ToggleGuide, RenderGuide -- (defined further down)

local scanButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
scanButton:SetSize(120, 22)
scanButton:SetPoint("TOPRIGHT", -12, -28)
scanButton:SetText("Scan prices")
scanButton:SetMotionScriptsWhileDisabled(true)
scanButton:SetScript("OnClick", function() StartScan() end)
scanButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
  GameTooltip:SetText("Scan prices", 1, 1, 1)
  GameTooltip:AddLine("Searches the AH for every item in the Auction House section and saves the cheapest price. Takes a few seconds.", 0.8, 0.8, 0.8, true)
  if not AHOpen() then GameTooltip:AddLine("Open the Auction House first.", 1, 0.6, 0.2, true) end
  GameTooltip:Show()
end)
scanButton:SetScript("OnLeave", GameTooltip_Hide)

-- Opens the step-by-step guide panel next to the window (Guide.lua)
local guideButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
guideButton:SetSize(64, 22)
guideButton:SetPoint("RIGHT", scanButton, "LEFT", -4, 0)
guideButton:SetText("Guide")
guideButton:SetScript("OnClick", function() ToggleGuide() end)
guideButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
  GameTooltip:SetText("Quest guide", 1, 1, 1)
  GameTooltip:AddLine("Step-by-step directions for the whole T0.5 chain, with map waypoints. Opens at the step you're on.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end)
guideButton:SetScript("OnLeave", GameTooltip_Hide)
subtitle:SetPoint("RIGHT", guideButton, "LEFT", -10, 0)

local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -54)
scroll:SetPoint("BOTTOMRIGHT", -32, 66)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(CONTENT_W, 1)
scroll:SetScrollChild(content)

-- Footer: the one number you came for, drawn like the XP bar
local divider = f:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 0.82, 0, 0.25)
divider:SetHeight(1)
divider:SetPoint("BOTTOMLEFT", 12, 62)
divider:SetPoint("BOTTOMRIGHT", -12, 62)
local leftLabel = Text(f, "GameFontNormal")
leftLabel:SetPoint("BOTTOMLEFT", 16, 38)
leftLabel:SetText("Still to spend:")
local leftValue = Text(f, "GameFontHighlight")
leftValue:SetPoint("LEFT", leftLabel, "RIGHT", 6, 0)
local pctText = Text(f, "GameFontHighlightSmall")
pctText:SetPoint("BOTTOMRIGHT", -16, 39)

local bar = CreateFrame("StatusBar", nil, f)
bar:SetPoint("BOTTOMLEFT", 16, 16)
bar:SetPoint("BOTTOMRIGHT", -16, 16)
bar:SetHeight(14)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.80, 0.62, 0.16)
bar:SetMinMaxValues(0, 1)
local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
barBg:SetColorTexture(0, 0, 0, 0.55)
local barEdge = bar:CreateTexture(nil, "BORDER")
barEdge:SetPoint("TOPLEFT", -1, 1)
barEdge:SetPoint("BOTTOMRIGHT", 1, -1)
barEdge:SetColorTexture(1, 0.82, 0, 0.2)

---------------------------------------------------------------------------
-- Rows (pooled)
---------------------------------------------------------------------------
local heads, rows = {}, {}

local function Head(i)
  local h = heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, content)
  h:SetSize(CONTENT_W, HEAD_H)
  h.title = Text(h, "GameFontNormal")
  h.title:SetPoint("BOTTOMLEFT", 4, 6)
  h.right = Text(h, "GameFontHighlightSmall")
  h.right:SetPoint("BOTTOMRIGHT", -4, 7)
  local line = h:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.2)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", 2, 1)
  line:SetPoint("BOTTOMRIGHT", -2, 1)
  heads[i] = h
  return h
end

---------------------------------------------------------------------------
-- Quest links (rows, header, guide): hover = the game's quest tooltip,
-- shift-click = link in chat, click = Wowhead URL to copy
---------------------------------------------------------------------------
local WOWHEAD = "https://www.wowhead.com/forever/quest=%d"
StaticPopupDialogs.T05SHOPPING_URL = {
  text = "Wowhead link. Press Ctrl+C to copy it, then paste it in your browser.",
  button1 = CLOSE or "Close",
  hasEditBox = true,
  editBoxWidth = 330,
  OnShow = function(self, url)
    local eb = self.editBox or self.EditBox
    eb.url = url
    eb:SetText(url)
    eb:HighlightText()
    eb:SetFocus()
  end,
  -- (read-only: any edit snaps back to the URL, still selected)
  EditBoxOnTextChanged = function(eb) if eb.url and eb:GetText() ~= eb.url then eb:SetText(eb.url); eb:HighlightText() end end,
  EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
  EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function QuestOf(link) return tonumber(link and link:match("^quest:(%d+)")) end

local function LinkEnter(self, link, text)
  local id = QuestOf(link)
  if not id then return end
  self.overLink = true
  GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
  local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
  if not ok or (GameTooltip:NumLines() or 0) == 0 then
    GameTooltip:SetText(text and text:match("%[(.-)%]") or "Quest", 1, 1, 0)
  end
  local done = IsCompleted(id)
  GameTooltip:AddLine(done and "Turned in" or IsOnQuest(id) and "In your quest log" or "Not started",
    done and 0.25 or 1, done and 1 or 0.82, done and 0.25 or 0)
  GameTooltip:AddLine("Click: Wowhead link to copy. Shift-click: link in chat.", 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end

local function LinkClick(self, link, text)
  local id = QuestOf(link)
  if not id then return end
  if IsModifiedClick("CHATLINK") then
    ChatEdit_InsertLink(text)
  else
    StaticPopup_Show("T05SHOPPING_URL", nil, nil, WOWHEAD:format(id))
  end
end

local function EnableLinks(frame, onLeave)
  frame:SetHyperlinksEnabled(true)
  frame:SetScript("OnHyperlinkEnter", LinkEnter)
  frame:SetScript("OnHyperlinkClick", LinkClick)
  frame:SetScript("OnHyperlinkLeave", function(self)
    self.overLink = nil
    GameTooltip:Hide()
    if onLeave then onLeave(self) end
  end)
end
EnableLinks(f)

local function OnEnter(self)
  local r = self.r
  if not r then return end
  local it = r.it
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if it.id then GameTooltip:SetItemByID(it.id) else GameTooltip:SetText(it.name, 1, 1, 1) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("For: " .. it.quest, 1, 0.82, 0)
  if r.turnedIn then
    GameTooltip:AddLine("Quest turned in: no longer needed.", 0.25, 1, 0.25)
  elseif r.onQuest then
    GameTooltip:AddLine("On this quest now.", 1, 0.82, 0)
  end
  if it.where then GameTooltip:AddLine(it.where, 0.8, 0.8, 0.8) end
  if it.note then GameTooltip:AddLine(it.note, 0.8, 0.8, 0.8, true) end
  if r.kind == "live" or r.kind == "stale" then
    GameTooltip:AddLine(string.format("%s: %s each, scanned %s", r.src == "scan" and "Your scan" or "Auctionator",
      ns.Money(r.lo), r.age and (r.age == 0 and "today" or r.age .. "d ago") or "recently"), 1, 1, 1)
    if r.kind == "stale" then GameTooltip:AddLine("Older than " .. STALE_DAYS .. " days: scan again for a fresh price.", 1, 0.6, 0.2, true) end
  elseif r.kind == "sheet" then
    GameTooltip:AddLine(it.sec == "ah" and "Not scanned yet: showing the spreadsheet price (21/11)." or "Fixed gold cost.", 0.8, 0.8, 0.8, true)
    if r.lo ~= r.hi then GameTooltip:AddLine(ns.Money(r.lo) .. " to " .. ns.Money(r.hi) .. " each", 1, 1, 1) end
  end
  if it.id then
    if it.sec == "ah" then
      GameTooltip:AddLine(AHOpen() and "Click to open it in the buy window." or "Open the Auction House, then click to buy.", 0.5, 0.5, 0.5)
    end
    GameTooltip:AddLine("Shift-click to link it in chat.", 0.5, 0.5, 0.5)
  else
    GameTooltip:AddLine("Click to mark as paid.", 0.5, 0.5, 0.5)
  end
  GameTooltip:Show()
end

local function Toggle(key)
  T05ShoppingDB.done[key] = not T05ShoppingDB.done[key] or nil
  Render()
end

local function OnClick(self)
  local it = self.r and self.r.it
  if not it or self.overLink then return end -- (the quest link handles its own click)
  if it.id then
    local _, link = GetItemInfo(it.id)
    if IsModifiedClick() then
      if link then HandleModifiedItemClick(link) end
    elseif it.sec == "ah" then
      OpenBuy(it.id, math.max(self.r.missing, 1))
    end
  else
    Toggle(it.key)
  end
end

local function Row(i)
  local b = rows[i]
  if b then return b end
  b = CreateFrame("Button", nil, content)
  b:SetSize(CONTENT_W, ROW_H)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b:GetHighlightTexture():SetAlpha(0.35)
  b.ready = b:CreateTexture(nil, "ARTWORK")
  b.ready:SetSize(16, 16)
  b.ready:SetPoint("LEFT", 2, 0)
  b.ready:SetTexture(READY)
  b.check = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
  b.check:SetSize(22, 22)
  b.check:SetPoint("LEFT", -1, 0)
  b.check:SetScript("OnClick", function() Toggle(b.r.it.key) end)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(28, 28)
  b.icon:SetPoint("LEFT", 22, 0)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.name = Text(b, "GameFontNormal")
  b.name:SetPoint("TOPLEFT", 58, -4)
  b.name:SetPoint("RIGHT", -222, 0)
  b.name:SetJustifyH("LEFT")
  b.sub = Text(b, "GameFontHighlightSmall")
  b.sub:SetPoint("BOTTOMLEFT", 58, 5)
  b.sub:SetPoint("RIGHT", -86, 0)
  b.sub:SetJustifyH("LEFT")
  b.sub:SetTextColor(unpack(GREY))
  b.count = Text(b, "GameFontHighlight")
  b.count:SetPoint("TOPRIGHT", -156, -5)
  b.count:SetWidth(60)
  b.count:SetJustifyH("RIGHT")
  b.price = Text(b, "GameFontHighlight")
  b.price:SetPoint("TOPRIGHT", -80, -5)
  b.price:SetWidth(72)
  b.price:SetJustifyH("RIGHT")
  b.age = Text(b, "GameFontHighlightSmall")
  b.age:SetPoint("BOTTOMRIGHT", -80, 5)
  b.age:SetJustifyH("RIGHT")
  b.total = Text(b, "GameFontHighlight")
  b.total:SetPoint("TOPRIGHT", -4, -5)
  b.total:SetWidth(72)
  b.total:SetJustifyH("RIGHT")
  b:SetScript("OnEnter", OnEnter)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", OnClick)
  EnableLinks(b, function(self) if self:IsMouseOver() then OnEnter(self) end end)
  rows[i] = b
  return b
end

local function FillRow(b, r)
  b.r = r
  local it = r.it
  b:SetAlpha(r.done and 0.6 or 1)
  b.check:SetShown(not it.id)
  b.check:SetChecked(r.done)
  b.ready:SetShown(it.id ~= nil and r.done)

  local sub = ns.QuestLink(it.quest) .. (r.onQuest and " |cffffd100(on quest)|r" or "") .. (it.where and (" · " .. it.where) or "")
  if it.id then
    local name, _, quality = GetItemInfo(it.id)
    b.icon:SetTexture(C_Item.GetItemIconByID(it.id) or QUESTION)
    if name then
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
      b.name:SetText(c and (c.hex .. name .. "|r") or name)
    else
      b.name:SetText("|cff9e9e9eLoading item...|r")
    end
    b.count:SetText(r.turnedIn and "Turned in" or (r.have .. "/" .. r.need))
    if r.done then b.count:SetTextColor(0.25, 1, 0.25) else b.count:SetTextColor(1, 0.82, 0) end
  else
    b.icon:SetTexture(COIN)
    b.name:SetText(it.name)
    b.name:SetTextColor(1, 1, 1)
    b.count:SetText(r.turnedIn and "Turned in" or r.done and "Paid" or "")
    b.count:SetTextColor(0.25, 1, 0.25)
  end
  b.sub:SetText(sub)

  if r.lo then
    b.price:SetText(it.id and ns.Money(r.lo) or "")
    b.total:SetText(r.done and "" or ns.Money(r.missing * r.lo))
    if r.kind == "live" then
      b.price:SetTextColor(1, 1, 1)
      b.age:SetText(r.age and (r.age == 0 and "today" or r.age .. "d") or "")
      b.age:SetTextColor(unpack(GREY))
    elseif r.kind == "stale" then
      b.price:SetTextColor(unpack(GREY))
      b.age:SetText(r.age .. "d old")
      b.age:SetTextColor(1, 0.6, 0.2)
    else
      b.price:SetTextColor(unpack(GREY))
      b.age:SetText(it.sec == "ah" and "(sheet)" or "")
      b.age:SetTextColor(unpack(GREY))
    end
  else
    b.price:SetText("")
    b.total:SetText("")
    b.age:SetText("")
  end
end

function Render()
  if not (f:IsShown() and T05ShoppingDB) then return end
  local bySec, t = ns.Compute(T05ShoppingDB.done)
  local y, nh, nr = 0, 0, 0
  for _, sec in ipairs(ns.SECTIONS) do
    local list = bySec[sec.key]
    if #list > 0 then
      nh = nh + 1
      local h = Head(nh)
      h:SetPoint("TOPLEFT", 0, -y)
      h.title:SetText(sec.title)
      if sec.key == "farm" then
        h.right:SetText(list.farm > 0 and (list.farm .. " still to farm") or "|cff40ff40All farmed|r")
      else
        h.right:SetText(list.left > 0 and (ns.Money(list.left) .. " left") or "|cff40ff40All done|r")
      end
      h:Show()
      y = y + HEAD_H + 2
      for _, r in ipairs(list) do
        nr = nr + 1
        local b = Row(nr)
        b:SetPoint("TOPLEFT", 0, -y)
        FillRow(b, r)
        b:Show()
        y = y + ROW_H
      end
      y = y + 8
    end
  end
  for i = nh + 1, #heads do heads[i]:Hide() end
  for i = nr + 1, #rows do rows[i]:Hide() end
  content:SetHeight(y)

  local pr = ns.Progress()
  if pr.step then
    subtitle:SetText(string.format("|cffffd100Step %d/%d:|r %s%s", pr.n, pr.total, ns.QuestLink(pr.step.name),
      pr.active and " |cff9e9e9e(on quest)|r" or ""))
  else
    subtitle:SetText("|cff40ff40Chain complete. Enjoy the set!|r")
  end
  RenderGuide()
  if t.leftLo <= 0 then
    leftValue:SetText("|cff40ff40nothing, you're set|r")
  elseif t.sheet then
    leftValue:SetText(Coin(t.leftLo) .. "  to  " .. Coin(t.leftHi))
  else
    leftValue:SetText(Coin(t.leftLo))
  end
  local pct = t.allLo > 0 and (1 - t.leftLo / t.allLo) or 1
  bar:SetValue(pct)
  pctText:SetText(string.format("%d/%d done · %d%% of gold spent", t.done, t.count, math.floor(pct * 100)))
end

-- Coalesce bursts of bag/item events into one repaint
local queued
local function Queue()
  if queued or not f:IsShown() then return end
  queued = true
  C_Timer.After(0.2, function() queued = false; Render() end)
end

---------------------------------------------------------------------------
-- Guide panel: docked to the right of the window, one part at a time
---------------------------------------------------------------------------
local GW, STEP_W = 340, 296
local g = CreateFrame("Frame", "T05ShoppingGuideFrame", f, "BasicFrameTemplateWithInset")
g:SetSize(GW, H)
g:SetPoint("TOPLEFT", f, "TOPRIGHT", -2, 0)
g:Hide()
tinsert(UISpecialFrames, g:GetName())
g.TitleText:SetText("T0.5 Quest Guide")

local partText = Text(g, "GameFontNormal")
partText:SetPoint("TOP", 0, -34)
local function NavButton(dir)
  local b = CreateFrame("Button", nil, g)
  b:SetSize(24, 24)
  local tex = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
  b:SetNormalTexture(tex .. "Up")
  b:SetPushedTexture(tex .. "Down")
  b:SetDisabledTexture(tex .. "Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  b:SetScript("OnClick", function() g.part = g.part + dir; RenderGuide() end)
  return b
end
local prevPart, nextPart = NavButton(-1), NavButton(1)
prevPart:SetPoint("TOPLEFT", 12, -28)
nextPart:SetPoint("TOPRIGHT", -12, -28)

local gScroll = CreateFrame("ScrollFrame", nil, g, "UIPanelScrollFrameTemplate")
gScroll:SetPoint("TOPLEFT", 12, -58)
gScroll:SetPoint("BOTTOMRIGHT", -32, 30)
local gContent = CreateFrame("Frame", nil, gScroll)
gContent:SetSize(STEP_W, 1)
gScroll:SetScrollChild(gContent)

-- Map pin: TomTom if you have it, else the game's own map pin
local function Waypoint(go)
  local map, x, y, zone = go[1], go[2], go[3], go[4]
  if TomTom and TomTom.AddWaypoint and pcall(TomTom.AddWaypoint, TomTom, map, x / 100, y / 100, { title = "T0.5 guide" }) then
    return
  end
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    print(string.format("|cffffd100T05:|r map pin set: %s %.1f, %.1f", zone, x, y))
    return
  end
  print(string.format("|cffffd100T05:|r go to %s %.1f, %.1f", zone, x, y))
end

local stepRows = {}
local function StepRow(i)
  local b = stepRows[i]
  if b then return b end
  b = CreateFrame("Frame", nil, gContent)
  b:SetWidth(STEP_W)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(1, 0.82, 0, 0.12)
  b.num = Text(b, "GameFontNormalSmall")
  b.num:SetPoint("TOPLEFT", 2, -5)
  b.check = b:CreateTexture(nil, "ARTWORK")
  b.check:SetSize(14, 14)
  b.check:SetPoint("TOPLEFT", 2, -4)
  b.check:SetTexture(READY)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("TOPLEFT", 24, -5)
  b.text:SetWidth(STEP_W - 50)
  b.text:SetJustifyH("LEFT")
  b.text:SetSpacing(2)
  EnableLinks(b)
  b.pin = CreateFrame("Button", nil, b)
  b.pin:SetSize(20, 20)
  b.pin:SetPoint("TOPRIGHT", -2, -2)
  b.pin:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
  b.pin:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.pin:SetScript("OnClick", function(self) Waypoint(self.go) end)
  b.pin:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Set waypoint", 1, 1, 1)
    GameTooltip:AddLine(string.format("%s %.1f, %.1f", self.go[4], self.go[2], self.go[3]), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b.pin:SetScript("OnLeave", GameTooltip_Hide)
  stepRows[i] = b
  return b
end

function RenderGuide()
  if not g:IsShown() then return end
  local steps, cur = ns.GuideSteps()
  local curPart = steps[cur] and steps[cur].part or 4
  g.part = math.max(1, math.min(4, g.part or curPart))
  partText:SetText(string.format("Part %d: %s", g.part, ns.PART_NAMES[g.part]))
  prevPart:SetEnabled(g.part > 1)
  nextPart:SetEnabled(g.part < 4)
  local y, n, curY = 0, 0, nil
  for i, st in ipairs(steps) do
    if st.part == g.part then
      n = n + 1
      local b = StepRow(n)
      b:SetPoint("TOPLEFT", 0, -y)
      b.text:SetText((st.opt and "|cff9e9e9e(optional)|r " or "") .. st.text)
      b.check:SetShown(st.past)
      b.num:SetShown(not st.past)
      b.num:SetText(i)
      b.bg:SetShown(i == cur)
      b:SetAlpha(st.past and 0.5 or 1)
      b.pin.go = st.go
      b.pin:SetShown(st.go ~= nil)
      local h = math.max(24, b.text:GetStringHeight() + 12)
      b:SetHeight(h)
      b:Show()
      if i == cur then curY = y end
      y = y + h + 2
    end
  end
  for i = n + 1, #stepRows do stepRows[i]:Hide() end
  gContent:SetHeight(math.max(y, 1))
  if curY then
    C_Timer.After(0, function()
      gScroll:SetVerticalScroll(math.min(math.max(curY - 60, 0), gScroll:GetVerticalScrollRange() or 0))
    end)
  end
end

function ToggleGuide()
  if g:IsShown() then g:Hide() return end
  g.part = nil -- (open at the part you're on)
  g:Show()
  RenderGuide()
end

---------------------------------------------------------------------------
-- Auction House (Forever uses the modern C_AuctionHouse). Every search result for
-- one of our items is recorded, whether it came from our scan, a buy-window click
-- or your own search in Blizzard's AH.
---------------------------------------------------------------------------
local AH = C_AuctionHouse
local PRICE_SORT = { { sortOrder = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }
local SCAN_TIMEOUT = 4 -- s per item; no reply means nothing listed or a dropped query
local ours, scan, buying = {}, nil, nil
for _, it in ipairs(ns.ITEMS) do if it.sec == "ah" then ours[it.id] = true end end

function AHOpen()
  return AuctionHouseFrame ~= nil and AuctionHouseFrame:IsShown() and AH ~= nil
end

-- Cheapest unit price you can buy (your own listings skipped)
local function CommodityMin(id)
  for i = 1, AH.GetNumCommoditySearchResults(id) or 0 do
    local r = AH.GetCommoditySearchResultInfo(id, i)
    if r and r.unitPrice and (r.quantity or 0) - (r.numOwnerItems or 0) > 0 then return r.unitPrice end
  end
end

-- ponytail: non-commodity results priced per auction (stack of 1); divide by quantity if stacks show up
local function ItemMin(key)
  for i = 1, AH.GetNumItemSearchResults(key) or 0 do
    local r = AH.GetItemSearchResultInfo(key, i)
    if r and r.buyoutAmount and not r.containsOwnerItem then return r.buyoutAmount end
  end
end

local function UpdateScanButton()
  if scan then
    scanButton:SetText(string.format("Scanning %d/%d", scan.i, #scan.ids))
    scanButton:Disable()
  else
    scanButton:SetText("Scan prices")
    scanButton:SetEnabled(AHOpen())
  end
end

local function Step()
  if not scan then return end
  scan.i = scan.i + 1
  local id = scan.ids[scan.i]
  if not id or not AHOpen() then
    if id then print("|cffffd100T05:|r scan stopped, the Auction House closed.")
    else print("|cffffd100T05:|r prices scanned.") end
    scan = nil
    UpdateScanButton()
    Render()
    return
  end
  UpdateScanButton()
  local step = scan.i
  local function Send()
    if not (scan and scan.i == step) then return end
    if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
      C_Timer.After(0.2, Send)
      return
    end
    AH.SendSearchQuery(AH.MakeItemKey(id), PRICE_SORT, true)
    C_Timer.After(SCAN_TIMEOUT, function() if scan and scan.i == step then Step() end end)
  end
  Send()
end

function StartScan()
  if scan or not AHOpen() then return end
  scan = { ids = {}, i = 0 }
  for _, it in ipairs(ns.ITEMS) do if it.sec == "ah" then scan.ids[#scan.ids + 1] = it.id end end
  Step()
end

local function Got(id, unit)
  ns.Record(id, unit)
  if scan and scan.ids[scan.i] == id then C_Timer.After(0.1, Step) end
  Queue()
end

-- Blizzard resets the quantity to 1 when results arrive, so set it after them
local function SetQuantity()
  local buy = AuctionHouseFrame and AuctionHouseFrame.CommoditiesBuyFrame
  local display = buy and buy:IsShown() and buy.BuyDisplay
  if buying and display and display.SetQuantitySelected then pcall(display.SetQuantitySelected, display, buying.qty) end
end

-- Open the item's page in Blizzard's AH with the missing quantity set. You still press Buy Now.
-- ponytail: no cheap-band cap like CraftersJournal; Blizzard shows the total before you confirm
function OpenBuy(id, qty)
  if not AHOpen() or not AuctionHouseFrame.SelectBrowseResult then
    print("|cffffd100T05:|r open the Auction House first.")
    return
  end
  buying = { id = id, qty = qty }
  local ok = pcall(AuctionHouseFrame.SelectBrowseResult, AuctionHouseFrame,
    { itemKey = AH.MakeItemKey(id), minPrice = 0, totalQuantity = 0, containsOwnerItem = false })
  if not ok then
    local name = GetItemInfo(id)
    local bar = AuctionHouseFrame.SearchBar
    if name and bar and bar.SetSearchText then bar:SetSearchText(name); bar:StartSearch() end
  end
  -- (already on this item's page: no new results come, so set it now too)
  C_Timer.After(0.3, SetQuantity)
end

f:SetScript("OnShow", function() UpdateScanButton(); Render() end)
for _, e in ipairs({ "ADDON_LOADED", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "GET_ITEM_INFO_RECEIVED",
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
  "QUEST_LOG_UPDATE", "QUEST_TURNED_IN" }) do
  f:RegisterEvent(e)
end
---------------------------------------------------------------------------
-- Minimap button (EllesmereUI's "Addon Buttons" and similar bags collect it) and
-- the Blizzard addon menu entry (AddonCompartmentFunc in the .toc)
---------------------------------------------------------------------------
local minimapButton
local function Toggle() f:SetShown(not f:IsShown()) end
T05Shopping_OnAddonCompartmentClick = Toggle

local function ButtonTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("T0.5 Shopping List", 1, 1, 1)
  GameTooltip:AddLine("Click to open or close.", 0.8, 0.8, 0.8)
  if self == minimapButton then GameTooltip:AddLine("Drag to move it around the minimap.", 0.8, 0.8, 0.8) end
  GameTooltip:Show()
end
T05Shopping_OnAddonCompartmentEnter = function(_, button) ButtonTooltip(button) end
T05Shopping_OnAddonCompartmentLeave = function() GameTooltip:Hide() end

local function PlaceMinimapButton(b)
  local a = math.rad(T05ShoppingDB.minimapAngle or 200)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

local function CreateMinimapButton()
  -- (named, a Button, 31px, child of Minimap: what minimap-button collectors look for)
  local b = CreateFrame("Button", "T05ShoppingMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetPoint("CENTER")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetScript("OnClick", Toggle)
  b:SetScript("OnEnter", ButtonTooltip)
  b:SetScript("OnLeave", GameTooltip_Hide)
  -- Drag around the minimap edge; the angle is saved
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      T05ShoppingDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      PlaceMinimapButton(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  PlaceMinimapButton(b)
  b:SetShown(not T05ShoppingDB.hideMinimap)
  minimapButton = b
end

f:SetScript("OnEvent", function(self, event, arg)
  if event == "ADDON_LOADED" then
    if arg == ADDON then
      T05ShoppingDB = T05ShoppingDB or {}
      T05ShoppingDB.done = T05ShoppingDB.done or {}
      CreateMinimapButton()
    end
    return
  elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    if ours[arg] then Got(arg, CommodityMin(arg)) end
    if buying and buying.id == arg then C_Timer.After(0, SetQuantity) end
    return
  elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
    if arg and ours[arg.itemID] then Got(arg.itemID, ItemMin(arg)) end
    return
  elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
    if event == "AUCTION_HOUSE_CLOSED" then buying = nil end
    UpdateScanButton() -- (a running scan stops itself on its next step)
  end
  Queue()
end)

SLASH_T05SHOPPING1 = "/t05"
SlashCmdList.T05SHOPPING = function(msg)
  if msg == "dump" then
    local _, t = ns.Compute(T05ShoppingDB.done)
    print(string.format("|cffffd100T05:|r %d/%d done. Still to spend %s to %s (of %s to %s).", t.done, t.count,
      ns.Money(t.leftLo), ns.Money(t.leftHi), ns.Money(t.allLo), ns.Money(t.allHi)))
    return
  elseif msg == "minimap" then
    T05ShoppingDB.hideMinimap = not T05ShoppingDB.hideMinimap or nil
    minimapButton:SetShown(not T05ShoppingDB.hideMinimap)
    print("|cffffd100T05:|r minimap button " .. (T05ShoppingDB.hideMinimap and "hidden. /t05 minimap brings it back." or "shown."))
    return
  end
  Toggle()
end
