local ADDON_NAME = ...

local MAX_SELL_PER_PASS = 12
local pendingAutoSell = false
local moneyBeforeSell

local function ForEachGreyItem(callback)
  for bag = BACKPACK_CONTAINER, NUM_BAG_FRAMES do
    for slot = 1, Tea_Util.GetContainerNumSlots(bag) do
      local itemID = Tea_Util.GetContainerItemID(bag, slot)
      if itemID and Tea_Util.IsGreyItem(itemID) then
        local _, stackCount, locked, _, _, _, _, _, hasNoValue = Tea_Util.GetContainerItemInfo(bag, slot)
        if not locked and not hasNoValue then
          local sellPrice = Tea_Util.GetSellPrice(itemID)
          if sellPrice > 0 then
            callback(bag, slot, itemID, stackCount, sellPrice * (stackCount or 1))
          end
        end
      end
    end
  end
end

local function GetGreySellValue()
  local total = 0
  ForEachGreyItem(function(_, _, _, _, value)
    total = total + value
  end)
  return total
end

function Tea_SellGreyItems()
  if not MerchantFrame or not MerchantFrame:IsShown() then
    Tea_Print("Open a merchant first.")
    return 0
  end

  if InCombatLockdown() then
    Tea_Print("Cannot sell while in combat.")
    return 0
  end

  local expected = GetGreySellValue()
  if expected == 0 then
    Tea_Print("No grey items to sell.")
    return 0
  end

  moneyBeforeSell = GetMoney()
  local sold = 0

  for bag = BACKPACK_CONTAINER, NUM_BAG_FRAMES do
    for slot = 1, Tea_Util.GetContainerNumSlots(bag) do
      if sold >= MAX_SELL_PER_PASS then
        break
      end

      local itemID = Tea_Util.GetContainerItemID(bag, slot)
      if itemID and Tea_Util.IsGreyItem(itemID) then
        local _, _, locked, _, _, _, _, _, hasNoValue = Tea_Util.GetContainerItemInfo(bag, slot)
        if not locked and not hasNoValue and Tea_Util.GetSellPrice(itemID) > 0 then
          Tea_Util.UseContainerItem(bag, slot)
          sold = sold + 1
        end
      end
    end

    if sold >= MAX_SELL_PER_PASS then
      break
    end
  end

  if sold > 0 then
    pendingAutoSell = true
  end

  return expected
end

local function FinishSellMessage()
  if not moneyBeforeSell then
    return
  end

  local gained = GetMoney() - moneyBeforeSell
  if gained > 0 then
    Tea_Print("Sold grey items for " .. Tea_FormatMoney(gained) .. ".")
  end

  moneyBeforeSell = nil
  pendingAutoSell = false
end

local function ContinueSellingIfNeeded()
  if not pendingAutoSell then
    return
  end

  if not MerchantFrame or not MerchantFrame:IsShown() then
    FinishSellMessage()
    return
  end

  if GetGreySellValue() == 0 then
    FinishSellMessage()
    return
  end

  Tea_SellGreyItems()
end

local function ProcessAutoSell()
  if not Tea_GetDB().modules.vendorTrash then
    return
  end
  if not MerchantFrame or not MerchantFrame:IsShown() then
    return
  end

  local expected = GetGreySellValue()
  if expected == 0 then
    return
  end

  if not moneyBeforeSell then
    moneyBeforeSell = GetMoney()
  end

  Tea_SellGreyItems()
end

local sellButton

local function UpdateSellButtonVisibility()
  if not sellButton then
    return
  end

  if MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
    sellButton:Show()
  else
    sellButton:Hide()
  end
end

local function UpdateSellButtonLayout()
  if not sellButton or not MerchantMoneyFrame then
    return
  end

  sellButton:ClearAllPoints()
  sellButton:SetPoint("RIGHT", MerchantMoneyFrame, "LEFT", -52, 1)

  if MerchantFrameTab1 then
    sellButton:SetFrameLevel(MerchantFrameTab1:GetFrameLevel() - 1)
  end

  UpdateSellButtonVisibility()
end

local function CreateSellButton()
  if sellButton or not MerchantFrame then
    return
  end

  sellButton = CreateFrame("Button", "TeaSellGreyButton", MerchantFrame, "UIPanelButtonTemplate")
  sellButton:SetSize(70, 22)
  sellButton:SetText("Sell Junk")
  sellButton:SetNormalFontObject("GameFontHighlight")
  sellButton:SetHighlightFontObject("GameFontHighlight")

  local fontString = sellButton:GetFontString()
  if fontString then
    fontString:SetTextColor(1, 0.82, 0)
  end

  sellButton:SetScript("OnClick", function()
    Tea_SellGreyItems()
  end)
  sellButton:SetScript("OnEnter", function(self)
    local label = self:GetFontString()
    if label then
      label:SetTextColor(1, 0.82, 0)
    end

    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("Sell grey items")
    local value = GetGreySellValue()
    if value > 0 then
      GameTooltip:AddLine("Value: " .. Tea_FormatMoney(value), 1, 1, 1)
    else
      GameTooltip:AddLine("No grey items found.", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
  end)
  sellButton:SetScript("OnLeave", GameTooltip_Hide)

  if MerchantFrame_Update then
    hooksecurefunc("MerchantFrame_Update", UpdateSellButtonLayout)
  end

  UpdateSellButtonLayout()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("PLAYER_MONEY")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    CreateSellButton()
    return
  end

  if event == "MERCHANT_SHOW" then
    UpdateSellButtonLayout()
    C_Timer.After(0.05, ProcessAutoSell)
  elseif event == "MERCHANT_CLOSED" then
    FinishSellMessage()
  elseif event == "PLAYER_MONEY" and pendingAutoSell then
    C_Timer.After(0.05, ContinueSellingIfNeeded)
  end
end)
