local Util = {}

function Tea_Print(msg)
  print("|cff66ccfftea|r: " .. tostring(msg))
end

function Tea_FormatMoney(copper)
  if not copper or copper == 0 then
    return "0|cffffffff|c"
  end
  return GetCoinTextureString(copper)
end

Util.GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
Util.GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
Util.GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
Util.GetContainerNumFreeSlots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
Util.GetContainerItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
Util.UseContainerItem = C_Container and C_Container.UseContainerItem or UseContainerItem
Util.PickupContainerItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem

function Util.GetContainerItemInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then
      return
    end
    return info.iconFileID,
      info.stackCount,
      info.isLocked,
      info.quality,
      info.isReadable,
      info.hasLoot,
      info.hyperlink,
      info.isFiltered,
      info.hasNoValue,
      info.itemID
  end
  return GetContainerItemInfo(bag, slot)
end

function Util.GetSellPrice(itemID)
  if not itemID then
    return 0
  end
  local sellPrice = select(11, Util.GetItemInfo(itemID))
  return sellPrice or 0
end

function Util.IsGreyItem(itemID)
  if not itemID then
    return false
  end
  local quality = select(3, Util.GetItemInfo(itemID))
  return quality == Enum.ItemQuality.Poor
end

Tea_Util = Util
