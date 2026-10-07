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

local function ValidInput(text, voiceID)
    if type(text) ~= "string" or not text:find("%S") then
        return false, "invalid-text"
    end

    if type(voiceID) ~= "number" or voiceID < 0 or voiceID % 1 ~= 0 then
        return false, "invalid-voice"
    end

    return true
end

local function StopPlayback(self)
    -- StopSpeakingText can itself emit playback events synchronously.
    if self.Stopping then
        return
    end

    self.Stopping = true
    C_VoiceChat.StopSpeakingText()
    self.Stopping = false
end

function TTS:Initialize()
    if self.Initialized then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
    frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_BOOKMARK")
    frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
    frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FAILED")
    frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    C_TTSSettings.SetSetting(
        Enum.TtsBoolSetting.PlaySoundSeparatingChatLineBreaks,
        false
    )

    self.Frame = frame
    self.SessionID = 0
    self.Initialized = true
end

function TTS:Stop()
    local session = self.CurrentSession

    if not session then
        return false
    end

    session.cancelled = true
    self.CurrentSession = nil
    StopPlayback(self)

    return true
end

function TTS:StartSession(mode, voiceID)
    self:Initialize()
    self:Stop()

    self.SessionID = self.SessionID + 1

    local session = {
        id = self.SessionID,
        mode = mode,
        voiceID = voiceID,
        utterances = {},
    }

    self.CurrentSession = session

    return session
end

function TTS:SubmitText(session, text, chunk)
    local token = chunk or "WHOLE"
    local mark = "OUTLOUD:SPEECH:" .. session.id .. ":" .. token
    local ok = pcall(
        C_VoiceChat.SpeakText,
        session.voiceID,
        '<bookmark mark="' .. mark .. '"/>' .. text,
        0,
        100,
        false
    )

    if not ok then
        session.failed = true

        if self.CurrentSession == session then
            self:Stop()
        end
    end

    if session.failed then
        return false, "speech-failed"
    end

    return true
end

function TTS:SubmitChunk(session, chunk)
    if self.CurrentSession ~= session or session.queued[chunk] then
        return false
    end

    local sentence = session.sentences[chunk]

    if not sentence then
        return false
    end

    -- Set before calling the engine because events may arrive synchronously.
    session.queued[chunk] = true
    return self:SubmitText(session, sentence, chunk)
end

function TTS:SpeakStreaming(text, voiceID)
    local valid, reason = ValidInput(text, voiceID)

    if not valid then
        return false, reason
    end

    local sentences = {}
    text = text:gsub("%s+", " ")

    for sentence in text:gmatch("[^.!?]+[.!?]*") do
        sentence = sentence:gsub("^%s+", ""):gsub("%s+$", "")

        if sentence ~= "" then
            sentences[#sentences + 1] = sentence
        end
    end

    if #sentences == 0 then
        return false, "no-sentences"
    end

    local session = self:StartSession(self.ReadingModes.SPLIT, voiceID)
    session.sentences = sentences
    session.queued = {}

    return self:SubmitChunk(session, 1)
end

function TTS:SpeakWholeText(text, voiceID)
    local valid, reason = ValidInput(text, voiceID)

    if not valid then
        return false, reason
    end

    local session = self:StartSession(self.ReadingModes.FULL, voiceID)
    return self:SubmitText(session, text)
end

function TTS:Speak(text, voiceID)
    if OutLoud.Database:GetReadingMode() == self.ReadingModes.SPLIT then
        return self:SpeakStreaming(text, voiceID)
    end

    return self:SpeakWholeText(text, voiceID)
end

function TTS:OnBookmark(utteranceID, bookmark)
    if type(bookmark) ~= "string" or type(utteranceID) ~= "number" then
        return
    end

    local sessionID, token = bookmark:match("^OUTLOUD:SPEECH:(%d+):(%w+)$")
    sessionID = tonumber(sessionID)
    local chunk = tonumber(token)

    if not sessionID or (token ~= "WHOLE" and (not chunk or chunk < 1)) then
        return
    end

    local session = self.CurrentSession

    if not session or session.id ~= sessionID then
        -- The counter recognizes old output even after its tables are discarded.
        -- StopSpeakingText is global, so also cancel any current session it stops.
        if sessionID > 0 and sessionID <= self.SessionID then
            if not self:Stop() then
                StopPlayback(self)
            end
        end

        return
    end

    if session.mode == self.ReadingModes.SPLIT then
        if not chunk or not session.queued[chunk] then
            return
        end

        session.utterances[utteranceID] = chunk
        self:SubmitChunk(session, chunk + 1)
    elseif token == "WHOLE" then
        session.utterances[utteranceID] = token
    end
end

function TTS:OnEvent(event, utteranceID, bookmark)
    if self.Stopping then
        return
    end

    if event == "VOICE_CHAT_TTS_PLAYBACK_BOOKMARK" then
        self:OnBookmark(utteranceID, bookmark)
        return
    end

    -- STARTED alone cannot establish ownership or authorize prefetching.
    local session = self.CurrentSession

    if not session then
        return
    end

    local token = session.utterances[utteranceID]

    if event == "VOICE_CHAT_TTS_PLAYBACK_FAILED" then
        -- Without an ownership bookmark, a failure could belong to other TTS.
        if token then
            session.failed = true
            self:Stop()
        end
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" and token then
        session.utterances[utteranceID] = nil

        if token == "WHOLE" or token == #session.sentences then
            session.finished = true
            self.CurrentSession = nil
        end
    end
end
