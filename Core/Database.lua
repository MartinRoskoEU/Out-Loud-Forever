local AddonName, OutLoud = ...

local Database = {}
OutLoud.Database = Database

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

    self.DB = db
    OutLoud.DB = db

    self.Initialized = true
end

function Database:GetVoice(raceID, gender)
    local raceVoices = self.DB.voices[raceID]

    if not raceVoices then
        return nil
    end

    return raceVoices[gender]
end

function Database:SetVoice(raceID, gender, voiceID)
    local voices = self.DB.voices

    if not voices[raceID] then
        voices[raceID] = {}
    end

    voices[raceID][gender] = voiceID
end

function Database:GetReadingMode()
    return self.DB.readingMode or OutLoud.TTS.ReadingModes.FULL
end

function Database:SetReadingMode(mode)
    self.DB.readingMode = mode
end