local S = Tea_OneBag

local HEADER_HEIGHT = 10
local SECTION_GAP = 8
local BAG_BAR_HEIGHT = 28
local BAG_ICON_SIZE = 28
local TITLE_TOP = -12
local TITLE_HEIGHT = 12
local SECTION_TOP_GAP = 6
local CONTENT_TOP = math.abs(TITLE_TOP) + TITLE_HEIGHT + SECTION_TOP_GAP
local SIDE_OFFSET = 12
local BOTTOM_BAR_OFFSET = 14
local BOTTOM_PADDING = 8
local INVENTORY_BAR_GAP = 4
local BANK_SECTION_TITLE = "Bank"
local BANK_HEADER_TITLE = "Bank Bags"
local BANK_CONTAINER_ID = BANK_CONTAINER or -1
local NUM_BANK_GENERIC_SLOTS = NUM_BANKGENERIC_SLOTS or 28
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 7
local NUM_PLAYER_BAG_SLOTS = NUM_BAG_SLOTS or NUM_BAG_FRAMES or 4
local FIRST_BANK_BAG_ID = NUM_PLAYER_BAG_SLOTS + 1
local LAST_BANK_BAG_ID = FIRST_BANK_BAG_ID + NUM_BANK_BAGS - 1
local EMPTY_BANK_BAG_TEXTURE = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local BOTTOM_BAR_HEIGHT = HEADER_HEIGHT + INVENTORY_BAR_GAP + BAG_BAR_HEIGHT + BOTTOM_BAR_OFFSET
local BOTTOM_BAR_LEVEL = 30
local CLOSE_BUTTON_SIZE = 16
local HIGHLIGHT_BAG_R, HIGHLIGHT_BAG_G, HIGHLIGHT_BAG_B = 0.58, 0.78, 0.98
local HIGHLIGHT_BAG_ALPHA = 0.58
local HIGHLIGHT_DIM_ALPHA = 0.6
local UNPURCHASED_OVERLAY_R, UNPURCHASED_OVERLAY_G, UNPURCHASED_OVERLAY_B = 1.0, 0.12, 0.12
local UNPURCHASED_OVERLAY_ALPHA = 0.22

local BLIZZARD_BANK_UI_FRAMES = {
  "BankFrame",
  "BankSlotsFrame",
  "BankBagFrame",
  "BankBagSlotsFrame",
}

local bankFrame
local bankFrameTitle
local bankBagBarFrame
local bankSlotButtons = {}
local bankBagButtons = {}
local bankBagContainers = {}
local bankBagsHeader
local bankSectionHeaders = {}
local highlightedBankBagID
local highlightBankBagSlots = false
local pinnedBankBagID
local bankActive = false
local closingTeaBank = false
local lastBankSlotCount = 0
local lastBankLayoutKey = ""
local lastBankSettingsKey = ""
local bankHooksInstalled = false
local LayoutBankSlots
local ScheduleBankRefresh
local ScheduleBankLayoutRefresh
local bankRefreshScheduled = false
local bankLayoutScheduled = false
local clearBankHighlightToken = 0

local function IsEnabled()
  return Tea_GetDB().modules.teaBank
end

local function GetBankSettings()
  return Tea_GetDB().teaBank
end

local function GetColumns()
  return GetBankSettings().columns or 8
end

local function GetSlotSize()
  return S.GetSlotSize()
end

local function GetSlotPadding()
  return S.GetSlotPadding()
end

local function GetGridWidth()
  local columns = GetColumns()
  local slotSize = GetSlotSize()
  local slotPadding = GetSlotPadding()
  return columns * (slotSize + slotPadding) + slotPadding
end

local function GetSettingsKey()
  return string.format("%d:%d:%d", GetColumns(), GetSlotSize(), GetSlotPadding())
end

local function UpdateSlot(button)
  return S.UpdateSlot(button)
end

local function GetSlotBagAndSlot(button)
  return S.GetSlotBagAndSlot(button)
end

local function EnsureSlotHighlight(button)
  return S.EnsureSlotHighlight(button)
end

local function GetSlotIconAlpha(button, hoverAlpha)
  return S.GetSlotIconAlpha(button, hoverAlpha)
end

local function GetButtonNormalTexture(button)
  return S.GetButtonNormalTexture(button)
end

local function HideEmptySlotArt(button)
  return S.HideEmptySlotArt(button)
end

local function SetupSlotHover(button)
  return S.SetupSlotHover(button)
end

local function EnsureSlotIcon(button)
  return S.EnsureSlotIcon(button)
end

local function ApplySlotButtonSize(button, slotSize)
  return S.ApplySlotButtonSize(button, slotSize)
end

local function ShowBagFrame()
  return S.ShowBagFrame()
end

local function IsBankOpen()
  return bankActive and bankFrame and bankFrame:IsShown()
end

