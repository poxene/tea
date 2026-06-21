local ADDON_NAME = ...

local draggableInstalled = false
local previewMode = false
local previewAnchor

local PREVIEW_ITEM_LINK = "item:6948"

local function IsLocked()
  return Tea_GetDB().tooltip.locked == true
end

local function IsDraggableEnabled()
  local db = Tea_GetDB().tooltip
  if db.draggable == false then
    return false
  end
  if IsLocked() then
    return false
  end
  return true
end

local function CanDragTooltip()
  return IsDraggableEnabled()
end

local function ShouldShow()
  local db = Tea_GetDB()
  if not db.modules.tooltipExtras then
    return false
  end
  if not previewMode and db.tooltip.requireShift and not IsShiftKeyDown() then
    return false
  end
  return true
end

local function GetTooltipStackCount(tooltip)
  if previewMode and tooltip and tooltip.teaPreviewActive then
    return 1
  end

  local owner = tooltip:GetOwner()
  if not owner then
    return 1
  end

  local bag
  if owner.GetBagID then
    bag = owner:GetBagID()
  elseif owner.GetParent then
    local parent = owner:GetParent()
    if parent and parent.GetID then
      bag = parent:GetID()
    end
  end

  local slot = owner.GetID and owner:GetID()
  if bag and slot and Tea_Util and Tea_Util.GetContainerItemInfo then
    local _, count = Tea_Util.GetContainerItemInfo(bag, slot)
    if count and count > 0 then
      return count
    end
  end
  return 1
end

local function GetEquipSlotLabel(equipLoc)
  if not equipLoc or equipLoc == "" then
    return nil
  end
  return _G[equipLoc] or equipLoc
end

local function AddTooltipLines(tooltip)
  if not ShouldShow() or not tooltip or not tooltip.GetItem then
    return
  end

  if not Tea_Util or not Tea_Util.GetItemInfo then
    return
  end

  local _, link = tooltip:GetItem()
  if not link then
    return
  end

  local db = Tea_GetDB()
  local itemID = Tea_Util.GetItemInfoInstant and Tea_Util.GetItemInfoInstant(link)
  local _, _, _, itemLevel, requiredLevel, itemType, itemSubType, maxStack, equipLoc, _, sellPrice =
    Tea_Util.GetItemInfo(link)
  local count = GetTooltipStackCount(tooltip)

  if db.tooltip.showTracked and itemID and Tea_IsTracked and Tea_IsTracked(itemID) then
    tooltip:AddLine("Tracked", 0.2, 0.85, 1)
  end

  if db.tooltip.showVendorPrice and sellPrice and sellPrice > 0 then
    local total = sellPrice * count
    if count > 1 then
      tooltip:AddLine(
        string.format("Vendor: %s (%s each)", Tea_FormatMoney(total), Tea_FormatMoney(sellPrice)),
        1, 1, 1
      )
    else
      tooltip:AddLine("Vendor: " .. Tea_FormatMoney(sellPrice), 1, 1, 1)
    end
  end

  if db.tooltip.showItemLevel and itemLevel and itemLevel > 0 then
    tooltip:AddLine("Item Level: " .. itemLevel, 1, 1, 1)
  end

  if db.tooltip.showRequiredLevel and requiredLevel and requiredLevel > 0 then
    tooltip:AddLine("Requires Level " .. requiredLevel, 1, 0.82, 0)
  end

  if db.tooltip.showEquipSlot then
    local slotLabel = GetEquipSlotLabel(equipLoc)
    if slotLabel then
      tooltip:AddLine(slotLabel, 1, 1, 1)
    end
  end

  if db.tooltip.showItemType and itemType and itemType ~= "" then
    if itemSubType and itemSubType ~= "" then
      tooltip:AddLine(itemType .. " - " .. itemSubType, 1, 1, 1)
    else
      tooltip:AddLine(itemType, 1, 1, 1)
    end
  end

  if db.tooltip.showMaxStack and maxStack and maxStack > 1 then
    tooltip:AddLine("Max stack: " .. maxStack, 1, 1, 1)
  end

  if db.tooltip.showItemId and itemID then
    tooltip:AddLine("ID: " .. itemID, 0.6, 0.6, 0.6)
  end
