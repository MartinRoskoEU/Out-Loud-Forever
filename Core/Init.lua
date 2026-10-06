local AddonName, OutLoud = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event ~= "ADDON_LOADED" or loadedAddonName ~= AddonName then
        return
    end

    OutLoud.Database:Initialize()
    OutLoud.UI.SettingsPage:Initialize()

    OutLoud.Loaded = true
end)