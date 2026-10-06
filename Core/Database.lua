local AddonName, OutLoud = ...

local Database = {}
OutLoud.Database = Database

function Database:Initialize()
    if self.Initialized then
        return
    end

    local db = OutLoudDB

    if type(db) ~= "table" then
        db = {}
        OutLoudDB = db
    end

    OutLoud.DB = db
    self.Initialized = true
end