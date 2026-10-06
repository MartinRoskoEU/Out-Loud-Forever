local AddonName, OutLoud = ...

local TalkingHead = {}
OutLoud.UI.TalkingHead = TalkingHead

local function AtlasOrFallback(primary, fallback)
    if C_Texture.GetAtlasExists(primary) then
        return primary
    end

    return fallback
end

function TalkingHead:Initialize()
    if self.Initialized then
        return
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetSize(570, 155)

    frame:SetPoint(
        "BOTTOM",
        UIParent,
        "BOTTOM",
        0,
        190
    )

    frame:SetScale(1.05)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(1)

    local background = frame:CreateTexture(
        nil,
        "BACKGROUND"
    )

    background:SetPoint(
        "CENTER",
        frame,
        "CENTER"
    )

    local model = CreateFrame(
        "PlayerModel",
        nil,
        frame
    )

    model:SetSize(115, 115)

    model:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        21,
        -21
    )

    local portraitBg = model:CreateTexture(
        nil,
        "BACKGROUND"
    )

    portraitBg:SetAllPoints(model)

    local portraitFrame = frame:CreateTexture(
        nil,
        "OVERLAY"
    )

    portraitFrame:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        5,
        -6
    )

    local name = frame:CreateFontString(
        nil,
        "ARTWORK"
    )

    name:SetPoint(
        "TOPLEFT",
        portraitFrame,
        "TOPRIGHT",
        10,
        -12
    )

    name:SetPoint(
        "RIGHT",
        frame,
        "RIGHT",
        -46,
        0
    )

    name:SetJustifyH("LEFT")
    name:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
    name:SetShadowColor(0, 0, 0, 0.85)
    name:SetShadowOffset(1, -1)

    local text = frame:CreateFontString(
        nil,
        "ARTWORK"
    )

    text:SetPoint(
        "TOPLEFT",
        name,
        "BOTTOMLEFT",
        0,
        -4
    )

    text:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -46,
        16
    )

    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetFont(STANDARD_TEXT_FONT, 16, "")
    text:SetTextColor(0.075, 0.040, 0.020, 1)
    text:SetShadowColor(0, 0, 0, 0)
    text:SetShadowOffset(0, 0)

    local close = CreateFrame(
        "Button",
        nil,
        frame,
        "UIPanelCloseButtonNoScripts"
    )

    close:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        -12,
        -12
    )

    close:SetScript("OnClick", function()
        self:Hide()
    end)

    local spinner = CreateFrame(
        "Frame",
        nil,
        frame,
        "LoadingSpinnerTemplate"
    )

    spinner:Hide()
    spinner:SetSize(24, 24)

    spinner:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -14,
        18
    )

    self.Frame = frame
    self.Background = background
    self.Model = model
    self.PortraitBackground = portraitBg
    self.PortraitFrame = portraitFrame
    self.NameText = name
    self.DialogText = text
    self.CloseButton = close
    self.Spinner = spinner
    self.IsLoading = false

    self.Initialized = true
end

function TalkingHead:Show(unit, text)
    if not unit or not UnitExists(unit) then
        self:Hide()
        return
    end

    self:Initialize()

    local faction = UnitFactionGroup(unit)

    local textureKit
    if faction == "Horde" then
        textureKit = "TalkingHeads-Horde"
    elseif faction == "Alliance" then
        textureKit = "TalkingHeads-Alliance"
    else
        textureKit = "TalkingHeads-Neutral"
    end

    self.Background:SetAtlas(
        AtlasOrFallback(
            textureKit .. "-TextBackground",
            "TalkingHeads-TextBackground"
        ),
        true
    )

    self.PortraitBackground:SetAtlas(
        AtlasOrFallback(
            textureKit .. "-PortraitBg",
            "TalkingHeads-PortraitBg"
        ),
        true
    )

    self.PortraitFrame:SetAtlas(
        AtlasOrFallback(
            textureKit .. "-PortraitFrame",
            "TalkingHeads-Alliance-PortraitFrame"
        ),
        true
    )

    self.Model:SetUnit(unit)

    if self.Model.SetPortraitZoom then
        self.Model:SetPortraitZoom(1)
    end

    self.NameText:SetText(UnitName(unit) or "Unknown")
    self.DialogText:SetText(text or "")

    if faction == "Alliance" then
        self.NameText:SetTextColor(0.88, 0.93, 1.00, 1)
    elseif faction == "Horde" then
        self.NameText:SetTextColor(1.00, 0.84, 0.52, 1)
    else
        self.NameText:SetTextColor(1.00, 0.88, 0.62, 1)
    end

    self.Frame:Show()
end

function TalkingHead:SetLoading(isLoading)
    self:Initialize()

    self.IsLoading = not not isLoading

    if self.IsLoading then
        self.Spinner:Show()
    else
        self.Spinner:Hide()
    end
end

function TalkingHead:Hide()
    self.IsLoading = false

    if self.Spinner then
        self.Spinner:Hide()
    end

    if self.Frame then
        self.Frame:Hide()
    end
end
