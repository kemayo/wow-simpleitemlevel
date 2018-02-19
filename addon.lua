local myname, ns = ...

-- events
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if ns[event] then return ns[event](ns, event, ...) end end)
function ns:RegisterEvent(...) for i=1,select("#", ...) do f:RegisterEvent((select(i, ...))) end end
function ns:UnregisterEvent(...) for i=1,select("#", ...) do f:UnregisterEvent((select(i, ...))) end end

local LIL = LibStub("LibItemLevel-1.0")
local function GetItemQualityAndLevel(unit, slotID)
    local itemID = GetInventoryItemID(unit, slotID)

    if itemID ~= nil then
        local quality = GetInventoryItemQuality(unit, slotID)
        local level = LIL.GetItemLevel(slotID, unit)

        return quality, level
    end
end
local function UpdateItemSlotButton(button, unit)
    local slotID = button:GetID()

    if (slotID >= INVSLOT_FIRST_EQUIPPED and slotID <= INVSLOT_LAST_EQUIPPED) then
        local itemQuality, itemLevel = GetItemQualityAndLevel(unit, slotID)

        if not button.simpleilvl then
            button.simpleilvl = button:CreateFontString('$parentItemLevel', 'ARTWORK')
            button.simpleilvl:SetPoint('TOPRIGHT', -2, -2)
            button.simpleilvl:SetFontObject(NumberFontNormal)
            button.simpleilvl:SetJustifyH('RIGHT')
        end

        if not itemLevel then
            return button.simpleilvl:Hide()
        end

        local r, g, b, hex = GetItemQualityColor(itemQuality)
        button.simpleilvl:SetFormattedText('|c%s%s|r', hex, itemLevel or '?')
        button.simpleilvl:Show()
    end
end
hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    UpdateItemSlotButton(button, "player")
end)

function ns:GET_ITEM_INFO_RECEIVED()
    if InspectFrame and InspectFrame:IsShown() then
        -- TODO: I think I need to schedule a flushed-cache a little while after the inspect happens. Artifact weapons are reliably not-quite-loaded.
        InspectPaperDollFrame_OnShow()
    end
end
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED")

function ns:ADDON_LOADED(event, addon)
    if addon == "Blizzard_InspectUI" then
        self:ModInspectUI()
    end
    if addon == myname then
        if IsAddOnLoaded("Blizzard_InspectUI") then
            self:ModInspectUI()
        end
    end
end
ns:RegisterEvent("ADDON_LOADED")

function ns:ModInspectUI()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, "target")
    end)
end
