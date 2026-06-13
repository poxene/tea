local ADDON_NAME = ...

local PANEL_WIDTH = 320
local PANEL_HEIGHT = 340
local FRAME_PADDING = 20
local TAB_TOP = -40
local CONTENT_TOP = -68
local ROW_SPACING = 4
local MAX_TRACK_ROWS = 10

local TABS = {
  {
    id = "modules",
    label = "Modules",
    options = {
      { label = "Tooltip extras", path = { "modules", "tooltipExtras" } },
      { label = "Auto-sell grey at vendors", path = { "modules", "vendorTrash" } },
      { label = "Repair warning at vendors", path = { "modules", "repairWarning" } },
      {
        label = "Item tracking",
        path = { "modules", "itemTrack" },
        onChange = function()
          if Tea_RefreshTrackHighlights then
            Tea_RefreshTrackHighlights()
          end
        end,
      },
    },
  },
  {
    id = "tooltip",
    label = "Tooltip",
    options = {
      { label = "Show vendor price", path = { "tooltip", "showVendorPrice" } },
      { label = "Show item ID", path = { "tooltip", "showItemId" } },
      { label = "Only while holding Shift", path = { "tooltip", "requireShift" } },
    },
  },
  {
    id = "tracking",
    label = "Track",
  },
  {
    id = "oneBag",
    label = "teaBag",
  },
}

local frame
local tabContainer
local tabButtons = {}
local tabPanels = {}
local checkboxes = {}
local trackListFrame
local trackEditBox
local oneBagSliders = {}
local activeTab = 1

local function GetOptionValue(path)
  local value = Tea_GetDB()
  for i = 1, #path do
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

local function GetNumericOptionValue(path)
  local value = Tea_GetDB()
  for i = 1, #path do
    value = value[path[i]]
  end
  return value
end

local function SetNumericOptionValue(path, value)
  local db = Tea_GetDB()
  local node = db
  for i = 1, #path - 1 do
    node = node[path[i]]
  end
  node[path[#path]] = value
end

local function RefreshCheckboxes()
  for _, entry in ipairs(checkboxes) do
    entry.button:SetChecked(GetOptionValue(entry.path))
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
    SetOptionValue(path, self:GetChecked())
    if option and option.onChange then
      option.onChange()
    end
  end)

  table.insert(checkboxes, { button = check, path = path })
  return check
end

local function BuildOptionsPanel(panel, options)
  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 8, -12)
  header:SetText(panel.tabTitle or "")

  local anchor = header
  for optionIndex, option in ipairs(options) do
    local offset = optionIndex == 1 and -8 or -ROW_SPACING
    anchor = CreateCheckbox(panel, option.label, option.path, anchor, offset, option)
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
  end
end

