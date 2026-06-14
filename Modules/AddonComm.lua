local ADDON_NAME = ...

local PREFIX = "Tea"
local LINE_R, LINE_G, LINE_B = 0.72, 0.95, 0.68
local BROADCAST_INTERVAL = 30

local teaUsers = {}
local whisperedTo = {}
local lastGroupBroadcast = 0
local lastGuildBroadcast = 0

local function RegisterPrefix()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    return
  end

  if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(PREFIX)
  end
end

local function SendVersionMessage(distribution, target)
  local version = Tea_GetAddonVersion and Tea_GetAddonVersion() or "?"
  local message = "V:" .. version

  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    local ok = C_ChatInfo.SendAddonMessage(PREFIX, message, distribution, target)
    return ok ~= false
  end

  if SendAddonMessage then
    SendAddonMessage(PREFIX, message, distribution, target)
    return true
  end

  return false
end

local function RememberTeaUser(name, version)
  if not name or name == "" or not version or version == "" then
    return
  end

  if UnitName("player") == name then
    return
  end

  teaUsers[name] = version
end

local function WhisperVersionTo(sender)
  if whisperedTo[sender] then
    return
  end

  whisperedTo[sender] = true
  SendVersionMessage("WHISPER", sender)
end

local function HandleAddonMessage(prefix, message, channel, sender)
  if prefix ~= PREFIX or not sender then
    return
  end

  local version = message and message:match("^V:(.+)$")
  if not version then
    return
  end

  RememberTeaUser(sender, version)

  if channel ~= "WHISPER" then
    WhisperVersionTo(sender)
  end
end

local function BroadcastToGroup(force)
  local now = GetTime()
  if not force and now - lastGroupBroadcast < BROADCAST_INTERVAL then
    return
  end

  if IsInGroup and IsInGroup() then
    if IsInRaid and IsInRaid() then
      SendVersionMessage("RAID")
    else
      SendVersionMessage("PARTY")
    end
    lastGroupBroadcast = now
  end
end

local function BroadcastToGuild(force)
  if not (IsInGuild and IsInGuild()) then
    return
  end

  local now = GetTime()
  if not force and now - lastGuildBroadcast < BROADCAST_INTERVAL then
    return
  end

  SendVersionMessage("GUILD")
  lastGuildBroadcast = now
end

local function BroadcastPresence(force)
  BroadcastToGroup(force)
  BroadcastToGuild(force)
end

local function GetTeaUserVersion(unit)
  if not unit or not UnitIsPlayer(unit) or not UnitName then
    return
  end

  local name = UnitName(unit)
  if not name then
    return
  end

  return teaUsers[name]
end

local function AddPlayerTeaLine(tooltip)
  if not tooltip or not tooltip.GetUnit then
    return
  end

  local _, unit = tooltip:GetUnit()
  local version = GetTeaUserVersion(unit)
  if not version then
    return
  end

  tooltip:AddLine("tea " .. version, LINE_R, LINE_G, LINE_B)
end

local function SafeAddPlayerTeaLine(tooltip)
  if Tea_Util and Tea_Util.SafeCall then
    Tea_Util.SafeCall(AddPlayerTeaLine, tooltip)
  else
    AddPlayerTeaLine(tooltip)
  end
end

local function HookUnitTooltip(tooltip)
  if not tooltip or tooltip.teaUnitHooked then
    return
  end

  tooltip.teaUnitHooked = true
  tooltip:HookScript("OnTooltipSetUnit", SafeAddPlayerTeaLine)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    RegisterPrefix()
    HookUnitTooltip(GameTooltip)
    return
  end

  if event == "PLAYER_LOGIN" then
    if Tea_Util and Tea_Util.After then
      Tea_Util.After(2, function()
        BroadcastPresence(true)
      end)
    else
      BroadcastPresence(true)
    end
    return
  end

  if event == "GROUP_ROSTER_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
    BroadcastPresence(false)
    return
  end

  if event == "CHAT_MSG_ADDON" then
    HandleAddonMessage(arg1, arg2, arg3, arg4)
  end
end)