local function UpdateBankSlotHighlight(button)
  EnsureSlotHighlight(button)

  if highlightedBankBagID and highlightBankBagSlots then
    local bag = GetSlotBagAndSlot(button)
    if bag == highlightedBankBagID then
      button.TeaBagHighlight:Show()
      if button.icon then
        button.icon:SetAlpha(GetSlotIconAlpha(button, 1))
      end
    else
      button.TeaBagHighlight:Hide()
      if button.icon then
        button.icon:SetAlpha(GetSlotIconAlpha(button, HIGHLIGHT_DIM_ALPHA))
      end
    end
  else
    button.TeaBagHighlight:Hide()
    if button.icon then
      button.icon:SetAlpha(GetSlotIconAlpha(button, 1))
    end
  end
end

local function UpdateBankBagHighlights()
  for _, button in ipairs(bankBagButtons) do
    if button:IsShown() then
      if button.border then
        if highlightedBankBagID and button.bagID == highlightedBankBagID then
          button.border:SetVertexColor(HIGHLIGHT_BAG_R, HIGHLIGHT_BAG_G, HIGHLIGHT_BAG_B, HIGHLIGHT_BAG_ALPHA)
          button.border:Show()
        else
          button.border:Hide()
        end
      end

      if button.icon then
        button.icon:SetAlpha(1)
        button.icon:SetVertexColor(1, 1, 1)
      end
    end
  end
end

local function UpdateBankSlotHighlights()
  for _, button in ipairs(bankSlotButtons) do
    if button:IsShown() then
      UpdateBankSlotHighlight(button)
    end
  end
end

local function SetHighlightedBankBag(bagID, highlightSlots)
  clearBankHighlightToken = clearBankHighlightToken + 1

  local slotsActive = bagID ~= nil and highlightSlots == true
  if highlightedBankBagID == bagID and highlightBankBagSlots == slotsActive then
    return
  end

  highlightedBankBagID = bagID
  highlightBankBagSlots = slotsActive

  if bankFrame and bankFrame:IsShown() then
    UpdateBankSlotHighlights()
    UpdateBankBagHighlights()
  else
    UpdateBankSlotHighlights()
    UpdateBankBagHighlights()
  end
end

local function ClearBankBagHighlight()
  pinnedBankBagID = nil
  SetHighlightedBankBag(nil)
end

local function IsTeaBankSlotButton(button)
  if not button or not button.GetName then
    return false
  end

  local name = button:GetName()
  return name and name:match("^TeaBankSlot") ~= nil
end

local function IsTeaBankBagButton(button)
  if not button or not button.GetName then
    return false
  end

  local name = button:GetName()
  return name and name:match("^TeaBankBag") ~= nil
end

local function ShouldKeepBankBagHighlight()
  if pinnedBankBagID then
    return true
  end

  local focus = GetMouseFocus and GetMouseFocus()
  if focus and (IsTeaBankSlotButton(focus) or IsTeaBankBagButton(focus)) then
    return true
  end

  for _, button in ipairs(bankBagButtons) do
    if button:IsShown() and button:IsMouseOver() then
      return true
    end
  end

  for _, button in ipairs(bankSlotButtons) do
    if button:IsShown() and button:IsMouseOver() then
      return true
    end
  end

  return false
end

local function ScheduleClearBankBagHighlight()
  clearBankHighlightToken = clearBankHighlightToken + 1
  local token = clearBankHighlightToken
  Tea_Util.After(0.05, function()
    if token ~= clearBankHighlightToken then
      return
    end
    if ShouldKeepBankBagHighlight() then
      return
    end
    ClearBankBagHighlight()
  end)
end
local function GetMainBankSlotCount()
  return Tea_Util.GetContainerNumSlots(BANK_CONTAINER_ID) or NUM_BANK_GENERIC_SLOTS
end

local function GetPurchasedBankBagCount()
  if GetNumBankSlots then
    return GetNumBankSlots()
  end
  return NUM_BANK_BAGS
end

local function IsFrameOffScreen(target)
  local point, _, _, x, y = target:GetPoint(1)
  if not point or x == nil or y == nil then
    return false
  end

  return math.abs(x) > 500 or math.abs(y) > 500
end

local function SuppressBlizzardBankFrame(target)
  if not target or target.teaBankConcealed then
    return
  end

  if target.teaBankConcealAlpha == nil then
    target.teaBankConcealAlpha = target:GetAlpha()
  end

  target.teaBankConcealed = true
  target:SetAlpha(0)

  if target.EnableMouse then
    target:EnableMouse(false)
  end
end

local function RestoreBlizzardBankFrame(target)
  if not target then
    return
  end

  if target.teaBankConcealed or target.teaBankConcealAlpha ~= nil then
    target:SetAlpha(target.teaBankConcealAlpha or 1)
    target.teaBankConcealAlpha = nil
    target.teaBankConcealed = nil

    if target.EnableMouse then
      target:EnableMouse(true)
    end

    target:Show()
  end

  if target.teaBankStoredPoint then
    local point, relativeTo, relativePoint, x, y = unpack(target.teaBankStoredPoint)
    target:ClearAllPoints()
    target:SetPoint(point, relativeTo, relativePoint, x, y)
    target.teaBankStoredPoint = nil
    target:SetAlpha(1)

    if target.EnableMouse then
      target:EnableMouse(true)
    end

    target:Show()
  elseif IsFrameOffScreen(target) then
    target:SetAlpha(1)

    if target.EnableMouse then
      target:EnableMouse(true)
    end

    target:Show()

    if UpdateUIPanelPositions then
      pcall(UpdateUIPanelPositions)
    end
  end
