local ADDON_CORE   = "AI_VoiceOver"
local ADDON_LOADER = "AI_VoiceOver_112"
local ADDON_LIBS   = "AI_VoiceOver_112_Libs"

-- Load this file in 1.12 only, it doesn't have the 4th return from GetBuildInfo, but just in case someone overwrote it - let's hope they made it return 11200
local _, _, _, version = GetBuildInfo()
if version and version ~= 11200 then
    DisableAddOn(ADDON_LOADER)
    return
end

-- The rest of this file is the same for all loaders
StaticPopupDialogs["VOICEOVER_LOADER_ERROR"] =
{
    text = format("VoiceOver|n|n%s %%s", (GetAddOnInfo(ADDON_LOADER))),
    button1 = OKAY,
    timeout = 0,
    whileDead = 1,
}

local function Load(addon)
    if IsAddOnLoaded(addon) then
        return
    end

    local _, _, _, enabled, loadable, reason = GetAddOnInfo(addon)

    -- We forcibly enable disabled and out-of-date addons, so we can ignore these reasons
    if reason == "DISABLED" or reason == "INTERFACE_VERSION" then
        reason = nil
        loadable = true
    end

    if reason == "MISSING" then
        StaticPopup_Show("VOICEOVER_LOADER_ERROR", format([[could not find the addon "%s".|nThis addon is required to run VoiceOver on this version of WoW.|nPlease verify that you installed VoiceOver correctly.]], addon))
        return
    end

    if reason then
        StaticPopup_Show("VOICEOVER_LOADER_ERROR", format([[failed to load the addon "%s". The reason given was "%s".|nThis addon is required to run VoiceOver on this version of WoW.|nPlease verify that you installed VoiceOver correctly.]], addon, getglobal("ADDON_" .. reason)))
        return
    end

    if not loadable then
        StaticPopup_Show("VOICEOVER_LOADER_ERROR", format([[failed to load the addon "%s" for an unknown reason.|nThis addon is required to run VoiceOver on this version of WoW.|nPlease verify that you installed VoiceOver correctly.]], addon))
        return
    end

    if not IsAddOnLoadOnDemand(addon) then
        StaticPopup_Show("VOICEOVER_LOADER_ERROR", format([[failed to load the addon "%s" because it's not marked as LoadOnDemand.|nYou may have forgotten to install or update one of the addons included in the package.|nPlease verify that you installed VoiceOver correctly.]], addon))
        return
    end

    if not enabled then
        EnableAddOn(addon)
    end

    local oldLoadOutOfDateAddons = GetCVar("checkAddonVersion")
    SetCVar("checkAddonVersion", 0)
    local loaded = LoadAddOn(addon)
    SetCVar("checkAddonVersion", oldLoadOutOfDateAddons)

    return loaded
end

if Load(ADDON_LIBS) then
    Load(ADDON_CORE)
end
