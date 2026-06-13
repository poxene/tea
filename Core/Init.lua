local ADDON_NAME = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Tea_GetDB()
  elseif event == "PLAYER_LOGIN" then
    Tea_Print("loaded. Type |cff66ccff/tea help|r for commands.")
  end
end)
