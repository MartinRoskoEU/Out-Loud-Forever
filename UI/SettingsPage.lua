local AddonName, OutLoud = ...

local SettingsPage = {}
OutLoud.UI.SettingsPage = SettingsPage

local VOICES_LAYOUT = {
    leftPadding = 10,
    rightPadding = 0,

    raceWidth = 120,

    voiceControlWidth = 250,
    columnGap = 10,
}

function SettingsPage:Initialize()
    if self.Initialized then
        return
    end

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Out Loud")
    Settings.RegisterAddOnCategory(category)

    self.Panel = panel
    self.Category = category

    self:CreateHeader()

    local voicesAnchor = self:CreateVoicesSection()
    self:CreateReadingSection(voicesAnchor)

    self.Initialized = true
end

function SettingsPage:CreateHeader()
    local title = self.Panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(AddonName)

    local divider = self.Panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 7, -50)
    divider:SetAtlas("Options_HorizontalDivider", true)
end

function SettingsPage:CreateVoicesSection()
    local header = CreateFrame(
        "Frame",
        nil,
        self.Panel,
        "SettingsListSectionHeaderTemplate"
    )

    header:SetPoint("TOPLEFT", 7, -70)
    header:SetPoint("TOPRIGHT", -7, -70)
    header.Title:SetText("Voices")

    local columns = CreateFrame("Frame", nil, self.Panel)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    columns:SetHeight(32)

    local raceLabel = columns:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    raceLabel:SetPoint(
        "LEFT",
        columns,
        "LEFT",
        VOICES_LAYOUT.leftPadding,
        0
    )

    raceLabel:SetWidth(VOICES_LAYOUT.raceWidth)
    raceLabel:SetJustifyH("LEFT")
    raceLabel:SetText("Family")

    local femaleCenter = VOICES_LAYOUT.rightPadding
        + (VOICES_LAYOUT.voiceControlWidth / 2)

    local maleCenter = VOICES_LAYOUT.rightPadding
        + VOICES_LAYOUT.voiceControlWidth
        + VOICES_LAYOUT.columnGap
        + (VOICES_LAYOUT.voiceControlWidth / 2)

    local maleLabel = columns:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    maleLabel:SetPoint(
        "CENTER",
        columns,
        "RIGHT",
        -maleCenter,
        0
    )

    maleLabel:SetText("Male")

    local femaleLabel = columns:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    femaleLabel:SetPoint(
        "CENTER",
        columns,
        "RIGHT",
        -femaleCenter,
        0
    )

    femaleLabel:SetText("Female")

    self.VoicesHeader = header
    self.VoicesColumns = columns

    return self:CreateVoiceRows(columns)
end

function SettingsPage:GetVoiceOptions()
    if self.VoiceOptions then
        return self.VoiceOptions
    end

    local options = {
        {
            label = "Not set",
            value = nil,
        },
    }

    for _, voice in ipairs(OutLoud.TTS:GetVoices()) do
        table.insert(options, {
            label = voice.name,
            value = voice.voiceID,
        })
    end

    self.VoiceOptions = options

    return options
end

function SettingsPage:CreateVoiceRows(anchor)
    local selection = OutLoud.VoiceSelection
    local families = selection:GetFamilies()
    local voiceOptions = self:GetVoiceOptions()

    self.VoiceRows = {}

    local previousFrame

    for _, family in ipairs(families) do
        local currentFamily = family

        for _, gender in pairs(selection.Genders) do
            local voiceID = OutLoud.Database:GetVoice(currentFamily, gender)

            if voiceID ~= nil then
                local available = false

                for _, option in ipairs(voiceOptions) do
                    if option.value == voiceID then
                        available = true
                        break
                    end
                end

                if not available then
                    OutLoud.Database:SetVoice(currentFamily, gender, nil)
                end
            end
        end

        local row = OutLoud.Classes.VoiceRow:New(
            self.Panel,
            VOICES_LAYOUT
        )

        if previousFrame then
            row.Frame:SetPoint(
                "TOPLEFT",
                previousFrame,
                "BOTTOMLEFT",
                0,
                -4
            )

            row.Frame:SetPoint(
                "TOPRIGHT",
                previousFrame,
                "BOTTOMRIGHT",
                0,
                -4
            )
        else
            row.Frame:SetPoint(
                "TOPLEFT",
                anchor,
                "BOTTOMLEFT",
                0,
                -4
            )

            row.Frame:SetPoint(
                "TOPRIGHT",
                anchor,
                "BOTTOMRIGHT",
                0,
                -4
            )
        end

        row:Setup(
            selection:GetFamilyName(currentFamily),
            voiceOptions,

            function()
                return OutLoud.Database:GetVoice(
                    currentFamily,
                    selection.Genders.MALE
                )
            end,

            function(voiceID)
                OutLoud.Database:SetVoice(
                    currentFamily,
                    selection.Genders.MALE,
                    voiceID
                )
            end,

            function()
                return OutLoud.Database:GetVoice(
                    currentFamily,
                    selection.Genders.FEMALE
                )
            end,

            function(voiceID)
                OutLoud.Database:SetVoice(
                    currentFamily,
                    selection.Genders.FEMALE,
                    voiceID
                )
            end
        )

        table.insert(self.VoiceRows, row)
        previousFrame = row.Frame
    end

    return previousFrame or anchor
