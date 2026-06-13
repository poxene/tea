local HEADER_HEIGHT = 20
local SECTION_GAP = 10
local BAG_BAR_HEIGHT = 30
local BAG_ICON_SIZE = 28
local BAG_ICON_GAP = 6
local CONTENT_TOP = 68
local SIDE_OFFSET = 12
local MONEY_BAR_HEIGHT = 28
local BOTTOM_PADDING = 14
local BASE_SLOT_SIZE = 37
local ITEM_QUALITY_POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
local ITEM_QUALITY_COMMON = (Enum and Enum.ItemQuality and (Enum.ItemQuality.Common or Enum.ItemQuality.Standard)) or 1
local QUALITY_BORDER_ALPHA_GREY = 0.6
local QUALITY_BORDER_ALPHA_WHITE = 0.3
local QUALITY_BORDER_ALPHA_COLORED = 0.88
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
local HIGHLIGHT_R, HIGHLIGHT_G, HIGHLIGHT_B = 0.45, 0.65, 0.88
local HIGHLIGHT_BAG_R, HIGHLIGHT_BAG_G, HIGHLIGHT_BAG_B = 0.58, 0.78, 0.98
local HIGHLIGHT_BAG_ALPHA = 0.58
local HIGHLIGHT_SLOT_ALPHA = 0.2
local HIGHLIGHT_DIM_ALPHA = 0.6
local GREY_JUNK_DIM_ALPHA = 0.35

local SECTION_DEFS = {
  { id = "bags", title = "Bags", order = 1 },
  { id = "ammo", title = "Ammo", order = 2 },
  { id = "soul", title = "Soul Shards", order = 3 },
  { id = "other", title = "Special", order = 4 },
}

local frame
local bagBarFrame
local moneyFrame
local slotButtons = {}
local equippedBagButtons = {}
local bagContainers = {}
local sectionHeaders = {}
local highlightedBagID
local highlightBagSlots = false
local lastSlotCount = 0
local lastLayoutKey = ""
local lastSettingsKey = ""

local function IsEnabled()
  return Tea_GetDB().modules.oneBag
end

local function GetBagSettings()
  return Tea_GetDB().oneBag
end

local function GetColumns()
  return GetBagSettings().columns or 8
end

local function GetSlotSize()
  return GetBagSettings().slotSize or 37
end

local function GetSlotPadding()
  return GetBagSettings().slotPadding or 2
end

local function GetGridWidth()
  local columns = GetColumns()
  local slotSize = GetSlotSize()
  local slotPadding = GetSlotPadding()
  return columns * (slotSize + slotPadding) + slotPadding
end

local function GetBagInventorySlot(bagID)
  if C_Container and C_Container.ContainerIDToInventoryID then
    return C_Container.ContainerIDToInventoryID(bagID)
  end
  if bagID == BACKPACK_CONTAINER then
    return 23
  end
  return bagID + 19
end

local function GetEquippedBags()
  local bags = {}
  for bag = BACKPACK_CONTAINER, NUM_BAG_FRAMES do
    local numSlots = Tea_Util.GetContainerNumSlots(bag) or 0
    if bag == BACKPACK_CONTAINER or numSlots > 0 then
      table.insert(bags, { bagID = bag, numSlots = numSlots })
    end
  end
  return bags
end

local function GetBagIconTexture(bagID)
  local inventorySlot = GetBagInventorySlot(bagID)
  local texture = GetInventoryItemTexture("player", inventorySlot)
  if texture then
    return texture
  end
  if bagID == BACKPACK_CONTAINER then
    return "Interface\\Buttons\\Button-Backpack-Up"
  end
end

local function ScaleTextureToSlot(texture, slotSize, point, relativeTo, relativePoint, offsetX, offsetY)
  if not texture then
    return
  end

  texture:ClearAllPoints()
  texture:SetSize(slotSize, slotSize)
  texture:SetPoint(point or "CENTER", relativeTo or texture:GetParent(), relativePoint or "CENTER", offsetX or 0, offsetY or 0)
end

local function GetButtonNormalTexture(button)
  if button.NormalTexture then
    return button.NormalTexture
  end
  if button.GetNormalTexture then
    return button:GetNormalTexture()
  end