end

local function SafeAddTooltipLines(tooltip)
  if Tea_Util and Tea_Util.SafeCall then
    Tea_Util.SafeCall(AddTooltipLines, tooltip)
  else
    AddTooltipLines(tooltip)
  end
end

local function HookTooltip(tooltip)
  if not tooltip or tooltip.teaHooked then
    return
  end
  tooltip.teaHooked = true
  tooltip:HookScript("OnTooltipSetItem", SafeAddTooltipLines)
end

local function GetFrameName(frame)
  if not frame or not frame.GetName then
    return nil
  end
  return frame:GetName()
end

local function IsMinimapRelatedFrame(frame)
  if not frame then
    return false
  end

  if Minimap and frame == Minimap then
    return true
  end

  local name = GetFrameName(frame)
  if not name then
    return false
  end

  if name == "MinimapCluster" or name == "MinimapBackdrop" then
    return true
  end

  if name:match("^MiniMap") then
    return true
  end

  if name == "GameTimeFrame" or name == "TimeManagerClockButton" then
    return true
  end

  if name == "MinimapZoneTextButton" or name == "MinimapToggleButton" then
    return true
  end

  return false
end

local function NameUsesDefaultTooltipPosition(name)
  if not name then
    return false
  end

  if name:match("^TeaBagSlot") or name:match("^TeaBankSlot") then
    return true
  end

  if name:match("^TeaEquippedBag") or name:match("^TeaBankBag") then
    return true
  end

  if name:match("^Character") and name:match("Slot$") then
    return true
  end

  if name:match("^ContainerFrame%d+Item%d+") then
    return true
  end

  if name:match("^BankFrameItem%d+") then
    return true
  end

  return false
end

local function FrameUsesDefaultTooltipPosition(owner)
  if not owner then
    return false
  end

  local frame = owner
  while frame do
    if IsMinimapRelatedFrame(frame) then
      return true
    end

    local name = GetFrameName(frame)
    if NameUsesDefaultTooltipPosition(name) then
      return true
    end

    if name == "PaperDollFrame" or name == "CharacterFrame" then
      return true
    end

    if frame.GetParent then
      frame = frame:GetParent()
    else
      break
    end
  end

  return false
end

local function UsesDefaultTooltipPosition(tooltip)
  if not tooltip or not tooltip.GetOwner then
    return false
  end

  return FrameUsesDefaultTooltipPosition(tooltip:GetOwner())
end

local function HasCustomTooltipAnchor(tooltip)
  if not tooltip or not Tea_GetDB().tooltip.dragUserPositioned then
    return false
  end

  local point, _, relativeTo = tooltip:GetPoint(1)
  return point ~= nil and relativeTo == UIParent
end

local function ReleaseCustomTooltipAnchor(tooltip)
  if HasCustomTooltipAnchor(tooltip) then
    tooltip:ClearAllPoints()
  end
end

local function SaveTooltipPosition(tooltip)
  if UsesDefaultTooltipPosition(tooltip) then
    return
  end

  local point, _, relativePoint, x, y = tooltip:GetPoint(1)
  if not point then
    return
  end

  local settings = Tea_GetDB().tooltip
  settings.dragPoint = point
  settings.dragRelativePoint = relativePoint or point
  settings.dragX = math.floor(x + 0.5)
  settings.dragY = math.floor(y + 0.5)
  settings.dragUserPositioned = true
end

local function ApplySavedTooltipPosition(tooltip)
  local settings = Tea_GetDB().tooltip
  if not settings.dragUserPositioned then
    return
  end

  tooltip:ClearAllPoints()
  tooltip:SetPoint(
    settings.dragPoint or "CENTER",
    UIParent,
    settings.dragRelativePoint or "CENTER",
    settings.dragX or 0,
    settings.dragY or 0
  )
