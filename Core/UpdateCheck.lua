local ADDON_NAME = "tea"

local RELEASES_URL = "https://github.com/poxene/tea/releases"

function Tea_GetAddonVersion()
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
  end
  return GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
end

function Tea_PrintVersionMessage()
  local version = Tea_GetAddonVersion()
  Tea_Print(
    string.format(
      "Version %s — check %s for the latest release. Type |cff66ccff/tea|r for options.",
      version,
      RELEASES_URL
    )
  )
end
