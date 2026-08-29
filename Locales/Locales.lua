local myname, ns = ...

-- Minimal localization table.
-- Untranslated keys fall back to the English source string, so the addon works
-- unchanged with no locale files present. Locale files just assign into ns.L.
local L = setmetatable({}, {
    __index = function(t, key)
        return key
    end,
})

ns.L = L
