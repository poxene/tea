local ADDON_NAME = ...

local PANEL_WIDTH = 440
local PANEL_HEIGHT = 480
local FRAME_PADDING = 20
local TITLE_SIDE_OFFSET = 12
local TITLE_TOP = -12
local CLOSE_BUTTON_SIZE = 16
local CONTENT_TOP = -36
local SIDEBAR_WIDTH = 104
local SIDEBAR_GAP = 8
local ROW_SPACING = 4
local SUBHEADER_TOP = 18
local SUBHEADER_TOP_FIRST = 16
local BAR_SLIDER_TOP = 14
local BAR_SLIDER_GAP = 26
local CONTENT_HEADER_TOP = -12
local MIN_CONTENT_HEIGHT = 320
local MAX_TRACK_ROWS = 10
local NAV_BUTTON_HEIGHT = 28
local NAV_BUTTON_SPACING = 2

local SELECTED_NAV_COLOR = { 0.28, 0.45, 0.28, 1 }
local DEFAULT_NAV_COLOR = { 0.15, 0.15, 0.15, 0.85 }

local SECTIONS = {
  {
    id = "general",
    label = "General",
    options = {
      { label = "Auto-sell grey at vendors", path = { "modules", "vendorTrash" } },
      {
        label = "Show 'Sell Junk' button at vendors",
        path = { "vendorTrash", "showSellButton" },
        onChange = function()
          if Tea_RefreshSellButton then
            Tea_RefreshSellButton()
          end
        end,
      },
      { label = "Repair warning at vendors", path = { "modules", "repairWarning" } },
      {
        label = "Show minimap button",
        path = { "minimap", "show" },
        onChange = function(checked)
          if checked then
            Tea_ShowMinimapButton()
          else
            Tea_HideMinimapButton()
          end
        end,
      },
    },
  },
  {
    id = "tooltip",
    label = "Tooltip",
    options = {
      { label = "Enable", path = { "modules", "tooltipExtras" } },
      { label = "Only while holding Shift", path = { "tooltip", "requireShift" } },
      { label = "Show vendor price", path = { "tooltip", "showVendorPrice" } },
      { label = "Show item ID", path = { "tooltip", "showItemId" } },
      { label = "Show item level", path = { "tooltip", "showItemLevel" } },
      { label = "Show required level", path = { "tooltip", "showRequiredLevel" } },
      { label = "Show equipment slot", path = { "tooltip", "showEquipSlot" } },
      { label = "Show item type", path = { "tooltip", "showItemType" } },
      { label = "Show max stack size", path = { "tooltip", "showMaxStack" } },
      { label = "Show tracked item marker", path = { "tooltip", "showTracked" } },
    },
  },
  { id = "tracking", label = "Tracking" },
  { id = "oneBag", label = "Bags" },
  {
    id = "teaBars",
    label = "Bars",
  },
}

local frame
local sidebar
local contentHost
local navButtons = {}
local contentPanels = {}
local activeSection = 1
local checkboxes = {}
local trackListFrame
local trackEditBox
local oneBagSliders = {}
local barSliders = {}
local RefreshTrackList

local BAR_POS_MIN = -600
local BAR_POS_MAX = 600
local BAR_INPUT_WIDTH = 52
local BAR_INPUT_RIGHT = 8
local BAR_INPUT_GAP = 8
local BAR_SLIDER_RIGHT_INSET = BAR_INPUT_WIDTH + BAR_INPUT_RIGHT + BAR_INPUT_GAP

local function TrimString(text)
  if strtrim then
    return strtrim(text)
  end
  return (text:match("^%s*(.-)%s*$")) or text
end

local function GetNumericOptionValue(path)
  local value = Tea_GetDB()
  for i = 1, #path do
    if type(value) ~= "table" then
      return nil
    end
    value = value[path[i]]
  end
  return value
end

