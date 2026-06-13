local ADDON_NAME = ...

local function ShouldShow()
  local db = Tea_GetDB()
  if not db.modules.tooltipExtras then
    return false
  end
  if db.tooltip.requireShift and not IsShiftKeyDown() then
    return false
  end
  return true
end

local function GetTooltipStackCount(tooltip, link)
  local owner = tooltip:GetOwner()
  if owner and owner.GetBagID then
    local bag = owner:GetBagID()
    local slot = owner.GetID and owner:GetID()
    if bag and slot then
      local _, count = Tea_Util.GetContainerItemInfo(bag, slot)
      if count and count > 0 then
        return count
      end
    end
  end
  return 1
end

local function AddTooltipLines(tooltip)
  if not ShouldShow() then
    return
  end

  local _, link = tooltip:GetItem()
  if not link then
    return
  end

  local db = Tea_GetDB()
  local itemID = Tea_Util.GetItemInfoInstant(link)
  local sellPrice = select(11, Tea_Util.GetItemInfo(link))
  local count = GetTooltipStackCount(tooltip, link)

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

  if db.tooltip.showItemId and itemID then
    tooltip:AddLine("ID: " .. itemID, 0.6, 0.6, 0.6)
  end
end

local function HookTooltip(tooltip)
  if not tooltip or tooltip.teaHooked then
    return
  end
  tooltip.teaHooked = true
  tooltip:HookScript("OnTooltipSetItem", AddTooltipLines)
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
  end
end)
