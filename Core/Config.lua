TeaDB = TeaDB or {}

local defaults = {
  modules = {
    tooltipExtras = true,
    vendorTrash = false,
    repairWarning = true,
    itemTrack = true,
    oneBag = true,
  },
  tooltip = {
    showVendorPrice = true,
    showItemId = true,
    requireShift = false,
  },
  trackedItems = {},
  track = {
    r = 0.2,
    g = 0.85,
    b = 1.0,
  },
}

local function ApplyDefaults(target, source)
  for key, value in pairs(source) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = {}
        ApplyDefaults(target[key], value)
      else
        target[key] = value
      end
    elseif type(value) == "table" and type(target[key]) == "table" then
      ApplyDefaults(target[key], value)
    end
  end
end

function Tea_GetDB()
  ApplyDefaults(TeaDB, defaults)
  return TeaDB
end
