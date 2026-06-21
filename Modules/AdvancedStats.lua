local ADDON_NAME = ...

local PANE_WIDTH = 248
local PANE_HEIGHT = 426
local PANE_X = -32
local PANE_Y = -13
local ROW_HEIGHT = 13
local SECTION_GAP = 10
local PADDING = 10
local REFRESH_INTERVAL = 0.25
local TOGGLE_WIDTH = 24
local TOGGLE_HEIGHT = 22
local TOGGLE_TAB_GAP = 2
local TOGGLE_X_OFFSET = 55
local TOGGLE_Y_OFFSET = 20
local TOGGLE_OVERLAP_RATIO = 0.4
local COLLECT_BATCH_SIZE = 12

local PRIMARY_STAT_LABELS = {
  "Strength",
  "Agility",
  "Stamina",
  "Intellect",
  "Spirit",
}

local RESISTANCE_LABELS = {
  [0] = "Physical (0)",
  [1] = "Physical (1)",
  [2] = "Holy",
  [3] = "Fire",
  [4] = "Nature",
  [5] = "Frost",
  [6] = "Shadow",
  [7] = "Arcane",
}

local SPELL_SCHOOL_LABELS = {
  [2] = "Holy",
  [3] = "Fire",
  [4] = "Nature",
  [5] = "Frost",
  [6] = "Shadow",
  [7] = "Arcane",
}

local COMBAT_RATING_IDS = {
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
}

local COMBAT_RATING_FALLBACK_NAMES = {
  [1] = "CR_WEAPON_SKILL",
  [2] = "CR_DEFENSE_SKILL",
  [3] = "CR_DODGE",
  [4] = "CR_PARRY",
  [5] = "CR_BLOCK",
  [6] = "CR_HIT_MELEE",
  [7] = "CR_HIT_RANGED",
  [8] = "CR_HIT_SPELL",
  [9] = "CR_CRIT_MELEE",
  [10] = "CR_CRIT_RANGED",
  [11] = "CR_CRIT_SPELL",
  [12] = "CR_HIT_TAKEN_MELEE",
  [13] = "CR_HIT_TAKEN_RANGED",
  [14] = "CR_HIT_TAKEN_SPELL",
  [15] = "CR_CRIT_TAKEN_MELEE",
  [16] = "CR_CRIT_TAKEN_RANGED",
  [17] = "CR_CRIT_TAKEN_SPELL",
  [18] = "CR_HASTE_MELEE",
  [19] = "CR_HASTE_RANGED",
  [20] = "CR_HASTE_SPELL",
  [21] = "CR_WEAPON_SKILL_MAINHAND",
  [22] = "CR_WEAPON_SKILL_OFFHAND",
  [23] = "CR_WEAPON_SKILL_RANGED",
  [24] = "CR_EXPERTISE",
  [25] = "CR_ARMOR_PENETRATION",
}

local toggleButton
local pane
local scrollFrame
local scrollChild
local collectFrame
local statusLine
local linePool = {}
local uiReady = false
local lastRefresh = 0
local cachedLines
local cacheDirty = true
local collectSteps
local collectStepIndex = 0
local pendingLines
local combatRatingLabels

local function IsEnabled()
  return Tea_GetDB().modules.advancedStats == true
end

local function FormatValue(value)
  if value == nil then
    return "nil"
  end
  if type(value) == "number" then
    if value ~= value then
      return "nan"
    end
    if math.abs(value - math.floor(value + 0.00001)) < 0.001 then
      return tostring(math.floor(value + 0.00001))
    end
    return string.format("%.2f", value)
  end
  if type(value) == "boolean" then
    return value and "true" or "false"
  end
  return tostring(value)
end

local function FormatReturns(...)
  local count = select("#", ...)
  if count == 0 then
    return "()"
  end
  local parts = {}
  for i = 1, count do
    parts[i] = FormatValue(select(i, ...))
  end
  return table.concat(parts, ", ")
end

local function SafeCall(label, fn)
  if type(fn) ~= "function" then
    return label, "(unavailable)"
  end

  local results = { pcall(fn) }
  if not results[1] then
    return label, "(error: " .. tostring(results[2]) .. ")"
  end

  table.remove(results, 1)
  if #results == 0 then
    return label, "()"
  end
  if #results == 1 then
    return label, FormatValue(results[1])
  end
  return label, FormatReturns(unpack(results))
