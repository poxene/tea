local ADDON_NAME = ...

local DURABILITY_THRESHOLD = 0.35

local function GetLowestDurability()
  local lowest = 1
  for slot = 1, 18 do
    local current, maximum = GetInventoryItemDurability(slot)
    if current and maximum and maximum > 0 then
      local ratio = current / maximum
      if ratio < lowest then
        lowest = ratio
      end
    end
  end
  return lowest
end

local function MaybeWarnRepair()
  local db = Tea_GetDB()
  if not db.modules.repairWarning then
    return
  end

  local lowest = GetLowestDurability()
  if lowest >= DURABILITY_THRESHOLD then
    return
  end

  local cost = GetRepairAllCost()
  if cost <= 0 then
    return
  end

  Tea_Print(
    string.format(
      "Gear at %d%% durability. Repair all: %s",
      math.floor(lowest * 100),
      Tea_FormatMoney(cost)
    )
  )
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    return
  end

  if event == "MERCHANT_SHOW" then
    C_Timer.After(0.1, MaybeWarnRepair)
  end
end)