end

local function HideEmptySlotArt(button)
  local normal = GetButtonNormalTexture(button)
  if normal then
    normal:Hide()
  end
  if button.ExtendedSlot then
    button.ExtendedSlot:Hide()
  end
  if button.IconOverlay then
    button.IconOverlay:Hide()
  end
end

local function SetupSlotHover(button)
  local anchor = button.icon or button

  local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
  if highlight then
    highlight:ClearAllPoints()
    highlight:SetAllPoints(anchor)
  end

  local pushed = button.GetPushedTexture and button:GetPushedTexture()
  if pushed then
    pushed:ClearAllPoints()
    pushed:SetAllPoints(anchor)
  end
end

local function ApplySlotButtonSize(button, slotSize)
  if not button then
    return
  end

  button:SetSize(slotSize, slotSize)
  local scale = slotSize / BASE_SLOT_SIZE

  ScaleTextureToSlot(button.icon, slotSize)

  if button.IconBorder then
    button.IconBorder:Hide()
  end

  ScaleTextureToSlot(button.ExtendedOverlay, slotSize, "CENTER", button, "CENTER", 0, -scale)
  ScaleTextureToSlot(button.ExtendedOverlay2, slotSize, "CENTER", button, "CENTER", 0, -scale)

  if button.IconQuestTexture then
    ScaleTextureToSlot(button.IconQuestTexture, slotSize, "TOP", button, "TOP", 0, 0)
  end

  HideEmptySlotArt(button)
  SetupSlotHover(button)

  if button.Cooldown then
    button.Cooldown:ClearAllPoints()
    button.Cooldown:SetSize(slotSize - 2, slotSize - 2)
    button.Cooldown:SetPoint("CENTER", button, "CENTER")
  end

  if button.Count then
    button.Count:ClearAllPoints()
    button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3 * scale, 2 * scale)
  end

  if button.TeaBagHighlight then
    local anchor = button.icon or button
    button.TeaBagHighlight:ClearAllPoints()
    button.TeaBagHighlight:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2 * scale, 2 * scale)
    button.TeaBagHighlight:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2 * scale, -2 * scale)
  end

  Tea_Util.LayoutRoundedIconBorder(button, "TeaQualityBorder", scale)
  Tea_Util.LayoutRoundedIconBorder(button, "TeaTrackBorder", scale)
end

local function EnsureSlotHighlight(button)
  if button.TeaBagHighlight then
    return
  end

  local anchor = button.icon or button
  local highlight = button:CreateTexture(nil, "OVERLAY", nil, 1)
  highlight:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
  highlight:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
  highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
  highlight:SetVertexColor(HIGHLIGHT_R, HIGHLIGHT_G, HIGHLIGHT_B, HIGHLIGHT_SLOT_ALPHA)
  highlight:Hide()
  button.TeaBagHighlight = highlight
end

local function GetSlotIconAlpha(button, hoverAlpha)
  if button.teaItemQuality == ITEM_QUALITY_POOR and GetBagSettings().greyJunkIcons then
    return math.min(hoverAlpha, GREY_JUNK_DIM_ALPHA)
  end

  return hoverAlpha
end

local function UpdateSlotHighlight(button)
  EnsureSlotHighlight(button)

  if highlightedBagID and highlightBagSlots and button.bagID == highlightedBagID then
    button.TeaBagHighlight:Show()
    if button.icon then
      button.icon:SetAlpha(GetSlotIconAlpha(button, 1))
    end
  else
    button.TeaBagHighlight:Hide()
    if button.icon then
      local hoverAlpha = highlightedBagID and highlightBagSlots and HIGHLIGHT_DIM_ALPHA or 1
      button.icon:SetAlpha(GetSlotIconAlpha(button, hoverAlpha))
    end
  end
end

