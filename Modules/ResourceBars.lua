local ADDON_NAME = ...

local MIN_WIDTH = 120
local MAX_WIDTH = 420
local MIN_HEIGHT = 28
local MAX_HEIGHT = 140
local BAR_GAP = 4
local TEXT_PADDING = 4
local RESIZE_GRIP_SIZE = 14

local frame
local healthBar
local healthText
local powerBar
local powerText
local resizeGrip
local updateElapsed = 0
local UPDATE_INTERVAL = 0.1

local PLAYER_UNIT_EVENTS = {
  "UNIT_HEALTH",
  "UNIT_MAXHEALTH",
  "UNIT_POWER_UPDATE",
  "UNIT_MAXPOWER",
  "UNIT_DISPLAYPOWER_CHANGED",
}

local function RegisterPlayerUnitEvents(targetFrame)
  for _, event in ipairs(PLAYER_UNIT_EVENTS) do
    if targetFrame.RegisterUnitEvent then
      targetFrame:RegisterUnitEvent(event, "player")
    else
      targetFrame:RegisterEvent(event)
    end
  end

  if targetFrame.RegisterUnitEvent then
    pcall(targetFrame.RegisterUnitEvent, targetFrame, "UNIT_POWER_FREQUENT", "player")
  end
end

local function ShouldHandleUnitEvent(unit)
  return not unit or unit == "player"
end

local function IsEnabled()
  return Tea_GetDB().modules.resourceBars
end

local function GetSettings()
  return Tea_GetDB().resourceBars
end

local function Clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function SaveFrameSettings()
  if not frame or IsLocked() then
    return
  end

  local settings = GetSettings()
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  if point then
    settings.point = point
    settings.relativePoint = relativePoint
    settings.x = math.floor(x + 0.5)
    settings.y = math.floor(y + 0.5)
  end

  settings.width = Clamp(math.floor(frame:GetWidth() + 0.5), MIN_WIDTH, MAX_WIDTH)
  settings.height = Clamp(math.floor(frame:GetHeight() + 0.5), MIN_HEIGHT, MAX_HEIGHT)
end

local function GetPowerType()
  if UnitPowerType then
    return UnitPowerType("player")
  end
  return (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
end

local function GetPowerColor(powerType)
  local rage = (Enum and Enum.PowerType and Enum.PowerType.Rage) or 1
  local focus = (Enum and Enum.PowerType and Enum.PowerType.Focus) or 2
  local energy = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3

  if powerType == rage then
    return 1, 0.1, 0.1
  end
  if powerType == energy then
    return 1, 0.95, 0.35
  end
  if powerType == focus then
    return 1, 0.55, 0.2
  end
  return 0.12, 0.58, 1
end

local function FormatResourceValue(value)
  if value >= 10000 then
    return string.format("%.1fk", value / 1000)
  end
  return tostring(value)
end

local function PlayerUsesPowerBar()
  local powerType = GetPowerType()
  local maxPower = UnitPowerMax("player", powerType) or 0
  return maxPower > 0
end

local function IsLocked()
  return GetSettings().locked == true
end

local function GetGripInset()
  if IsLocked() or not resizeGrip or not resizeGrip:IsShown() then
    return 0
  end
  return RESIZE_GRIP_SIZE / 2
end

local function ApplyLayout()
  if not frame or not healthBar or not powerBar then
    return
  end

  local width = frame:GetWidth()
  local height = frame:GetHeight()
  local showPower = PlayerUsesPowerBar()
  local barHeight
  local gripInset = GetGripInset()

  powerBar:SetShown(showPower)
  powerText:SetShown(showPower)

  if showPower then
    barHeight = (height - BAR_GAP) / 2
    healthBar:ClearAllPoints()
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -gripInset, 0)
    healthBar:SetHeight(barHeight)

    powerBar:ClearAllPoints()
    powerBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, -BAR_GAP)
    powerBar:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, -BAR_GAP)
    powerBar:SetHeight(barHeight)
  else
    healthBar:ClearAllPoints()
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -gripInset, gripInset)
  end

  healthText:SetWidth(width - TEXT_PADDING * 2 - gripInset * 2)
  powerText:SetWidth(width - TEXT_PADDING * 2 - gripInset * 2)
end

local function ShowFrameTooltip()
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  GameTooltip:SetText("tea resource bars")
  GameTooltip:AddLine("Drag to move.", 0.9, 0.9, 0.9)
  GameTooltip:AddLine("Use the corner grip to resize.", 0.9, 0.9, 0.9)
  GameTooltip:Show()
end

local function ShowGripTooltip()
  GameTooltip:SetOwner(resizeGrip, "ANCHOR_RIGHT")
  GameTooltip:SetText("Drag to resize")
  GameTooltip:Show()
end

