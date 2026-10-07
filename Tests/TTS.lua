-- Run from the addon root with Lua 5.1: lua Tests/TTS.lua
local LoadFile = assert(rawget(_G, "loadfile"), "Run tests with standalone Lua 5.1")

local function Equal(actual, expected, message)
    assert(actual == expected, (message or "Mismatch")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Harness()
    local test = { calls = {}, order = {}, stops = 0, settings = 0, frames = 0 }
    local environment = setmetatable({}, { __index = _G })
    environment._G = environment
    environment.print = function() error("Production speech must be silent") end
    environment.C_Timer = { After = function() error("Speech must not use timers") end }
    environment.VoiceSelection = nil
    environment.Enum = { TtsBoolSetting = { PlaySoundSeparatingChatLineBreaks = 0 } }
    environment.C_TTSSettings = { SetSetting = function(setting, value)
        Equal(setting, 0, "Only the separator setting is changed")
        Equal(value, false, "Disable separator sound")
        test.settings = test.settings + 1
    end }
    environment.CreateFrame = function()
        test.frames = test.frames + 1
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(event, callback)
            Equal(event, "OnEvent")
            self.callback = callback
        end
        test.frame = frame
        return frame
    end
    environment.C_VoiceChat = {
        GetTtsVoices = function() error("Speech must use the supplied voice ID") end,
        SpeakText = function(voiceID, text, rate, volume, overlap)
            local call = {
                voiceID = voiceID, text = text, rate = rate,
                volume = volume, overlap = overlap,
                mark = text:match('^<bookmark mark="([^"]+)"/>'),
                spoken = text:gsub('^<bookmark mark="[^"]+"/>', ""),
            }
            test.calls[#test.calls + 1] = call
            test.order[#test.order + 1] = "speak"

            if test.onSpeak then return test.onSpeak(#test.calls) end
        end,
        StopSpeakingText = function()
            test.stops = test.stops + 1
            test.order[#test.order + 1] = "stop"
            if test.onStop then test.onStop() end
        end,
    }

    local addon = {}
    for _, path in ipairs({
        "Core/Namespace.lua", "Core/VoiceSelection.lua", "Core/Database.lua", "Core/TTS.lua",
    }) do
        local chunk = assert(LoadFile(path))
        setfenv(chunk, environment)
        chunk("OutLoud", addon)
    end
    addon.Database:Initialize()
    test.tts = addon.TTS
    test.db = addon.Database
    -- No classifier or NPC/quest API is available to the controller.
    addon.VoiceSelection = nil

    function test:Event(event, ...)
        self.frame.callback(self.frame, "VOICE_CHAT_TTS_PLAYBACK_" .. event, ...)
    end
    function test:Bookmark(callIndex, utteranceID)
        self:Event("BOOKMARK", utteranceID, self.calls[callIndex].mark)
    end

    return test
end

local passed = 0
local function Test(name, callback)
    local ok, reason = pcall(callback)
    assert(ok, name .. ": " .. tostring(reason))
    passed = passed + 1
end

local text = "First sentence. Second sentence. Third sentence."

Test("Streaming submits immediately and stays one sentence ahead", function()
    local test = Harness()
    Equal(test.tts:SpeakStreaming(text, 0), true)
    Equal(#test.calls, 1, "Only sentence 1 is initially submitted")
    Equal(test.calls[1].spoken, "First sentence.")
    test:Event("STARTED", 101)
    test:Event("BOOKMARK", 101, "Start")
    Equal(#test.calls, 1, "Only our bookmark authorizes prefetch")
    test:Bookmark(1, 101)
    Equal(#test.calls, 2)
    Equal(test.calls[2].spoken, "Second sentence.")
    test:Event("FINISHED", 101)
    assert(test.tts.CurrentSession, "An intermediate finish must not end the session")
    Equal(#test.calls, 2, "Finish does not prefetch")
    test:Bookmark(2, 102)
    Equal(#test.calls, 3)
    Equal(test.calls[3].spoken, "Third sentence.")
    test:Bookmark(3, 103)
    Equal(#test.calls, 3)
end)

Test("Tested splitter preserves punctuation and normalizes whitespace", function()
    local test = Harness()
    test.tts:SpeakStreaming("  Hello!\n How\tare you? I am fine.  ", 7)
    test:Bookmark(1, 101)
    test:Bookmark(2, 102)
    Equal(#test.calls, 3)
    Equal(test.calls[1].spoken, "Hello!")
    Equal(test.calls[2].spoken, "How are you?")
    Equal(test.calls[3].spoken, "I am fine.")
    for _, call in ipairs(test.calls) do
        Equal(call.voiceID, 7)
        Equal(call.rate, 0)
        Equal(call.volume, 100)
        Equal(call.overlap, false)
    end
end)

Test("Whole text stays intact in exactly one request", function()
    local test = Harness()
    local whole = "  First sentence.\nSecond sentence.\tThird sentence.  "
    Equal(test.tts:SpeakWholeText(whole, 7), true)
    Equal(#test.calls, 1)
    Equal(test.calls[1].spoken, whole, "Do not normalize or split whole text")
    Equal(test.tts.CurrentSession.sentences, nil)
    Equal(test.tts.CurrentSession.queued, nil)
    test:Bookmark(1, 101)
    Equal(#test.calls, 1, "Whole bookmark never prefetches")
    test:Event("FINISHED", 101)
    Equal(test.tts.CurrentSession, nil)
end)

Test("Dispatcher uses the existing saved readingMode", function()
    local test = Harness()
    local stream, whole = 0, 0
    test.tts.SpeakStreaming = function(_, suppliedText, suppliedVoice)
        Equal(suppliedText, text)
        Equal(suppliedVoice, 7)
        stream = stream + 1
        return true
    end
    test.tts.SpeakWholeText = function(_, suppliedText, suppliedVoice)
        Equal(suppliedText, text)
        Equal(suppliedVoice, 7)
        whole = whole + 1
        return true
    end
    test.tts:Speak(text, 7)
    Equal(whole, 1, "Existing default is full")
    test.db:SetReadingMode(test.tts.ReadingModes.SPLIT)
    test.tts:Speak(text, 7)
    Equal(stream, 1)
    Equal(whole, 1)
    test.db:SetReadingMode(test.tts.ReadingModes.FULL)
    test.tts:Speak(text, 7)
    Equal(whole, 2)
    Equal(stream, 1)
end)

for _, modes in ipairs({
    { "SpeakStreaming", "SpeakStreaming" },
    { "SpeakStreaming", "SpeakWholeText" },
    { "SpeakWholeText", "SpeakStreaming" },
    { "SpeakWholeText", "SpeakWholeText" },
}) do
    Test("Cancellation " .. modes[1] .. " -> " .. modes[2], function()
        local test = Harness()
        test.tts[modes[1]](test.tts, text, 7)
        local old = test.tts.CurrentSession
        test.tts[modes[2]](test.tts, "New narration.", 8)
        Equal(old.cancelled, true)
        Equal(test.tts.CurrentSession.id, old.id + 1)
        Equal(test.stops, 1)
        Equal(#test.calls, 2, "Start replacement immediately")
        Equal(test.order[2], "stop")
        Equal(test.order[3], "speak")
        Equal(test.calls[2].voiceID, 8)
        assert(test.calls[1].mark ~= test.calls[2].mark, "Unique session bookmarks")
    end)
end

Test("Stale bookmarks stop playback without restarting old prefetch", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    test.tts:SpeakStreaming("New sentence. Another sentence.", 7)
    local replacement = test.tts.CurrentSession
    test:Bookmark(1, 101)
    Equal(#test.calls, 2)
    Equal(test.stops, 2, "Emergency stop after cancellation")
    Equal(replacement.cancelled, true, "Global stop also cancels newer narration")
    Equal(test.tts.CurrentSession, nil, "Do not keep a globally stopped session active")
    test.tts:SpeakWholeText("Fresh narration.", 7)
    Equal(#test.calls, 3, "Ready to start again")
end)

Test("Late bookmarks remain recognizable after Stop and cleanup", function()
    local test = Harness()
    test.tts:SpeakWholeText(text, 7)
    test.tts:Stop()
    test:Bookmark(1, 101)
    Equal(test.stops, 2)
    Equal(test.tts.CurrentSession, nil)
    Equal(#test.calls, 1)
end)

Test("Duplicate bookmarks cannot submit a chunk twice", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    test:Bookmark(1, 101)
    test:Bookmark(1, 101)
    Equal(#test.calls, 2)
    test:Bookmark(2, 102)
    test:Bookmark(2, 102)
    test:Bookmark(1, 101)
    Equal(#test.calls, 3)
end)

Test("Final streaming finish clears the active session", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    local session = test.tts.CurrentSession
    test:Bookmark(1, 101)
    test:Bookmark(2, 102)
    test:Bookmark(3, 103)
    test:Event("FINISHED", 103)
    Equal(session.finished, true)
    Equal(test.tts.CurrentSession, nil)
    Equal(test.stops, 0, "Normal finish does not stop unrelated playback")
    test.tts:SpeakWholeText("Next.", 7)
    Equal(test.stops, 0)
end)

Test("Invalid input never calls the engine or cancels current speech", function()
    local test = Harness()
    for _, method in ipairs({ "SpeakStreaming", "SpeakWholeText", "Speak" }) do
        for _, invalid in ipairs({ false, 42, {}, "", " \t\n" }) do
            Equal(test.tts[method](test.tts, invalid, 7), false)
        end
        Equal(test.tts[method](test.tts, nil, 7), false)
        for _, voice in ipairs({ false, "7", -1, 1.5, {}, 0 / 0, 1 / 0 }) do
            Equal(test.tts[method](test.tts, text, voice), false)
        end
        Equal(test.tts[method](test.tts, text, nil), false)
    end
    Equal(test.tts:SpeakStreaming(".!?", 7), false, "No usable sentences")
    Equal(#test.calls, 0)
    Equal(test.frames, 0, "Invalid input has no initialization side effects")
    test.tts:SpeakWholeText(text, 7)
    local current = test.tts.CurrentSession
    test.tts:SpeakStreaming("", 7)
    Equal(test.tts.CurrentSession, current)
    Equal(test.stops, 0)
end)

for _, method in ipairs({ "SpeakStreaming", "SpeakWholeText" }) do
    Test("Tracked playback failure clears " .. method, function()
        local test = Harness()
        test.tts[method](test.tts, "Only sentence.", 7)
        local session = test.tts.CurrentSession
        test:Bookmark(1, 101)
        test:Event("FAILED", 101, 13)
        Equal(session.failed, true)
        Equal(test.tts.CurrentSession, nil)
        Equal(test.stops, 1)
        test.tts:SpeakWholeText("Next.", 7)
        Equal(#test.calls, 2)
    end)
end

Test("Unrelated events and bookmarks cannot alter the session", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    local session = test.tts.CurrentSession
    test:Event("STARTED", 999)
    test:Event("FINISHED", 999)
    test:Event("FAILED", 999, 13)
    for _, bookmark in ipairs({
        "Start", "OTHER:1:1", "OUTLOUD:SPEECH:999:1",
        "OUTLOUD:SPEECH:0:1", "OUTLOUD:SPEECH:1:0",
        "OUTLOUD:SPEECH:1:3", "OUTLOUD:SPEECH:1:WHOLE",
    }) do
        test:Event("BOOKMARK", 999, bookmark)
    end
    test:Event("BOOKMARK", 999, nil)
    Equal(test.tts.CurrentSession, session)
    Equal(#test.calls, 1)
    Equal(test.stops, 0)
end)

Test("Stop cancels once and is safe while idle", function()
    local test = Harness()
    Equal(test.tts:Stop(), false)
    Equal(test.stops, 0)
    test.tts:SpeakStreaming(text, 7)
    local session = test.tts.CurrentSession
    Equal(test.tts:Stop(), true)
    Equal(session.cancelled, true)
    Equal(test.tts.CurrentSession, nil)
    Equal(test.tts:Stop(), false)
    Equal(test.stops, 1)
    test.tts:SpeakStreaming("Again.", 7)
    Equal(#test.calls, 2)
end)

Test("Event frame and separator initialization occur once", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    test.tts:SpeakWholeText(text, 7)
    test.tts:Stop()
    test.tts:SpeakStreaming(text, 7)
    Equal(test.frames, 1)
    Equal(test.settings, 1)
    for _, event in ipairs({ "STARTED", "BOOKMARK", "FINISHED", "FAILED" }) do
        Equal(test.frame.events["VOICE_CHAT_TTS_PLAYBACK_" .. event], true)
    end
end)

Test("Synchronous bookmark events preserve the queued guard", function()
    local test = Harness()
    test.onSpeak = function(index)
        test:Bookmark(index, 100 + index)
        test:Bookmark(index, 100 + index)
    end
    Equal(test.tts:SpeakStreaming(text, 7), true)
    Equal(#test.calls, 3, "One submission for each playback bookmark")
end)

Test("Untracked events during submission cannot claim our session", function()
    local test = Harness()
    test.onSpeak = function()
        test:Event("FAILED", 999, 13)
        test:Event("FINISHED", 999)
        test:Event("STARTED", 999)
    end
    Equal(test.tts:SpeakWholeText(text, 7), true)
    assert(test.tts.CurrentSession, "Unrelated events must not cancel our speech")
    Equal(test.stops, 0)
end)

Test("Native exceptions are silent and clear failed submissions", function()
    local test = Harness()
    test.onSpeak = function() error("Engine rejected the request") end
    local accepted, reason = test.tts:SpeakStreaming(text, 7)
    Equal(accepted, false)
    Equal(reason, "speech-failed")
    Equal(test.tts.CurrentSession, nil)
end)

Test("An identified intermediate failure cancels prefetched audio", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    test:Bookmark(1, 101)
    test:Bookmark(2, 102)
    Equal(#test.calls, 3)
    test:Event("FAILED", 102, 13)
    Equal(test.tts.CurrentSession, nil)
    Equal(test.stops, 1)
    test:Bookmark(3, 103)
    Equal(#test.calls, 3, "Late prefetched audio cannot continue the failed session")
    Equal(test.stops, 2, "Late audio is stopped")
end)

Test("Synchronous cancellation events cannot end the replacement session", function()
    local test = Harness()
    test.tts:SpeakStreaming(text, 7)
    test:Bookmark(1, 101)
    test.onStop = function()
        test:Event("FINISHED", 101)
        test:Bookmark(1, 101)
    end
    test.tts:SpeakWholeText("Replacement.", 7)
    Equal(test.stops, 1, "No recursive emergency stop")
    assert(test.tts.CurrentSession, "Replacement remains active")
    Equal(test.calls[#test.calls].spoken, "Replacement.")
end)

Test("Repeated sessions retain only the current session", function()
    local test = Harness()
    for index = 1, 100 do
        test.tts:SpeakWholeText("One sentence.", 7)
        test:Bookmark(index, 100 + index)
        test:Event("FINISHED", 100 + index)
        Equal(test.tts.CurrentSession, nil)
    end
    Equal(test.tts.SessionID, 100)
    Equal(test.frames, 1)
    Equal(test.tts.sessions, nil)
    Equal(test.tts.bookmarkInfo, nil)
    Equal(test.tts.utteranceInfo, nil)
    test:Bookmark(1, 101)
    Equal(test.stops, 1, "Old output is recognized after cleanup")
end)

print("PASS: " .. passed .. " speech controller checks")