end

local function SuppressBlizzardBankUI()
  for _, frameName in ipairs(BLIZZARD_BANK_UI_FRAMES) do
    SuppressBlizzardBankFrame(_G[frameName])
  end
end

local function RestoreBlizzardBankUI()
  for _, frameName in ipairs(BLIZZARD_BANK_UI_FRAMES) do
    RestoreBlizzardBankFrame(_G[frameName])
  end
end

local function RefreshBlizzardBankDisplay()
  if not BankFrame then
    return
  end

  if BankFrame_OnOpen then
    pcall(BankFrame_OnOpen, BankFrame)
  end
  if BankFrame_Update then
    pcall(BankFrame_Update, BankFrame)
  end
  if UpdateBankBagSlotStatus then
    pcall(UpdateBankBagSlotStatus)
  end
  if ShowUIPanel and BankFrame:IsShown() then
    pcall(ShowUIPanel, BankFrame)
  end

  local numSlots = NUM_BANKGENERIC_SLOTS or 28
  for slot = 1, numSlots do
    for _, prefix in ipairs({ "BankButton", "BankFrameItem" }) do
      local button = _G[prefix .. slot]
      if button then
        if BankFrame_UpdateSlot then
          pcall(BankFrame_UpdateSlot, button)
        end
        if BankFrameItemButton_Update then
          pcall(BankFrameItemButton_Update, button)
        end
      end
    end
  end
end

local function DisableCustomBankUI()
  pinnedBankBagID = nil
  highlightedBankBagID = nil
  highlightBankBagSlots = false
  bankActive = false
  RestoreBlizzardBankUI()
  if bankFrame then
    bankFrame:Hide()
  end
  RefreshBlizzardBankDisplay()
  Tea_Util.After(0, RefreshBlizzardBankDisplay)
  Tea_Util.After(0.1, RefreshBlizzardBankDisplay)
end

function Tea_RestoreBlizzardBank()
  DisableCustomBankUI()
end

local function GetBankBagSlotIndex(bagID)
  return bagID - FIRST_BANK_BAG_ID + 1
end

local function GetItemIconFromInventorySlot(invSlot)
  if not invSlot then
    return
  end

  local texture = GetInventoryItemTexture("player", invSlot)
  if texture then
    return texture
  end

  local itemID = GetInventoryItemID("player", invSlot)
  local hyperlink = GetInventoryItemLink("player", invSlot)

  if hyperlink and GetItemInfo then
    local ok, _, _, _, _, _, _, _, _, itemTexture = pcall(GetItemInfo, hyperlink)
    if ok and itemTexture then
      return itemTexture
    end
  end

  if itemID and GetItemInfo then
    local ok, _, _, _, _, _, _, _, _, itemTexture = pcall(GetItemInfo, itemID)
    if ok and itemTexture then
      return itemTexture
    end
  end

  if itemID and C_Item and C_Item.GetItemIconByID then
    return C_Item.GetItemIconByID(itemID)
  end
end

local function GetBlizzardBankBagButtonTexture(bagIndex)
  for _, name in ipairs({
    "BankFrameBag" .. bagIndex,
    "BankSlotsFrameBag" .. bagIndex,
  }) do
    local frame = _G[name]
    if frame then
      local icon = frame.icon
      if not icon and frame.GetName then
        icon = _G[frame:GetName() .. "IconTexture"]
      end
      if icon and icon.GetTexture then
        local texture = icon:GetTexture()
        if texture then
          return texture
        end
      end
    end
  end
end

local function GetBankBagInventorySlot(bagID)
  if bagID == BANK_CONTAINER_ID then
    return
  end

  local bagIndex = GetBankBagSlotIndex(bagID)
  if bagIndex < 1 then
    return
  end

  if ContainerIDToInventoryID then
    local ok, invSlot = pcall(ContainerIDToInventoryID, bagID)
    if ok and invSlot then
      return invSlot
    end
  end

  if C_Container and C_Container.ContainerIDToInventoryID then
    local invSlot = C_Container.ContainerIDToInventoryID(bagID)
    if invSlot then
      return invSlot
    end
  end

  if BankButtonIDToInvSlotID then
    local invSlot = BankButtonIDToInvSlotID(bagIndex, 1)
    if not invSlot then
      invSlot = BankButtonIDToInvSlotID(bagIndex, true)
    end
    if invSlot then
      return invSlot
    end
  end
end

