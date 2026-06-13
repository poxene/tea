local ADDON_NAME = ...

local function OnOff(value)
  return value and "on" or "off"
end

local function SetModuleToggle(name, state)
  local db = Tea_GetDB()
  if db.modules[name] == nil then
    Tea_Print("Unknown module: " .. name)
    return
  end
  db.modules[name] = state
  Tea_Print(name .. " " .. OnOff(state))
end

SLASH_TEA1 = "/tea"
SlashCmdList["TEA"] = function(msg)
  msg = msg:lower():match("^%s*(.-)%s*$")

  if msg == "" then
    Tea_ToggleOptions()
    return
  end

  if msg == "help" then
    Tea_Print("Commands:")
    Tea_Print("  /tea            Open options")
    Tea_Print("  /tea status")
    Tea_Print("  /tea tooltip on|off")
    Tea_Print("  /tea junk on|off")
    Tea_Print("  /tea repair on|off")
    Tea_Print("  /tea track <id>")
    Tea_Print("  /tea untrack <id>")
    Tea_Print("  /tea track list")
    Tea_Print("  /tea bag")
    Tea_Print("  /tea minimap")
    Tea_Print("  /tea sell")
    Tea_Print("  /tea reload")
    return
  end

  if msg == "config" or msg == "options" then
    Tea_ShowOptions()
    return
  end

  if msg == "status" then
    local db = Tea_GetDB()
    Tea_Print("tooltipExtras: " .. OnOff(db.modules.tooltipExtras))
    Tea_Print("vendorTrash (auto): " .. OnOff(db.modules.vendorTrash))
    Tea_Print("repairWarning: " .. OnOff(db.modules.repairWarning))
    Tea_Print("itemTrack: " .. OnOff(db.modules.itemTrack))
    Tea_Print("oneBag: " .. OnOff(db.modules.oneBag))
    Tea_Print("tooltip shift-only: " .. OnOff(db.tooltip.requireShift))
    Tea_Print("tracked items: " .. #Tea_GetTrackedItemIDs())
    return
  end

  local trackId = msg:match("^track%s+(%d+)$")
  if trackId then
    local ok, message = Tea_TrackItem(trackId)
    Tea_Print(message)
    return
  end

  local untrackId = msg:match("^untrack%s+(%d+)$")
  if untrackId then
    local ok, message = Tea_UntrackItem(untrackId)
    Tea_Print(message)
    return
  end

  if msg == "track list" then
    local ids = Tea_GetTrackedItemIDs()
    if #ids == 0 then
      Tea_Print("No tracked items.")
      return
    end
    for _, itemID in ipairs(ids) do
      local name = Tea_Util.GetItemInfo(itemID)
      if name then
        Tea_Print(string.format("%s (%d)", name, itemID))
      else
        Tea_Print(tostring(itemID))
      end
    end
    return
  end

  local module, toggle = msg:match("^(%a+)%s+(on|off)$")
  if module == "tooltip" then
    SetModuleToggle("tooltipExtras", toggle == "on")
    return
  end
  if module == "junk" then
    SetModuleToggle("vendorTrash", toggle == "on")
    return
  end
  if module == "repair" then
    SetModuleToggle("repairWarning", toggle == "on")
    return
  end

  if msg == "sell" then
    Tea_SellGreyItems()
    return
  end

  if msg == "bag" or msg == "bags" then
    Tea_ToggleBag()
    return
  end

  if msg == "minimap" then
    Tea_ShowMinimapButton()
    Tea_Print("Minimap icon shown.")
    return
  end

  if msg == "reload" then
    ReloadUI()
    return
  end

  Tea_Print("Unknown command. Try /tea help")
end