local function UpdateEquippedBagHighlights()
  for _, button in ipairs(equippedBagButtons) do
    if button:IsShown() then
      if highlightedBagID and button.bagID == highlightedBagID then
        button.border:SetVertexColor(HIGHLIGHT_BAG_R, HIGHLIGHT_BAG_G, HIGHLIGHT_BAG_B, HIGHLIGHT_BAG_ALPHA)
        if button.icon then
          button.icon:SetAlpha(1)
        end
      else
        button.border:SetVertexColor(1, 1, 1, 0.15)
        if button.icon then
          button.icon:SetAlpha(highlightedBagID and highlightBagSlots and HIGHLIGHT_DIM_ALPHA or 1)
        end
      end
    end
  end
end

local function UpdateSlotHighlights()
  for _, button in ipairs(slotButtons) do
    if button:IsShown() then
      UpdateSlotHighlight(button)
    end
  end
end

local function SetHighlightedBag(bagID, highlightSlots)
  if highlightedBagID == bagID and highlightBagSlots == (bagID ~= nil and highlightSlots == true) then
    return
  end

  highlightedBagID = bagID
  highlightBagSlots = bagID ~= nil and highlightSlots == true
  UpdateSlotHighlights()
  UpdateEquippedBagHighlights()
end

local function ClearBagHighlight()
  SetHighlightedBag(nil)
end

local function GetBagFamily(bag)
  local _, family = Tea_Util.GetContainerNumFreeSlots(bag)
  return family or 0
end

local function GetSectionId(bag)
  local family = GetBagFamily(bag)

  if family == 1 or family == 2 then
    return "ammo"
  end
  if bit.band(family, 4) == 4 then
    return "soul"
  end
  if family == 0 then
    return "bags"
  end
  return "other"
end

local function GetBagSections()
  local sectionMap = {}
  for _, def in ipairs(SECTION_DEFS) do
    sectionMap[def.id] = { title = def.title, order = def.order, slots = {} }
  end

  for bag = BACKPACK_CONTAINER, NUM_BAG_FRAMES do
    local numSlots = Tea_Util.GetContainerNumSlots(bag) or 0
    if numSlots > 0 then
      local sectionId = GetSectionId(bag)
      local section = sectionMap[sectionId]
      for slot = 1, numSlots do
        table.insert(section.slots, { bag = bag, slot = slot })
      end
    end
  end

  local sections = {}
  for _, def in ipairs(SECTION_DEFS) do
    local section = sectionMap[def.id]
    if #section.slots > 0 then
      table.insert(sections, section)
    end
  end

  return sections
end

local function GetLayoutKey()
  local parts = {}
  for bag = BACKPACK_CONTAINER, NUM_BAG_FRAMES do
    local invSlot = GetBagInventorySlot(bag)
    local bagItemID = GetInventoryItemID("player", invSlot) or 0
    table.insert(parts, bag .. ":" .. GetBagFamily(bag) .. ":" .. (Tea_Util.GetContainerNumSlots(bag) or 0) .. ":" .. bagItemID)
  end
  return table.concat(parts, ",")
end

local function GetBagSlots()
  local slots = {}
  for _, section in ipairs(GetBagSections()) do
    for _, slotInfo in ipairs(section.slots) do
      table.insert(slots, slotInfo)
    end
  end
  return slots
end

local function GetSettingsKey()
  return string.format("%d:%d:%d", GetColumns(), GetSlotSize(), GetSlotPadding())
end

local function GetBagContainer(bagID)
  if not bagContainers[bagID] then
    local container = CreateFrame("Frame", "TeaBagContainer" .. bagID, frame)
    container:SetID(bagID)
    container:SetSize(1, 1)
    bagContainers[bagID] = container
  end
  return bagContainers[bagID]
end

local function GetSlotQualityBorderColor(quality)
  if quality == nil then
    return nil
  end

  if quality == ITEM_QUALITY_POOR then
    return 0.62, 0.62, 0.62
  end

  if quality == ITEM_QUALITY_COMMON then
    return 1, 1, 1
  end

  if BAG_ITEM_QUALITY_COLORS and BAG_ITEM_QUALITY_COLORS[quality] then
    local color = BAG_ITEM_QUALITY_COLORS[quality]
    return color.r, color.g, color.b
  end

  if GetItemQualityColor then
    return GetItemQualityColor(quality)
  end
end

