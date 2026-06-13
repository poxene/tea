local SLOT_SIZE = 37
local SLOT_PADDING = 4
local COLUMNS = 8
local HEADER_HEIGHT = 20
local SECTION_GAP = 10
local BAG_BAR_HEIGHT = 30
local BAG_ICON_SIZE = 28
local BAG_ICON_GAP = 6
local CONTENT_TOP = 68
local SIDE_OFFSET = 12
local ITEM_QUALITY_COMMON = (Enum and Enum.ItemQuality and (Enum.ItemQuality.Common or Enum.ItemQuality.Standard)) or 1
local HIGHLIGHT_R, HIGHLIGHT_G, HIGHLIGHT_B = 0.45, 0.65, 0.88
local HIGHLIGHT_BAG_R, HIGHLIGHT_BAG_G, HIGHLIGHT_BAG_B = 0.58, 0.78, 0.98
local HIGHLIGHT_BAG_ALPHA = 0.58
local HIGHLIGHT_SLOT_ALPHA = 0.2
local HIGHLIGHT_DIM_ALPHA = 0.6

local SECTION_DEFS = {
  { id = "bags", title = "Bags", order = 1 },
  { id = "ammo", title = "Ammo", order = 2 },
  { id = "soul", title = "Soul Shards", order = 3 },
  { id = "other", title = "Special", order = 4 },
}

local frame
local bagBarFrame
local slotButtons = {}
local equippedBagButtons = {}
local bagContainers = {}
local sectionHeaders = {}
local highlightedBagID
local highlightBagSlots = false
local highlightLeaveToken = 0
local lastSlotCount = 0
local lastLayoutKey = ""

local function IsEnabled()
  return Tea_GetDB().modules.oneBag
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

local function UpdateSlotHighlight(button)
  EnsureSlotHighlight(button)

  if highlightedBagID and highlightBagSlots and button.bagID == highlightedBagID then
    button.TeaBagHighlight:Show()
    if button.icon then
      button.icon:SetAlpha(1)
    end
  else
    button.TeaBagHighlight:Hide()
    if button.icon then
      button.icon:SetAlpha(highlightedBagID and highlightBagSlots and HIGHLIGHT_DIM_ALPHA or 1)
    end
  end
end

local function GetBagHighlightTarget()
  local focus = GetMouseFocus and GetMouseFocus()
  while focus do
    if focus.bagID then
      return focus, focus.bagID
    end
    for _, bagButton in ipairs(equippedBagButtons) do
      if focus == bagButton and bagButton:IsShown() then
        return bagButton, bagButton.bagID
      end
    end
    focus = focus.GetParent and focus:GetParent()
  end
end

local function ShouldClearBagHighlight()
  return GetBagHighlightTarget() == nil
end

local function ScheduleClearBagHighlight()
  highlightLeaveToken = highlightLeaveToken + 1
  local token = highlightLeaveToken
  C_Timer.After(0, function()
    if token ~= highlightLeaveToken then
      return
    end
    if ShouldClearBagHighlight() then
      SetHighlightedBag(nil)
    end
  end)
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
          button.icon:SetAlpha(highlightedBagID and HIGHLIGHT_DIM_ALPHA or 1)
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

local function GetBagContainer(bagID)
  if not bagContainers[bagID] then
    local container = CreateFrame("Frame", "TeaBagContainer" .. bagID, frame)
    container:SetID(bagID)
    container:SetSize(1, 1)
    bagContainers[bagID] = container
  end
  return bagContainers[bagID]
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
    if SetItemButtonQuality then
      SetItemButtonQuality(button, quality, hyperlink)
    end
    if button.IconBorder and (not quality or quality <= ITEM_QUALITY_COMMON) then
      button.IconBorder:Hide()
    end
  else
    SetItemButtonTexture(button, nil)
    SetItemButtonCount(button, 0)
    if button.IconBorder then
      button.IconBorder:Hide()
    end
    if button.icon then
      button.icon:Hide()
    end
    if SetItemButtonQuality then
      SetItemButtonQuality(button, ITEM_QUALITY_COMMON, nil)
    end
    itemID = nil
  end

  if button.Cooldown then
    local start, duration, enable
    if C_Container and C_Container.GetContainerItemCooldown then
      start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
    else
      start, duration, enable = GetContainerItemCooldown(bag, slot)
    end
    CooldownFrame_Set(button.Cooldown, start, duration, enable)
  end

  if Tea_UpdateTrackBorder then
    Tea_UpdateTrackBorder(button, itemID)
  end

  UpdateSlotHighlight(button)
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
  highlightLeaveToken = highlightLeaveToken + 1
  SetHighlightedBag(self.bagID, false)
  ShowSlotTooltip(self)
end

local function OnSlotLeave(self)
  ScheduleClearBagHighlight()

  if ContainerFrameItemButton_OnLeave then
    ContainerFrameItemButton_OnLeave(self)
  else
    GameTooltip_Hide()
  end
end

local function CreateSlotButton(index, bagID)
  local button = CreateFrame("Button", "TeaBagSlot" .. index, GetBagContainer(bagID), "ContainerFrameItemButtonTemplate")
  button:SetSize(SLOT_SIZE, SLOT_SIZE)
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
    highlightLeaveToken = highlightLeaveToken + 1
    SetHighlightedBag(self.bagID, true)
    ShowEquippedBagTooltip(self)
  end)
  button:SetScript("OnLeave", function(self)
    ScheduleClearBagHighlight()
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

local function LayoutSlots()
  local sections = GetBagSections()
  local gridWidth = COLUMNS * (SLOT_SIZE + SLOT_PADDING) + SLOT_PADDING
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

      local col = (slotIndex - 1) % COLUMNS
      local row = math.floor((slotIndex - 1) / COLUMNS)
      button:ClearAllPoints()
      button:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        SIDE_OFFSET + SLOT_PADDING + col * (SLOT_SIZE + SLOT_PADDING),
        y - SLOT_PADDING - row * (SLOT_SIZE + SLOT_PADDING)
      )

      UpdateSlot(button)
    end

    local rows = math.ceil(#section.slots / COLUMNS)
    y = y - rows * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING - SECTION_GAP
  end

  for index = buttonIndex + 1, #slotButtons do
    slotButtons[index]:Hide()
  end

  frame:SetSize(gridWidth + 24, math.abs(y) + 24)
  lastSlotCount = #GetBagSlots()
  lastLayoutKey = GetLayoutKey()
  UpdateSlotHighlights()
  UpdateEquippedBagHighlights()
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

  LayoutSlots()
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
  if slotCount ~= lastSlotCount or layoutKey ~= lastLayoutKey then
    LayoutSlots()
  else
    RefreshBag()
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" then
    OnBagUpdate()
  elseif event == "PLAYER_LOGIN" then
    local origToggleBackpack = ToggleBackpack
    ToggleBackpack = function()
      if IsEnabled() then
        Tea_ToggleBag()
      else
        origToggleBackpack()
      end
    end
  end
end)
