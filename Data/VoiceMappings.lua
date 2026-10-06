local AddonName, OutLoud = ...

local VoiceMappings = {}
OutLoud.VoiceMappings = VoiceMappings

VoiceMappings.Genders = {
    MALE = 2,
    FEMALE = 3,
}

VoiceMappings.Races = {
    HUMAN = 1,
    ORC = 2,
    DWARF = 3,
    NIGHT_ELF = 4,
    UNDEAD = 5,
    TAUREN = 6,
    GNOME = 7,
    TROLL = 8,
}

VoiceMappings.Models = {
    [959310] = {
        race = VoiceMappings.Races.UNDEAD,
        gender = VoiceMappings.Genders.MALE,
    },
}

function VoiceMappings:GetRaces()
    local races = {}

    for _, model in pairs(self.Models) do
        races[model.race] = true
    end

    return races
end