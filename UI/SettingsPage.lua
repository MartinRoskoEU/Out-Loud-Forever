local AddonName, OutLoud = ...

local SettingsPage = {}
OutLoud.SettingsPage = SettingsPage

function SettingsPage:Initialize()
    if self.Initialized then
        return
    end

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Out Loud")
    Settings.RegisterAddOnCategory(category)

    self.Panel = panel
    self.Category = category

    self:CreateLayout()

    self.Initialized = true
end

function SettingsPage:CreateLayout()
    
    local title = self.Panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(AddonName)

    local divider = self.Panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 7, -50)
    divider:SetAtlas("Options_HorizontalDivider", true)

end