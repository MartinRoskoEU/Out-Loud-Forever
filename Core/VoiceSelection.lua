local AddonName, OutLoud = ...

local VoiceSelection = {}
OutLoud.VoiceSelection = VoiceSelection

-- Runtime UnitSex values, independent of generated model data.
VoiceSelection.Genders = {
    MALE = 2,
    FEMALE = 3,
}

function VoiceSelection:GetFamilies()
    local mappings = OutLoud.VoiceMappings
    local unique = {}

    if mappings.Families then
        for _, family in pairs(mappings.Families) do
            unique[family] = true
        end
    else
        -- Keep the checked-in legacy export usable until it is regenerated.
        for family in pairs(mappings.Races or {}) do
            unique[family] = true
        end
    end

    local families = {}

    for family in pairs(unique) do
        table.insert(families, family)
    end

    table.sort(families)

    return families
end

function VoiceSelection:GetFamilyName(family)
    local name = family:gsub("_", " "):lower()
    return (name:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest
    end))
end

function VoiceSelection:GetFamily(fileDataID)
    local mappings = OutLoud.VoiceMappings
    local mapping = mappings.Models[fileDataID]

    if type(mapping) == "string" then
        return mapping
    end

    -- Legacy export compatibility only; its model gender is never used.
    if type(mapping) == "table" and not mappings.Families then
        for family, raceID in pairs(mappings.Races or {}) do
            if raceID == mapping.race then
                return family
            end
        end
    end
end

-- The caller supplies a PlayerModel already loaded for this unit.
-- Returns the configured voice ID (or nil) and inspection details.
function VoiceSelection:Resolve(unit, model)
    local info = {}

    if not unit or not UnitExists(unit) then
        info.reason = "unit-unavailable"
        return nil, info
    end

    info.name = UnitName(unit)
    info.sex = UnitSex(unit)

    if info.sex == self.Genders.MALE then
        info.gender = "MALE"
    elseif info.sex == self.Genders.FEMALE then
        info.gender = "FEMALE"
    end

    info.modelFileID = model and model:GetModelFileID()

    if not info.modelFileID or info.modelFileID == 0 then
        info.reason = "model-unavailable"
        return nil, info
    end

    info.family = self:GetFamily(info.modelFileID)

    if not info.family then
        info.reason = "unknown-model"
        return nil, info
    end

    if not info.gender then
        info.reason = "unknown-sex"
        return nil, info
    end

    info.voiceID = OutLoud.Database:GetVoice(info.family, info.sex)

    if info.voiceID == nil then
        info.reason = "voice-not-set"
    end

    return info.voiceID, info
end
