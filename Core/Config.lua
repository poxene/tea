TeaDB = TeaDB or {}

local defaults = {
  modules = {
    tooltipExtras = true,
    vendorTrash = false,
    repairWarning = true,
    itemTrack = true,
    oneBag = true,
    resourceBars = false,
    castBars = false,
  },
  tooltip = {
    showVendorPrice = true,
    showItemId = true,
    showItemLevel = false,
    showRequiredLevel = false,
    showEquipSlot = false,
    showItemType = false,
    showMaxStack = false,
    showTracked = true,
    requireShift = false,
  },
  trackedItems = {},
  track = {
    r = 0.2,
    g = 0.85,
    b = 1.0,
  },
  oneBag = {
    columns = 8,
    slotSize = 37,
    slotPadding = 2,
    greyJunkIcons = true,
  },
  minimap = {
    show = true,
    angle = 220,
  },
  vendorTrash = {
    showSellButton = true,
  },
  resourceBars = {
    width = 200,
    height = 48,
    point = "CENTER",
    relativePoint = "CENTER",
    x = -320,
    y = -180,
    locked = false,
  },
  castBars = {
    showPlayer = true,
    showTarget = true,
    locked = false,
    player = {
      width = 240,
      height = 24,
      point = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = -120,
    },
    target = {
      width = 240,
      height = 24,
      point = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = -90,
    },
  },
}

local ONE_BAG_LAYOUT_VERSION = 1

local function ApplyOneBagLayoutDefaults(db)
  db.oneBag = db.oneBag or {}
  db.oneBag.columns = defaults.oneBag.columns
  db.oneBag.slotSize = defaults.oneBag.slotSize
  db.oneBag.slotPadding = defaults.oneBag.slotPadding
  db.oneBag.borderInset = nil
  db.oneBagLayoutVersion = ONE_BAG_LAYOUT_VERSION
end

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

local function MigrateTrackedItems(db)
  local default = db.track or defaults.track
  for itemID, value in pairs(db.trackedItems) do
    if value == true then
      db.trackedItems[itemID] = {
        r = default.r,
        g = default.g,
        b = default.b,
      }
    end
  end
end

local function MigrateMinimapSettings(db)
  db.minimap = db.minimap or {}
  if db.minimap.show == nil then
    if db.minimap.hide ~= nil then
      db.minimap.show = not db.minimap.hide
    else
      db.minimap.show = true
    end
  end
end

local function MigrateCastBarLock(db)
  db.castBars = db.castBars or {}
  if db.castBars.locked == nil then
    local playerLocked = db.castBars.player and db.castBars.player.locked
    local targetLocked = db.castBars.target and db.castBars.target.locked
    db.castBars.locked = playerLocked == true or targetLocked == true
  end
end

function Tea_GetDB()
  ApplyDefaults(TeaDB, defaults)

  if (TeaDB.oneBagLayoutVersion or 0) < ONE_BAG_LAYOUT_VERSION then
    ApplyOneBagLayoutDefaults(TeaDB)
  end

  MigrateTrackedItems(TeaDB)
  MigrateMinimapSettings(TeaDB)
  MigrateCastBarLock(TeaDB)

  return TeaDB
end
