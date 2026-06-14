local ADDON_NAME = ...

local MIN_WIDTH = 120
local MAX_WIDTH = 480
local MIN_HEIGHT = 16
local MAX_HEIGHT = 48
local RESIZE_GRIP_SIZE = 14
local TEXT_PADDING = 6
local ICON_SIZE = 18
local UPDATE_INTERVAL = 0.03

local PLAYER_COLOR = { 1, 0.82, 0 }
local TARGET_COLOR = { 1, 0.55, 0.2 }
local TARGET_UNINTERRUPTIBLE_COLOR = { 0.85, 0.15, 0.15 }

local CAST_EVENTS = {
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_CHANNEL_STOP",
}

local playerBar
local targetBar
local updateElapsed = 0
local blizzardCastBarSuppressed = false
local previewMode = false

local DEMO_CAST_SECONDS = 3
local DEMO_PLAYER_SPELL = "Fireball"
local DEMO_PLAYER_TEXTURE = "Interface\\Icons\\Spell_Fire_Fireball02"
local DEMO_TARGET_SPELL = "Shadow Bolt"
local DEMO_TARGET_TEXTURE = "Interface\\Icons\\Spell_Shadow_ShadowBolt02"

local function GetBlizzardCastBar()
  if PlayerCastingBarFrame then
    return PlayerCastingBarFrame
  end
  return CastingBarFrame
end

local function ShouldSuppressBlizzardCastBar()
  if previewMode and IsEnabled() and GetSettings().showPlayer ~= false then
    return true
  end
  return IsEnabled() and GetSettings().showPlayer ~= false
end

local function RestoreBlizzardCastBar(frame)
  if type(CastingBarFrame_OnLoad) == "function" then
    CastingBarFrame_OnLoad(frame)
  end
  if frame.SetUnit then
    frame:SetUnit("player", false, false)
  elseif type(CastingBarFrame_SetUnit) == "function" then
    CastingBarFrame_SetUnit(frame, "player")
  end
  blizzardCastBarSuppressed = false
end

local function UpdateBlizzardCastBar()
  local frame = GetBlizzardCastBar()
  if not frame then
    return
  end

  if ShouldSuppressBlizzardCastBar() then
    frame:UnregisterAllEvents()
    frame:Hide()
    blizzardCastBarSuppressed = true
  elseif blizzardCastBarSuppressed then
    RestoreBlizzardCastBar(frame)
  end
end

local function IsEnabled()
  return Tea_GetDB().modules.castBars
end

local function GetSettings()
  return Tea_GetDB().castBars
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

local function GetCastInfo(unit)
  if not UnitExists(unit) then
    return
  end

  local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo(unit)
  if name then
    return name, texture, startTimeMS, endTimeMS, false, notInterruptible
  end

  name, _, texture, startTimeMS, endTimeMS, _, notInterruptible = UnitChannelInfo(unit)
  if name then
    return name, texture, startTimeMS, endTimeMS, true, notInterruptible
  end
end

local function SaveBarSettings(bar)
  if not bar or not bar.frame or bar:IsLocked() then
    return
  end

  local settings = bar.settings
  local point, _, relativePoint, x, y = bar.frame:GetPoint(1)
  if point then
    settings.point = point
    settings.relativePoint = relativePoint
    settings.x = math.floor(x + 0.5)
    settings.y = math.floor(y + 0.5)
  end

  settings.width = Clamp(math.floor(bar.frame:GetWidth() + 0.5), MIN_WIDTH, MAX_WIDTH)
  settings.height = Clamp(math.floor(bar.frame:GetHeight() + 0.5), MIN_HEIGHT, MAX_HEIGHT)
end

local function ApplyBarLayout(bar)
  if not bar or not bar.frame or not bar.statusBar then
    return
  end

  local width = bar.frame:GetWidth()
  local height = bar.frame:GetHeight()
  local gripInset = bar:GetGripInset()
  local showIcon = bar.icon and bar.icon:IsShown()

  bar.statusBar:ClearAllPoints()
  if showIcon then
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("LEFT", bar.frame, "LEFT", 2, 0)
    bar.icon:SetSize(ICON_SIZE, ICON_SIZE)
    bar.statusBar:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 2, 0)
    bar.statusBar:SetPoint("BOTTOMRIGHT", bar.frame, "BOTTOMRIGHT", -gripInset, gripInset)
  else
    bar.statusBar:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0)
    bar.statusBar:SetPoint("BOTTOMRIGHT", bar.frame, "BOTTOMRIGHT", -gripInset, gripInset)
  end

  bar.text:SetWidth(width - TEXT_PADDING * 2 - gripInset - (showIcon and ICON_SIZE + 4 or 0))