local function GetBankBagIconTexture(bagID)
  local bagIndex = GetBankBagSlotIndex(bagID)
  local numSlots = Tea_Util.GetContainerNumSlots(bagID) or 0

  if UpdateBankBagSlotStatus then
    pcall(UpdateBankBagSlotStatus)
  end

  if bagIndex >= 1 then
    local blizzardTexture = GetBlizzardBankBagButtonTexture(bagIndex)
    if blizzardTexture then
      return blizzardTexture
    end
  end

  local invSlot = GetBankBagInventorySlot(bagID)
  local texture = GetItemIconFromInventorySlot(invSlot)
  if texture then
    return texture
  end

  if numSlots > 0 and invSlot then
    local bagItemID = GetInventoryItemID("player", invSlot)
    if bagItemID and GetItemInfo then
      local ok, _, _, _, _, _, _, _, _, itemTexture = pcall(GetItemInfo, bagItemID)
      if ok and itemTexture then
        return itemTexture
      end
    end
  end

  return EMPTY_BANK_BAG_TEXTURE
end

local function ApplyBankBagIcon(button, bagID)
  if not button or not button.icon then
    return
  end

  button.icon:SetTexture(GetBankBagIconTexture(bagID))
  button.icon:SetVertexColor(1, 1, 1)
  button.icon:Show()
end

local function GetNextBankSlotCost()
  if not GetBankSlotCost or not GetNumBankSlots then
    return
  end

  local numSlots = GetNumBankSlots()
  if type(numSlots) ~= "number" then
    numSlots = 0
  end

  local cost = GetBankSlotCost(numSlots)
  if cost then
    return cost
  end

  return GetBankSlotCost(numSlots + 1)
end

local BANK_SLOT_PURCHASE_DIALOG = "TEA_CONFIRM_BUY_BANK_SLOT"
local bankSlotPurchaseDialogRegistered = false

local function RegisterBankSlotPurchaseDialog()
  if bankSlotPurchaseDialogRegistered or not StaticPopupDialogs then
    return bankSlotPurchaseDialogRegistered
  end

  StaticPopupDialogs[BANK_SLOT_PURCHASE_DIALOG] = {
    text = CONFIRM_BUY_BANK_SLOT or "Do you want to purchase a bank bag slot?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
      if PurchaseSlot then
        PurchaseSlot()
      end
    end,
    OnShow = function(dialog)
      local cost = GetNextBankSlotCost()
      if not cost or not MoneyFrame_Update then
        return
      end

      if dialog.moneyFrame then
        MoneyFrame_Update(dialog.moneyFrame, cost)
      elseif dialog.GetName then
        MoneyFrame_Update(dialog:GetName() .. "MoneyFrame", cost)
      end
    end,
    hasMoneyFrame = 1,
    timeout = 0,
    hideOnEscape = 1,
    whileDead = 1,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
  }

  bankSlotPurchaseDialogRegistered = true
  return true
end

local function HideBankSlotPurchaseDialog()
  if StaticPopup_Hide then
    StaticPopup_Hide(BANK_SLOT_PURCHASE_DIALOG)
  end
end

local function ShowBankSlotPurchaseDialog()
  if not RegisterBankSlotPurchaseDialog() or not StaticPopup_Show then
    return false
  end

  if PlaySound then
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or "igMainMenuOption")
  end

  StaticPopup_Show(BANK_SLOT_PURCHASE_DIALOG)
  return true
end

local function ShowUnpurchasedBankBagTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
  if BANK_BAG_PURCHASE then
    GameTooltip:SetText(BANK_BAG_PURCHASE)
  else
    GameTooltip:SetText("Purchase Bank Bag Slot")
  end
  local cost = GetNextBankSlotCost()
  if cost then
    GameTooltip:AddLine("Cost: " .. (GetCoinTextureString and GetCoinTextureString(cost) or tostring(cost)), 1, 1, 1)
  end
  GameTooltip:Show()
end

local function HandleUnpurchasedBankBagClick()
  if GetNumBankSlots and NUM_BANK_BAGS then
    local numSlots = GetNumBankSlots()
    if type(numSlots) == "number" and numSlots >= NUM_BANK_BAGS then
      return
    end
  end

  ShowBankSlotPurchaseDialog()
end

local function ApplyBankBagBarButton(button, bagIndex)
  local purchasedCount = GetPurchasedBankBagCount()
  local isPurchased = bagIndex <= purchasedCount
  local bagID = FIRST_BANK_BAG_ID + bagIndex - 1

  button.bagIndex = bagIndex
  button.bagID = bagID
  button.isPurchased = isPurchased

  if isPurchased then
    ApplyBankBagIcon(button, bagID)
    if button.purchaseOverlay then
      button.purchaseOverlay:Hide()
    end
  elseif button.icon then
    local texture = GetBlizzardBankBagButtonTexture(bagIndex) or EMPTY_BANK_BAG_TEXTURE
    button.icon:SetTexture(texture)
    button.icon:SetVertexColor(1, 1, 1)
    button.icon:Show()
    if button.purchaseOverlay then
      button.purchaseOverlay:Show()
    end
  end
end

