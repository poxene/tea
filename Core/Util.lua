local Util = {}

local ITEM_QUALITY_POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0

local timerFrame
local pendingTimers = {}
local timerID = 0

function Tea_Print(msg)
  print("|cff66ccfftea|r: " .. tostring(msg))
end

function Tea_FormatMoney(copper)
  if not copper or copper == 0 then
    return "0|cffffffff|c"
  end
  if GetCoinTextureString then
    return GetCoinTextureString(copper)
  end
  return tostring(copper)
end

function Util.SafeCall(func, ...)
  if type(func) ~= "function" then
    return false
  end
  local ok, result = pcall(func, ...)
  if ok then
    return result
  end
  return false
end

function Util.After(delay, callback)
  if type(callback) ~= "function" then
    return
  end

  delay = tonumber(delay) or 0
  if delay < 0 then
    delay = 0
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function()
      Util.SafeCall(callback)
    end)
    return
  end

  if not timerFrame then
    timerFrame = CreateFrame("Frame")
    timerFrame:Hide()
    timerFrame:SetScript("OnUpdate", function()
      local now = GetTime()
      for id, entry in pairs(pendingTimers) do
        if now >= entry.deadline then
          pendingTimers[id] = nil
          Util.SafeCall(entry.callback)
        end
      end
      if not next(pendingTimers) then
        timerFrame:Hide()
      end
    end)
  end

  timerID = timerID + 1
  pendingTimers[timerID] = {
    deadline = GetTime() + delay,
    callback = callback,
  }
  timerFrame:Show()
end

function Util.GetItemInfo(idOrLink)
  if not idOrLink then
    return
  end
  if C_Item and C_Item.GetItemInfo then
    return C_Item.GetItemInfo(idOrLink)
  end
  if GetItemInfo then
    return GetItemInfo(idOrLink)
  end
end

function Util.GetItemInfoInstant(idOrLink)
  if not idOrLink then
    return
  end
  if C_Item and C_Item.GetItemInfoInstant then
    return C_Item.GetItemInfoInstant(idOrLink)
  end
  if GetItemInfoInstant then
    return GetItemInfoInstant(idOrLink)
  end
  if type(idOrLink) == "string" then
    return tonumber(idOrLink:match("item:(%d+)"))
  end
  return tonumber(idOrLink)
end

Util.GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
Util.GetContainerNumFreeSlots = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
Util.GetContainerItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
Util.UseContainerItem = (C_Container and C_Container.UseContainerItem) or UseContainerItem
Util.PickupContainerItem = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem

function Util.GetContainerItemInfo(bag, slot)
  if bag == nil or slot == nil then
    return
  end
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
  if GetContainerItemInfo then
    return GetContainerItemInfo(bag, slot)
  end
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
  if quality == nil then
    return false
  end
  return quality == ITEM_QUALITY_POOR
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
