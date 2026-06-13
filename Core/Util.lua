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

local BORDER_EDGE_FILE = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_BORDER_SIZE = 2
local BORDER_ALPHA = 0.55

function Util.GetIconBorderThickness(scale)
  scale = scale or 1
  return math.max(1, math.floor(DEFAULT_BORDER_SIZE * scale + 0.5))
end

local function CleanupBorderArtifact(button, storageKey)
  local inner = button[storageKey .. "Inner"]
  if inner then
    inner:Hide()
    inner:SetParent(nil)
    button[storageKey .. "Inner"] = nil
  end
end

local function ApplyIconBorderLayout(border, anchor, scale)
  if not border or not anchor then
    return
  end

  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
  border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)

  if border.SetBackdrop then
    border:SetBackdrop({
      edgeFile = BORDER_EDGE_FILE,
      edgeSize = Util.GetIconBorderThickness(scale),
    })
  end

  if border.teaBorderColor and border.SetBackdropBorderColor then
    local color = border.teaBorderColor
    border:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or BORDER_ALPHA)
  end
end

function Util.EnsureRoundedIconBorder(button, storageKey, levelOffset)
  if not button then
    return nil
  end

  CleanupBorderArtifact(button, storageKey)

  local existing = button[storageKey]
  if existing then
    if existing.SetBackdrop then
      ApplyIconBorderLayout(existing, button.icon or button, 1)
      return existing
    end

    existing:Hide()
    existing:SetParent(nil)
    button[storageKey] = nil
  end

  local anchor = button.icon or button
  local border = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate")
  border:SetFrameLevel(button:GetFrameLevel() + (levelOffset or 3))
  ApplyIconBorderLayout(border, anchor, 1)
  border:Hide()
  button[storageKey] = border
  return border
end

function Util.LayoutRoundedIconBorder(button, storageKey, scale)
  if not button or not button[storageKey] then
    return
  end

  local border = button[storageKey]
  if not border.SetBackdrop then
    return
  end

  ApplyIconBorderLayout(border, button.icon or button, scale)
end

function Util.SetRoundedIconBorderColor(border, r, g, b, show, alpha)
  if not border then
    return
  end

  alpha = alpha or BORDER_ALPHA

  if show and r and border.SetBackdropBorderColor then
    border.teaBorderColor = { r, g, b, alpha }
    border:SetBackdropBorderColor(r, g, b, alpha)
    border:Show()
  else
    border.teaBorderColor = nil
    border:Hide()
  end
end

function Util.SetButtonRoundedIconBorderColor(button, storageKey, r, g, b, show, alpha)
  if not button then
    return
  end

  Util.SetRoundedIconBorderColor(button[storageKey], r, g, b, show, alpha)
end

Tea_Util = Util