end

local function AddLine(lines, label, value)
  lines[#lines + 1] = { kind = "line", label = label, value = value }
end

local function AddSection(lines, title)
  lines[#lines + 1] = { kind = "section", title = title }
end

local function GetCombatRatingLabel(id)
  if not combatRatingLabels then
    combatRatingLabels = {}
    for name, value in pairs(_G) do
      if type(name) == "string" and type(value) == "number" and name:match("^CR_") then
        combatRatingLabels[value] = name
      end
    end
    for ratingID, name in pairs(COMBAT_RATING_FALLBACK_NAMES) do
      combatRatingLabels[ratingID] = combatRatingLabels[ratingID] or name
    end
  end

  return combatRatingLabels[id] or ("CR_" .. id)
end

local function BuildCollectSteps()
  local steps = {}
  local unit = "player"

  local function step(fn)
    steps[#steps + 1] = fn
  end

  step(function(lines)
    AddSection(lines, "Unit")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitLevel", function()
      return UnitLevel(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitHealth / Max", function()
      return UnitHealth(unit), UnitHealthMax(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitPowerType", function()
      return UnitPowerType(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitPower / Max", function()
      return UnitPower(unit), UnitPowerMax(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitClass", function()
      local _, className, classID = UnitClass(unit)
      return className, classID
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitRace", function()
      local _, raceName, raceID = UnitRace(unit)
      return raceName, raceID
    end))
  end)

  step(function(lines)
    AddSection(lines, "Primary stats (UnitStat)")
  end)
  for index, label in ipairs(PRIMARY_STAT_LABELS) do
    step(function(lines)
      AddLine(lines, SafeCall(label, function()
        return UnitStat(unit, index)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Armor")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitArmor", function()
      return UnitArmor(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("PaperDollFrame_GetArmorReduction", function()
      if not PaperDollFrame_GetArmorReduction then
        return nil
      end
      local _, effective = UnitArmor(unit)
      return PaperDollFrame_GetArmorReduction(effective, UnitLevel(unit))
    end))
  end)

  step(function(lines)
    AddSection(lines, "Attack")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitAttackBothHands", function()
      return UnitAttackBothHands(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitAttackPower", function()
      return UnitAttackPower(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitRangedAttackPower", function()
      return UnitRangedAttackPower(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitDamage", function()
      return UnitDamage(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitRangedDamage", function()
      return UnitRangedDamage(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitAttackSpeed", function()
      return UnitAttackSpeed(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitRangedAttackSpeed", function()
      return UnitRangedAttackSpeed(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetExpertise", function()
      if not GetExpertise then
        return nil
      end
      return GetExpertise()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetExpertisePercent", function()
      if not GetExpertisePercent then
        return nil
      end
      return GetExpertisePercent()
    end))
  end)

  step(function(lines)
    AddSection(lines, "Crit")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetCritChance", function()
      return GetCritChance()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetRangedCritChance", function()
      return GetRangedCritChance()
    end))
  end)
  for school = 1, 7 do
    local schoolLabel = SPELL_SCHOOL_LABELS[school] or ("School " .. school)
    step(function(lines)
      AddLine(lines, SafeCall("GetSpellCritChance " .. schoolLabel, function()
        return GetSpellCritChance(school)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Avoidance")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("UnitDefense", function()
      return UnitDefense(unit)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetDodgeChance", function()
      return GetDodgeChance()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetParryChance", function()
      return GetParryChance()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetBlockChance", function()
      return GetBlockChance()
    end))
  end)

  step(function(lines)
    AddSection(lines, "Combat ratings")
  end)
  for _, id in ipairs(COMBAT_RATING_IDS) do
    local label = GetCombatRatingLabel(id)
    step(function(lines)
      AddLine(lines, SafeCall(label .. " rating", function()
        if not GetCombatRating then
          return nil
        end
        return GetCombatRating(id)
      end))
    end)
    step(function(lines)
      AddLine(lines, SafeCall(label .. " bonus %", function()
        if not GetCombatRatingBonus then
          return nil
        end
        return GetCombatRatingBonus(id)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Resistances (UnitResistance)")
  end)
  for index = 0, 7 do
    local label = RESISTANCE_LABELS[index] or ("School " .. index)
    step(function(lines)
      AddLine(lines, SafeCall(label, function()
        return UnitResistance(unit, index)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Spell power")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetSpellBonusHealing", function()
      return GetSpellBonusHealing()
    end))
  end)
  for school = 2, 7 do
    local schoolLabel = SPELL_SCHOOL_LABELS[school] or ("School " .. school)
    step(function(lines)
      AddLine(lines, SafeCall("GetSpellBonusDamage " .. schoolLabel, function()
        return GetSpellBonusDamage(school)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Mana regen")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetManaRegen (casting)", function()
      return GetManaRegen()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetManaRegen (not casting)", function()
      return GetManaRegen(1)
    end))
  end)

  step(function(lines)
    AddSection(lines, "Alternate power types")
  end)
  for powerType = 0, 10 do
    step(function(lines)
      AddLine(lines, SafeCall("UnitPower type " .. powerType, function()
        return UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Inventory durability")
  end)
  for slot = 1, 19 do
    step(function(lines)
      AddLine(lines, SafeCall("Slot " .. slot, function()
        return GetInventoryItemDurability(slot)
      end))
    end)
  end

  step(function(lines)
    AddSection(lines, "Misc probes")
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetHitModifier", function()
      if not GetHitModifier then
        return nil
      end
      return GetHitModifier()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetRangedHitModifier", function()
      if not GetRangedHitModifier then
        return nil
      end
      return GetRangedHitModifier()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetSpellHitModifier", function()
      if not GetSpellHitModifier then
        return nil
      end
      return GetSpellHitModifier()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetCombatRating(CR_HIT_MELEE)", function()
      if not GetCombatRating or not CR_HIT_MELEE then
        return nil
      end
      return GetCombatRating(CR_HIT_MELEE)
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetShieldBlock", function()
      if not GetShieldBlock then
        return nil
      end
      return GetShieldBlock()
    end))
  end)
  step(function(lines)
    AddLine(lines, SafeCall("GetMoney", function()
      return GetMoney()
    end))
  end)

  return steps
end

local function InvalidateCache()
  cacheDirty = true
end

local function AcquireLine(index)
  local line = linePool[index]
  if not line then
    line = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", PADDING, -PADDING - (index - 1) * ROW_HEIGHT)
    line:SetPoint("RIGHT", scrollChild, "RIGHT", -PADDING, 0)
    line:SetJustifyH("LEFT")
    linePool[index] = line
  end
  line:Show()
  return line
end

local function HideUnusedLines(fromIndex)
  for index = fromIndex, #linePool do
    linePool[index]:Hide()
  end
end

local function RenderLines(lines)
  if not scrollChild then
    return
  end

  if statusLine then
    statusLine:Hide()
  end

  local lineIndex = 0
  local y = PADDING

  for _, entry in ipairs(lines) do
    lineIndex = lineIndex + 1
    local fs = AcquireLine(lineIndex)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PADDING, -y)

    if entry.kind == "section" then
      if lineIndex > 1 then
        y = y + SECTION_GAP
      end
      fs:SetTextColor(0.75, 0.82, 1)
      fs:SetText(entry.title)
      y = y + ROW_HEIGHT + 2
    else
      fs:SetTextColor(0.85, 0.85, 0.85)
      fs:SetText(string.format("%s: |cffcccccc%s|r", entry.label, entry.value))
      y = y + ROW_HEIGHT
    end
  end

  HideUnusedLines(lineIndex + 1)
  scrollChild:SetWidth(PANE_WIDTH - 28)
  scrollChild:SetHeight(math.max(y + PADDING, pane and pane:GetHeight() or 400))
end

local function ShowLoadingState()
  if not scrollChild then
    return
  end

  HideUnusedLines(2)
  if not statusLine then
    statusLine = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusLine:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PADDING, -PADDING)
    statusLine:SetPoint("RIGHT", scrollChild, "RIGHT", -PADDING, 0)
    statusLine:SetJustifyH("LEFT")
  end
  statusLine:SetTextColor(0.7, 0.7, 0.7)
  statusLine:SetText("Loading stats...")
  statusLine:Show()
  scrollChild:SetHeight(pane and pane:GetHeight() or 400)
end

local function FinishCollect()
  cachedLines = pendingLines
  pendingLines = nil
  collectSteps = nil
  collectStepIndex = 0
  cacheDirty = false
  lastRefresh = GetTime()
  collectFrame:Hide()

  if pane and pane:IsShown() then
    RenderLines(cachedLines)
  end
end

local function ProcessCollectBatch()
  if not collectSteps or not pendingLines then
    collectFrame:Hide()
    return
  end

  local endIndex = math.min(collectStepIndex + COLLECT_BATCH_SIZE, #collectSteps)

  for index = collectStepIndex + 1, endIndex do
    collectSteps[index](pendingLines)
  end

  collectStepIndex = endIndex

  if collectStepIndex >= #collectSteps then
    FinishCollect()
  end
end

local function StartCollect(force)
  if collectFrame and collectFrame:IsShown() and not force then
    return
  end

  if not force and not cacheDirty and cachedLines then
    return
  end

  if not collectSteps then
    collectSteps = BuildCollectSteps()
  end

  pendingLines = {}
  collectStepIndex = 0
  collectFrame:Show()
  ProcessCollectBatch()
end

local function PrefetchStats()
  if not IsEnabled() then
    return
  end
  StartCollect(false)
end

local function RefreshPane(force)
  if not pane or not pane:IsShown() or not IsEnabled() then
    return
  end

  local now = GetTime()
  if not force and not cacheDirty and cachedLines and (now - lastRefresh) < REFRESH_INTERVAL then
    RenderLines(cachedLines)
    return
  end

  if cachedLines and not cacheDirty then
    RenderLines(cachedLines)
    return
  end

  if pendingLines and collectFrame and collectFrame:IsShown() then
    RenderLines(pendingLines)
    return
  end

  ShowLoadingState()
  StartCollect(true)
end

local function GetTabLabel(tab)
  if not tab or not tab.GetText then
    return nil
  end

  local text = tab:GetText() or ""
  text = text:gsub("|c%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return text
end

local function GetHonorTabFrame()
  local honorText = _G.HONOR

  for index = 1, 6 do
    local tab = _G["CharacterFrameTab" .. index]
    if tab then
      local label = GetTabLabel(tab)
      if label and honorText and label == honorText then
        return tab
      end
      if label and label:lower() == "honor" then
        return tab
      end
    end
  end

  return _G.CharacterFrameTab4 or _G.CharacterFrameTab5
end

local function UpdateTogglePosition()
  if not toggleButton or not CharacterFrame then
    return
  end

  toggleButton:ClearAllPoints()

  local honorTab = GetHonorTabFrame()
  if honorTab then
    local overlap = math.floor(TOGGLE_WIDTH * TOGGLE_OVERLAP_RATIO + 0.5)
    toggleButton:SetPoint("BOTTOM", honorTab, "BOTTOM", TOGGLE_X_OFFSET, TOGGLE_Y_OFFSET)
    toggleButton:SetPoint("LEFT", honorTab, "RIGHT", TOGGLE_TAB_GAP - overlap + TOGGLE_X_OFFSET, TOGGLE_Y_OFFSET)
    return
  end

  local tabAnchor = _G.CharacterFrameTab1
  if tabAnchor then
    toggleButton:SetPoint("BOTTOM", tabAnchor, "BOTTOM", TOGGLE_X_OFFSET, TOGGLE_Y_OFFSET)
    toggleButton:SetPoint("LEFT", tabAnchor, "RIGHT", TOGGLE_TAB_GAP + TOGGLE_X_OFFSET, TOGGLE_Y_OFFSET)
    return
  end

  toggleButton:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", 4 + TOGGLE_X_OFFSET, 28 + TOGGLE_Y_OFFSET)
end

local function HookTabPositionUpdates()
  for index = 1, 6 do
    local tab = _G["CharacterFrameTab" .. index]
    if tab and not tab.teaAdvancedStatsHooked then
      tab.teaAdvancedStatsHooked = true
      tab:HookScript("OnShow", UpdateTogglePosition)
      tab:HookScript("OnHide", UpdateTogglePosition)
    end
  end
end

local function GetPaneHeight()
  if PANE_HEIGHT > 0 then
    return PANE_HEIGHT
  end
  if CharacterFrame then
    return CharacterFrame:GetHeight()
  end
  return 420
end

local function UpdateLayout()
  if not CharacterFrame or not pane then
    return
  end

  pane:ClearAllPoints()
  pane:SetSize(PANE_WIDTH, GetPaneHeight())
  pane:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", PANE_X, PANE_Y)
  UpdateTogglePosition()
end

local function SetPaneOpen(open)
  local db = Tea_GetDB()
  db.advancedStats = db.advancedStats or {}
  db.advancedStats.open = open and true or false

  if not pane or not toggleButton then
    return
  end

  if open and IsEnabled() then
    pane:Show()
    UpdateLayout()
    toggleButton:SetText("<")
    UpdateTogglePosition()
    if cachedLines and not cacheDirty then
      RenderLines(cachedLines)
    else
      ShowLoadingState()
      StartCollect(true)
    end
  else
    pane:Hide()
    toggleButton:SetText(">")
    UpdateTogglePosition()
  end
end

local function TogglePane()
  local db = Tea_GetDB()
  db.advancedStats = db.advancedStats or {}
  SetPaneOpen(not db.advancedStats.open)
end

local function SyncVisibility()
  if not toggleButton or not pane then
    return
  end

  if not IsEnabled() or not CharacterFrame or not CharacterFrame:IsShown() then
    toggleButton:Hide()
    pane:Hide()
    return
  end

  toggleButton:Show()
  local db = Tea_GetDB()
  if db.advancedStats and db.advancedStats.open then
    SetPaneOpen(true)
  else
    SetPaneOpen(false)
  end
end

local function CreateUI()
  if uiReady or not CharacterFrame then
    return
  end
  uiReady = true

  local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

  toggleButton = CreateFrame("Button", "TeaAdvancedStatsToggle", CharacterFrame, "UIPanelButtonTemplate")
  toggleButton:SetSize(TOGGLE_WIDTH, TOGGLE_HEIGHT)
  toggleButton:SetFrameLevel(CharacterFrame:GetFrameLevel() + 5)
  toggleButton:SetText(">")
  toggleButton:SetScript("OnClick", TogglePane)

  collectFrame = CreateFrame("Frame")
  collectFrame:Hide()
  collectFrame:SetScript("OnUpdate", function()
    ProcessCollectBatch()
  end)

  pane = CreateFrame("Frame", "TeaAdvancedStatsPane", UIParent, backdropTemplate)
  pane:SetSize(PANE_WIDTH, GetPaneHeight())
  pane:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", PANE_X, PANE_Y)
  pane:SetFrameStrata(CharacterFrame:GetFrameStrata())
  pane:SetFrameLevel(CharacterFrame:GetFrameLevel() + 4)
  pane:EnableMouse(true)
  pane:Hide()

  if pane.SetBackdrop then
    pane:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    pane:SetBackdropColor(0.06, 0.06, 0.07, 0.96)
    pane:SetBackdropBorderColor(0.35, 0.35, 0.38, 1)
  end

  local title = pane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("Advanced Stats")
  title:SetTextColor(0.9, 0.9, 0.9)

  scrollFrame = CreateFrame("ScrollFrame", "TeaAdvancedStatsScroll", pane, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 4, -28)
  scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

  scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(PANE_WIDTH - 28)
  scrollChild:SetHeight(400)
  scrollFrame:SetScrollChild(scrollChild)

  CharacterFrame:HookScript("OnShow", function()
    UpdateLayout()
    HookTabPositionUpdates()
    SyncVisibility()
    Tea_Util.After(0.05, PrefetchStats)
    Tea_Util.After(0, UpdateTogglePosition)
  end)

  CharacterFrame:HookScript("OnHide", function()
    pane:Hide()
    toggleButton:Hide()
    if collectFrame then
      collectFrame:Hide()
    end
  end)

  UpdateLayout()
  HookTabPositionUpdates()
  SyncVisibility()
end

local function TryCreateUI()
  if uiReady then
    SyncVisibility()
    return
  end
  if CharacterFrame then
    CreateUI()
  end
end

if ShowUIPanel then
  hooksecurefunc("ShowUIPanel", function(frame)
    if frame == CharacterFrame then
      TryCreateUI()
    end
  end)
end

function Tea_RefreshAdvancedStats()
  TryCreateUI()
  InvalidateCache()
  SyncVisibility()
  RefreshPane(true)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_STATS")
eventFrame:RegisterEvent("COMBAT_RATING_UPDATE")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Tea_Util.After(0, TryCreateUI)
    return
  end

  if event == "PLAYER_LOGIN" then
    Tea_Util.After(0, TryCreateUI)
    return
  end

  if event == "UNIT_STATS" and arg1 ~= "player" then
    return
  end

  InvalidateCache()
  RefreshPane(false)
end)
