local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local db

function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

-- events
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if ns[event] then return ns[event](ns, event, ...) end end)
function ns:RegisterEvent(...) for i=1,select("#", ...) do f:RegisterEvent((select(i, ...))) end end
function ns:UnregisterEvent(...) for i=1,select("#", ...) do f:UnregisterEvent((select(i, ...))) end end

local LAI = LibStub("LibAppropriateItems-1.0")

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
                upgrades = true,
                color = true,
            },
        })
        db = _G[myname.."DB"]
    end
end
ns:RegisterEvent("ADDON_LOADED")

local function PrepareItemButton(button)
    if button.simpleilvl then
        return
    end

    local overlayFrame = CreateFrame("FRAME", nil, button)
    overlayFrame:SetFrameLevel(4) -- Azerite overlay must be overlaid itself...
    overlayFrame:SetAllPoints()

    button.simpleilvl = overlayFrame:CreateFontString('$parentItemLevel', 'OVERLAY')
    button.simpleilvl:SetPoint('TOPRIGHT', -2, -2)
    button.simpleilvl:SetFontObject(NumberFontNormal)
    button.simpleilvl:SetJustifyH('RIGHT')
    button.simpleilvl:Hide()

    button.simpleilvlup = overlayFrame:CreateTexture(nil, "OVERLAY")
    button.simpleilvlup:SetSize(8, 8)
    button.simpleilvlup:SetPoint('TOPLEFT', 2, -2)
    -- MiniMap-PositionArrowUp?
    button.simpleilvlup:SetAtlas("poi-door-arrow-up")
    button.simpleilvlup:Hide()
end
local function AddLevelToButton(button, itemLevel, itemQuality)
    if not itemLevel then
        return button.simpleilvl and button.simpleilvl:Hide()
    end
    PrepareItemButton(button)
    local _, _, _, hex = GetItemQualityColor(db.color and itemQuality or 1)
    button.simpleilvl:SetFormattedText('|c%s%s|r', hex, itemLevel or '?')
    button.simpleilvl:Show()
end
local function AddUpgradeToButton(button, item, equipLoc)
    if not (db.upgrades and LAI:IsAppropriate(item:GetItemID())) then
        return button.simpleilvlup and button.simpleilvlup:Hide()
    end
    ns.ForEquippedItems(equipLoc, function(equippedItem)
        if equippedItem:IsItemEmpty() or equippedItem:GetCurrentItemLevel() < item:GetCurrentItemLevel() then
            PrepareItemButton(button)
            button.simpleilvlup:Show()
        end
    end)
end

-- Character frame:

local function GetItemQualityAndLevel(unit, slotID)
    -- link is more reliably fetched than ID, for whatever reason
    local itemLink = GetInventoryItemLink(unit, slotID)

    if itemLink ~= nil then
        local quality = GetInventoryItemQuality(unit, slotID)
        local level = GetDetailedItemLevelInfo(itemLink)

        return quality, level
    end
end
local function UpdateItemSlotButton(button, unit)
    if button.simpleilvl then button.simpleilvl:Hide() end
    local key = unit == "player" and "character" or "inspect"
    if not db[key] then
        return
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

function ns:ModInspectUI()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, "target")
    end)
end

-- Bags:

local function UpdateContainerButton(button, bag)
    if button.simpleilvl then button.simpleilvl:Hide() end
    if button.simpleilvlup then button.simpleilvlup:Hide() end
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
        local _, _, _, equipLoc, _, itemClass, itemSubClass = GetItemInfoInstant(itemID)
        if
            quality >= Enum.ItemQuality.Uncommon and (
                itemClass == LE_ITEM_CLASS_WEAPON or
                itemClass == LE_ITEM_CLASS_ARMOR or
                (itemClass == LE_ITEM_CLASS_GEM and itemSubClass == LE_ITEM_GEM_ARTIFACTRELIC)
            )
        then
            AddLevelToButton(button, item:GetCurrentItemLevel(), quality)
            AddUpgradeToButton(button, item, equipLoc)
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

-- Inventorian
local inv = LibStub("AceAddon-3.0"):GetAddon("Inventorian", true)
if inv then
    hooksecurefunc(inv.Item.prototype, "Update", function(self, ...)
        UpdateContainerButton(self, self.bag)
    end)
end

--Baggins:
if Baggins then
    hooksecurefunc(Baggins, "UpdateItemButton", function(baggins, bagframe, button, bag, slot)
        UpdateContainerButton(button, bag)
    end)
end

--Bagnon:
if Bagnon then
    hooksecurefunc(Bagnon.Item, "Update", function(frame)
        local bag = frame:GetBag()
        UpdateContainerButton(frame, bag)
    end)
end

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
        ns.Print('upgrades - Upgrade arrows in bags', db.upgrades and YES or NO)
        ns.Print('color - Color item level by item quality', db.color and YES or NO)
        ns.Print("To toggle: /simpleilvl [type]")
    end
end

-- helper

do
    local EquipLocToSlot1 = {
        INVTYPE_HEAD = 1,
        INVTYPE_NECK = 2,
        INVTYPE_SHOULDER = 3,
        INVTYPE_BODY = 4,
        INVTYPE_CHEST = 5,
        INVTYPE_ROBE = 5,
        INVTYPE_WAIST = 6,
        INVTYPE_LEGS = 7,
        INVTYPE_FEET = 8,
        INVTYPE_WRIST = 9,
        INVTYPE_HAND = 10,
        INVTYPE_FINGER = 11,
        INVTYPE_TRINKET = 13,
        INVTYPE_CLOAK = 15,
        INVTYPE_WEAPON = 16,
        INVTYPE_SHIELD = 17,
        INVTYPE_2HWEAPON = 16,
        INVTYPE_WEAPONMAINHAND = 16,
        INVTYPE_RANGED = 16,
        INVTYPE_RANGEDRIGHT = 16,
        INVTYPE_WEAPONOFFHAND = 17,
        INVTYPE_HOLDABLE = 17,
        INVTYPE_TABARD = 19,
    }
    local EquipLocToSlot2 = {
        INVTYPE_FINGER = 12,
        INVTYPE_TRINKET = 14,
        INVTYPE_WEAPON = 17,
    }
    local ForEquippedItem = function(slot, callback)
        if not slot then
            return
        end
        local item = Item:CreateFromEquipmentSlot(slot)
        if item:IsItemEmpty() then
            return callback(item)
        end
        item:ContinueOnItemLoad(function() callback(item) end)
    end
    ns.ForEquippedItems = function(equipLoc, callback)
        ForEquippedItem(EquipLocToSlot1[equipLoc], callback)
        ForEquippedItem(EquipLocToSlot2[equipLoc], callback)
    end
end