end

local function ApplyDefaultPreviewPosition(tooltip)
  tooltip:ClearAllPoints()
  tooltip:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
end

local function ApplyManagedTooltipPosition(tooltip)
  if not tooltip then
    return
  end

  if previewMode and tooltip.teaPreviewActive then
    if Tea_GetDB().tooltip.dragUserPositioned then
      ApplySavedTooltipPosition(tooltip)
    else
      ApplyDefaultPreviewPosition(tooltip)
    end
    return
  end

  if Tea_GetDB().tooltip.dragUserPositioned then
    if not UsesDefaultTooltipPosition(tooltip) then
      ApplySavedTooltipPosition(tooltip)
    end
  end
end

local function ShouldManageTooltipPosition(tooltip)
  if previewMode and tooltip and tooltip.teaPreviewActive then
    return true
  end
  if Tea_GetDB().tooltip.dragUserPositioned ~= true then
    return false
  end
  if UsesDefaultTooltipPosition(tooltip) then
    return false
  end
  return true
end

local function ForwardTooltipClickToOwner(tooltip, mouseButton)
  if mouseButton ~= "RightButton" then
    return
  end

  local owner = tooltip:GetOwner()
  if not owner or owner:GetObjectType() ~= "Button" then
    return
  end

  if ContainerFrameItemButton_OnClick then
    ContainerFrameItemButton_OnClick(owner, mouseButton)
  elseif owner.Click then
    owner:Click(mouseButton)
  end
end

local function ApplyTooltipClickPassthrough(tooltip)
  if tooltip.SetPassThroughButtons then
    tooltip:SetPassThroughButtons("RightButton")
    tooltip:SetScript("OnMouseUp", nil)
    return
  end

  tooltip:SetScript("OnMouseUp", function(self, button)
    ForwardTooltipClickToOwner(self, button)
  end)
end

local function ClearTooltipClickPassthrough(tooltip)
  if tooltip.SetPassThroughButtons then
    tooltip:SetPassThroughButtons()
  end
  tooltip:SetScript("OnMouseUp", nil)
end

local function GetOrCreatePreviewAnchor()
  if not previewAnchor then
    previewAnchor = CreateFrame("Frame", "TeaTooltipPreviewAnchor", UIParent)
    previewAnchor:SetSize(1, 1)
    previewAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  end
  return previewAnchor
end

local function HidePreviewTooltip()
  if not GameTooltip or not GameTooltip.teaPreviewActive then
    return
  end

  GameTooltip.teaPreviewActive = nil
  GameTooltip:Hide()
end

local function ShowPreviewTooltip()
  if not previewMode or not GameTooltip then
    return
  end

  local anchor = GetOrCreatePreviewAnchor()
  local previousAlpha = GameTooltip:GetAlpha()

  GameTooltip.teaPreviewActive = true
  GameTooltip:SetAlpha(0)
  GameTooltip:Hide()

  GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
  ApplyManagedTooltipPosition(GameTooltip)

  if GameTooltip.SetHyperlink then
    GameTooltip:SetHyperlink(PREVIEW_ITEM_LINK)
  else
    GameTooltip:SetText("Sample Item")
  end

  ApplyManagedTooltipPosition(GameTooltip)
  SafeAddTooltipLines(GameTooltip)
  GameTooltip:AddLine("Preview", 0.6, 0.8, 1)
  ApplyManagedTooltipPosition(GameTooltip)
  GameTooltip:Show()
  ApplyManagedTooltipPosition(GameTooltip)
  GameTooltip:SetAlpha(previousAlpha > 0 and previousAlpha or 1)
end