local function ApplyLockState()
  if not frame or not resizeGrip then
    return
  end

  local locked = IsLocked()

  frame:SetMovable(not locked)
  frame:SetResizable(not locked)

  if locked then
    frame:RegisterForDrag()
    frame:EnableMouse(false)
    resizeGrip:Hide()
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    resizeGrip:SetScript("OnEnter", nil)
    resizeGrip:SetScript("OnLeave", nil)
    resizeGrip:SetScript("OnMouseDown", nil)
    resizeGrip:SetScript("OnMouseUp", nil)
  else
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(true)
    resizeGrip:Show()
    frame:SetScript("OnEnter", ShowFrameTooltip)
    frame:SetScript("OnLeave", GameTooltip_Hide)
    resizeGrip:SetScript("OnEnter", ShowGripTooltip)
    resizeGrip:SetScript("OnLeave", GameTooltip_Hide)
    resizeGrip:SetScript("OnMouseDown", function()
      frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
      frame:StopMovingOrSizing()
      SaveFrameSettings()
    end)
  end

  ApplyLayout()
end

local function UpdateBars()
  if not frame or not frame:IsShown() then
    return
  end

  local health = UnitHealth("player") or 0
  local maxHealth = UnitHealthMax("player") or 0
  healthBar:SetMinMaxValues(0, math.max(maxHealth, 1))
  healthBar:SetValue(health)
  healthText:SetText(string.format("%s / %s", FormatResourceValue(health), FormatResourceValue(maxHealth)))

  if PlayerUsesPowerBar() then
    local powerType = GetPowerType()
    local power = UnitPower("player", powerType) or 0
    local maxPower = UnitPowerMax("player", powerType) or 0
    local r, g, b = GetPowerColor(powerType)
    powerBar:SetStatusBarColor(r, g, b)
    powerBar:SetMinMaxValues(0, math.max(maxPower, 1))
    powerBar:SetValue(power)
    powerText:SetText(string.format("%s / %s", FormatResourceValue(power), FormatResourceValue(maxPower)))
  end
end

local function ApplyFrameSettings()
  if not frame then
    return
  end

  local settings = GetSettings()
  frame:SetSize(
    Clamp(settings.width or 200, MIN_WIDTH, MAX_WIDTH),
    Clamp(settings.height or 48, MIN_HEIGHT, MAX_HEIGHT)
  )
  frame:ClearAllPoints()
  frame:SetPoint(
    settings.point or "CENTER",
    UIParent,
    settings.relativePoint or "CENTER",
    settings.x or -320,
    settings.y or -180
  )
  ApplyLayout()
  UpdateBars()
end

local function CreateBars()
  if frame then
    return
  end

  local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "TeaResourceBarsFrame", UIParent, backdropTemplate)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  if frame.SetResizeBounds then
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
  end

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      tile = false,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.45)
    frame:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.9)
  end

  healthBar = CreateFrame("StatusBar", nil, frame)
  healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  healthBar:SetStatusBarColor(0.12, 0.78, 0.12)

  healthText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)

  powerBar = CreateFrame("StatusBar", nil, frame)
  powerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

  powerText = powerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  powerText:SetPoint("CENTER", powerBar, "CENTER", 0, 0)

  resizeGrip = CreateFrame("Frame", nil, frame)
  resizeGrip:SetSize(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
  resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  resizeGrip:EnableMouse(true)

  local grip = resizeGrip:CreateTexture(nil, "ARTWORK")
  grip:SetAllPoints()
  grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

  frame:SetScript("OnDragStart", function(self)
    if IsLocked() then
      return
    end
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFrameSettings()
  end)
  frame:SetScript("OnSizeChanged", function()
    if IsLocked() then
      return
    end
    ApplyLayout()
    SaveFrameSettings()
    UpdateBars()
  end)
  frame:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then
      return
    end

    updateElapsed = updateElapsed + elapsed
    if updateElapsed >= UPDATE_INTERVAL then
      updateElapsed = 0
      UpdateBars()
    end
  end)

  ApplyFrameSettings()
  ApplyLockState()
end

function Tea_RefreshResourceBars()
  if not IsEnabled() then
    if frame then
      frame:Hide()
    end
    return
  end

  CreateBars()
  ApplyFrameSettings()
  ApplyLockState()
  frame:Show()
  updateElapsed = 0
  UpdateBars()
end

local function OnPlayerResourceEvent()
  if not IsEnabled() or not frame or not frame:IsShown() or not powerBar then
    return
  end

  if PlayerUsesPowerBar() ~= powerBar:IsShown() then
    ApplyLayout()
  end
  UpdateBars()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RegisterPlayerUnitEvents(eventFrame)

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    return
  end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    Tea_RefreshResourceBars()
    return
  end

  if not ShouldHandleUnitEvent(arg1) then
    return
  end

  OnPlayerResourceEvent()
end)