end

local function ApplyBarFrameSettings(bar)
  if not bar or not bar.frame then
    return
  end

  local settings = bar.settings
  bar.frame:SetSize(
    Clamp(settings.width or 240, MIN_WIDTH, MAX_WIDTH),
    Clamp(settings.height or 24, MIN_HEIGHT, MAX_HEIGHT)
  )
  bar.frame:ClearAllPoints()
  bar.frame:SetPoint(
    settings.point or "CENTER",
    UIParent,
    settings.relativePoint or "CENTER",
    settings.x or 0,
    settings.y or 0
  )
  ApplyBarLayout(bar)
end

local function ApplyBarLockState(bar)
  if not bar or not bar.frame or not bar.grip then
    return
  end

  local locked = bar:IsLocked()
  bar.frame:SetMovable(not locked)
  if bar.frame.SetResizable then
    bar.frame:SetResizable(not locked)
  end

  if locked then
    bar.frame:RegisterForDrag()
    bar.frame:EnableMouse(false)
    bar.grip:Hide()
    bar.frame:SetScript("OnEnter", nil)
    bar.frame:SetScript("OnLeave", nil)
    bar.grip:SetScript("OnEnter", nil)
    bar.grip:SetScript("OnLeave", nil)
    bar.grip:SetScript("OnMouseDown", nil)
    bar.grip:SetScript("OnMouseUp", nil)
  else
    bar.frame:RegisterForDrag("LeftButton")
    bar.frame:EnableMouse(true)
    bar.grip:Show()
    bar.frame:SetScript("OnEnter", function()
      GameTooltip:SetOwner(bar.frame, "ANCHOR_RIGHT")
      local title = "teaBars " .. bar.key .. " cast bar"
      if previewMode then
        title = title .. " (preview)"
      end
      GameTooltip:SetText(title)
      GameTooltip:AddLine("Drag to move.", 0.9, 0.9, 0.9)
      GameTooltip:AddLine("Use the corner grip to resize.", 0.9, 0.9, 0.9)
      GameTooltip:Show()
    end)
    bar.frame:SetScript("OnLeave", GameTooltip_Hide)
    bar.grip:SetScript("OnEnter", function()
      GameTooltip:SetOwner(bar.grip, "ANCHOR_RIGHT")
      GameTooltip:SetText("Drag to resize")
      GameTooltip:Show()
    end)
    bar.grip:SetScript("OnLeave", GameTooltip_Hide)
    bar.grip:SetScript("OnMouseDown", function()
      bar.frame:StartSizing("BOTTOMRIGHT")
    end)
    bar.grip:SetScript("OnMouseUp", function()
      bar.frame:StopMovingOrSizing()
      SaveBarSettings(bar)
    end)
  end

  ApplyBarLayout(bar)
end

local function ShouldShowPreviewBar(bar)
  if not previewMode or not bar or not IsEnabled() then
    return false
  end
  if bar.unit == "player" then
    return GetSettings().showPlayer ~= false
  end
  return GetSettings().showTarget ~= false
end

local function UpdatePreviewCastBar(bar)
  if not ShouldShowPreviewBar(bar) then
    if bar and bar.frame then
      bar.frame:Hide()
    end
    return
  end

  local now = GetTime()
  if not bar.previewStart then
    bar.previewStart = now
  end

  local durationMS = DEMO_CAST_SECONDS * 1000
  local elapsedMS = ((now - bar.previewStart) % DEMO_CAST_SECONDS) * 1000

  bar.statusBar:SetMinMaxValues(0, durationMS)
  bar.statusBar:SetValue(elapsedMS)
  bar.text:SetText(bar.unit == "player" and DEMO_PLAYER_SPELL or DEMO_TARGET_SPELL)

  if bar.icon then
    bar.icon:SetTexture(bar.unit == "player" and DEMO_PLAYER_TEXTURE or DEMO_TARGET_TEXTURE)
    bar.icon:Show()
  end

  if bar.unit == "player" then
    bar.statusBar:SetStatusBarColor(PLAYER_COLOR[1], PLAYER_COLOR[2], PLAYER_COLOR[3])
  else
    bar.statusBar:SetStatusBarColor(TARGET_COLOR[1], TARGET_COLOR[2], TARGET_COLOR[3])
  end

  ApplyBarLayout(bar)
  bar.frame:Show()
end

