local ADDON_NAME = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function BootstrapModules()
  if Tea_RefreshResourceBars then
    Tea_RefreshResourceBars()
  end
end

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Tea_GetDB()
    BootstrapModules()
  elseif event == "PLAYER_LOGIN" then
    Tea_Print("loaded. Type |cff66ccff/tea|r for options.")
    BootstrapModules()
  elseif event == "PLAYER_ENTERING_WORLD" and (arg1 or arg2) then
    BootstrapModules()
  end
end)