local function GetSlotQualityBorderAlpha(quality)
  if quality == ITEM_QUALITY_POOR then
    return QUALITY_BORDER_ALPHA_GREY
  end

  if quality == ITEM_QUALITY_COMMON then
    return QUALITY_BORDER_ALPHA_WHITE
  end

  return QUALITY_BORDER_ALPHA_COLORED
end

local function ApplySlotIconAppearance(button, quality, hasItem)
  local icon = button.icon
  if not icon then
    return
  end

  button.teaItemQuality = hasItem and quality or nil

  if icon.SetDesaturated then
    local greyOut = hasItem
      and GetBagSettings().greyJunkIcons
      and quality == ITEM_QUALITY_POOR

    icon:SetDesaturated(greyOut)
  end

  icon:SetVertexColor(1, 1, 1)
end

local function EnsureQualityBorder(button)
  Tea_Util.EnsureRoundedIconBorder(button, "TeaQualityBorder")
end

local function ApplySlotQualityBorder(button, quality, hasItem)
  EnsureQualityBorder(button)

  if button.IconBorder then
    button.IconBorder:Hide()
  end

  if not hasItem then
    Tea_Util.SetButtonRoundedIconBorderColor(button, "TeaQualityBorder", nil, nil, nil, false)
    return
  end

  local r, g, b = GetSlotQualityBorderColor(quality)
  local alpha = GetSlotQualityBorderAlpha(quality)

  Tea_Util.SetButtonRoundedIconBorderColor(button, "TeaQualityBorder", r, g, b, r ~= nil, alpha)
end

local function UpdateSlot(button)
  local bag, slot = button.bagID, button.slotID
  local texture, count, locked, quality, _, _, hyperlink, _, _, itemID = Tea_Util.GetContainerItemInfo(bag, slot)

  if button.NewItemTexture then
    button.NewItemTexture:Hide()
  end
  if button.BattlepayItemTexture then
    button.BattlepayItemTexture:Hide()
  end

  if texture then
    SetItemButtonTexture(button, texture)
    SetItemButtonCount(button, count or 0)
    if button.icon then
      button.icon:Show()
    end
  else
    SetItemButtonTexture(button, nil)
    SetItemButtonCount(button, 0)
    if button.icon then
      button.icon:Hide()
    end
    itemID = nil
    quality = nil
  end

  HideEmptySlotArt(button)
  SetupSlotHover(button)

  if button.Cooldown then
    local start, duration, enable
    if C_Container and C_Container.GetContainerItemCooldown then
      start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
    else
      start, duration, enable = GetContainerItemCooldown(bag, slot)
    end
    CooldownFrame_Set(button.Cooldown, start, duration, enable)
  end

  ApplySlotButtonSize(button, GetSlotSize())
  ApplySlotIconAppearance(button, quality, texture ~= nil)
  UpdateSlotHighlight(button)
  ApplySlotQualityBorder(button, quality, texture ~= nil)

  if Tea_UpdateTrackBorder then
    Tea_UpdateTrackBorder(button, itemID)
  end

  if button.TeaQualityBorder and button.TeaQualityBorder.teaBorderColor then
    button.TeaQualityBorder:Show()
  end
end

local function RefreshEquippedBags()
  for _, button in ipairs(equippedBagButtons) do
    if button:IsShown() and button.bagID then
      button.icon:SetTexture(GetBagIconTexture(button.bagID))
    end
  end
end

local function RefreshBag()
  if not frame then
    return
  end

  RefreshEquippedBags()

  local mouseFocus = GetMouseFocus and GetMouseFocus()

  for _, button in ipairs(slotButtons) do
    if button:IsShown() and button ~= mouseFocus then
      UpdateSlot(button)
    end
  end

  UpdateSlotHighlights()
  UpdateEquippedBagHighlights()
  UpdateMoney()
end

function Tea_BagRefreshTracks()
  if not frame or not frame:IsShown() then
    return
  end
  RefreshBag()
end

local function OnSlotClick(self, mouseButton)
  if InCombatLockdown() then
    return
  end

  if mouseButton == "RightButton" then
    Tea_Util.UseContainerItem(self.bagID, self.slotID)
  else
    Tea_Util.PickupContainerItem(self.bagID, self.slotID)
  end
