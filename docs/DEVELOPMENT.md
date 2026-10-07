# Development Guide

Implementation reference, testing commands, and in-game diagnostic helpers for
[Out Loud](../README.md). See the main README for capabilities and project status.

## Runtime modules and initialization

Runtime services use singleton tables in the `OutLoud` namespace. `OutLoud.toc`
loads generated data, Core services, UI components, and initialization in order.
On addon load, initialization prepares the database, Options, and Talking Head UI.
The speech event frame is created on the first valid speech request.

## Voice data, resolution, and saved settings

- `OutLoudDB.voices[family][sex]` stores voice assignments. Families are stable
  string identities, rather than numeric DB2 RaceIDs. Runtime `UnitSex` values
  are `2` for Male and `3` for Female.
- `Data/VoiceMappings.lua` contains `VoiceMappings.Families` and direct
  `VoiceMappings.Models[FileDataID]` family mappings. It can be replaced with
  generator output and contains no gender data or addon runtime helpers.
- Options derives its rows from unique `VoiceMappings.Families` values, including
  families without model entries. Display labels convert keys such as `NIGHT_ELF`
  into readable names such as "Night Elf".
- `OutLoud.VoiceSelection:Resolve(unit, model)` accepts a PlayerModel already
  loaded for that unit and returns the configured voice ID plus inspection
  details. Unknown models, unavailable models/units, unknown sex, and unset voices
  return no voice, with a reason in the details. The resolver does not start speech.
- The original eight-race numeric settings are copied once to family keys without
  overwriting existing family assignments. Numeric entries remain as backups;
  `voiceSettingsVersion = 2` prevents restoring voices the user later clears.

## Speech controller API

Callers supply text and an already-resolved voice ID to the `OutLoud.TTS` singleton:

- `SpeakStreaming(text, voiceID)` normalizes whitespace and uses the tested
  `.`, `!`, `?` sentence splitter. The first sentence is submitted immediately;
  each valid playback bookmark submits only the next sentence. Duplicate bookmarks
  cannot queue a sentence twice. No timers or artificial delays are used.
- `SpeakWholeText(text, voiceID)` submits the complete text unchanged in one
  request, preceded by one ownership bookmark. It never splits or prefetches.
- `Speak(text, voiceID)` reads the existing saved `readingMode` through the
  database: `"split"` selects streaming and `"full"` selects whole text. The
  default is `"full"`.
- `Stop()` cancels active Out Loud speech. Calling it while idle leaves other
  TTS alone.

Speak methods return `true` when submission succeeds, or `false` plus a reason:
`invalid-text`, `invalid-voice`, `no-sentences`, or `speech-failed`. A supplied
voice ID must be a nonnegative integer; `0` is valid. Rate is `0`, volume is
`100`, and overlap is `false`. Initialization creates the event frame once and
disables Blizzard's line-separator sound once.

## Sessions, cancellation, and known limitations

Both modes share cancellation and monotonically increasing session IDs. Starting
valid new speech cancels the active session before submitting immediately.
Completed/cancelled session tables are discarded; bookmark session IDs recognize
late stale audio without keeping a session history. Stale Out Loud audio triggers
`StopSpeakingText()`. Because this API stops global playback, that emergency stop
also cancels any newer Out Loud session instead of leaving it marked active.

Only owned utterances can finish or fail a session. Native call errors are caught
silently. Bookmarks establish ownership. An asynchronous failure before the first
ownership bookmark cannot be distinguished from unrelated TTS and is ignored;
use `Stop()` if a request fails before identification. Speech methods do not
extract quest text, resolve voices, or control Talking Head behavior.

## Development testing

Run the mocked checks from the addon root with standalone Lua 5.1:

```text
lua Tests/VoiceSelection.lua
lua Tests/TTS.lua
```

Voice-selection tests exercise the generated mappings, real Options controls,
SavedVariables migration, and addon load order. Speech tests mock the native
engine and playback events to check streaming, mode dispatch, cancellation,
stale/duplicate bookmarks, completion, failures, and input validation. Model
loading, rendering, and actual audio still require in-game checks.

### Inspect the current quest NPC

With a quest dialog open, run this Lua command in Toolbox Console. It uses a
separate model and prints once after a short loading delay. If the reason is
`model-unavailable`, rerun after the model loads. The delay belongs only to this
inspection command, not the speech controller.

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

### Test speech directly

Run one Toolbox Console line at a time, replacing `voiceID` with your supplied
numeric WoW TTS voice ID:

```lua
OutLoud.TTS:SpeakStreaming("First sentence. Second sentence. Third sentence.", voiceID)
OutLoud.TTS:SpeakWholeText("First sentence. Second sentence. Third sentence.", voiceID)
OutLoud.TTS:Speak("First sentence. Second sentence. Third sentence.", voiceID)
OutLoud.TTS:Stop()
```
