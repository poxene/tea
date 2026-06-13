local DEFAULT_COLOR = { r = 0.2, g = 0.85, b = 1.0 }

local function CopyColor(color)
  return {
    r = color.r or DEFAULT_COLOR.r,
    g = color.g or DEFAULT_COLOR.g,
    b = color.b or DEFAULT_COLOR.b,
  }
end

function Tea_GetDefaultTrackColor()
  return CopyColor(Tea_GetDB().track or DEFAULT_COLOR)
end

function Tea_IsTracked(itemID)
  if not itemID then
    return false
  end
  return Tea_GetDB().trackedItems[itemID] ~= nil
end

function Tea_GetTrackColor(itemID)
  local default = Tea_GetDefaultTrackColor()
  if not itemID then
    return default.r, default.g, default.b
  end

  local color = Tea_GetDB().trackedItems[itemID]
  if type(color) == "table" then
    return color.r or default.r, color.g or default.g, color.b or default.b
  end

  return default.r, default.g, default.b
end

function Tea_SetTrackColor(itemID, r, g, b)
  itemID = tonumber(itemID)
  if not itemID or not Tea_GetDB().trackedItems[itemID] then
    return false
  end

  Tea_GetDB().trackedItems[itemID] = { r = r, g = g, b = b }
  if Tea_RefreshTrackHighlights then
    Tea_RefreshTrackHighlights()
  end
  return true
end

function Tea_GetTrackedItemIDs()
  local ids = {}
  for itemID in pairs(Tea_GetDB().trackedItems) do
    table.insert(ids, itemID)
  end
  table.sort(ids)
  return ids
end

function Tea_TrackItem(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then
    return false, "Invalid item ID."
  end

  Tea_GetDB().trackedItems[itemID] = Tea_GetDefaultTrackColor()
  if Tea_RefreshTrackHighlights then
    Tea_RefreshTrackHighlights()
  end
  if Tea_RefreshTrackOptions then
    Tea_RefreshTrackOptions()
  end

  local name = Tea_Util.GetItemInfo(itemID)
  if name then
    return true, string.format("Tracking %s (%d).", name, itemID)
  end
  return true, string.format("Tracking item %d.", itemID)
end

function Tea_UntrackItem(itemID)
  itemID = tonumber(itemID)
  if not itemID or not Tea_GetDB().trackedItems[itemID] then
    return false, "Item is not tracked."
  end

  Tea_GetDB().trackedItems[itemID] = nil
  if Tea_RefreshTrackHighlights then
    Tea_RefreshTrackHighlights()
  end
  if Tea_RefreshTrackOptions then
    Tea_RefreshTrackOptions()
  end

  return true, string.format("Stopped tracking item %d.", itemID)
end
