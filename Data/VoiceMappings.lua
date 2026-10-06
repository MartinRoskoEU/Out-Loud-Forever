local AddonName, OutLoud = ...

local VoiceMappings = {}
OutLoud.VoiceMappings = VoiceMappings

VoiceMappings.Families = {
    BLOOD_ELF = "BLOOD_ELF",
    DRAENEI = "DRAENEI",
    DWARF = "DWARF",
    GNOME = "GNOME",
    GOBLIN = "GOBLIN",
    HUMAN = "HUMAN",
    NIGHT_ELF = "NIGHT_ELF",
    ORC = "ORC",
    SKYBORNE = "SKYBORNE",
    TAUREN = "TAUREN",
    TROLL = "TROLL",
    UNDEAD = "UNDEAD",
}

VoiceMappings.Models = {
    [119369] = VoiceMappings.Families.GOBLIN,
    [119376] = VoiceMappings.Families.GOBLIN,
    [878772] = VoiceMappings.Families.DWARF,
    [900914] = VoiceMappings.Families.GNOME,
    [917116] = VoiceMappings.Families.ORC,
    [921844] = VoiceMappings.Families.NIGHT_ELF,
    [940356] = VoiceMappings.Families.GNOME,
    [949470] = VoiceMappings.Families.ORC,
    [950080] = VoiceMappings.Families.DWARF,
    [959310] = VoiceMappings.Families.UNDEAD,
    [968705] = VoiceMappings.Families.TAUREN,
    [974343] = VoiceMappings.Families.NIGHT_ELF,
    [986648] = VoiceMappings.Families.TAUREN,
    [997378] = VoiceMappings.Families.UNDEAD,
    [1000764] = VoiceMappings.Families.HUMAN,
    [1005887] = VoiceMappings.Families.DRAENEI,
    [1011653] = VoiceMappings.Families.HUMAN,
    [1018060] = VoiceMappings.Families.TROLL,
    [1022598] = VoiceMappings.Families.DRAENEI,
    [1022938] = VoiceMappings.Families.TROLL,
    [1100087] = VoiceMappings.Families.BLOOD_ELF,
    [1100258] = VoiceMappings.Families.BLOOD_ELF,
    [1793470] = VoiceMappings.Families.HUMAN,
    [7478487] = VoiceMappings.Families.SKYBORNE,
    [7478494] = VoiceMappings.Families.SKYBORNE,
}