local function UpdateCastBar(bar)
  if not bar or not bar.frame then
    return
  end

  if previewMode then
    UpdatePreviewCastBar(bar)
    return
  end

  if not IsEnabled() or not bar:IsActive() then
    bar.frame:Hide()
    return
  end

  local name, texture, startTimeMS, endTimeMS, isChannel, notInterruptible = GetCastInfo(bar.unit)
  if not name then
    bar.frame:Hide()
    return
  end

  local now = GetTime() * 1000
  local duration = math.max(endTimeMS - startTimeMS, 1)
  local value

  if isChannel then
    value = math.max(endTimeMS - now, 0)
  else
    value = math.min(math.max(now - startTimeMS, 0), duration)
  end

  bar.statusBar:SetMinMaxValues(0, duration)
  bar.statusBar:SetValue(value)
  bar.text:SetText(name)

  if bar.icon then
    if texture then
      bar.icon:SetTexture(texture)
      bar.icon:Show()
    else
      bar.icon:Hide()
    end
  end

  if bar.unit == "player" then
    bar.statusBar:SetStatusBarColor(PLAYER_COLOR[1], PLAYER_COLOR[2], PLAYER_COLOR[3])
  elseif notInterruptible then
    bar.statusBar:SetStatusBarColor(
      TARGET_UNINTERRUPTIBLE_COLOR[1],
      TARGET_UNINTERRUPTIBLE_COLOR[2],
      TARGET_UNINTERRUPTIBLE_COLOR[3]
    )
  else
    bar.statusBar:SetStatusBarColor(TARGET_COLOR[1], TARGET_COLOR[2], TARGET_COLOR[3])
  end

  ApplyBarLayout(bar)
  bar.frame:Show()
end

local function CreateCastBar(key, unit, defaultY)
  local settings = GetSettings()[key]
  local bar = {
    key = key,
    unit = unit,
    settings = settings,
  }

  function bar:IsLocked()
    return GetSettings().locked == true
  end

  function bar:IsActive()
    if not IsEnabled() then
      return false
    end
    if self.unit == "player" then
      return GetSettings().showPlayer ~= false
    end
    return GetSettings().showTarget ~= false and UnitExists("target")
  end

  function bar:GetGripInset()
    if self:IsLocked() or not self.grip or not self.grip:IsShown() then
      return 0
    end
    return RESIZE_GRIP_SIZE / 2
  end

  local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
  bar.frame = CreateFrame("Frame", nil, UIParent, backdropTemplate)
  bar.frame:SetFrameStrata("HIGH")
  bar.frame:SetClampedToScreen(true)
  bar.frame:SetMovable(true)
  if bar.frame.SetResizable then
    bar.frame:SetResizable(true)
  end
  bar.frame:EnableMouse(true)
  bar.frame:RegisterForDrag("LeftButton")
  bar.frame:Hide()

  if bar.frame.SetResizeBounds then
    bar.frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
  end

  if bar.frame.SetBackdrop then
    bar.frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      tile = false,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bar.frame:SetBackdropColor(0, 0, 0, 0.45)
    bar.frame:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.9)
  end

  bar.icon = bar.frame:CreateTexture(nil, "ARTWORK")
  bar.icon:Hide()

  bar.statusBar = CreateFrame("StatusBar", nil, bar.frame)
  bar.statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar.statusBar:SetStatusBarColor(PLAYER_COLOR[1], PLAYER_COLOR[2], PLAYER_COLOR[3])

  bar.text = bar.statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER", bar.statusBar, "CENTER", 0, 0)

  bar.grip = CreateFrame("Frame", nil, bar.frame)
  bar.grip:SetSize(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
  bar.grip:SetPoint("BOTTOMRIGHT", bar.frame, "BOTTOMRIGHT", 0, 0)
  bar.grip:EnableMouse(true)

  local gripTexture = bar.grip:CreateTexture(nil, "ARTWORK")
  gripTexture:SetAllPoints()
  gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

  if settings.y == nil and defaultY then
    settings.y = defaultY
  end

  bar.frame:SetScript("OnDragStart", function(self)
    if bar:IsLocked() then
      return
    end
    self:StartMoving()
  end)
  bar.frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveBarSettings(bar)
  end)
  bar.frame:SetScript("OnSizeChanged", function()
    if bar:IsLocked() then
      return
    end
    ApplyBarLayout(bar)
    SaveBarSettings(bar)
    UpdateCastBar(bar)
  end)

  ApplyBarFrameSettings(bar)
  ApplyBarLockState(bar)
  return bar
end