local function GetEquippedBankBags()
  local bags = {}
  local purchased = GetPurchasedBankBagCount()

  for index = 1, purchased do
    table.insert(bags, { bagID = FIRST_BANK_BAG_ID + index - 1 })
  end

  return bags
end

local function GetBankSections()
  local sections = {}
  local mainSlots = GetMainBankSlotCount()
  local mainSectionSlots = {}

  for slot = 1, mainSlots do
    table.insert(mainSectionSlots, { bag = BANK_CONTAINER_ID, slot = slot })
  end

  if #mainSectionSlots > 0 then
    table.insert(sections, {
      id = "main",
      title = BANK_SECTION_TITLE,
      slots = mainSectionSlots,
    })
  end

  for _, bagInfo in ipairs(GetEquippedBankBags()) do
    local bag = bagInfo.bagID
    local numSlots = Tea_Util.GetContainerNumSlots(bag) or 0
    if numSlots > 0 then
      local bagSlots = {}
      for slot = 1, numSlots do
        table.insert(bagSlots, { bag = bag, slot = slot })
      end
      table.insert(sections, {
        id = "bag" .. bag,
        bagID = bag,
        slots = bagSlots,
      })
    end
  end

  return sections
end

local function GetBankSlots()
  local slots = {}
  for _, section in ipairs(GetBankSections()) do
    for _, slotInfo in ipairs(section.slots) do
      table.insert(slots, slotInfo)
    end
  end
  return slots
end

local function GetBankLayoutKey()
  local parts = {
    "main:" .. GetMainBankSlotCount(),
    "bags:" .. GetPurchasedBankBagCount(),
  }

  for _, bagInfo in ipairs(GetEquippedBankBags()) do
    local inventorySlot = GetBankBagInventorySlot(bagInfo.bagID)
    local bagItemID = 0
    if inventorySlot then
      bagItemID = GetInventoryItemID("player", inventorySlot) or 0
    end
    local numSlots = Tea_Util.GetContainerNumSlots(bagInfo.bagID) or 0
    table.insert(parts, bagInfo.bagID .. ":" .. numSlots .. ":" .. bagItemID)
  end

  return table.concat(parts, ",")
end

local function GetBankBagContainer(bagID)
  if not bankBagContainers[bagID] then
    local container = CreateFrame("Frame", "TeaBankContainer" .. bagID, bankFrame)
    container:SetID(bagID)
    container:SetSize(1, 1)
    bankBagContainers[bagID] = container
  end
  return bankBagContainers[bagID]
end

local function CreateBankSlotButton(index, bagID)
  local button = CreateFrame("Button", "TeaBankSlot" .. index, GetBankBagContainer(bagID), "ContainerFrameItemButtonTemplate")

  local normal = GetButtonNormalTexture(button)
  if normal then
    normal:SetTexture(nil)
    normal:Hide()
  end

  HideEmptySlotArt(button)
  SetupSlotHover(button)
  EnsureSlotIcon(button)
  ApplySlotButtonSize(button, GetSlotSize())
  return button
end

local function ShowBankBagTooltip(self)
  local inventorySlot = GetBankBagInventorySlot(self.bagID)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
  if inventorySlot and GetInventoryItemLink("player", inventorySlot) then
    GameTooltip:SetInventoryItem("player", inventorySlot)
  else
    GameTooltip:SetText("Bank Bag")
  end
  GameTooltip:Show()
end

local function TogglePinnedBankBag(bagID)
  if pinnedBankBagID == bagID then
    pinnedBankBagID = nil
    ClearBankBagHighlight()
  else
    pinnedBankBagID = bagID
    SetHighlightedBankBag(bagID, true)
  end
end

local function HandleBankBagPickup(self)
  local inventoryID = GetBankBagInventorySlot(self.bagID)
  if not inventoryID then
    return
  end

  if PickupBagFromSlot then
    PickupBagFromSlot(inventoryID)
  elseif PickupInventoryItem then
    PickupInventoryItem(inventoryID)
  end
end

local function HandleBankBagClick(self, mouseButton)
  local inventoryID = GetBankBagInventorySlot(self.bagID)
  if not inventoryID then
    return
  end

  if IsModifiedClick and IsModifiedClick("PICKUPACTION") then
    HandleBankBagPickup(self)
    return
  end

  if mouseButton == "RightButton" then
    return
  end

  local hadItem = PutItemInBag and PutItemInBag(inventoryID)
  if not hadItem and ToggleBag and self.bagID then
    ToggleBag(self.bagID)
  end
end

