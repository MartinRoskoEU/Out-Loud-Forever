local AddonName, OutLoud = ...

local TTS = {}
OutLoud.TTS = TTS

TTS.ReadingModes = {
    FULL = "full",
    SPLIT = "split",
}

function TTS:GetVoices()
    if self.Voices then
        return self.Voices
    end

    self.Voices = C_VoiceChat.GetTtsVoices() or {}

    return self.Voices
end