local AddonName, OutLoud = ...

local Database = {}
OutLoud.Database = Database

Database.AutoNarrationDelay = {
    DEFAULT = 2,
    MIN = 0,
    MAX = 5,
    STEP = 0.5,
}

local function NormalizeAutoNarrationDelay(value)
    local range = Database.AutoNarrationDelay
    if type(value) ~= "number" or value ~= value then
        return range.DEFAULT
    end
    value = math.max(range.MIN, math.min(range.MAX, value))
    return math.floor(value / range.STEP + 0.5) * range.STEP
end

-- Snapshot of the numeric keys used by the original SavedVariables schema.
-- Available Options families always come from the generated data instead.
local LegacyFamilies = {
    [1] = "HUMAN",
    [2] = "ORC",
    [3] = "DWARF",
    [4] = "NIGHT_ELF",
    [5] = "UNDEAD",
    [6] = "TAUREN",
    [7] = "GNOME",
    [8] = "TROLL",
}

function Database:Initialize()
    if self.Initialized then
        return
    end

    local db = OutLoudDB

    if type(db) ~= "table" then
        db = {}
        OutLoudDB = db
    end

    if type(db.voices) ~= "table" then
        db.voices = {}
    end

    if db.autoNarrateQuests == nil then
        db.autoNarrateQuests = false
    end
    db.autoNarrationDelay = NormalizeAutoNarrationDelay(db.autoNarrationDelay)

    if db.voiceSettingsVersion == nil then
        for raceID, family in pairs(LegacyFamilies) do
            local legacyVoices = db.voices[raceID]

            if type(legacyVoices) == "table" then
                local familyVoices = db.voices[family]

                if type(familyVoices) ~= "table" then
                    familyVoices = {}
                    db.voices[family] = familyVoices
                end

                for _, gender in pairs(OutLoud.VoiceSelection.Genders) do
                    if familyVoices[gender] == nil then
                        familyVoices[gender] = legacyVoices[gender]
                    end
                end
            end
        end

        -- Retain numeric entries as a backup, but never reimport cleared voices.
        db.voiceSettingsVersion = 2
    end

    self.DB = db
    OutLoud.DB = db

    self.Initialized = true
end

function Database:GetVoice(family, gender)
    local familyVoices = self.DB.voices[family]

    if not familyVoices then
        return nil
    end

    return familyVoices[gender]
end

function Database:SetVoice(family, gender, voiceID)
    local voices = self.DB.voices

    if not voices[family] then
        voices[family] = {}
    end

    voices[family][gender] = voiceID
end

function Database:GetReadingMode()
    return self.DB.readingMode or OutLoud.TTS.ReadingModes.FULL
end

function Database:SetReadingMode(mode)
    self.DB.readingMode = mode
end

function Database:GetAutoNarrateQuests()
    return self.DB.autoNarrateQuests == true
end

function Database:SetAutoNarrateQuests(enabled)
    self.DB.autoNarrateQuests = enabled == true
end

function Database:GetAutoNarrationDelay()
    return NormalizeAutoNarrationDelay(self.DB.autoNarrationDelay)
end

function Database:SetAutoNarrationDelay(delay)
    self.DB.autoNarrationDelay = NormalizeAutoNarrationDelay(delay)
end
