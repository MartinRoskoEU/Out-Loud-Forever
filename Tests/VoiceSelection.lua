-- Run from the addon root with Lua 5.1: lua Tests/VoiceSelection.lua
local function Equal(actual, expected, message)
    assert(actual == expected, (message or "Mismatch")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Frame()
    local frame = { scripts = {} }
    local methods = {
        SetScript = function(self, event, callback) self.scripts[event] = callback end,
        SetText = function(self, text) self.textValue = text end,
        CreateFontString = function() return Frame() end,
        CreateTexture = function() return Frame() end,
        SetupMenu = function(self, callback) self.menu = callback end,
    }
    setmetatable(frame, { __index = function(self, key)
        if key == "Title" or key == "Label" or key == "Dropdown" or key == "text" then
            local child = Frame()
            rawset(self, key, child)
            return child
        end
        return methods[key] or function() end
    end })
    return frame
end

local frames = {}
function CreateFrame()
    local frame = Frame()
    table.insert(frames, frame)
    return frame
end

local sex, exists = 2, true
function UnitSex() return sex end
function UnitExists() return exists end
function UnitName() return "Test NPC" end
Settings = {
    RegisterCanvasLayoutCategory = function() return {} end,
    RegisterAddOnCategory = function() end,
}
C_VoiceChat = { GetTtsVoices = function()
    local voices = {}
    for id = 0, 60 do
        table.insert(voices, { voiceID = id, name = "Voice " .. id })
    end
    return voices
end }

local addon = {}
local function Load(path)
    assert(loadfile(path))("OutLoud", addon)
end

-- Load the real files in their declared order and exercise ADDON_LOADED.
for line in io.lines("OutLoud.toc") do
    if line:match("%.lua$") then
        Load((line:gsub("\\", "/")))
    end
end

local selection = addon.VoiceSelection
Equal(selection:GetFamily(959310), "UNDEAD", "Checked-in legacy export")
Equal(#selection:GetFamilies(), 8, "Legacy family catalog")
local legacyMappings = addon.VoiceMappings

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
OutLoudDB = {
    voices = {
        [5] = { [2] = 40, [3] = 41 },
        UNDEAD = { [2] = 50 },
        SKYBORNE = { [2] = 10, [3] = 11 },
        HUMAN = { [2] = 0, [3] = 13 },
        [999] = { [2] = 60 },
    },
    readingMode = "split",
}
local initFrame = frames[#frames]
initFrame.scripts.OnEvent(initFrame, "ADDON_LOADED", "OtherAddon")
Equal(addon.Loaded, false, "Ignore unrelated addon event")
initFrame.scripts.OnEvent(initFrame, "ADDON_LOADED", "OutLoud")
Equal(addon.Loaded, true, "TOC initialization")
Equal(addon.Database:GetVoice("UNDEAD", 2), 50, "Keep newer assignment")
Equal(addon.Database:GetVoice("UNDEAD", 3), 41, "Migrate legacy female")
Equal(OutLoudDB.voices[5][2], 40, "Keep numeric backup")
Equal(OutLoudDB.voices[999][2], 60, "Keep unknown legacy keys")
Equal(addon.Database:GetReadingMode(), "split", "Keep reading settings")
Equal(OutLoudDB.voiceSettingsVersion, 2, "Migration marker")

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

local newMappings = addon.VoiceMappings
addon.VoiceMappings = legacyMappings
Resolve(959310, 3, "UNDEAD", "FEMALE", 41)
addon.VoiceMappings = newMappings

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
local anchor = Frame()
Equal(addon.UI.SettingsPage:CreateVoiceRows(anchor), anchor, "Empty catalog anchor")
Equal(#addon.UI.SettingsPage.VoiceRows, 0, "No rows from model entries")

print("PASS: requested classification cases, Options selectors, TOC load order, and SavedVariables migration")