local function SetNumericOptionValue(path, value)
  local db = Tea_GetDB()
  local node = db
  for i = 1, #path - 1 do
    node = node[path[i]]
    if not node then
      return
    end
  end
  node[path[#path]] = value
end

local function SanitizeBarPositionInputText(text)
  if not text or text == "" then
    return ""
  end

  local sign = ""
  local rest = text
  if rest:sub(1, 1) == "-" then
    sign = "-"
    rest = rest:sub(2)
  end

  rest = rest:gsub("%D", "")
  return sign .. rest
end

local function ClampBarPosition(value, minValue, maxValue)
  if type(value) == "string" then
    value = TrimString(value)
    if value == "" or value == "-" or value == "+" then
      return nil
    end
  end
  value = math.floor(tonumber(value) or minValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function CommitBarPosition(path, value, minValue, maxValue, controls, onChange, forceApply)
  local parsed = ClampBarPosition(value, minValue, maxValue)
  if parsed == nil then
    parsed = ClampBarPosition(GetNumericOptionValue(path) or minValue, minValue, maxValue)
  end
  value = parsed

  local current = ClampBarPosition(GetNumericOptionValue(path) or minValue, minValue, maxValue)

  controls.updating = true
  SetNumericOptionValue(path, value)
  controls.slider:SetValue(value)
  controls.input:SetText(tostring(value))
  controls.updating = false

  if (forceApply or current ~= value) and onChange then
    onChange(value)
  end
end

local function CommitBarPositionInput(controls, forceApply)
  CommitBarPosition(
    controls.path,
    controls.input:GetText(),
    controls.minValue,
    controls.maxValue,
    controls,
    controls.onChange,
    forceApply
  )
end

local function GetOptionValue(path)
  local value = Tea_GetDB()
  for i = 1, #path do
    if type(value) ~= "table" then
      return nil
    end
    value = value[path[i]]
  end
  return value
end

local function SetOptionValue(path, checked)
  local db = Tea_GetDB()
  local node = db
  for i = 1, #path - 1 do
    node = node[path[i]]
  end
  node[path[#path]] = checked
end

local function FindSectionIndex(sectionId)
  for index, section in ipairs(SECTIONS) do
    if section.id == sectionId then
      return index
    end
  end
end

local SCROLLBAR_WIDTH = 26

local function GetPanelContentWidth(panel)
  local width = panel and panel:GetWidth() or 0
  if width > 0 then
    return width
  end

  return PANEL_WIDTH
    - (FRAME_PADDING * 2)
    - SIDEBAR_WIDTH
    - SIDEBAR_GAP
    - SCROLLBAR_WIDTH
end

local function SyncScrollSize(panel)
  if not panel or not panel.scrollFrame or not panel.scrollChild then
    return
  end

  local scrollFrame = panel.scrollFrame
  local scrollChild = panel.scrollChild
  local width = scrollFrame:GetWidth()

  if width and width > 0 then
    scrollChild:SetWidth(width)
  else
    scrollChild:SetWidth(GetPanelContentWidth(panel))
  end

  if scrollFrame.UpdateScrollChildRect then
    scrollFrame:UpdateScrollChildRect()
  end
end

local function UpdateScrollHeight(panel, bottomWidget, padding)
  if not panel or not panel.scrollChild or not panel.scrollFrame then
    return
  end

  padding = padding or 24
  local scrollChild = panel.scrollChild
  local scrollFrame = panel.scrollFrame
  local frameHeight = scrollFrame:GetHeight() or 0
  local contentHeight = MIN_CONTENT_HEIGHT

  SyncScrollSize(panel)

  if bottomWidget then
    local bottom = bottomWidget:GetBottom()
    local top = scrollChild:GetTop()
    if bottom and top then
      contentHeight = math.max((top - bottom) + padding, frameHeight, MIN_CONTENT_HEIGHT)
    elseif bottom then
      contentHeight = math.max(-bottom + padding, frameHeight, MIN_CONTENT_HEIGHT)
    end
  end

  scrollChild:SetHeight(contentHeight)

  if scrollFrame.UpdateScrollChildRect then
    scrollFrame:UpdateScrollChildRect()
  end
end

local function CreateScrollArea(panel)
  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
  scrollFrame:SetFrameLevel(panel:GetFrameLevel() + 2)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(GetPanelContentWidth(panel))
  scrollChild:SetHeight(MIN_CONTENT_HEIGHT)
  scrollFrame:SetScrollChild(scrollChild)

  scrollFrame:SetScript("OnShow", function()
    SyncScrollSize(panel)
    UpdateScrollHeight(panel, panel.scrollBottom)
  end)

  scrollFrame:SetScript("OnSizeChanged", function()
    SyncScrollSize(panel)
  end)

  panel.scrollFrame = scrollFrame
  panel.scrollChild = scrollChild
  return scrollChild
end

local function RefreshCheckboxes()
  for _, entry in ipairs(checkboxes) do
    entry.button:SetChecked(GetOptionValue(entry.path) and true or false)
  end
end

local function CreateCheckbox(parent, label, path, anchorFrame, yOffset, option)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOffset)

  local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("LEFT", check, "RIGHT", 4, 0)
  text:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
  text:SetJustifyH("LEFT")
  text:SetText(label)
  text:SetScript("OnMouseUp", function()
    check:Click()
  end)

  check:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    SetOptionValue(path, checked)
    if option and option.onChange then
      option.onChange(checked)
    end
  end)

  check:SetChecked(GetOptionValue(path) and true or false)

  table.insert(checkboxes, { button = check, path = path })
  return check
end

local function CreatePanelHeader(content, title)
  local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", content, "TOPLEFT", 8, CONTENT_HEADER_TOP)
  header:SetText(title)
  return header
end

local function BuildOptionsPanel(content, section)
  local header = CreatePanelHeader(content, section.label)
  local anchor = header
  local lastWasHeader = false
  local options = section.options or {}

  for optionIndex, option in ipairs(options) do
    if option.header then
      local offset = lastWasHeader and -SUBHEADER_TOP or (optionIndex == 1 and -SUBHEADER_TOP_FIRST or -SUBHEADER_TOP)
      local subheader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      subheader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
      subheader:SetText(option.header)
      anchor = subheader
      lastWasHeader = true
    elseif option.hint then
      local offset = lastWasHeader and -10 or -12
      local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      hint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
      hint:SetPoint("RIGHT", content, "RIGHT", -8, 0)
      hint:SetJustifyH("LEFT")
      hint:SetText(option.hint)
      anchor = hint
      lastWasHeader = false
    else
      local offset = lastWasHeader and -8 or (optionIndex == 1 and -8 or -ROW_SPACING)
      anchor = CreateCheckbox(content, option.label, option.path, anchor, offset, option)
      lastWasHeader = false
    end
  end

  return anchor
end

local ROW_HEIGHT = 18
local COLOR_SWATCH_SIZE = 18

local function ClearTrackList()
  if not trackListFrame then
    return
  end

  for _, region in ipairs({ trackListFrame:GetRegions() }) do
    region:Hide()
    region:SetParent(nil)
  end

  for _, child in ipairs({ trackListFrame:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
end

local function UpdateColorSwatch(swatch, itemID)
  local r, g, b = Tea_GetTrackColor(itemID)
  local texture = swatch.texture
  if texture.SetColorTexture then
    texture:SetColorTexture(r, g, b, 1)
  else
    texture:SetVertexColor(r, g, b, 1)
  end
end

local function OpenTrackColorPicker(itemID, swatch)
  local r, g, b = Tea_GetTrackColor(itemID)

  local function ApplyColor(nr, ng, nb)
    Tea_SetTrackColor(itemID, nr, ng, nb)
    UpdateColorSwatch(swatch, itemID)
  end

  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = r,
      g = g,
      b = b,
      hasOpacity = false,
      swatchFunc = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        ApplyColor(nr, ng, nb)
      end,
      cancelFunc = function()
        ApplyColor(r, g, b)
      end,
    })
    return
  end

  ColorPickerFrame:Hide()
  ColorPickerFrame:SetColorRGB(r, g, b)
  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.previousValues = { r = r, g = g, b = b }
  ColorPickerFrame.func = function()
    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
    ApplyColor(nr, ng, nb)
  end
  ColorPickerFrame.cancelFunc = function()
    local prev = ColorPickerFrame.previousValues
    ApplyColor(prev.r, prev.g, prev.b)
  end
  ColorPickerFrame:Show()
end

local function CreateTrackColorSwatch(parent, itemID)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(COLOR_SWATCH_SIZE, COLOR_SWATCH_SIZE)

  local border = swatch:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\Buttons\\WHITE8x8")
  border:SetVertexColor(0.35, 0.35, 0.35, 1)

  local texture = swatch:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints()
  texture:SetTexture("Interface\\Buttons\\WHITE8x8")
  swatch.texture = texture

  UpdateColorSwatch(swatch, itemID)

  swatch:SetScript("OnClick", function()
    OpenTrackColorPicker(itemID, swatch)
  end)
  swatch:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Border color")
    GameTooltip:Show()
  end)
  swatch:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return swatch
end

RefreshTrackList = function()
  if not trackListFrame then
    return
  end

  ClearTrackList()

  local ids = Tea_GetTrackedItemIDs()
  if #ids == 0 then
    local empty = trackListFrame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 0, 0)
    empty:SetText("No tracked items.")
    return
  end

  local y = 0
  for index = 1, math.min(#ids, MAX_TRACK_ROWS) do
    local itemID = ids[index]
    local row = CreateFrame("Frame", nil, trackListFrame)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", trackListFrame, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", trackListFrame, "TOPRIGHT", 0, y)

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(36, 16)
    remove:SetPoint("RIGHT", 0, 0)
    remove:SetText("X")
    remove:SetScript("OnClick", function()
      Tea_UntrackItem(itemID)
    end)

    local colorSwatch = CreateTrackColorSwatch(row, itemID)
    colorSwatch:SetPoint("RIGHT", remove, "LEFT", -6, 0)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetPoint("RIGHT", colorSwatch, "LEFT", -6, 0)
    label:SetJustifyH("LEFT")

    local name = Tea_Util.GetItemInfo(itemID)
    if name then
      label:SetText(string.format("%s (%d)", name, itemID))
    else
      label:SetText(tostring(itemID))
      Tea_Util.GetItemInfo(itemID)
    end

    y = y - ROW_HEIGHT
  end

  if #ids > MAX_TRACK_ROWS then
    local more = trackListFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    more:SetPoint("TOPLEFT", 0, y)
    more:SetText(string.format("+%d more (use /tea track list)", #ids - MAX_TRACK_ROWS))
  end
end

local function RefreshTrackingPanel()
  local panel = contentPanels[FindSectionIndex("tracking")]
  if not panel then
    return
  end

  SyncScrollSize(panel)
  RefreshTrackList()
  UpdateScrollHeight(panel, panel.scrollBottom)

  if panel.scrollFrame and panel.scrollFrame.UpdateScrollChildRect then
    panel.scrollFrame:UpdateScrollChildRect()
  end
end

local function AddTrackedItemFromInput()
  if not trackEditBox then
    return
  end

  local itemID = tonumber(trackEditBox:GetText())
  local ok, message = Tea_TrackItem(itemID)
  Tea_Print(message)
  if ok then
    trackEditBox:SetText("")
    RefreshTrackingPanel()
  end
end

local function BuildTrackingPanel(content)
  local header = CreatePanelHeader(content, "Tracking")

  local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  hint:SetText("Input an item ID and click 'Add' to track it.\nYou can adjust the border color of tracked items.")

  trackEditBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
  trackEditBox:SetSize(140, 20)
  trackEditBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
  trackEditBox:SetAutoFocus(false)
  trackEditBox:SetNumeric(true)
  trackEditBox:SetMaxLetters(10)

  local addButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  addButton:SetSize(52, 20)
  addButton:SetPoint("LEFT", trackEditBox, "RIGHT", 6, 0)
  addButton:SetText("Add")
  addButton:SetScript("OnClick", AddTrackedItemFromInput)

  trackEditBox:SetScript("OnEnterPressed", function()
    AddTrackedItemFromInput()
  end)

  trackListFrame = CreateFrame("Frame", nil, content)
  trackListFrame:SetPoint("TOPLEFT", trackEditBox, "BOTTOMLEFT", 0, -10)
  trackListFrame:SetPoint("RIGHT", content, "RIGHT", -8, 0)
  trackListFrame:SetHeight(180)

  return trackListFrame
end

function Tea_RefreshTrackOptions()
  RefreshTrackingPanel()
end

local function CreateBarSlider(content, label, path, minValue, maxValue, step, anchor, yOffset, onChange)
  local slider = CreateFrame("Slider", "TeaBarSlider" .. #barSliders + 1, content, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
  slider:SetPoint("RIGHT", content, "RIGHT", -BAR_SLIDER_RIGHT_INSET, 0)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)

  local initialValue = ClampBarPosition(GetNumericOptionValue(path) or minValue, minValue, maxValue)
  slider:SetValue(initialValue)

  local sliderName = slider:GetName()
  local text = _G[sliderName .. "Text"]
  local low = _G[sliderName .. "Low"]
  local high = _G[sliderName .. "High"]
  if text then
    text:SetText(label)
  end
  if low then
    low:SetText(tostring(minValue))
  end
  if high then
    high:SetText(tostring(maxValue))
  end

  local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
  input:SetSize(BAR_INPUT_WIDTH, 20)
  input:SetPoint("RIGHT", content, "RIGHT", -BAR_INPUT_RIGHT, 0)
  input:SetPoint("TOP", slider, "TOP", 0, -1)
  input:SetAutoFocus(false)
  input:SetMaxLetters(5)
  input:EnableKeyboard(true)
  input:SetText(tostring(initialValue))

  local controls = {
    slider = slider,
    input = input,
    path = path,
    minValue = minValue,
    maxValue = maxValue,
    onChange = onChange,
    updating = false,
    skipBlurCommit = false,
  }

  input:SetScript("OnTextChanged", function(self)
    if controls.updating then
      return
    end

    local cleaned = SanitizeBarPositionInputText(self:GetText())
    if self:GetText() ~= cleaned then
      controls.updating = true
      self:SetText(cleaned)
      controls.updating = false
    end
  end)

  slider:SetScript("OnValueChanged", function(self)
    if controls.updating then
      return
    end
    local value = math.floor(self:GetValue() + 0.5)
    CommitBarPosition(path, value, minValue, maxValue, controls, onChange, true)
  end)

  input:SetScript("OnEnterPressed", function(self)
    CommitBarPositionInput(controls, true)
    controls.skipBlurCommit = true
    self:ClearFocus()
  end)

  input:SetScript("OnEditFocusLost", function(self)
    if controls.updating then
      return
    end
    if controls.skipBlurCommit then
      controls.skipBlurCommit = false
      return
    end
    CommitBarPositionInput(controls, false)
  end)

  input:SetScript("OnEscapePressed", function(self)
    local value = ClampBarPosition(GetNumericOptionValue(path) or minValue, minValue, maxValue)
    controls.updating = true
    controls.input:SetText(tostring(value))
    controls.slider:SetValue(value)
    controls.updating = false
    self:ClearFocus()
  end)

  table.insert(barSliders, controls)
  return slider
end

local function RefreshBarSliders()
  for _, controls in ipairs(barSliders) do
    local value = ClampBarPosition(
      GetNumericOptionValue(controls.path) or controls.minValue,
      controls.minValue,
      controls.maxValue
    )
    controls.updating = true
    controls.slider:SetValue(value)
    controls.input:SetText(tostring(value))
    controls.updating = false
  end
end

local function CreateOptionsButton(content, label, anchor, yOffset, onClick)
  local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  button:SetSize(132, 22)
  button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
  button:SetText(label)
  button:SetScript("OnClick", onClick)
  return button
end

local function CreateSectionSubheader(content, text, anchor, yOffset)
  local subheader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  subheader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
  subheader:SetText(text)
  return subheader
end

local function RefreshResourceBarsFromOptions()
  if Tea_ApplyResourceBarsPosition then
    Tea_ApplyResourceBarsPosition()
  elseif Tea_RefreshResourceBars then
    Tea_RefreshResourceBars()
  end
end

local function RefreshCastBarsFromOptions()
  if Tea_ApplyCastBarsPosition then
    Tea_ApplyCastBarsPosition()
  elseif Tea_RefreshCastBars then
    Tea_RefreshCastBars()
  end
end

local function BuildTeaBarsPanel(content)
  local header = CreatePanelHeader(content, "Bars")

  local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
  hint:SetPoint("RIGHT", content, "RIGHT", -8, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText("Preview bars appear on screen while this panel is open. Drag and resize them to set their layout.")

  local resourceHeader = CreateSectionSubheader(content, "Resource", hint, -SUBHEADER_TOP)
  local resourceEnable = CreateCheckbox(content, "Enable", { "modules", "resourceBars" }, resourceHeader, -8, {
    onChange = RefreshResourceBarsFromOptions,
  })
  local resourceLock = CreateCheckbox(content, "Lock bars", { "resourceBars", "locked" }, resourceEnable, -ROW_SPACING, {
    onChange = RefreshResourceBarsFromOptions,
  })
  local resourceCenter = CreateOptionsButton(content, "Center horizontally", resourceLock, -10, function()
    if Tea_CenterResourceBarsHorizontally then
      Tea_CenterResourceBarsHorizontally()
      RefreshBarSliders()
    end
  end)
  local resourceX = CreateBarSlider(
    content,
    "Position X",
    { "resourceBars", "x" },
    BAR_POS_MIN,
    BAR_POS_MAX,
    1,
    resourceCenter,
    -BAR_SLIDER_TOP,
    RefreshResourceBarsFromOptions
  )
  local resourceY = CreateBarSlider(
    content,
    "Position Y",
    { "resourceBars", "y" },
    BAR_POS_MIN,
    BAR_POS_MAX,
    1,
    resourceX,
    -BAR_SLIDER_GAP,
    RefreshResourceBarsFromOptions
  )

  local castHeader = CreateSectionSubheader(content, "Cast", resourceY, -SUBHEADER_TOP)
  local castEnable = CreateCheckbox(content, "Enable", { "modules", "castBars" }, castHeader, -8, {
    onChange = RefreshCastBarsFromOptions,
  })
  local castShowPlayer = CreateCheckbox(content, "Show player cast bar", { "castBars", "showPlayer" }, castEnable, -ROW_SPACING, {
    onChange = RefreshCastBarsFromOptions,
  })
  local castShowTarget = CreateCheckbox(content, "Show target cast bar", { "castBars", "showTarget" }, castShowPlayer, -ROW_SPACING, {
    onChange = RefreshCastBarsFromOptions,
  })
  local castLock = CreateCheckbox(content, "Lock bars", { "castBars", "locked" }, castShowTarget, -ROW_SPACING, {
    onChange = RefreshCastBarsFromOptions,
  })
  local castPlayerHeader = CreateSectionSubheader(content, "Player position", castLock, -SUBHEADER_TOP)
  local castPlayerCenter = CreateOptionsButton(content, "Center horizontally", castPlayerHeader, -10, function()
    if Tea_CenterCastBarHorizontally then
      Tea_CenterCastBarHorizontally("player")
      RefreshBarSliders()
    end
  end)
  local castPlayerX = CreateBarSlider(
    content,
    "Position X",
    { "castBars", "player", "x" },
    BAR_POS_MIN,
    BAR_POS_MAX,
    1,
    castPlayerCenter,
    -BAR_SLIDER_TOP,
    RefreshCastBarsFromOptions
  )
  local castPlayerY = CreateBarSlider(
    content,
    "Position Y",
    { "castBars", "player", "y" },
    BAR_POS_MIN,
    BAR_POS_MAX,
    1,
    castPlayerX,
    -BAR_SLIDER_GAP,
    RefreshCastBarsFromOptions
  )
  local castTargetHeader = CreateSectionSubheader(content, "Target position", castPlayerY, -SUBHEADER_TOP)
  local castTargetCenter = CreateOptionsButton(content, "Center horizontally", castTargetHeader, -10, function()
    if Tea_CenterCastBarHorizontally then
      Tea_CenterCastBarHorizontally("target")
      RefreshBarSliders()
    end
  end)
  local castTargetX = CreateBarSlider(
    content,
    "Position X",
    { "castBars", "target", "x" },
    BAR_POS_MIN,
    BAR_POS_MAX,
    1,
    castTargetCenter,
    -BAR_SLIDER_TOP,
    RefreshCastBarsFromOptions
  )
  local castTargetY = CreateBarSlider(
    content,
    "Position Y",
    { "castBars", "target", "y" },
    BAR_POS_MIN,
    BAR_POS_MAX,
    1,
    castTargetX,
    -BAR_SLIDER_GAP,
    RefreshCastBarsFromOptions
  )

  return castTargetY
end

local function CreateSlider(content, label, path, minValue, maxValue, step, anchor, yOffset, onChange)
  local slider = CreateFrame("Slider", "TeaOptionsSlider" .. #oneBagSliders + 1, content, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
  slider:SetPoint("RIGHT", content, "RIGHT", -24, 0)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(GetNumericOptionValue(path) or minValue)

  local sliderName = slider:GetName()
  local text = _G[sliderName .. "Text"]
  local low = _G[sliderName .. "Low"]
  local high = _G[sliderName .. "High"]
  if text then
    text:SetText(label)
  end
  if low then
    low:SetText(tostring(minValue))
  end
  if high then
    high:SetText(tostring(maxValue))
  end

  slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    if value ~= GetNumericOptionValue(path) then
      SetNumericOptionValue(path, value)
      if onChange then
        onChange(value)
      end
    end
  end)

  table.insert(oneBagSliders, { slider = slider, path = path })
  return slider
end

local function RefreshOneBagSliders()
  for _, entry in ipairs(oneBagSliders) do
    local minValue = select(1, entry.slider:GetMinMaxValues())
    entry.slider:SetValue(GetNumericOptionValue(entry.path) or minValue)
  end
end

local function RefreshBagAppearance()
  if Tea_BagRelayout then
    Tea_BagRelayout()
  end
  if Tea_RefreshTrackHighlights then
    Tea_RefreshTrackHighlights()
  end
end

local function BuildOneBagPanel(content)
  local header = CreatePanelHeader(content, "Bags")

  local enable = CreateCheckbox(content, "Enable", { "modules", "oneBag" }, header, -8, {
    onChange = RefreshBagAppearance,
  })

  local greyCheckbox = CreateCheckbox(content, "Grey out junk item icons", { "oneBag", "greyJunkIcons" }, enable, -ROW_SPACING, {
    onChange = RefreshBagAppearance,
  })

  local columnsHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  columnsHint:SetPoint("TOPLEFT", greyCheckbox, "BOTTOMLEFT", 0, -14)
  columnsHint:SetText("Items per row")

  local columnsSlider = CreateSlider(
    content,
    "Columns",
    { "oneBag", "columns" },
    4,
    12,
    1,
    columnsHint,
    -8,
    RefreshBagAppearance
  )

  local slotHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  slotHint:SetPoint("TOPLEFT", columnsSlider, "BOTTOMLEFT", 0, -18)
  slotHint:SetText("Slot size")

  local slotSlider = CreateSlider(
    content,
    "Slot size",
    { "oneBag", "slotSize" },
    28,
    48,
    1,
    slotHint,
    -8,
    RefreshBagAppearance
  )

  local paddingHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  paddingHint:SetPoint("TOPLEFT", slotSlider, "BOTTOMLEFT", 0, -18)
  paddingHint:SetText("Slot padding")

  local paddingSlider = CreateSlider(
    content,
    "Padding",
    { "oneBag", "slotPadding" },
    0,
    8,
    1,
    paddingHint,
    -8,
    RefreshBagAppearance
  )

  return paddingSlider
end

local function SetNavButtonSelected(button, selected)
  if selected then
    button.bg:SetVertexColor(SELECTED_NAV_COLOR[1], SELECTED_NAV_COLOR[2], SELECTED_NAV_COLOR[3], SELECTED_NAV_COLOR[4])
    button.text:SetFontObject(GameFontNormal)
    button.text:SetTextColor(0.85, 0.98, 0.8)
  else
    button.bg:SetVertexColor(DEFAULT_NAV_COLOR[1], DEFAULT_NAV_COLOR[2], DEFAULT_NAV_COLOR[3], DEFAULT_NAV_COLOR[4])
    button.text:SetFontObject(GameFontHighlightSmall)
    button.text:SetTextColor(0.9, 0.9, 0.9)
  end
end

local function UpdateBarsPanelPreview()
  local barsIndex = FindSectionIndex("teaBars")
  local showPreview = frame and frame:IsShown() and activeSection == barsIndex
  if Tea_SetResourceBarPreview then
    Tea_SetResourceBarPreview(showPreview)
  end
  if Tea_SetCastBarPreview then
    Tea_SetCastBarPreview(showPreview)
  end
end

local function RefreshActivePanel()
  local panel = contentPanels[activeSection]
  if not panel then
    return
  end

  if SECTIONS[activeSection].id == "tracking" then
    RefreshTrackingPanel()
    return
  end

  SyncScrollSize(panel)
  UpdateScrollHeight(panel, panel.scrollBottom)
end

local function SelectSection(index)
  if not contentPanels[index] then
    return
  end

  activeSection = index

  for i, panel in ipairs(contentPanels) do
    if i == index then
      panel:Show()
    else
      panel:Hide()
    end
  end

  for i, button in ipairs(navButtons) do
    SetNavButtonSelected(button, i == index)
  end

  RefreshActivePanel()
  UpdateBarsPanelPreview()
end

local function CreateNavButton(parent, section, index)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(SIDEBAR_WIDTH - 8, NAV_BUTTON_HEIGHT)

  if index == 1 then
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -8)
  else
    button:SetPoint("TOPLEFT", navButtons[index - 1], "BOTTOMLEFT", 0, -NAV_BUTTON_SPACING)
  end

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  button.bg = bg

  local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", 8, 0)
  text:SetText(section.label)
  button.text = text

  button:SetScript("OnClick", function()
    SelectSection(index)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
  end)

  SetNavButtonSelected(button, index == activeSection)
  return button
end

local function BuildSectionPanel(section, index)
  local panel = CreateFrame("Frame", nil, contentHost)
  panel:SetAllPoints()
  panel:Hide()

  local panelBg = panel:CreateTexture(nil, "BACKGROUND")
  panelBg:SetAllPoints()
  if panelBg.SetColorTexture then
    panelBg:SetColorTexture(0.05, 0.05, 0.05, 1)
  else
    panelBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    panelBg:SetVertexColor(0.05, 0.05, 0.05, 1)
  end

  local content = CreateScrollArea(panel)
  local bottom

  if section.id == "tracking" then
    bottom = BuildTrackingPanel(content)
  elseif section.id == "oneBag" then
    bottom = BuildOneBagPanel(content)
  elseif section.id == "teaBars" then
    bottom = BuildTeaBarsPanel(content)
  else
    bottom = BuildOptionsPanel(content, section)
  end

  panel.scrollBottom = bottom
  UpdateScrollHeight(panel, bottom)
  contentPanels[index] = panel
end

local function RefreshPanel()
  RefreshCheckboxes()
  RefreshOneBagSliders()
  RefreshBarSliders()
  RefreshActivePanel()
  UpdateBarsPanelPreview()
end

local function BuildPanel()
  local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "TeaOptionsFrame", UIParent, backdropTemplate)
  frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", RefreshPanel)
  frame:SetScript("OnHide", function()
    if Tea_SetResourceBarPreview then
      Tea_SetResourceBarPreview(false)
    end
    if Tea_SetCastBarPreview then
      Tea_SetCastBarPreview(false)
    end
  end)
  frame:Hide()

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
  else
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.05, 0.05, 0.05, 1)
  end

  tinsert(UISpecialFrames, frame:GetName())

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  title:SetPoint("TOPLEFT", TITLE_SIDE_OFFSET, TITLE_TOP)
  title:SetText("tea")
  title:SetTextColor(0.72, 0.95, 0.68)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetSize(CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)
  close:SetPoint("TOPRIGHT", -6, -10)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("BOTTOM", 0, 14)
  hint:SetText("Drag to move. Press Esc to close.")

  sidebar = CreateFrame("Frame", nil, frame)
  sidebar:SetPoint("TOPLEFT", FRAME_PADDING, CONTENT_TOP)
  sidebar:SetPoint("BOTTOMLEFT", FRAME_PADDING, 36)
  sidebar:SetWidth(SIDEBAR_WIDTH)

  local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
  sidebarBg:SetAllPoints()
  if sidebarBg.SetColorTexture then
    sidebarBg:SetColorTexture(0.08, 0.08, 0.08, 1)
  else
    sidebarBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    sidebarBg:SetVertexColor(0.08, 0.08, 0.08, 1)
  end

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
  divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
  divider:SetWidth(1)
  if divider.SetColorTexture then
    divider:SetColorTexture(0.25, 0.25, 0.25, 1)
  else
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.25, 0.25, 0.25, 1)
  end

  contentHost = CreateFrame("Frame", nil, frame)
  contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", SIDEBAR_GAP, 0)
  contentHost:SetPoint("BOTTOMRIGHT", -FRAME_PADDING, 36)

  for index, section in ipairs(SECTIONS) do
    navButtons[index] = CreateNavButton(sidebar, section, index)
    BuildSectionPanel(section, index)
  end

  SelectSection(1)
end

function Tea_RefreshOptionsCheckboxes()
  RefreshCheckboxes()
end

function Tea_ToggleOptions()
  if not frame then
    BuildPanel()
  end

  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

function Tea_ShowOptions()
  if not frame then
    BuildPanel()
  end
  frame:Show()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    BuildPanel()
  end
end)
