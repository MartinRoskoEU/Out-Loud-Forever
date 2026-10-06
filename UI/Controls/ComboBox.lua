local AddonName, OutLoud = ...

local ComboBox = {}
ComboBox.__index = ComboBox

OutLoud.Classes.ComboBox = ComboBox

function ComboBox:New(parent, width)
    local instance = setmetatable({}, self)

    local control = CreateFrame("Frame", nil, parent, "SettingsDropdownWithButtonsTemplate")
    control:SetWidth(width)
    control.Label:Hide()

    local dropdown = control.Dropdown
    dropdown:SetWidth(width - 80)

    instance.Frame = control
    instance.Dropdown = dropdown

    return instance
end

function ComboBox:Setup(options, getValue, setValue)
    self.Dropdown:SetupMenu(function(_, rootDescription)
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(
                option.label,
                function(value)
                    return getValue() == value
                end,
                function(value)
                    setValue(value)
                end,
                option.value
            )
        end
    end)
end