end

local function ShowSlotTooltip(self)
  if not self.bagID or not self.slotID then
    return
  end

  if ContainerFrameItemButton_OnEnter and self:GetID() then
    ContainerFrameItemButton_OnEnter(self)
    return
  end

  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetBagItem(self.bagID, self.slotID)
end

local function OnSlotEnter(self)
  SetHighlightedBag(self.bagID, false)
  ShowSlotTooltip(self)
end

local function OnSlotLeave(self)
  ClearBagHighlight()

  if ContainerFrameItemButton_OnLeave then
    ContainerFrameItemButton_OnLeave(self)
  else
    GameTooltip_Hide()
  end
end

local function CreateSlotButton(index, bagID)
  local button = CreateFrame("Button", "TeaBagSlot" .. index, GetBagContainer(bagID), "ContainerFrameItemButtonTemplate")

  local normal = GetButtonNormalTexture(button)
  if normal then
    normal:SetTexture(nil)
    normal:Hide()
  end

  HideEmptySlotArt(button)
  SetupSlotHover(button)
  ApplySlotButtonSize(button, GetSlotSize())
  button:RegisterForDrag("LeftButton")

  function button:GetBagID()
    return self.bagID
  end

  button:SetScript("OnClick", OnSlotClick)
  button:SetScript("OnDragStart", OnSlotClick)
  button:SetScript("OnReceiveDrag", OnSlotClick)
  button:SetScript("OnEnter", OnSlotEnter)
  button:SetScript("OnLeave", OnSlotLeave)
  button.UpdateTooltip = ShowSlotTooltip
  return button
end

local function ShowEquippedBagTooltip(self)
  local inventorySlot = GetBagInventorySlot(self.bagID)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
  if GetInventoryItemLink("player", inventorySlot) then
    GameTooltip:SetInventoryItem("player", inventorySlot)
  elseif self.bagID == BACKPACK_CONTAINER then
    GameTooltip:SetText("Backpack")
  else
    GameTooltip:SetText("Bag")
  end
  GameTooltip:Show()
end

local function CreateEquippedBagButton(index)
  local button = CreateFrame("Button", "TeaEquippedBag" .. index, bagBarFrame)
  button:SetSize(BAG_ICON_SIZE, BAG_ICON_SIZE)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\Buttons\\WHITE8x8")
  border:SetVertexColor(1, 1, 1, 0.15)
  button.border = border

  button:SetScript("OnEnter", function(self)
    SetHighlightedBag(self.bagID, true)
    ShowEquippedBagTooltip(self)
  end)
  button:SetScript("OnLeave", function(self)
    ClearBagHighlight()
    GameTooltip:Hide()
  end)

  return button
end

local function LayoutEquippedBags()
  if not bagBarFrame then
    bagBarFrame = CreateFrame("Frame", nil, frame)
    bagBarFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_OFFSET, -30)
    bagBarFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SIDE_OFFSET, -30)
    bagBarFrame:SetHeight(BAG_BAR_HEIGHT)
  end

  local equippedBags = GetEquippedBags()

  for index, bagInfo in ipairs(equippedBags) do
    local button = equippedBagButtons[index]
    if not button then
      button = CreateEquippedBagButton(index)
      equippedBagButtons[index] = button
    end

    button.bagID = bagInfo.bagID
    button.icon:SetTexture(GetBagIconTexture(bagInfo.bagID))
    button:ClearAllPoints()

    if index == 1 then
      button:SetPoint("LEFT", bagBarFrame, "LEFT", 0, 0)
    else
      button:SetPoint("LEFT", equippedBagButtons[index - 1], "RIGHT", BAG_ICON_GAP, 0)
    end

    button:Show()
  end

  for index = #equippedBags + 1, #equippedBagButtons do
    equippedBagButtons[index]:Hide()
  end
end

local function HideSectionHeaders()
  for _, header in ipairs(sectionHeaders) do
    header:Hide()
  end
end

local function GetOrCreateHeader(index, title)
  local header = sectionHeaders[index]
  if not header then
    header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionHeaders[index] = header
  end
  header:SetText(title)
  header:Show()
  return header
