local AddonName, OutLoud = ...

_G.OutLoud = OutLoud

OutLoud.Name = AddonName
OutLoud.Loaded = false

OutLoud.UI = {}
OutLoud.Classes = {}

-- Routine diagnostics are opt-in for the current login.
OutLoud.DebugEnabled = false

function OutLoud:Debug(...)
    if self.DebugEnabled then
        print("[Out Loud]", ...)
    end
end

function OutLoud:Error(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    print("|cffff0000[Out Loud] " .. table.concat(parts, " ") .. "|r")
end