local function RefreshTrackList()
  if not trackListFrame then
    return
  end

  for _, child in ipairs({ trackListFrame:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end

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
    row:SetSize(trackListFrame:GetWidth(), 18)
    row:SetPoint("TOPLEFT", 0, y)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(trackListFrame:GetWidth() - 44)
    label:SetJustifyH("LEFT")

    local name = Tea_Util.GetItemInfo(itemID)
    if name then
      label:SetText(string.format("%s (%d)", name, itemID))
    else
      label:SetText(tostring(itemID))
      Tea_Util.GetItemInfo(itemID)
    end

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(36, 16)
    remove:SetPoint("RIGHT", 0, 0)
    remove:SetText("X")
    remove:SetScript("OnClick", function()
      Tea_UntrackItem(itemID)
    end)

    y = y - 18
  end

  if #ids > MAX_TRACK_ROWS then
    local more = trackListFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    more:SetPoint("TOPLEFT", 0, y)
    more:SetText(string.format("+%d more (use /tea track list)", #ids - MAX_TRACK_ROWS))
  end
end

local function BuildTrackingPanel(panel)
  panel.tabTitle = "Tracked Items"

  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 8, -12)
  header:SetText("Tracked Items")

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  hint:SetText("Item IDs show on tooltips when enabled.")

  trackEditBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  trackEditBox:SetSize(140, 20)
  trackEditBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
  trackEditBox:SetAutoFocus(false)
  trackEditBox:SetNumeric(true)
  trackEditBox:SetMaxLetters(10)

  local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  addButton:SetSize(52, 20)
  addButton:SetPoint("LEFT", trackEditBox, "RIGHT", 6, 0)
  addButton:SetText("Add")
  addButton:SetScript("OnClick", AddTrackedItemFromInput)

  trackEditBox:SetScript("OnEnterPressed", function()
    AddTrackedItemFromInput()
  end)

  trackListFrame = CreateFrame("Frame", nil, panel)
  trackListFrame:SetPoint("TOPLEFT", trackEditBox, "BOTTOMLEFT", 0, -10)
  trackListFrame:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
  trackListFrame:SetHeight(180)
end

function Tea_RefreshTrackOptions()
  RefreshTrackList()
end

local function CreateSlider(panel, label, path, minValue, maxValue, step, anchor, yOffset, onChange)
  local slider = CreateFrame("Slider", "TeaOptionsSlider" .. #oneBagSliders + 1, panel, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
  slider:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(GetNumericOptionValue(path))

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

local function RefreshOneBagPanel()
  for _, entry in ipairs(oneBagSliders) do
    entry.slider:SetValue(GetNumericOptionValue(entry.path))
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

local function BuildOneBagPanel(panel)
  panel.tabTitle = "teaBag"

  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 8, -12)
  header:SetText("teaBag")

  local enable = CreateCheckbox(panel, "Enable one bag", { "modules", "oneBag" }, header, -12, {
    onChange = RefreshBagAppearance,
  })

  local columnsHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  columnsHint:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -14)
  columnsHint:SetText("Items per row")

  local columnsSlider = CreateSlider(
    panel,
    "Columns",
    { "oneBag", "columns" },
    4,
    12,
    1,
    columnsHint,
    -8,
    RefreshBagAppearance
  )

  local slotHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  slotHint:SetPoint("TOPLEFT", columnsSlider, "BOTTOMLEFT", 0, -18)
  slotHint:SetText("Slot size")

  local slotSlider = CreateSlider(
    panel,
    "Slot size",
    { "oneBag", "slotSize" },
    28,
    48,
    1,
    slotHint,
    -8,
    RefreshBagAppearance
  )

  local paddingHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  paddingHint:SetPoint("TOPLEFT", slotSlider, "BOTTOMLEFT", 0, -18)
  paddingHint:SetText("Slot padding")

  CreateSlider(
    panel,
    "Padding",
    { "oneBag", "slotPadding" },
    0,
    8,
    1,
    paddingHint,
    -8,
    RefreshBagAppearance
  )
end

local TAB_PANEL_LEVEL = 5
local TAB_BAR_LEVEL = 20
local SELECTED_TAB_LEVEL_OFFSET = 20

local function UpdateTabLevels(selectedIndex)
  if not tabContainer then
    return
  end

  local base = tabContainer:GetFrameLevel()
  for i, tabButton in ipairs(tabButtons) do
    tabButton:SetFrameLevel(base + (i == selectedIndex and SELECTED_TAB_LEVEL_OFFSET or i))
  end
end

local function SelectTab(index)
  activeTab = index

  for i, tabButton in ipairs(tabButtons) do
    if i == index then
      PanelTemplates_SelectTab(tabButton)
      tabPanels[i]:Show()
    else
      PanelTemplates_DeselectTab(tabButton)
      tabPanels[i]:Hide()
    end
  end

  UpdateTabLevels(index)

  if TABS[index].id == "tracking" then
    RefreshTrackList()
  elseif TABS[index].id == "oneBag" then
    RefreshOneBagPanel()
  end
end

local TAB_PADDING = 8
local TAB_OVERLAP = 15

local function GetTabAbsoluteWidth()
  local available = PANEL_WIDTH - (FRAME_PADDING * 2)
  return math.floor((available + (#TABS - 1) * TAB_OVERLAP) / #TABS)
end

local function ResizeTab(tabButton)
  PanelTemplates_TabResize(tabButton, TAB_PADDING, GetTabAbsoluteWidth())
  local text = tabButton.Text or _G[tabButton:GetName() .. "Text"]
  if text then
    text:SetFontObject(GameFontHighlightSmall)
  end
end

local function CreateTabBar()
  tabContainer = CreateFrame("Frame", "TeaOptionsTabContainer", frame)
  tabContainer:SetPoint("TOPLEFT", FRAME_PADDING, TAB_TOP)
  tabContainer:SetPoint("TOPRIGHT", -FRAME_PADDING, TAB_TOP)
  tabContainer:SetHeight(24)
  tabContainer:SetFrameLevel(TAB_BAR_LEVEL)

  for index, tab in ipairs(TABS) do
    local tabButton = CreateFrame("Button", "TeaOptionsTab" .. index, tabContainer, "PanelTopTabButtonTemplate")
    tabButton:SetID(index)
    tabButton:SetText(tab.label)

    if index == 1 then
      tabButton:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 0, 0)
    else
      tabButton:SetPoint("LEFT", tabButtons[index - 1], "RIGHT", -TAB_OVERLAP, 0)
    end

    tabButton:SetScript("OnShow", ResizeTab)
    ResizeTab(tabButton)

    tabButton:SetScript("OnClick", function(self)
      SelectTab(self:GetID())
      PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    end)

    tabButtons[index] = tabButton
  end
end

local function RefreshPanel()
  RefreshCheckboxes()
  if TABS[activeTab].id == "tracking" then
    RefreshTrackList()
  elseif TABS[activeTab].id == "oneBag" then
    RefreshOneBagPanel()
  end
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

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText("tea")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("BOTTOM", 0, 14)
  hint:SetText("Drag to move. Press Esc to close.")

  CreateTabBar()

  for index, tab in ipairs(TABS) do
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", FRAME_PADDING, CONTENT_TOP)
    panel:SetPoint("BOTTOMRIGHT", -FRAME_PADDING, 36)
    panel:SetFrameLevel(TAB_PANEL_LEVEL)
    panel:Hide()

    local panelBg = panel:CreateTexture(nil, "BACKGROUND")
    panelBg:SetAllPoints()
    if panelBg.SetColorTexture then
      panelBg:SetColorTexture(0.05, 0.05, 0.05, 1)
    else
      panelBg:SetTexture("Interface\\Buttons\\WHITE8x8")
      panelBg:SetVertexColor(0.05, 0.05, 0.05, 1)
    end

    tabPanels[index] = panel

    if tab.options then
      panel.tabTitle = tab.label
      BuildOptionsPanel(panel, tab.options)
    elseif tab.id == "tracking" then
      BuildTrackingPanel(panel)
    elseif tab.id == "oneBag" then
      BuildOneBagPanel(panel)
    end
  end

  SelectTab(1)
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