local function CreateBankBagButton(index)
  local button = CreateFrame("Button", "TeaBankBag" .. index, bankBagBarFrame)
  button:SetSize(BAG_ICON_SIZE, BAG_ICON_SIZE)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  button.icon = icon

  local purchaseOverlay = button:CreateTexture(nil, "OVERLAY")
  purchaseOverlay:SetAllPoints(icon)
  purchaseOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
  purchaseOverlay:SetVertexColor(
    UNPURCHASED_OVERLAY_R,
    UNPURCHASED_OVERLAY_G,
    UNPURCHASED_OVERLAY_B,
    UNPURCHASED_OVERLAY_ALPHA
  )
  purchaseOverlay:Hide()
  button.purchaseOverlay = purchaseOverlay

  local border = button:CreateTexture(nil, "OVERLAY", nil, 1)
  border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\Buttons\\WHITE8x8")
  border:Hide()
  button.border = border

  button:SetScript("OnEnter", function(self)
    if not self.isPurchased then
      ShowUnpurchasedBankBagTooltip(self)
      return
    end
    SetHighlightedBankBag(self.bagID, true)
    ShowBankBagTooltip(self)
  end)
  button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    if not self.isPurchased then
      return
    end
    if pinnedBankBagID == self.bagID then
      return
    end
    ScheduleClearBankBagHighlight()
  end)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(self, mouseButton)
    if not self.isPurchased then
      HandleUnpurchasedBankBagClick()
      return
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
      TogglePinnedBankBag(self.bagID)
      return
    end
    HandleBankBagClick(self, mouseButton)
  end)
  button:SetScript("OnDragStart", function(self)
    if not self.isPurchased then
      return
    end
    HandleBankBagPickup(self)
  end)
  button:SetScript("OnReceiveDrag", function(self)
    if not self.isPurchased then
      return
    end
    HandleBankBagClick(self, "LeftButton")
  end)

  return button
end

local function LayoutBankBagBar()
  if not bankBagBarFrame then
    bankBagBarFrame = CreateFrame("Frame", nil, bankFrame)
  end

  local slotPadding = GetSlotPadding()
  local barItemCount = NUM_BANK_BAGS
  local barWidth = barItemCount * BAG_ICON_SIZE + math.max(0, barItemCount - 1) * slotPadding

  bankBagBarFrame:ClearAllPoints()
  bankBagBarFrame:SetSize(math.max(barWidth, 1), BAG_BAR_HEIGHT)
  bankBagBarFrame:SetPoint("BOTTOMLEFT", bankFrame, "BOTTOMLEFT", SIDE_OFFSET + slotPadding, BOTTOM_BAR_OFFSET)
  bankBagBarFrame:SetFrameLevel(bankFrame:GetFrameLevel() + BOTTOM_BAR_LEVEL)
  bankBagBarFrame:Show()

  for bagIndex = 1, NUM_BANK_BAGS do
    local button = bankBagButtons[bagIndex]
    if not button then
      button = CreateBankBagButton(bagIndex)
      bankBagButtons[bagIndex] = button
    end

    ApplyBankBagBarButton(button, bagIndex)
    button:SetFrameLevel(bankBagBarFrame:GetFrameLevel() + 1)
    button:ClearAllPoints()

    if bagIndex == 1 then
      button:SetPoint("BOTTOMLEFT", bankBagBarFrame, "BOTTOMLEFT", 0, 0)
    else
      button:SetPoint("LEFT", bankBagButtons[bagIndex - 1], "RIGHT", slotPadding, 0)
    end

    button:Show()
  end

  for index = NUM_BANK_BAGS + 1, #bankBagButtons do
    bankBagButtons[index]:Hide()
  end
end

local function HideBankSectionHeaders()
  for _, header in ipairs(bankSectionHeaders) do
    header:Hide()
  end
end

local function GetOrCreateBankHeader(index, title)
  local header = bankSectionHeaders[index]
  if not header then
    header = bankFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bankSectionHeaders[index] = header
  end
  header:SetText(title)
  header:Show()
  return header
end