local function EnsureBars()
  if not playerBar then
    playerBar = CreateCastBar("player", "player", -120)
  end
  if not targetBar then
    targetBar = CreateCastBar("target", "target", -90)
  end
end

local function UpdateAllCastBars()
  UpdateCastBar(playerBar)
  UpdateCastBar(targetBar)
end

local function PlayerIsReady()
  return UnitGUID("player") ~= nil
end

local function TryShowCastBars(applyOnly)
  if not IsEnabled() then
    if playerBar and playerBar.frame then
      playerBar.frame:Hide()
    end
    if targetBar and targetBar.frame then
      targetBar.frame:Hide()
    end
    UpdateBlizzardCastBar()
    return true
  end

  if not PlayerIsReady() then
    return false
  end

  EnsureBars()

  if not applyOnly then
    if playerBar.frame:IsShown() then
      SaveBarSettings(playerBar)
    end
    if targetBar.frame:IsShown() then
      SaveBarSettings(targetBar)
    end
  end

  ApplyBarFrameSettings(playerBar)
  ApplyBarFrameSettings(targetBar)
  ApplyBarLockState(playerBar)
  ApplyBarLockState(targetBar)
  UpdateAllCastBars()
  UpdateBlizzardCastBar()
  return true
end

function Tea_CenterCastBarHorizontally(barKey)
  local settings = GetSettings()
  local barSettings = settings[barKey]
  if barSettings then
    barSettings.point = "CENTER"
    barSettings.relativePoint = "CENTER"
    barSettings.x = 0
  end

  Tea_ApplyCastBarsPosition()
end

function Tea_ApplyCastBarsPosition()
  if previewMode then
    EnsureBars()
    ApplyBarFrameSettings(playerBar)
    ApplyBarFrameSettings(targetBar)
    ApplyBarLockState(playerBar)
    ApplyBarLockState(targetBar)
    UpdateAllCastBars()
    UpdateBlizzardCastBar()
    return
  end

  TryShowCastBars(true)
end

function Tea_RefreshCastBars()
  if previewMode then
    Tea_ApplyCastBarsPosition()
    return
  end

  TryShowCastBars(false)
end

function Tea_SetCastBarPreview(active)
  local wantPreview = active and true or false
  if previewMode == wantPreview then
    if wantPreview then
      Tea_RefreshCastBars()
    end
    return
  end

  previewMode = wantPreview

  if previewMode then
    Tea_RefreshCastBars()
    return
  end

  if playerBar then
    playerBar.previewStart = nil
  end
  if targetBar then
    targetBar.previewStart = nil
  end

  TryShowCastBars(false)
end

local function OnCastEvent(unit)
  if unit == "player" and playerBar then
    UpdateCastBar(playerBar)
  elseif unit == "target" and targetBar then
    UpdateCastBar(targetBar)
  end
end

local bootstrapFrame = CreateFrame("Frame")
local bootstrapTicks = 0
local MAX_BOOTSTRAP_TICKS = 100

local function StartBootstrap()
  bootstrapTicks = MAX_BOOTSTRAP_TICKS
  bootstrapFrame:Show()
end

bootstrapFrame:Hide()
bootstrapFrame:SetScript("OnUpdate", function(self)
  if bootstrapTicks <= 0 then
    self:Hide()
    return
  end

  bootstrapTicks = bootstrapTicks - 1
  if TryShowCastBars() then
    bootstrapTicks = 0
    self:Hide()
  end
end)

local tickFrame = CreateFrame("Frame")
tickFrame:SetScript("OnUpdate", function(_, elapsed)
  if not IsEnabled() and not previewMode then
    return
  end

  local playerVisible = playerBar and playerBar.frame and playerBar.frame:IsShown()
  local targetVisible = targetBar and targetBar.frame and targetBar.frame:IsShown()
  if not playerVisible and not targetVisible then
    return
  end

  updateElapsed = updateElapsed + elapsed
  if updateElapsed >= UPDATE_INTERVAL then
    updateElapsed = 0
    UpdateAllCastBars()
  end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

for _, event in ipairs(CAST_EVENTS) do
  eventFrame:RegisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    StartBootstrap()
    return
  end

  if event == "PLAYER_LOGIN" then
    StartBootstrap()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    if arg1 or arg2 then
      StartBootstrap()
    end
    UpdateBlizzardCastBar()
    return
  end

  if event == "PLAYER_TARGET_CHANGED" then
    UpdateCastBar(targetBar)
    return
  end

  if arg1 == "player" or arg1 == "target" then
    OnCastEvent(arg1)
  end
end)
