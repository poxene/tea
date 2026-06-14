local ADDON_NAME = ...

local THISTLE_TEA_ITEM_ID = 7676
local THISTLE_TEA_ICON = "Interface\\Icons\\INV_Drink_Milk_05"
local BUTTON_SIZE = 31
local ICON_SIZE = 20
local ICON_OFFSET_X = 7
local ICON_OFFSET_Y = -6
local BACKGROUND_OFFSET_X = 7
local BACKGROUND_OFFSET_Y = -5
local MINIMAP_RADIUS = 80
local DRAG_THRESHOLD = 4

local button

local function GetThistleTeaIcon()
  if Tea_Util and Tea_Util.GetItemInfoInstant then
    local _, _, _, _, icon = Tea_Util.GetItemInfoInstant(THISTLE_TEA_ITEM_ID)
    if icon then
      return icon
    end
  end

  if C_Item and C_Item.GetItemIconByID then
    local icon = C_Item.GetItemIconByID(THISTLE_TEA_ITEM_ID)
    if icon then
      return icon
    end
  end

  local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(THISTLE_TEA_ITEM_ID)
  if texture then
    return texture
  end

  return THISTLE_TEA_ICON
end

local function ApplyMinimapIcon()
  if not button or not button.icon then
    return
  end

  button.icon:SetTexture(GetThistleTeaIcon())
end

local function GetMinimapSettings()
  return Tea_GetDB().minimap
end

local function PositionButton()
  if not button or not Minimap then
    return
  end

  local angle = math.rad(GetMinimapSettings().angle or 220)
  local x = math.cos(angle) * MINIMAP_RADIUS
  local y = math.sin(angle) * MINIMAP_RADIUS
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function SetButtonShown(show)
  if not button then
    return
  end

  if show then
    button:Show()
    PositionButton()
  else
    button:Hide()
  end
end

local function NotifyMinimapVisibilityChanged()
  if Tea_RefreshOptionsCheckboxes then
    Tea_RefreshOptionsCheckboxes()
  end
end

local function UpdateDrag(self)
  if not self.isMouseDown or not Minimap then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cursorX = cursorX / scale
  cursorY = cursorY / scale

  local deltaX = cursorX - self.dragStartX
  local deltaY = cursorY - self.dragStartY
  if (deltaX * deltaX) + (deltaY * deltaY) >= DRAG_THRESHOLD * DRAG_THRESHOLD then
    self.didDrag = true
  end

  if not self.didDrag then
    return
  end

  local centerX, centerY = Minimap:GetCenter()
  GetMinimapSettings().angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
  PositionButton()
end

local function CreateMinimapButton()
  button = CreateFrame("Button", "TeaMinimapButton", Minimap)
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:SetMovable(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(20, 20)
  background:SetPoint("TOPLEFT", button, "TOPLEFT", BACKGROUND_OFFSET_X, BACKGROUND_OFFSET_Y)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_OFFSET_X, ICON_OFFSET_Y)
  icon:SetTexture(GetThistleTeaIcon())
  button.icon = icon

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("tea")
    GameTooltip:AddLine("Click to open options.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:SetScript("OnMouseDown", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then
      return
    end

    self.isMouseDown = true
    self.didDrag = false
    self.dragStartX, self.dragStartY = GetCursorPosition()
    self.dragStartX = self.dragStartX / Minimap:GetEffectiveScale()
    self.dragStartY = self.dragStartY / Minimap:GetEffectiveScale()
    self:SetScript("OnUpdate", UpdateDrag)
  end)

  button:SetScript("OnMouseUp", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then
      return
    end

    self.isMouseDown = false
    self:SetScript("OnUpdate", nil)
  end)

  button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "LeftButton" and not self.didDrag then
      Tea_ToggleOptions()
    elseif mouseButton == "RightButton" then
      Tea_HideMinimapButton()
      Tea_Print("Minimap icon hidden. Use /tea minimap or General options to show it again.")
    end
  end)

  SetButtonShown(GetMinimapSettings().show ~= false)
end

function Tea_InitMinimap()
  if button or not Minimap then
    return
  end

  CreateMinimapButton()
end

function Tea_ShowMinimapButton()
  GetMinimapSettings().show = true
  if not button then
    if Minimap then
      CreateMinimapButton()
    end
    return
  end

  SetButtonShown(true)
  NotifyMinimapVisibilityChanged()
end

function Tea_HideMinimapButton()
  GetMinimapSettings().show = false
  SetButtonShown(false)
  NotifyMinimapVisibilityChanged()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Tea_GetDB()
  elseif event == "PLAYER_LOGIN" then
    Tea_InitMinimap()
    ApplyMinimapIcon()
  end
end)