local function LayoutBankSectionSlots(section, startY, buttonIndex, columns, slotSize, slotPadding, withSectionHeader)
  local y = withSectionHeader and (startY - HEADER_HEIGHT) or startY

  for slotIndex, slotInfo in ipairs(section.slots) do
    buttonIndex = buttonIndex + 1
    local button = bankSlotButtons[buttonIndex]
    if not button then
      button = CreateBankSlotButton(buttonIndex, slotInfo.bag)
      bankSlotButtons[buttonIndex] = button
    elseif button:GetParent() ~= GetBankBagContainer(slotInfo.bag) then
      button:SetParent(GetBankBagContainer(slotInfo.bag))
    end

    button:SetID(slotInfo.slot)
    button:Show()

    local col = (slotIndex - 1) % columns
    local row = math.floor((slotIndex - 1) / columns)
    button:ClearAllPoints()
    button:SetPoint(
      "TOPLEFT",
      bankFrame,
      "TOPLEFT",
      SIDE_OFFSET + slotPadding + col * (slotSize + slotPadding),
      y - slotPadding - row * (slotSize + slotPadding)
    )

    UpdateSlot(button)
  end

  local rows = math.ceil(#section.slots / columns)
  return y - rows * (slotSize + slotPadding) - slotPadding, buttonIndex
end

local function LayoutBankSlots()
  local sections = GetBankSections()
  local columns = GetColumns()
  local slotSize = GetSlotSize()
  local slotPadding = GetSlotPadding()
  local gridWidth = GetGridWidth()
  local y = -CONTENT_TOP
  local buttonIndex = 0
  local headerIndex = 0

  LayoutBankBagBar()
  HideBankSectionHeaders()

  for _, section in ipairs(sections) do
    if section.title then
      headerIndex = headerIndex + 1
      local header = GetOrCreateBankHeader(headerIndex, section.title)
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", SIDE_OFFSET, y)
    end

    y, buttonIndex = LayoutBankSectionSlots(
      section,
      y,
      buttonIndex,
      columns,
      slotSize,
      slotPadding,
      section.title ~= nil
    )
    y = y - SECTION_GAP
  end

  local frameHeight = math.abs(y) + BOTTOM_BAR_HEIGHT + BOTTOM_PADDING

  if not bankBagsHeader then
    bankBagsHeader = bankFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  end
  bankBagsHeader:SetText(BANK_HEADER_TITLE)
  bankBagsHeader:Show()
  bankBagsHeader:ClearAllPoints()
  local bagBarTop = -(frameHeight - BOTTOM_BAR_OFFSET - BAG_BAR_HEIGHT)
  bankBagsHeader:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", SIDE_OFFSET, bagBarTop + HEADER_HEIGHT + INVENTORY_BAR_GAP)

  for index = buttonIndex + 1, #bankSlotButtons do
    bankSlotButtons[index]:Hide()
  end

  for index = headerIndex + 1, #bankSectionHeaders do
    bankSectionHeaders[index]:Hide()
  end

  bankFrame:SetSize(gridWidth + 24, frameHeight)
  lastBankSlotCount = #GetBankSlots()
  lastBankLayoutKey = GetBankLayoutKey()
  lastBankSettingsKey = GetSettingsKey()
  UpdateBankSlotHighlights()
  UpdateBankBagHighlights()
end

local function RefreshBankBags()
  for bagIndex, button in ipairs(bankBagButtons) do
    if button:IsShown() then
      ApplyBankBagBarButton(button, bagIndex)
    end
  end
end

local function RefreshBankTrackBorders()
  for _, button in ipairs(bankSlotButtons) do
    if button:IsShown() and Tea_UpdateTrackBorder then
      local bag, slot = GetSlotBagAndSlot(button)
      if bag and slot then
        Tea_UpdateTrackBorder(button, Tea_Util.GetContainerItemID(bag, slot))
      end
    end
  end
end

local function RefreshBank()
  if not bankFrame then
    return
  end

  RefreshBankBags()

  local mouseFocus = GetMouseFocus and GetMouseFocus()
  for _, button in ipairs(bankSlotButtons) do
    if button:IsShown() and button ~= mouseFocus then
      Tea_Util.SafeCall(UpdateSlot, button)
    end
  end

  UpdateBankSlotHighlights()
  UpdateBankBagHighlights()
end

ScheduleBankRefresh = function()
  if bankRefreshScheduled then
    return
  end

  bankRefreshScheduled = true
  Tea_Util.After(0.05, function()
    bankRefreshScheduled = false
    if IsBankOpen() then
      RefreshBank()
    end
  end)
end

ScheduleBankLayoutRefresh = function()
  if bankLayoutScheduled then
    return
  end

  bankLayoutScheduled = true
  Tea_Util.After(0.05, function()
    bankLayoutScheduled = false
    if not IsBankOpen() then
      return
    end

    local slotCount = #GetBankSlots()
    local layoutKey = GetBankLayoutKey()
    local settingsKey = GetSettingsKey()
    if slotCount ~= lastBankSlotCount or layoutKey ~= lastBankLayoutKey or settingsKey ~= lastBankSettingsKey then
      LayoutBankSlots()
    else
      RefreshBank()
    end
  end)
end

local function BuildBankFrame()
  local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
  bankFrame = CreateFrame("Frame", "TeaBankFrame", UIParent, backdropTemplate)
  bankFrame:SetPoint("LEFT", UIParent, "LEFT", 40, 0)
  bankFrame:SetFrameStrata("HIGH")
  bankFrame:EnableMouse(true)
  bankFrame:SetMovable(true)
  bankFrame:SetClampedToScreen(true)
  bankFrame:RegisterForDrag("LeftButton")
  bankFrame:SetScript("OnDragStart", bankFrame.StartMoving)
  bankFrame:SetScript("OnDragStop", bankFrame.StopMovingOrSizing)
  bankFrame:Hide()

  bankFrame:SetScript("OnHide", function()
    ClearBankBagHighlight()
    if closingTeaBank then
      return
    end

    if bankActive then
      closingTeaBank = true
      bankActive = false
      if CloseBankFrame then
        CloseBankFrame()
      else
        RestoreBlizzardBankUI()
      end
      closingTeaBank = false
    end
  end)

  tinsert(UISpecialFrames, bankFrame:GetName())

  if bankFrame.SetBackdrop then
    bankFrame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    bankFrame:SetBackdropColor(0.05, 0.05, 0.05, 1)
    bankFrame:SetBackdropBorderColor(1, 1, 1, 1)
  end

  bankFrameTitle = bankFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  bankFrameTitle:SetPoint("TOPLEFT", SIDE_OFFSET, TITLE_TOP)
  bankFrameTitle:SetText("teaBank")
  bankFrameTitle:SetTextColor(0.72, 0.95, 0.68)

  local close = CreateFrame("Button", nil, bankFrame, "UIPanelCloseButton")
  close:SetSize(CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)
  close:SetPoint("TOPRIGHT", -6, -10)
  close:SetScript("OnClick", function()
    Tea_CloseBank()
  end)

  LayoutBankSlots()
end

local function ShowTeaBankFrame()
  if not IsEnabled() then
    return false
  end

  if not bankFrame then
    BuildBankFrame()
  end
  if not bankFrame then
    return false
  end

  bankActive = true
  SuppressBlizzardBankUI()
  if CloseBankBagFrames then
    CloseBankBagFrames()
  end
  LayoutBankSlots()
  bankFrame:Show()
  RefreshBank()
  return bankFrame:IsShown()
end

local function EndTeaBankSession()
  bankActive = false
  pinnedBankBagID = nil
  HideBankSlotPurchaseDialog()
  ClearBankBagHighlight()
  RestoreBlizzardBankUI()
  if bankFrame then
    bankFrame:Hide()
  end
end

function Tea_BankIsOpen()
  return IsBankOpen()
end

function Tea_BankIsEnabled()
  return IsEnabled()
end

function Tea_CloseBank()
  closingTeaBank = true
  bankActive = false
  pinnedBankBagID = nil
  HideBankSlotPurchaseDialog()
  ClearBankBagHighlight()
  RestoreBlizzardBankUI()
  if bankFrame then
    bankFrame:Hide()
  end
  if CloseBankFrame then
    CloseBankFrame()
  end
  closingTeaBank = false
end

local function HandleBankOpen()
  if not IsEnabled() then
    DisableCustomBankUI()
    return
  end

  local function tryShow()
    if not IsEnabled() then
      return
    end

    ShowTeaBankFrame()
    ShowBagFrame()
  end

  tryShow()
  Tea_Util.After(0, tryShow)
end

local function HandleBankClose()
  if closingTeaBank then
    return
  end

  if not IsEnabled() then
    bankActive = false
    if bankFrame then
      bankFrame:Hide()
    end
    return
  end

  EndTeaBankSession()
end

local function OnBankUpdate()
  if not IsBankOpen() then
    return
  end

  local slotCount = #GetBankSlots()
  local layoutKey = GetBankLayoutKey()
  local settingsKey = GetSettingsKey()
  if slotCount ~= lastBankSlotCount or layoutKey ~= lastBankLayoutKey or settingsKey ~= lastBankSettingsKey then
    ScheduleBankLayoutRefresh()
  else
    ScheduleBankRefresh()
  end
end

function Tea_InstallBankHooks()
  if bankHooksInstalled then
    return
  end
  bankHooksInstalled = true

  if BankFrame then
    BankFrame:HookScript("OnShow", function()
      if not IsEnabled() then
        RestoreBlizzardBankUI()
        RefreshBlizzardBankDisplay()
        return
      end

      SuppressBlizzardBankUI()
      HandleBankOpen()
    end)
  end

  if updateContainerFrameAnchors then
    hooksecurefunc("updateContainerFrameAnchors", function()
      if bankActive and IsEnabled() then
        SuppressBlizzardBankUI()
      end
    end)
  end
end


function Tea_OneBagUpdateBankSlotHighlight(button)
  UpdateBankSlotHighlight(button)
end

function Tea_OneBagHighlightBankBag(bagID, highlightSlots)
  SetHighlightedBankBag(bagID, highlightSlots)
end

function Tea_OneBagClearBankBagHighlight()
  ScheduleClearBankBagHighlight()
end

function Tea_OneBagScheduleClearBankBagHighlight()
  ScheduleClearBankBagHighlight()
end

function Tea_BankRefreshTracks()
  RefreshBankTrackBorders()
end

function Tea_BankRelayout()
  if not IsEnabled() then
    DisableCustomBankUI()
    return
  end

  if bankFrame then
    LayoutBankSlots()
    if bankFrame:IsShown() then
      RefreshBank()
    end
  end
end

local bankEventFrame = CreateFrame("Frame")
bankEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
bankEventFrame:RegisterEvent("BANKFRAME_CLOSED")
bankEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bankEventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

bankEventFrame:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" then
    if IsBankOpen() then
      OnBankUpdate()
    end
  elseif event == "BANKFRAME_OPENED" then
    HandleBankOpen()
  elseif event == "BANKFRAME_CLOSED" then
    HandleBankClose()
  elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
    if IsBankOpen() then
      OnBankUpdate()
    elseif not IsEnabled() and BankFrame and BankFrame:IsShown() then
      RefreshBlizzardBankDisplay()
    end
  end
end)

if not IsEnabled() then
  RestoreBlizzardBankUI()
end

if UnitName("player") and Tea_FinishOneBagLoad then
  Tea_FinishOneBagLoad()
end