end

function SettingsPage:CreateReadingSection(anchor)
    local header = CreateFrame(
        "Frame",
        nil,
        self.Panel,
        "SettingsListSectionHeaderTemplate"
    )

    header:SetPoint(
        "TOPLEFT",
        anchor,
        "BOTTOMLEFT",
        0,
        -24
    )

    header:SetPoint(
        "TOPRIGHT",
        anchor,
        "BOTTOMRIGHT",
        0,
        -24
    )

    header.Title:SetText("Reading")

    local fullButton = CreateFrame(
        "CheckButton",
        nil,
        self.Panel,
        "UIRadioButtonTemplate"
    )

    fullButton:SetPoint(
        "TOPLEFT",
        header,
        "BOTTOMLEFT",
        10,
        -18
    )

    fullButton.text:SetFontObject(GameFontNormal)
    fullButton.text:SetText("Read full text")

    local fullDescription = self.Panel:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlightSmall"
    )

    fullDescription:SetPoint(
        "TOPLEFT",
        fullButton,
        "BOTTOMLEFT",
        21,
        -5
    )

    fullDescription:SetWidth(620)
    fullDescription:SetJustifyH("LEFT")
    fullDescription:SetJustifyV("TOP")
    fullDescription:SetWordWrap(true)

    fullDescription:SetText(
        "Sends the entire text to TTS in a single request. This provides more context to the voice model and usually produces more natural and consistent speech, but longer texts take more time to process before playback can begin."
    )

    local splitButton = CreateFrame(
        "CheckButton",
        nil,
        self.Panel,
        "UIRadioButtonTemplate"
    )

    splitButton:SetPoint(
        "TOPLEFT",
        fullDescription,
        "BOTTOMLEFT",
        -21,
        -16
    )

    splitButton.text:SetFontObject(GameFontNormal)
    splitButton.text:SetText("Split text")

    local splitDescription = self.Panel:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlightSmall"
    )

    splitDescription:SetPoint(
        "TOPLEFT",
        splitButton,
        "BOTTOMLEFT",
        21,
        -5
    )

    splitDescription:SetWidth(620)
    splitDescription:SetJustifyH("LEFT")
    splitDescription:SetJustifyV("TOP")
    splitDescription:SetWordWrap(true)

    splitDescription:SetText(
        "Splits the text into smaller parts and sends them to TTS sequentially. Playback can begin sooner, especially for longer texts, but the voice model receives less context and pauses or changes in delivery between parts may be more noticeable."
    )

    local function Refresh()
        local mode = OutLoud.Database:GetReadingMode()

        fullButton:SetChecked(
            mode == OutLoud.TTS.ReadingModes.FULL
        )

        splitButton:SetChecked(
            mode == OutLoud.TTS.ReadingModes.SPLIT
        )
    end

    fullButton:SetScript("OnClick", function()
        OutLoud.Database:SetReadingMode(
            OutLoud.TTS.ReadingModes.FULL
        )

        Refresh()
    end)

    splitButton:SetScript("OnClick", function()
        OutLoud.Database:SetReadingMode(
            OutLoud.TTS.ReadingModes.SPLIT
        )

        Refresh()
    end)

    Refresh()

    self.ReadingHeader = header
    self.FullTextButton = fullButton
    self.SplitTextButton = splitButton
end