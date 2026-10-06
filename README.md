# Out Loud

Voice configuration uses `OutLoudDB.voices[family][sex]`, where `family` is a
generated string identity and `sex` is the runtime `UnitSex` value: `2` for Male,
`3` for Female. Options creates one row with both selectors for each unique value
in `VoiceMappings.Families`, including families without model entries.

`OutLoud.VoiceSelection:Resolve(unit, model)` accepts a PlayerModel loaded for
that unit and returns the configured voice ID plus inspection details. It reads
the family from the model FileDataID and the gender independently from
`UnitSex(unit)`. Unknown models, unavailable models/units, unknown sex, and unset
voices return no voice, with a reason in the details. It does not start speech;
quest event handling and a TTS speech call are not implemented in this project.

The original numeric race settings are copied once to family keys without
overwriting existing family assignments. Numeric entries remain as backups;
`voiceSettingsVersion = 2` prevents reimporting voices the user later clears.
This migration uses the original eight-race schema, not the available family
catalog. The checked-in legacy mapping export is still supported by a small
adapter; replace `Data/VoiceMappings.lua` with generator output when ready.
Model gender is ignored even with the legacy export.

With a quest dialog open, run this Lua command in Toolbox Console to inspect
the current `questnpc`. It uses a separate model and prints once after a short
loading delay. If the reason is `model-unavailable`, rerun after the model loads.

```lua
local model = CreateFrame("PlayerModel")
model:SetUnit("questnpc")
C_Timer.After(0.5, function()
    local voice, info = OutLoud.VoiceSelection:Resolve("questnpc", model)
    print("NPC:", tostring(info.name), "ModelFileID:", tostring(info.modelFileID),
        "Family:", tostring(info.family), "UnitSex:", tostring(info.sex),
        "Gender:", info.gender or "UNKNOWN", "Voice:", tostring(voice),
        "Reason:", info.reason or "resolved")
end)
```

Run the mocked compatibility checks from the addon root with Lua 5.1:
`lua Tests/VoiceSelection.lua`. They exercise the real Options controls and
addon load order; model loading and rendering still require an in-game check.