end

local function UpdateMoney()
  if not moneyFrame then
    return
  end

  if MoneyFrame_Update then
    MoneyFrame_Update(moneyFrame:GetName(), GetMoney())
  end
end

local function LayoutSlots()
  local sections = GetBagSections()
  local columns = GetColumns()
  local slotSize = GetSlotSize()
  local slotPadding = GetSlotPadding()
  local gridWidth = GetGridWidth()
  local y = -CONTENT_TOP
  local buttonIndex = 0
  local headerIndex = 0

  LayoutEquippedBags()
  HideSectionHeaders()

  for _, section in ipairs(sections) do
    headerIndex = headerIndex + 1
    local header = GetOrCreateHeader(headerIndex, section.title)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_OFFSET, y)
    y = y - HEADER_HEIGHT

    for slotIndex, slotInfo in ipairs(section.slots) do
      buttonIndex = buttonIndex + 1
      local button = slotButtons[buttonIndex]
      if not button then
        button = CreateSlotButton(buttonIndex, slotInfo.bag)
        slotButtons[buttonIndex] = button
      elseif button:GetParent() ~= GetBagContainer(slotInfo.bag) then
        button:SetParent(GetBagContainer(slotInfo.bag))
      end

      button.bagID = slotInfo.bag
      button.slotID = slotInfo.slot
      button:SetID(slotInfo.slot)
      button:Show()

      local col = (slotIndex - 1) % columns
      local row = math.floor((slotIndex - 1) / columns)
      button:ClearAllPoints()
      button:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        SIDE_OFFSET + slotPadding + col * (slotSize + slotPadding),
        y - slotPadding - row * (slotSize + slotPadding)
      )

      UpdateSlot(button)
    end

    local rows = math.ceil(#section.slots / columns)
    y = y - rows * (slotSize + slotPadding) - slotPadding - SECTION_GAP
  end

  for index = buttonIndex + 1, #slotButtons do
    slotButtons[index]:Hide()
  end

  frame:SetSize(gridWidth + 24, math.abs(y) + MONEY_BAR_HEIGHT + BOTTOM_PADDING)
  lastSlotCount = #GetBagSlots()
  lastLayoutKey = GetLayoutKey()
  lastSettingsKey = GetSettingsKey()
  UpdateSlotHighlights()
  UpdateEquippedBagHighlights()
  UpdateMoney()
end

local function BuildFrame()
  local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "TeaBagFrame", UIParent, backdropTemplate)
  frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
  end

  tinsert(UISpecialFrames, frame:GetName())

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText("teaBag")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function()
    Tea_CloseBag()
  end)

  moneyFrame = CreateFrame("Frame", "TeaBagMoneyFrame", frame, "SmallMoneyFrameTemplate")
  moneyFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10)
  if SmallMoneyFrame_OnLoad then
    SmallMoneyFrame_OnLoad(moneyFrame)
  end
  if MoneyFrame_SetType then
    MoneyFrame_SetType(moneyFrame, "PLAYER")
  end

  LayoutSlots()
end

function Tea_BagRelayout()
  if not frame then
    return
  end

  LayoutSlots()
  if frame:IsShown() then
    RefreshBag()
  end
end

local function CloseBlizzardBags()
  for i = 1, NUM_CONTAINER_FRAMES do
    local bagFrame = _G["ContainerFrame" .. i]
    if bagFrame and bagFrame:IsShown() then
      bagFrame:Hide()
    end
  end
  if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
    ContainerFrameCombinedBags:Hide()
  end
end

local origOpenAllBags
local origOpenBag
local origOpenBackpack
local origGenerateContainerFrame

local function GuardBlizzardBagFrame(bagFrame)
  if not bagFrame or bagFrame.teaBagGuarded then
    return
  end

  bagFrame.teaBagGuarded = true
  bagFrame:HookScript("OnShow", function(self)
    if IsEnabled() then
      self:Hide()
    end
  end)
end

local function GuardAllBlizzardBagFrames()
  for i = 1, NUM_CONTAINER_FRAMES do
    GuardBlizzardBagFrame(_G["ContainerFrame" .. i])
  end

  if ContainerFrameCombinedBags then
    GuardBlizzardBagFrame(ContainerFrameCombinedBags)
  end
