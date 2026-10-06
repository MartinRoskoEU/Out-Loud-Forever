local AddonName, OutLoud = ...

local Database = {}
OutLoud.Database = Database

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