local function InstallDraggableGameTooltip()
  if draggableInstalled or not GameTooltip then
    return
  end
  draggableInstalled = true

  if GameTooltip.SetClampedToScreen then
    GameTooltip:SetClampedToScreen(true)
  end

  GameTooltip:HookScript("OnShow", function(self)
    if not ShouldManageTooltipPosition(self) then
      return
    end
    ApplyManagedTooltipPosition(self)
  end)

  if GameTooltip.SetOwner then
    hooksecurefunc(GameTooltip, "SetOwner", function(self, owner)
      owner = owner or self:GetOwner()
      if FrameUsesDefaultTooltipPosition(owner) then
        ReleaseCustomTooltipAnchor(self)
        return
      end
      if ShouldManageTooltipPosition(self) then
        ApplyManagedTooltipPosition(self)
      end
    end)
  end

  if GameTooltip_SetDefaultAnchor then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
      if ShouldManageTooltipPosition(tooltip) then
        ApplyManagedTooltipPosition(tooltip)
      end
    end)
  end

  if GameTooltip.SetHyperlink then
    hooksecurefunc(GameTooltip, "SetHyperlink", function(self)
      if ShouldManageTooltipPosition(self) then
        ApplyManagedTooltipPosition(self)
      end
    end)
  end

  if GameTooltip.SetBagItem then
    hooksecurefunc(GameTooltip, "SetBagItem", function(self)
      ReleaseCustomTooltipAnchor(self)
    end)
  end

  if GameTooltip.SetInventoryItem then
    hooksecurefunc(GameTooltip, "SetInventoryItem", function(self)
      if ShouldManageTooltipPosition(self) then
        ApplyManagedTooltipPosition(self)
      end
    end)
  end
end

function Tea_RefreshDraggableTooltip()
  if not GameTooltip then
    return
  end

  InstallDraggableGameTooltip()

  if not CanDragTooltip() and not previewMode then
    ClearTooltipClickPassthrough(GameTooltip)
    GameTooltip:EnableMouse(false)
    GameTooltip:SetMovable(false)
    GameTooltip:RegisterForDrag()
    GameTooltip:SetScript("OnDragStart", nil)
    GameTooltip:SetScript("OnDragStop", nil)
    return
  end

  if previewMode and not CanDragTooltip() then
    ClearTooltipClickPassthrough(GameTooltip)
    GameTooltip:EnableMouse(false)
    GameTooltip:SetMovable(false)
    GameTooltip:RegisterForDrag()
    GameTooltip:SetScript("OnDragStart", nil)
    GameTooltip:SetScript("OnDragStop", nil)
    return
  end

  GameTooltip:EnableMouse(true)
  ApplyTooltipClickPassthrough(GameTooltip)
  GameTooltip:SetMovable(true)
  GameTooltip:RegisterForDrag("LeftButton")
  GameTooltip:SetScript("OnDragStart", function(self)
    if not CanDragTooltip() then
      return
    end
    if previewMode and not self.teaPreviewActive then
      return
    end
    if UsesDefaultTooltipPosition(self) then
      return
    end
    self:StartMoving()
  end)
  GameTooltip:SetScript("OnDragStop", function(self)
    if not CanDragTooltip() then
      return
    end
    if previewMode and not self.teaPreviewActive then
      return
    end
    self:StopMovingOrSizing()
    SaveTooltipPosition(self)
  end)
end

function Tea_RefreshTooltipPreview()
  if previewMode then
    ShowPreviewTooltip()
  end
end

function Tea_SetTooltipPreview(active)
  local wantPreview = active and true or false
  if previewMode == wantPreview then
    if wantPreview then
      Tea_RefreshTooltipPreview()
    end
    return
  end

  previewMode = wantPreview

  if previewMode then
    ShowPreviewTooltip()
    Tea_RefreshDraggableTooltip()
    return
  end

  HidePreviewTooltip()
  Tea_RefreshDraggableTooltip()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    HookTooltip(GameTooltip)
    HookTooltip(ItemRefTooltip)
    if ShoppingTooltip1 then
      HookTooltip(ShoppingTooltip1)
    end
    if ShoppingTooltip2 then
      HookTooltip(ShoppingTooltip2)
    end
    Tea_RefreshDraggableTooltip()
  end
end)