end

local function SuppressDefaultBags(frame)
  if not IsEnabled() then
    return false
  end

  if frame and FRAME_THAT_OPENED_BAGS == nil then
    FRAME_THAT_OPENED_BAGS = frame:GetName()
  end

  CloseBlizzardBags()
  return true
end

local function SetupBlizzardBagSuppression()
  GuardAllBlizzardBagFrames()

  if OpenAllBags and not SetupBlizzardBagSuppression.openAllHooked then
    origOpenAllBags = OpenAllBags
    _G.OpenAllBags = function(frame)
      if SuppressDefaultBags(frame) then
        return
      end
      origOpenAllBags(frame)
    end
    SetupBlizzardBagSuppression.openAllHooked = true
  end

  if OpenBag and not SetupBlizzardBagSuppression.openBagHooked then
    origOpenBag = OpenBag
    _G.OpenBag = function(id, force)
      if IsEnabled() then
        CloseBlizzardBags()
        return
      end
      origOpenBag(id, force)
    end
    SetupBlizzardBagSuppression.openBagHooked = true
  end

  if OpenBackpack and not SetupBlizzardBagSuppression.openBackpackHooked then
    origOpenBackpack = OpenBackpack
    _G.OpenBackpack = function()
      if IsEnabled() then
        CloseBlizzardBags()
        return
      end
      origOpenBackpack()
    end
    SetupBlizzardBagSuppression.openBackpackHooked = true
  end

  if ContainerFrame_GenerateFrame and not SetupBlizzardBagSuppression.generateHooked then
    origGenerateContainerFrame = ContainerFrame_GenerateFrame
    _G.ContainerFrame_GenerateFrame = function(frame, size, id)
      if IsEnabled() then
        return
      end
      origGenerateContainerFrame(frame, size, id)
    end
    SetupBlizzardBagSuppression.generateHooked = true
  end
end

function Tea_BagIsOpen()
  return frame and frame:IsShown()
end

function Tea_OpenBag()
  if not IsEnabled() then
    Tea_Print("One bag is disabled. Enable it in /tea options.")
    return
  end

  if not frame then
    BuildFrame()
  end

  if not frame then
    return
  end

  LayoutSlots()
  UpdateMoney()
  CloseBlizzardBags()
  frame:Show()
end

function Tea_CloseBag()
  if frame then
    SetHighlightedBag(nil)
    frame:Hide()
  end
end

function Tea_ToggleBag()
  if Tea_BagIsOpen() then
    Tea_CloseBag()
  else
    Tea_OpenBag()
  end
end

local function OnBagUpdate()
  if not Tea_BagIsOpen() then
    return
  end

  local slotCount = #GetBagSlots()
  local layoutKey = GetLayoutKey()
  local settingsKey = GetSettingsKey()
  if slotCount ~= lastSlotCount or layoutKey ~= lastLayoutKey or settingsKey ~= lastSettingsKey then
    LayoutSlots()
  else
    RefreshBag()
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("MERCHANT_SHOW")

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" then
    OnBagUpdate()
  elseif event == "PLAYER_MONEY" then
    UpdateMoney()
  elseif event == "MERCHANT_SHOW" then
    if IsEnabled() then
      SuppressDefaultBags(MerchantFrame)
    end
  elseif event == "PLAYER_LOGIN" then
    if not eventFrame.backpackHooked and ToggleBackpack then
      local origToggleBackpack = ToggleBackpack
      ToggleBackpack = function()
        if IsEnabled() then
          Tea_ToggleBag()
        else
          origToggleBackpack()
        end
      end
      eventFrame.backpackHooked = true
    end

    SetupBlizzardBagSuppression()
  elseif event == "PLAYER_ENTERING_WORLD" then
    SetupBlizzardBagSuppression()
  end
end)

local function ScheduleBagSuppressionSetup()
  SetupBlizzardBagSuppression()
  C_Timer.After(0, SetupBlizzardBagSuppression)
end

if UnitName("player") then
  ScheduleBagSuppressionSetup()
end
