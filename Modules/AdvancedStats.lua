local ADDON_NAME = ...

local PANE_WIDTH = 248
local PANE_HEIGHT = 426
local PANE_X = -32
local PANE_Y = -13
local ROW_HEIGHT = 14
local PADDING = 14
local VALUE_COLUMN = -10
local REFRESH_INTERVAL = 0.25
local TOGGLE_WIDTH = 24
local TOGGLE_HEIGHT = 22
local TOGGLE_TAB_GAP = 2
local TOGGLE_X_OFFSET = 55
local TOGGLE_Y_OFFSET = 20
local TOGGLE_OVERLAP_RATIO = 0.4

local RESISTANCE_SCHOOLS = {
  { index = 1, label = "Holy" },
  { index = 2, label = "Fire" },
  { index = 3, label = "Nature" },
  { index = 4, label = "Frost" },
  { index = 5, label = "Shadow" },
  { index = 6, label = "Arcane" },
}

local RATING_ENTRIES = {
  { id = 6, label = "Hit" },
  { id = 8, label = "Spell Hit" },
  { id = 9, label = "Crit" },
  { id = 10, label = "Ranged Crit" },
  { id = 11, label = "Spell Crit" },
  { id = 3, label = "Dodge Rating" },
  { id = 4, label = "Parry Rating" },
  { id = 5, label = "Block Rating" },
}

local STAT_NAME_FALLBACKS = {
  "Strength",
  "Agility",
  "Stamina",
  "Intellect",
  "Spirit",
}

local toggleButton
local pane
local scrollFrame
local scrollChild
local statusLine
local linePool = {}
local uiReady = false
local lastRefresh = 0
local cachedLines
local cacheDirty = true

local function IsEnabled()
  return Tea_GetDB().modules.advancedStats == true
end

local function IsShortLabel(text)
  if type(text) ~= "string" or text == "" then
    return false
  end
  if #text > 22 then
    return false
  end
  local lower = text:lower()
  if text:find("%%") or lower:find("increase") or lower:find("your ") or lower:find(" by ") then
    return false
  end
  return true
end

local function SafeLabel(value, fallback)
  if IsShortLabel(value) then
    return value
  end
  return fallback
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local results = { pcall(fn, ...) }
  if not results[1] then
    return nil
  end
  table.remove(results, 1)
  return unpack(results)
end

local function AsNumber(value)
  return tonumber(value)
end

local function Round(value)
  local number = AsNumber(value)
  if number == nil then
    return 0
  end
  return math.floor(number + 0.5)
end

local function FormatPercent(value)
  local number = AsNumber(value)
  if number == nil then
    return nil
  end
  return string.format("%.2f%%", number)
end

local function FormatRange(minValue, maxValue)
  local minNumber = AsNumber(minValue)
  local maxNumber = AsNumber(maxValue)
  if minNumber == nil or maxNumber == nil then
    return nil
  end
  return string.format("%d - %d", Round(minNumber), Round(maxNumber))
end

local function FormatSpeed(speed)
  local number = AsNumber(speed)
  if number == nil or number <= 0 then
    return nil
  end
  return string.format("%.2f", number)
end

local function FormatPrimaryStat(index)
  local _, effective, posBuff, negBuff = SafeCall(UnitStat, "player", index)
  effective = AsNumber(effective)
  if effective == nil then
    return nil
  end

  posBuff = AsNumber(posBuff) or 0
  negBuff = AsNumber(negBuff) or 0

  if posBuff ~= 0 or negBuff ~= 0 then
    local detail = tostring(Round(effective))
    if posBuff > 0 then
      detail = detail .. " |cff00ff00+" .. Round(posBuff) .. "|r"
    end
    if negBuff > 0 then
      detail = detail .. " |cffff2020-" .. Round(negBuff) .. "|r"
    end
    return detail
  end

  return tostring(Round(effective))
end

local function GetStatLabel(index)
  local globals = { STAT_STRENGTH, STAT_AGILITY, STAT_STAMINA, STAT_INTELLECT, STAT_SPIRIT }
  return SafeLabel(globals[index], STAT_NAME_FALLBACKS[index] or "Stat")
end

