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

    self:CreateScrollContainer()
    self:CreateHeader()

    local voicesAnchor = self:CreateVoicesSection()
    self:CreateReadingSection(voicesAnchor)
    self:UpdateScrollLayout()

    self.Initialized = true
end

function SettingsPage:CreateScrollContainer()
    local scroll = CreateFrame("ScrollFrame", nil, self.Panel)
    scroll:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", 0, 0)
    -- Reserve room for the template's scrollbar outside the clipped viewport.
    scroll:SetPoint("BOTTOMRIGHT", self.Panel, "BOTTOMRIGHT", -32, 14)
    scroll:EnableMouseWheel(true)

    -- The Core API annotations omit the scrollbar methods supplied by this template.
    ---@class OutLoudSettingsScrollBar : EventFrame
    ---@field SetHideIfUnscrollable fun(self: OutLoudSettingsScrollBar, hide: boolean)
    ---@field SetScrollPercentage fun(self: OutLoudSettingsScrollBar, percentage: number, forceImmediate?: boolean)
    ---@field SetVisibleExtentPercentage fun(self: OutLoudSettingsScrollBar, percentage: number)
    ---@field SetPanExtentPercentage fun(self: OutLoudSettingsScrollBar, percentage: number)
    ---@field ScrollStepInDirection fun(self: OutLoudSettingsScrollBar, direction: number)
    local scrollBar = CreateFrame("EventFrame", nil, self.Panel, "MinimalScrollBar")
    ---@cast scrollBar OutLoudSettingsScrollBar
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
    scrollBar:SetHideIfUnscrollable(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    content:SetPoint("TOPLEFT")
    scroll:SetScrollChild(content)

    self.ScrollFrame = scroll
    self.ScrollBar = scrollBar
    self.Content = content

    -- SetScrollPercentage emits OnScroll even when its value has not changed.
    local syncingScrollBar = false
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        if syncingScrollBar then
            return
        end

        local range = math.max(0, scroll:GetVerticalScrollRange())
        local percentage = range > 0 and offset / range or 0
        syncingScrollBar = true
        scrollBar:SetScrollPercentage(percentage, ScrollBoxConstants.NoScrollInterpolation)
        syncingScrollBar = false
    end)
    scrollBar:RegisterCallback("OnScroll", function(_, percentage)
        if not syncingScrollBar then
            self:SetScrollPosition(percentage * math.max(0, scroll:GetVerticalScrollRange()))
        end
    end, scroll)

    scroll:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:ScrollStepInDirection(-delta)
    end)
    scroll:SetScript("OnSizeChanged", function()
        self:UpdateScrollLayout()
    end)
    scroll:SetScript("OnShow", function()
        self:UpdateScrollLayout()
    end)
end

function SettingsPage:SetScrollPosition(position)
    local scroll = self.ScrollFrame
    local range = math.max(0, scroll:GetVerticalScrollRange())
    scroll:SetVerticalScroll(math.max(0, math.min(range, position)))
end

function SettingsPage:UpdateScrollLayout()
    local scroll, content = self.ScrollFrame, self.Content
    content:SetWidth(math.max(1, scroll:GetWidth()))

    if not self.SplitDescription then
        return
    end

    self:UpdateVoiceWidths(content:GetWidth())
    -- Keep the existing description width unless the viewport requires wrapping.
    local descriptionWidth = math.max(1, math.min(620, content:GetWidth() - 45))
    self.FullDescription:SetWidth(descriptionWidth)
    self.SplitDescription:SetWidth(descriptionWidth)

    local top, bottom = content:GetTop(), self.SplitDescription:GetBottom()
    if top and bottom then
        content:SetHeight(math.max(1, top - bottom + 24))
    end

    local position = scroll:GetVerticalScroll()
    scroll:UpdateScrollChildRect()
    local range = math.max(0, scroll:GetVerticalScrollRange())
    local visiblePercentage = 1
    if content:GetHeight() > 0 then
        visiblePercentage = math.max(0, math.min(1, scroll:GetHeight() / content:GetHeight()))
    end
    self.ScrollBar:SetVisibleExtentPercentage(visiblePercentage)
    self.ScrollBar:SetPanExtentPercentage(range > 0 and math.min(1, 36 / range) or 0)
    self:SetScrollPosition(position)
    local percentage = range > 0 and scroll:GetVerticalScroll() / range or 0
    self.ScrollBar:SetScrollPercentage(percentage, ScrollBoxConstants.NoScrollInterpolation)
end

function SettingsPage:UpdateVoiceWidths(contentWidth)
    -- Preserve the 250-pixel controls unless the scrollbar gutter makes them crowd.
    local available = contentWidth - 14 - VOICES_LAYOUT.leftPadding
        - VOICES_LAYOUT.raceWidth - VOICES_LAYOUT.rightPadding
        - 2 * VOICES_LAYOUT.columnGap
    local width = math.max(100, math.min(VOICES_LAYOUT.voiceControlWidth, available / 2))

    for _, row in ipairs(self.VoiceRows) do
        for _, combo in ipairs({ row.MaleComboBox, row.FemaleComboBox }) do
            combo.Frame:SetWidth(width)
            combo.Dropdown:SetWidth(width - 80)
        end
    end

    local femaleCenter = VOICES_LAYOUT.rightPadding + width / 2
    local maleCenter = femaleCenter + width + VOICES_LAYOUT.columnGap
    self.VoicesMaleLabel:SetPoint("CENTER", self.VoicesColumns, "RIGHT", -maleCenter, 0)
    self.VoicesFemaleLabel:SetPoint("CENTER", self.VoicesColumns, "RIGHT", -femaleCenter, 0)
end

function SettingsPage:CreateHeader()
    local title = self.Content:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(AddonName)

    local divider = self.Content:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 7, -50)
    divider:SetAtlas("Options_HorizontalDivider", true)
end

function SettingsPage:CreateVoicesSection()
    local header = CreateFrame(
        "Frame",
        nil,
        self.Content,
        "SettingsListSectionHeaderTemplate"
    )

    header:SetPoint("TOPLEFT", 7, -70)
    header:SetPoint("TOPRIGHT", -7, -70)
    header.Title:SetText("Voices")

    local columns = CreateFrame("Frame", nil, self.Content)
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
    self.VoicesMaleLabel = maleLabel
    self.VoicesFemaleLabel = femaleLabel

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

    for _, row in ipairs(self.VoiceRows or {}) do
        row.Frame:Hide()
        row.Frame:ClearAllPoints()
    end
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
            self.Content,
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

    local lastFrame = previousFrame or anchor
    if self.ReadingHeader then
        self:AnchorReadingSection(lastFrame)
        self:UpdateScrollLayout()
    end

    return lastFrame
end

function SettingsPage:AnchorReadingSection(anchor)
    local header = self.ReadingHeader
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -24)
    header:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -24)
end

function SettingsPage:CreateReadingSection(anchor)
    local header = CreateFrame(
        "Frame",
        nil,
        self.Content,
        "SettingsListSectionHeaderTemplate"
    )

    self.ReadingHeader = header
    self:AnchorReadingSection(anchor)

    header.Title:SetText("Reading")

    local fullButton = CreateFrame(
        "CheckButton",
        nil,
        self.Content,
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

    local fullDescription = self.Content:CreateFontString(
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
        self.Content,
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

    local splitDescription = self.Content:CreateFontString(
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

    self.FullTextButton = fullButton
    self.SplitTextButton = splitButton
    self.FullDescription = fullDescription
    self.SplitDescription = splitDescription
end
