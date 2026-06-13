local function IsEnabled()
  return Tea_GetDB().modules.itemTrack
end

local function ApplyBorder(button, itemID)
  if not button or not button.TeaTrackBorder then
    return
  end

  if IsEnabled() and itemID and Tea_IsTracked(itemID) then
    local r, g, b = Tea_GetTrackColor()
    Tea_Util.SetRoundedIconBorderColor(button.TeaTrackBorder, r, g, b, true)
  else
    Tea_Util.SetRoundedIconBorderColor(button.TeaTrackBorder, nil, nil, nil, false)
  end
end

function Tea_EnsureTrackBorder(button)
  Tea_Util.EnsureRoundedIconBorder(button, "TeaTrackBorder", "OVERLAY", 5)
end

function Tea_UpdateTrackBorder(button, itemID)
  Tea_EnsureTrackBorder(button)
  ApplyBorder(button, itemID)
end

local function UpdateBlizzardButton(button, bag, slot)
  Tea_UpdateTrackBorder(button, Tea_Util.GetContainerItemID(bag, slot))
end

local function UpdateBlizzardBags()
  for i = 1, NUM_CONTAINER_FRAMES do
    local container = _G["ContainerFrame" .. i]
    if container and container:IsShown() then
      local bag = container:GetID()
      local j = 1
      while true do
        local button = _G[container:GetName() .. "Item" .. j]
        if not button then
          break
        end
        UpdateBlizzardButton(button, bag, button:GetID())
        j = j + 1
      end
    end
  end
end

function Tea_RefreshTrackHighlights()
  UpdateBlizzardBags()
  if Tea_BagRefreshTracks then
    Tea_BagRefreshTracks()
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" then
    Tea_RefreshTrackHighlights()
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(0.5, Tea_RefreshTrackHighlights)
  end
end)

if ContainerFrame_Update then
  hooksecurefunc("ContainerFrame_Update", function(container)
    if not container or not container:IsShown() then
      return
    end
    local bag = container:GetID()
    local j = 1
    while true do
      local button = _G[container:GetName() .. "Item" .. j]
      if not button then
        break
      end
      UpdateBlizzardButton(button, bag, button:GetID())
      j = j + 1
    end
  end)
end