local function AddLine(lines, label, value)
  if value == nil or value == "" then
    return
  end
  if type(value) == "number" then
    value = tostring(value)
  elseif type(value) ~= "string" then
    return
  end
  lines[#lines + 1] = { kind = "line", label = SafeLabel(label, "Stat"), value = value }
end

local function AddSection(lines, title)
  lines[#lines + 1] = { kind = "section", title = SafeLabel(title, "Stats") }
end

local function HasRangedStats()
  local ap = AsNumber(SafeCall(UnitRangedAttackPower, "player"))
  return ap and ap > 0
end

local function GetSpellDamage()
  local best = 0
  for school = 2, 7 do
    local bonus = AsNumber(SafeCall(GetSpellBonusDamage, school)) or 0
    if bonus > best then
      best = bonus
    end
  end
  if best <= 0 then
    return nil
  end
  return best
end

local function GetSpellCrit()
  local best = 0
  for school = 2, 7 do
    local crit = AsNumber(SafeCall(GetSpellCritChance, school)) or 0
    if crit > best then
      best = crit
    end
  end
  if best <= 0 then
    return nil
  end
  return best
end

local function GetTotalResistance(unit, index)
  if type(UnitResistance) ~= "function" then
    return nil
  end

  local ok, base, total = pcall(UnitResistance, unit, index)
  if not ok then
    return nil
  end

  total = AsNumber(total)
  if total and total > 0 then
    return total
  end

  return AsNumber(base)
end

local function GetNotCastingManaRegen()
  if type(GetManaRegen) ~= "function" then
    return nil
  end

  local casting, notCasting = SafeCall(GetManaRegen)
  return AsNumber(notCasting) or AsNumber(casting)
end

local function FormatRatingLine(label, id)
  if type(GetCombatRating) ~= "function" then
    return nil
  end

  local bonus = AsNumber(SafeCall(GetCombatRatingBonus, id))
  local rating = AsNumber(SafeCall(GetCombatRating, id))
  if (not bonus or bonus == 0) and (not rating or rating == 0) then
    return nil
  end

  if bonus and bonus ~= 0 then
    local percentText = FormatPercent(bonus)
    if not percentText then
      return nil
    end
    if rating and rating > 0 then
      return percentText .. " (" .. Round(rating) .. ")"
    end
    return percentText
  end

  if rating and rating > 0 then
    return tostring(Round(rating))
  end

  return nil
end

local function BuildStatLines()
  local lines = {}
  local unit = "player"

  AddSection(lines, SafeLabel(ATTRIBUTES_LABEL, "Attributes"))
  for index = 1, 5 do
    AddLine(lines, GetStatLabel(index), FormatPrimaryStat(index))
  end

  AddSection(lines, SafeLabel(MELEE, "Melee"))
  local minDamage, maxDamage = SafeCall(UnitDamage, unit)
  AddLine(lines, SafeLabel(DAMAGE, "Damage"), FormatRange(minDamage, maxDamage))
  AddLine(lines, "Attack Power", Round(SafeCall(UnitAttackPower, unit)))
  AddLine(lines, SafeLabel(ATTACK_SPEED, "Speed"), FormatSpeed(SafeCall(UnitAttackSpeed, unit)))
  AddLine(lines, "Critical Strike Chance", FormatPercent(SafeCall(GetCritChance)))

  if HasRangedStats() then
    AddSection(lines, SafeLabel(RANGED, "Ranged"))
    local rangedMin, rangedMax = SafeCall(UnitRangedDamage, unit)
    AddLine(lines, SafeLabel(DAMAGE, "Damage"), FormatRange(rangedMin, rangedMax))
    AddLine(lines, "Attack Power", Round(SafeCall(UnitRangedAttackPower, unit)))
    AddLine(lines, SafeLabel(ATTACK_SPEED, "Speed"), FormatSpeed(SafeCall(UnitRangedAttackSpeed, unit)))
    AddLine(lines, "Critical Strike Chance", FormatPercent(SafeCall(GetRangedCritChance)))
  end

  local spellDamage = GetSpellDamage()
  local spellHealing = AsNumber(SafeCall(GetSpellBonusHealing)) or 0
  local spellCrit = GetSpellCrit()
  local manaRegen = GetNotCastingManaRegen()
  if spellDamage or spellHealing > 0 or spellCrit or (manaRegen and manaRegen > 0) then
    AddSection(lines, SafeLabel(SPELLS, "Spell"))
    if spellDamage then
      AddLine(lines, SafeLabel(SPELL_BONUS_DAMAGE, "Bonus Damage"), "+" .. Round(spellDamage))
    end
    if spellHealing > 0 then
      AddLine(lines, SafeLabel(SPELL_BONUS_HEALING, "Bonus Healing"), "+" .. Round(spellHealing))
    end
    if spellCrit then
      AddLine(lines, "Critical Strike Chance", FormatPercent(spellCrit))
    end
    if manaRegen and manaRegen > 0 then
      AddLine(lines, SafeLabel(MANA_REGEN, "Mana Regeneration"), string.format("%d / 5 sec", Round(manaRegen)))
    end
  end

  AddSection(lines, SafeLabel(DEFENSE, "Defense"))
  local _, effectiveArmor = SafeCall(UnitArmor, unit)
  effectiveArmor = AsNumber(effectiveArmor)
  AddLine(lines, SafeLabel(ARMOR, "Armor"), Round(effectiveArmor))
  if type(PaperDollFrame_GetArmorReduction) == "function" and effectiveArmor then
    local reduction = AsNumber(SafeCall(PaperDollFrame_GetArmorReduction, effectiveArmor, UnitLevel(unit)))
    if reduction then
      AddLine(lines, SafeLabel(DAMAGE_REDUCTION, "Damage Reduction"), FormatPercent(reduction))
    end
  end

  local baseDefense, armorDefense = SafeCall(UnitDefense, unit)
  baseDefense = AsNumber(baseDefense)
  armorDefense = AsNumber(armorDefense) or 0
  if baseDefense then
    local defenseValue = Round(baseDefense + armorDefense)
    if defenseValue > 0 then
      AddLine(lines, "Defense Skill", defenseValue)
    end
  end

  AddLine(lines, SafeLabel(STAT_DODGE, "Dodge"), FormatPercent(SafeCall(GetDodgeChance)))
  AddLine(lines, SafeLabel(STAT_PARRY, "Parry"), FormatPercent(SafeCall(GetParryChance)))
  AddLine(lines, SafeLabel(STAT_BLOCK, "Block"), FormatPercent(SafeCall(GetBlockChance)))

  local blockValue = AsNumber(SafeCall(GetShieldBlock))
  if blockValue and blockValue > 0 then
    AddLine(lines, SafeLabel(BLOCK_VALUE, "Block Value"), Round(blockValue))
  end

  local hasRatings = false
  local ratingLines = {}
  if type(GetCombatRating) == "function" then
    for _, entry in ipairs(RATING_ENTRIES) do
      local value = FormatRatingLine(entry.label, entry.id)
      if value then
        hasRatings = true
        ratingLines[#ratingLines + 1] = { label = entry.label, value = value }
      end
    end
  end

  if hasRatings then
    AddSection(lines, SafeLabel(COMBAT_RATING, "Combat Ratings"))
    for _, row in ipairs(ratingLines) do
      AddLine(lines, row.label, row.value)
    end
  end

  local hasResistances = false
  local resistanceLines = {}
  for _, school in ipairs(RESISTANCE_SCHOOLS) do
    local amount = GetTotalResistance(unit, school.index)
    if amount and amount > 0 then
      hasResistances = true
      resistanceLines[#resistanceLines + 1] = {
        label = school.label,
        value = tostring(Round(amount)),
      }
    end
  end

  if hasResistances then
    AddSection(lines, SafeLabel(RESISTANCE, "Resistances"))
    for _, row in ipairs(resistanceLines) do
      AddLine(lines, row.label, row.value)
    end
  end

  return lines
end

local function InvalidateCache()
  cacheDirty = true
end

local function AcquireLine(index)
  local line = linePool[index]
  if not line then
    line = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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

  for index, entry in ipairs(lines) do
    lineIndex = lineIndex + 1
    local fs = AcquireLine(lineIndex)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PADDING, -y)
    fs:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", VALUE_COLUMN, -y)

    if entry.kind == "section" then
      fs:SetJustifyH("LEFT")
      fs:SetTextColor(1, 0.82, 0)
      fs:SetText(tostring(entry.title or ""))
      y = y + ROW_HEIGHT
    else
      fs:SetJustifyH("LEFT")
      fs:SetText(tostring(entry.label or ""))
      lineIndex = lineIndex + 1
      local valueFs = AcquireLine(lineIndex)
      valueFs:ClearAllPoints()
      valueFs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", PADDING, -y)
      valueFs:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", VALUE_COLUMN, -y)
      valueFs:SetJustifyH("RIGHT")
      valueFs:SetTextColor(1, 1, 1)
      valueFs:SetText(entry.value)
      y = y + ROW_HEIGHT

      local nextEntry = lines[index + 1]
      if not nextEntry or nextEntry.kind == "section" then
        y = y + ROW_HEIGHT
      end
    end
  end

  HideUnusedLines(lineIndex + 1)
  scrollChild:SetWidth(PANE_WIDTH - 36)
  scrollChild:SetHeight(math.max(y + PADDING, pane and pane:GetHeight() or 400))
end

local function ShowLoadingState()
  if not scrollChild then
    return
  end

  HideUnusedLines(2)
  if not statusLine then
    statusLine = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusLine:SetPoint("TOP", scrollChild, "TOP", 0, -PADDING - 8)
    statusLine:SetJustifyH("CENTER")
  end
  statusLine:SetTextColor(0.65, 0.65, 0.65)
  statusLine:SetText("Loading...")
  statusLine:Show()
  scrollChild:SetHeight(pane and pane:GetHeight() or 400)
end

local function CollectStatLines()
  local ok, lines = pcall(BuildStatLines)
  if ok and type(lines) == "table" then
    return lines
  end

  if not ok and Tea_Print then
    Tea_Print("Advanced stats error: " .. tostring(lines))
  end

  return nil
end

local function RefreshStats(force)
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

  local lines = CollectStatLines()
  if not lines then
    if statusLine then
      statusLine:Show()
      statusLine:SetText("Unable to load stats.")
    else
      ShowLoadingState()
      if statusLine then
        statusLine:SetText("Unable to load stats.")
      end
    end
    return
  end

  cachedLines = lines
  cacheDirty = false
  lastRefresh = now
  RenderLines(cachedLines)
end

local function PrefetchStats()
  if not IsEnabled() then
    return
  end
  if cacheDirty or not cachedLines then
    local lines = CollectStatLines()
    if lines then
      cachedLines = lines
      cacheDirty = false
      lastRefresh = GetTime()
    end
  end
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
    RefreshStats(false)
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

local function ApplyPaneBackdrop(frame)
  if not frame.SetBackdrop then
    return
  end

  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetBackdropColor(0, 0, 0, 1)
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

  pane = CreateFrame("Frame", "TeaAdvancedStatsPane", UIParent, backdropTemplate)
  pane:SetSize(PANE_WIDTH, GetPaneHeight())
  pane:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", PANE_X, PANE_Y)
  pane:SetFrameStrata(CharacterFrame:GetFrameStrata())
  pane:SetFrameLevel(CharacterFrame:GetFrameLevel() + 4)
  pane:EnableMouse(true)
  pane:Hide()

  ApplyPaneBackdrop(pane)

  local title = pane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", pane, "TOP", 0, -16)
  title:SetText("Advanced Stats")
  title:SetTextColor(1, 0.82, 0)

  local titleLeft = pane:CreateTexture(nil, "ARTWORK")
  titleLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Info-Title")
  titleLeft:SetTexCoord(0.2, 0.8, 0, 1)
  titleLeft:SetPoint("TOPLEFT", 16, -28)
  titleLeft:SetPoint("TOPRIGHT", pane, "TOP", -8, -28)
  titleLeft:SetHeight(12)

  local titleRight = pane:CreateTexture(nil, "ARTWORK")
  titleRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Info-Title")
  titleRight:SetTexCoord(0.2, 0.8, 0, 1)
  titleRight:SetPoint("TOPLEFT", pane, "TOP", 8, -28)
  titleRight:SetPoint("TOPRIGHT", -16, -28)
  titleRight:SetHeight(12)

  scrollFrame = CreateFrame("ScrollFrame", "TeaAdvancedStatsScroll", pane, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 12, -42)
  scrollFrame:SetPoint("BOTTOMRIGHT", -28, 14)

  scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(PANE_WIDTH - 36)
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
  RefreshStats(true)
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
  RefreshStats(false)
end)
