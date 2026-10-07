-- Run from the addon root with Lua 5.1: lua Tests/VoiceSelection.lua
-- Keep mock APIs local so the editor cannot infer game API types from them.
local environment = setmetatable({}, { __index = _G })
environment._G = environment

-- Standalone Lua supplies these APIs; the WoW editor configuration omits them.
local LoadFile = assert(rawget(_G, "loadfile"), "Run tests with standalone Lua 5.1")
local FileIO = assert(rawget(_G, "io"), "Run tests with standalone Lua 5.1")

local function Equal(actual, expected, message)
    assert(actual == expected, (message or "Mismatch")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Frame(parent)
    local frame = { scripts = {}, points = {}, parent = parent, shown = true,
        heightValue = 0, widthValue = 800, scrollValue = 0, minimum = 0, maximum = 0 }
    local methods = {
        SetScript = function(self, event, callback) self.scripts[event] = callback end,
        GetScript = function(self, event) return self.scripts[event] end,
        SetText = function(self, text) self.textValue = text end,
        SetWidth = function(self, width) self.widthValue = width end,
        GetWidth = function(self) return self.widthValue end,
        SetHeight = function(self, height)
            local changed = self.heightValue ~= height
            self.heightValue = height
            if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self) end
        end,
        GetHeight = function(self) return self.heightValue end,
        SetSize = function(self, width, height) self.widthValue, self.heightValue = width, height end,
        SetPoint = function(self, point, relative, relativePoint, x, y)
            if type(relative) == "number" then
                x, y, relativePoint, relative = relative, relativePoint, point, rawget(self, "parent")
            elseif not relative then
                relative, relativePoint = rawget(self, "parent"), point
            end
            self.points[point] = { relative = relative, point = relativePoint, x = x or 0, y = y or 0 }
        end,
        ClearAllPoints = function(self) self.points = {} end,
        GetTop = function(self)
            local anchor = self.points.TOPLEFT or self.points.TOPRIGHT or self.points.TOP
            if not anchor then return 600 end
            local top = 600
            if anchor.relative then
                top = anchor.point:find("BOTTOM") and anchor.relative:GetBottom() or anchor.relative:GetTop()
            end
            return top + anchor.y
        end,
        GetBottom = function(self) return self:GetTop() - self:GetHeight() end,
        Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
        Hide = function(self) self.shown = false end,
        IsShown = function(self) return self.shown end,
        SetScrollChild = function(self, child) self.scrollChild = child end,
        GetVerticalScroll = function(self) return self.scrollValue end,
        SetVerticalScroll = function(self, value) self.scrollValue = value end,
        SetMinMaxValues = function(self, minimum, maximum) self.minimum, self.maximum = minimum, maximum end,
        GetMinMaxValues = function(self) return self.minimum, self.maximum end,
        GetValue = function(self) return self.scrollValue end,
        SetValue = function(self, value)
            self.scrollValue = math.max(self.minimum, math.min(self.maximum, value))
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, self.scrollValue) end
        end,
        CreateFontString = function(self)
            local font = Frame(self)
            font:SetHeight(32) -- Simulated text height, not proof of real font wrapping.
            return font
        end,
        CreateTexture = function(self) return Frame(self) end,
        SetupMenu = function(self, callback) self.menu = callback end,
    }
    setmetatable(frame, { __index = function(self, key)
        if key == "Title" or key == "Label" or key == "Dropdown" or key == "text" or key == "ScrollBar" then
            local child = Frame(self)
            rawset(self, key, child)
            return child
        end
        return methods[key] or function() end
    end })
    return frame
end

local frames = {}
function environment.CreateFrame(kind, _name, parent, template)
    local frame = Frame(parent)
    if template == "SettingsListSectionHeaderTemplate" then frame:SetHeight(20) end
    if template == "UIRadioButtonTemplate" then frame:SetHeight(16) end
    if kind == "ScrollFrame" then
        frame:SetSize(760, 420)
        -- Simulate only the template's range/value connection needed by these checks.
        frame.ScrollBar:SetScript("OnValueChanged", function(_, value) frame:SetVerticalScroll(value) end)
        frame:SetScript("OnScrollRangeChanged", function(_, _xrange, yrange)
            local bar = frame.ScrollBar
            bar:SetMinMaxValues(0, math.floor(yrange))
            bar:SetValue(bar:GetValue())
            if yrange > 0 then bar:Show() else bar:Hide() end
        end)
    end
    table.insert(frames, frame)
    return frame
end

