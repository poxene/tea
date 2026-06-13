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

function Util.IsGreyItem(itemID)
  if not itemID then
    return false
  end
  local quality = select(3, Util.GetItemInfo(itemID))
  return quality == Enum.ItemQuality.Poor
end

local BORDER_TEXTURE = "Interface\\Common\\WhiteIconFrame"

function Util.GetIconBorderScale()
  return 1
end

local function ApplyRoundedIconBorderLayout(border, anchor)
  if not border or not anchor then
    return
  end

  local iconSize = anchor:GetWidth()
  if not iconSize or iconSize <= 0 then
    iconSize = anchor:GetHeight() or 37
  end

  local borderSize = iconSize * Util.GetIconBorderScale()
  border:ClearAllPoints()
  border:SetSize(borderSize, borderSize)
  border:SetPoint("CENTER", anchor, "CENTER")

  if border.teaBorderColor and border.SetVertexColor then
    border:SetVertexColor(border.teaBorderColor[1], border.teaBorderColor[2], border.teaBorderColor[3], border.teaBorderColor[4] or 1)
  end
end

function Util.EnsureRoundedIconBorder(button, storageKey, drawLayer, drawSubLevel)
  if not button then
    return nil
  end

  local existing = button[storageKey]
  if existing then
    if existing.SetVertexColor then
      return existing
    end

    existing:Hide()
    existing:SetParent(nil)
    button[storageKey] = nil
  end

  local anchor = button.icon or button
  local border = button:CreateTexture(nil, drawLayer or "OVERLAY", nil, drawSubLevel or 2)
  border:SetTexture(BORDER_TEXTURE)
  ApplyRoundedIconBorderLayout(border, anchor)
  border:Hide()
  button[storageKey] = border
  return border
end

function Util.LayoutRoundedIconBorder(button, storageKey, scale)
  if not button or not button[storageKey] then
    return
  end

  local anchor = button.icon or button
  ApplyRoundedIconBorderLayout(button[storageKey], anchor)
end

function Util.SetRoundedIconBorderColor(border, r, g, b, show)
  if not border then
    return
  end

  if show and r and border.SetVertexColor then
    border.teaBorderColor = { r, g, b, 1 }
    border:SetVertexColor(r, g, b, 1)
    border:Show()
  else
    border.teaBorderColor = nil
    border:Hide()
  end
end

Tea_Util = Util
