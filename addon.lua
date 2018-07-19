local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local db

function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

-- events
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if ns[event] then return ns[event](ns, event, ...) end end)
function ns:RegisterEvent(...) for i=1,select("#", ...) do f:RegisterEvent((select(i, ...))) end end
function ns:UnregisterEvent(...) for i=1,select("#", ...) do f:UnregisterEvent((select(i, ...))) end end

local LIL = LibStub("LibItemLevel-1.0")

function ns:ADDON_LOADED(event, addon)
    if addon == "Blizzard_InspectUI" then
        self:ModInspectUI()
    end
    if addon == myname then
        if IsAddOnLoaded("Blizzard_InspectUI") then
            self:ModInspectUI()
        end

        _G[myname.."DB"] = setmetatable(_G[myname.."DB"] or {}, {
            __index = {
                character = true,
                inspect = true,
                bags = true,
            },
        })
        db = _G[myname.."DB"]
    end
end
ns:RegisterEvent("ADDON_LOADED")

local function AddLevelToButton(button, itemLevel, itemQuality)
    if not itemLevel then
        return button.simpleilvl and button.simpleilvl:Hide()
    end

    if not button.simpleilvl then
        button.simpleilvl = button:CreateFontString('$parentItemLevel', 'ARTWORK')
        button.simpleilvl:SetPoint('TOPRIGHT', -2, -2)
        button.simpleilvl:SetFontObject(NumberFontNormal)
        button.simpleilvl:SetJustifyH('RIGHT')
    end

    local r, g, b, hex = GetItemQualityColor(itemQuality)
    button.simpleilvl:SetFormattedText('|c%s%s|r', hex, itemLevel or '?')
    button.simpleilvl:Show()
end

-- Character frame:

local function GetItemQualityAndLevel(unit, slotID)
    local itemID = GetInventoryItemID(unit, slotID)

    if itemID ~= nil then
        local quality = GetInventoryItemQuality(unit, slotID)
        local level = LIL.GetItemLevel(slotID, unit)

        return quality, level
    end
end
local function UpdateItemSlotButton(button, unit)
    local key = unit == "player" and "character" or "inspect"
    if not db[key] then
        return button.simpleilvl and button.simpleilvl:Hide()
    end
    local slotID = button:GetID()

    if (slotID >= INVSLOT_FIRST_EQUIPPED and slotID <= INVSLOT_LAST_EQUIPPED) then
        if unit == "player" then
            local item = Item:CreateFromEquipmentSlot(slotID)
            if item:IsItemEmpty() then
                return
            end
            return item:ContinueOnItemLoad(function()
                AddLevelToButton(button, item:GetCurrentItemLevel(), item:GetItemQuality())
            end)
        else
            local itemQuality, itemLevel = GetItemQualityAndLevel(unit, slotID)
            if itemLevel then
                return AddLevelToButton(button, itemLevel, itemQuality)
            end
        end
    end
    return button.simpleilvl and button.simpleilvl:Hide()
end
hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    UpdateItemSlotButton(button, "player")
end)

-- Inspect frame:

function ns:GET_ITEM_INFO_RECEIVED()
    if InspectFrame and InspectFrame:IsShown() then
        -- TODO: I think I need to schedule a flushed-cache a little while after the inspect happens. Artifact weapons are reliably not-quite-loaded.
        InspectPaperDollFrame_OnShow()
    end
end
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED")
function ns:ModInspectUI()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, "target")
    end)
end

-- Bags:

local function UpdateContainerButton(button, bag)
    if button.simpleilvl then button.simpleilvl:Hide() end
    if not db.bags then
        return
    end
    local slot = button:GetID()
    local item = Item:CreateFromBagAndSlot(bag, slot)
    if item:IsItemEmpty() then
        return
    end
    item:ContinueOnItemLoad(function()
        local itemID = item:GetItemID()
        local quality = item:GetItemQuality()
        local _, _, _, _, _, itemClass, itemSubClass = GetItemInfoInstant(itemID)
        if
            quality >= LE_ITEM_QUALITY_UNCOMMON and (
                itemClass == LE_ITEM_CLASS_WEAPON or
                itemClass == LE_ITEM_CLASS_ARMOR or
                (itemClass == LE_ITEM_CLASS_GEM and itemSubClass == LE_ITEM_GEM_ARTIFACTRELIC)
            )
        then
            AddLevelToButton(button, item:GetCurrentItemLevel(), quality)
        end
    end)
end

hooksecurefunc("ContainerFrame_Update", function(container)
    local bag = container:GetID()
    local name = container:GetName()
    for i = 1, container.size, 1 do
        local button = _G[name .. "Item" .. i]
        UpdateContainerButton(button, bag)
    end
end)

hooksecurefunc("BankFrameItemButton_Update", function(button)
    if not button.isBag then
        UpdateContainerButton(button, -1)
    end
end)

-- Quick config:

_G["SLASH_".. myname:upper().."1"] = "/simpleilvl"
SlashCmdList[myname:upper()] = function(msg)
    msg = msg:trim()
    if msg ~= "" and db[msg] ~= nil then
        db[msg] = not db[msg]

    end
    if msg == "" then
        ns.Print(SHOW_ITEM_LEVEL)
        ns.Print('bags -', BAGSLOTTEXT, "-", db.bags and YES or NO)
        ns.Print('character -', ORDER_HALL_EQUIPMENT_SLOTS, "-", db.character and YES or NO)
        ns.Print('inspect -', INSPECT, "-", db.inspect and YES or NO)
        ns.Print("To toggle: /simpleilvl [type]")
    end
end