local sex, exists = 2, true
function environment.UnitSex() return sex end
function environment.UnitExists() return exists end
function environment.UnitName() return "Test NPC" end
environment.Settings = {
    RegisterCanvasLayoutCategory = function(_panel, _name) return {} end,
    RegisterAddOnCategory = function(_category) end,
}
environment.C_VoiceChat = { GetTtsVoices = function()
    local voices = {}
    for id = 0, 60 do
        table.insert(voices, { voiceID = id, name = "Voice " .. id })
    end
    return voices
end }

local addon = {}
local function Load(path)
    local chunk = assert(LoadFile(path))
    setfenv(chunk, environment)
    chunk("OutLoud", addon)
end

-- Load the real files in their declared order and exercise ADDON_LOADED.
for line in FileIO.lines("OutLoud.toc") do
    if line:match("%.lua$") then
        Load((line:gsub("\\", "/")))
    end
end

local selection = addon.VoiceSelection
local exportedMappings = addon.VoiceMappings
local exportedFamilies = {}
local exportedCount = 0
for _, family in pairs(exportedMappings.Families) do
    if not exportedFamilies[family] then
        exportedFamilies[family] = true
        exportedCount = exportedCount + 1
    end
end
Equal(#selection:GetFamilies(), exportedCount, "Generated family catalog")
for fileDataID, family in pairs(exportedMappings.Models) do
    Equal(type(family), "string", "Generated model maps directly to a family")
    assert(exportedFamilies[family], "Model family is missing from the catalog")
    Equal(selection:GetFamily(fileDataID), family, "Generated model lookup")
end

local savedVariables = {
    voices = {
        [5] = { [2] = 40, [3] = 41 },
        UNDEAD = { [2] = 50 },
        SKYBORNE = { [2] = 10, [3] = 11 },
        HUMAN = { [2] = 0, [3] = 13 },
        [999] = { [2] = 60 },
    },
    readingMode = "split",
}
environment.OutLoudDB = savedVariables
local initFrame = frames[#frames]
initFrame.scripts.OnEvent(initFrame, "ADDON_LOADED", "OtherAddon")
Equal(addon.Loaded, false, "Ignore unrelated addon event")
initFrame.scripts.OnEvent(initFrame, "ADDON_LOADED", "OutLoud")
Equal(addon.Loaded, true, "TOC initialization")
assert(addon.UI.QuestIntegration.LoadFrame, "Quest integration initializes and waits for Blizzard UI")
local settingsPage = addon.UI.SettingsPage
Equal(settingsPage.ScrollFrame.parent, settingsPage.Panel, "Fixed page owns viewport")
Equal(settingsPage.Content.parent, settingsPage.ScrollFrame, "Viewport owns scroll child")
Equal(settingsPage.ScrollFrame.scrollChild, settingsPage.Content, "Native scroll child set")
Equal(settingsPage.VoiceRows[1].Frame.parent, settingsPage.Content, "Voice rows inside content")
Equal(settingsPage.FullTextButton.parent, settingsPage.Content, "Reading controls inside content")
Equal(settingsPage.ScrollFrame.points.BOTTOMRIGHT.x, -32, "Scrollbar gutter reserved")
assert(settingsPage.Content:GetHeight() > settingsPage.ScrollFrame:GetHeight(), "Dynamic rows exceed viewport")
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 0, "Initial scroll at top")
Equal(addon.Database:GetVoice("UNDEAD", 2), 50, "Keep newer assignment")
Equal(addon.Database:GetVoice("UNDEAD", 3), 41, "Migrate legacy female")
Equal(savedVariables.voices[5][2], 40, "Keep numeric backup")
Equal(savedVariables.voices[999][2], 60, "Keep unknown legacy keys")
Equal(addon.Database:GetReadingMode(), "split", "Keep reading settings")
Equal(savedVariables.voiceSettingsVersion, 2, "Migration marker")

local modelID = 959310
local model = { GetModelFileID = function() return modelID end }
local function Resolve(id, unitSex, family, gender, voice)
    modelID, sex = id, unitSex
    local voiceID, info = selection:Resolve("questnpc", model)
    Equal(info.name, "Test NPC", "NPC name")
    Equal(info.modelFileID, id, "Model ID")
    Equal(info.family, family, "Family")
    Equal(info.sex, unitSex, "Runtime sex")
    Equal(info.gender, gender, "Gender")
    Equal(voiceID, voice, "Configured voice")
    Equal(info.reason, nil, "Successful lookup")
end

-- Verify Options and runtime selection against the actual generated export first.
Equal(#addon.UI.SettingsPage.VoiceRows, exportedCount, "Generated Options row count")
local exportedSkyborneRows = 0
for _, row in ipairs(addon.UI.SettingsPage.VoiceRows) do
    if row.RaceLabel.textValue == "Skyborne" then
        exportedSkyborneRows = exportedSkyborneRows + 1
        assert(row.MaleComboBox and row.FemaleComboBox, "Both generated Skyborne selectors")
    end
end
Equal(exportedSkyborneRows, 1, "Generated export has one Skyborne row")
Resolve(959310, 2, "UNDEAD", "MALE", 50)
Resolve(997378, 3, "UNDEAD", "FEMALE", 41)
Resolve(7478487, 2, "SKYBORNE", "MALE", 10)
Resolve(7478494, 3, "SKYBORNE", "FEMALE", 11)
Resolve(1000764, 2, "HUMAN", "MALE", 0)
Resolve(1011653, 3, "HUMAN", "FEMALE", 13)

-- Replace the export completely: no Races, Genders, or GetRaces helper.
addon.VoiceMappings = {
    Families = {
        HUMAN = "HUMAN", UNDEAD = "UNDEAD", SKYBORNE = "SKYBORNE",
        SKYBORNE_ALIAS = "SKYBORNE", NIGHT_ELF = "NIGHT_ELF",
        FUTURE_FAMILY = "FUTURE_FAMILY",
    },
    Models = {
        [959310] = "UNDEAD", [7478487] = "SKYBORNE",
        [7478494] = "SKYBORNE", [100] = "HUMAN", [101] = "HUMAN",
    },
}
addon.UI.SettingsPage:CreateVoiceRows(addon.UI.SettingsPage.VoicesColumns)

Resolve(959310, 2, "UNDEAD", "MALE", 50)
Resolve(959310, 3, "UNDEAD", "FEMALE", 41)
Resolve(7478487, 2, "SKYBORNE", "MALE", 10)
Resolve(7478494, 3, "SKYBORNE", "FEMALE", 11)
-- Deliberately swap sex on the same Skyborne model IDs.
Resolve(7478487, 3, "SKYBORNE", "FEMALE", 11)
Resolve(7478494, 2, "SKYBORNE", "MALE", 10)
Resolve(100, 2, "HUMAN", "MALE", 0)
Resolve(101, 2, "HUMAN", "MALE", 0)
Resolve(100, 3, "HUMAN", "FEMALE", 13)
Resolve(101, 3, "HUMAN", "FEMALE", 13)

local function Unresolved(id, unitSex, reason)
    modelID, sex = id, unitSex
    local voice, info = selection:Resolve("questnpc", model)
    Equal(voice, nil, "Unresolved voice")
    Equal(info.reason, reason, "Unresolved reason")
    if reason == "unknown-sex" then Equal(info.gender, nil, "No invented gender") end
end
for _, unitSex in ipairs({ 1, 0, 4, "2" }) do
    Unresolved(959310, unitSex, "unknown-sex")
end
Unresolved(959310, nil, "unknown-sex")
Unresolved(999999, 2, "unknown-model")
Unresolved(0, 2, "model-unavailable")
Unresolved(nil, 2, "model-unavailable")
exists = false
Unresolved(959310, 2, "unit-unavailable")
exists = true

local rows = addon.UI.SettingsPage.VoiceRows
Equal(#rows, 5, "One row per unique catalog family, including unmodeled families")
local byName, skyborneCount = {}, 0
for _, row in ipairs(rows) do
    local name = row.RaceLabel.textValue
    byName[name] = row
    if name == "Skyborne" then skyborneCount = skyborneCount + 1 end
end
Equal(skyborneCount, 1, "Only one Skyborne row")
assert(byName["Night Elf"] and byName["Future Family"], "Readable dynamic family names")
local selectors = 0
for _, combo in ipairs({ byName.Skyborne.MaleComboBox, byName.Skyborne.FemaleComboBox }) do
    local entries = {}
    combo.Dropdown.menu(nil, { CreateRadio = function(_, label, get, set, value)
        if value == 20 then entries[1] = { get = get, set = set } end
    end })
    entries[1].set(20)
    Equal(entries[1].get(20), true, "Dropdown read/write callback")
    selectors = selectors + 1
end
Equal(selectors, 2, "Separate Skyborne selectors")
Equal(addon.Database:GetVoice("SKYBORNE", 2), 20, "Male selector saves family")
Equal(addon.Database:GetVoice("SKYBORNE", 3), 20, "Female selector saves family")
Equal(addon.Database:GetVoice("UNDEAD", 2), 50, "Callbacks do not capture another family")

addon.Database:SetVoice("UNDEAD", 3, nil)
addon.Database.Initialized = false
addon.Database:Initialize()
Equal(addon.Database:GetVoice("UNDEAD", 3), nil, "Reload does not resurrect cleared legacy voice")
Unresolved(959310, 3, "voice-not-set")

-- Empty exports still anchor the Reading section safely.
addon.VoiceMappings.Families = {}
local anchor = settingsPage.VoicesColumns
Equal(addon.UI.SettingsPage:CreateVoiceRows(anchor), anchor, "Empty catalog anchor")
Equal(#addon.UI.SettingsPage.VoiceRows, 0, "No rows from model entries")

-- Exercise scroll layout against rebuilt real controls, using simulated geometry.
local emptyHeight = settingsPage.Content:GetHeight()
local function RebuildFamilies(count)
    local families = {}
    for index = 1, count do families[index] = "SCROLL_FAMILY_" .. index end
    addon.VoiceMappings.Families = families
    settingsPage:CreateVoiceRows(settingsPage.VoicesColumns)
end
RebuildFamilies(30)
Equal(settingsPage.Content:GetHeight(), emptyHeight + 30 * 36, "Every family adds its row height and gap")
local minimum, maximum = settingsPage.ScrollBar:GetMinMaxValues()
Equal(minimum, 0, "Range begins at zero")
Equal(maximum, settingsPage.Content:GetHeight() - settingsPage.ScrollFrame:GetHeight(), "Range follows content")
Equal(settingsPage.ScrollBar:IsShown(), true, "Overflow shows native scrollbar")
local wheel = settingsPage.ScrollFrame.scripts.OnMouseWheel
wheel(settingsPage.ScrollFrame, -1)
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 36, "Wheel down moves down")
wheel(settingsPage.ScrollFrame, 1)
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 0, "Wheel up moves up")
wheel(settingsPage.ScrollFrame, -10000)
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), maximum, "Clamp at bottom")
wheel(settingsPage.ScrollFrame, 10000)
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 0, "Clamp at top")
settingsPage:SetScrollPosition(72)
local oldRows = settingsPage.VoiceRows
RebuildFamilies(31)
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 72, "Preserve valid offset on rebuild")
Equal(oldRows[1].Frame:IsShown(), false, "Replaced controls hidden")
Equal(next(oldRows[1].Frame.points), nil, "Old controls detached from layout")
settingsPage.ScrollFrame:Hide()
settingsPage.ScrollFrame:Show()
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 72, "Reopening keeps session position")
settingsPage.FullTextButton.scripts.OnClick()
Equal(addon.Database:GetReadingMode(), "full", "Reading selector works while scrolled")
settingsPage.SplitTextButton.scripts.OnClick()
Equal(addon.Database:GetReadingMode(), "split", "Split selector works while scrolled")
settingsPage:SetScrollPosition(10000)
RebuildFamilies(0)
Equal(settingsPage.Content:GetHeight(), emptyHeight, "Shorter rebuild updates content height")
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 0, "Shorter content clamps old position")
Equal(select(2, settingsPage.ScrollBar:GetMinMaxValues()), 0, "No negative range when content fits")
Equal(settingsPage.ScrollBar:IsShown(), false, "Scrollbar hidden when content fits")
RebuildFamilies(30)
settingsPage:SetScrollPosition(10000)
settingsPage.ScrollFrame:SetHeight(settingsPage.Content:GetHeight() + 100)
Equal(settingsPage.ScrollFrame:GetVerticalScroll(), 0, "Viewport resize clamps position")
Equal(settingsPage.ScrollBar:IsShown(), false, "Larger viewport needs no scrollbar")
settingsPage.ScrollFrame:SetHeight(420)
Equal(settingsPage.ScrollBar:IsShown(), true, "Smaller viewport restores scrolling")
settingsPage.ScrollFrame:SetWidth(600)
settingsPage:UpdateScrollLayout()
Equal(settingsPage.Content:GetWidth(), 600, "Content follows viewport width")
Equal(settingsPage.SplitDescription:GetWidth(), 555, "Descriptions fit narrower content")
Equal(settingsPage.VoiceRows[1].MaleComboBox.Frame:GetWidth(), 218, "Voice columns fit narrower viewport")
Equal(settingsPage.VoiceRows[1].MaleComboBox.Dropdown:GetWidth(), 138, "Dropdown follows control width")
settingsPage.ScrollFrame:SetWidth(760)
settingsPage:UpdateScrollLayout()
Equal(settingsPage.VoiceRows[1].MaleComboBox.Frame:GetWidth(), 250, "Existing sizing restored when it fits")

print("PASS: classification, Options selectors and scrolling, TOC load order, and SavedVariables migration")
