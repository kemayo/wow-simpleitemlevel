local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local db
local isClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE

function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

-- events
local hooks = {}
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if ns[event] then return ns[event](ns, event, ...) end end)
function ns:RegisterEvent(...) for i=1,select("#", ...) do f:RegisterEvent((select(i, ...))) end end
function ns:UnregisterEvent(...) for i=1,select("#", ...) do f:UnregisterEvent((select(i, ...))) end end
function ns:RegisterAddonHook(addon, callback)
    if IsAddOnLoaded(addon) then
        callback()
    else
        hooks[addon] = callback
    end
end

local LAI = LibStub("LibAppropriateItems-1.0")

ns.defaults = {
    character = true,
    inspect = true,
    bags = true,
    loot = true,
    upgrades = true,
    color = true,
    tooltip = isClassic,
    -- Shadowlands has Uncommon, BCC/Classic has Good
    quality = Enum.ItemQuality.Good or Enum.ItemQuality.Uncommon,
    equipmentonly = true,
    pointless = 5,
}

function ns:ADDON_LOADED(event, addon)
    if hooks[addon] then
        hooks[addon]()
        hooks[addon] = nil
    end
    if addon == myname then
        _G[myname.."DB"] = setmetatable(_G[myname.."DB"] or {}, {
            __index = ns.defaults,
        })
        db = _G[myname.."DB"]
        ns.db = db
    end
end
ns:RegisterEvent("ADDON_LOADED")

local function PrepareItemButton(button)
    if button.simpleilvl then
        button.simpleilvloverlay:SetFrameLevel(button:GetFrameLevel() + 1)
        return
    end

    local overlayFrame = CreateFrame("FRAME", nil, button)
    overlayFrame:SetAllPoints()
    overlayFrame:SetFrameLevel(button:GetFrameLevel() + 1)
    button.simpleilvloverlay = overlayFrame

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
local function AddUpgradeToButton(button, item, equipLoc, minLevel)
    if not (db.upgrades and LAI:IsAppropriate(item:GetItemID())) then
        return button.simpleilvlup and button.simpleilvlup:Hide()
    end
    ns.ForEquippedItems(equipLoc, function(equippedItem)
        if equippedItem:IsItemEmpty() or equippedItem:GetCurrentItemLevel() < item:GetCurrentItemLevel() then
            PrepareItemButton(button)
            button.simpleilvlup:Show()
            if minLevel and minLevel > UnitLevel("player") then
                button.simpleilvlup:SetVertexColor(1, 0, 0)
            else
                button.simpleilvlup:SetVertexColor(1, 1, 1)
            end
        end
    end)
end
local function ShouldShowOnItem(item)
    local quality = item:GetItemQuality()
    if quality < db.quality then
        return false
    end
    if not db.equipmentonly then
        return true
    end
    local _, _, _, equipLoc, _, itemClass, itemSubClass = GetItemInfoInstant(item:GetItemID())
    return (
        itemClass == Enum.ItemClass.Weapon or
        itemClass == Enum.ItemClass.Armor or
        (itemClass == Enum.ItemClass.Gem and itemSubClass == Enum.ItemGemSubclass.Artifactrelic)
    )
end
local function UpdateButtonFromItem(button, item)
    if item:IsItemEmpty() then
        return
    end
    item:ContinueOnItemLoad(function()
        if not ShouldShowOnItem(item) then return end
        local itemID = item:GetItemID()
        local link = item:GetItemLink()
        local quality = item:GetItemQuality()
        local _, _, _, equipLoc, _, itemClass, itemSubClass = GetItemInfoInstant(itemID)
        local minLevel = link and select(5, GetItemInfo(link or itemID))
        AddLevelToButton(button, item:GetCurrentItemLevel(), quality)
        AddUpgradeToButton(button, item, equipLoc, minLevel)
    end)
end
local function CleanButton(button)
    if button.simpleilvl then button.simpleilvl:Hide() end
    if button.simpleilvlup then button.simpleilvlup:Hide() end
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
    CleanButton(button)
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
    return CleanButton(button)
end
hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    UpdateItemSlotButton(button, "player")
end)

-- Inspect frame:

ns:RegisterAddonHook("Blizzard_InspectUI", function()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, "target")
    end)
end)

-- Bags:

local function UpdateContainerButton(button, bag, slot)
    CleanButton(button)
    if not db.bags then
        return
    end
    local item = Item:CreateFromBagAndSlot(bag, slot or button:GetID())
    UpdateButtonFromItem(button, item)
end

if _G.ContainerFrame_Update then
    hooksecurefunc("ContainerFrame_Update", function(container)
        local bag = container:GetID()
        local name = container:GetName()
        for i = 1, container.size, 1 do
            local button = _G[name .. "Item" .. i]
            UpdateContainerButton(button, bag)
        end
    end)
else
    local update = function(frame)
        for _, itemButton in frame:EnumerateValidItems() do
            UpdateContainerButton(itemButton, itemButton:GetBagID(), itemButton:GetID())
        end
    end
    -- can't use ContainerFrameUtil_EnumerateContainerFrames because it depends on the combined bags setting
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", update)
    for _, frame in ipairs(UIParent.ContainerFrames) do
        hooksecurefunc(frame, "UpdateItems", update)
    end
end

hooksecurefunc("BankFrameItemButton_Update", function(button)
    if not button.isBag then
        UpdateContainerButton(button, button:GetParent():GetID())
    end
end)

-- Loot

if _G.LootFrame_UpdateButton then
    -- Classic
    hooksecurefunc("LootFrame_UpdateButton", function(index)
        local button = _G["LootButton"..index]
        if not button then return end
        CleanButton(button)
        if not db.loot then return end
        -- ns.Debug("LootFrame_UpdateButton", button:IsEnabled(), button.slot, button.slot and GetLootSlotLink(button.slot))
        if button:IsEnabled() and button.slot then
            local link = GetLootSlotLink(button.slot)
            if link then
                UpdateButtonFromItem(button, Item:CreateFromItemLink(link))
            end
        end
    end)
else
    -- Dragonflight
    local function handleSlot(frame)
        if not frame.Item then return end
        CleanButton(frame.Item)
        if not db.loot then return end
        local data = frame:GetElementData()
        if not (data and data.slotIndex) then return end
        local link = GetLootSlotLink(data.slotIndex)
        if link then
            UpdateButtonFromItem(frame.Item, Item:CreateFromItemLink(link))
        end
    end
    LootFrame.ScrollBox:RegisterCallback("OnUpdate", function(...)
        LootFrame.ScrollBox:ForEachFrame(handleSlot)
    end)
end

-- Tooltip

local OnTooltipSetItem = function(self)
    if not db.tooltip then return end
    local _, itemLink = self:GetItem()
    if not itemLink then return end
    local item = Item:CreateFromItemLink(itemLink)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        self:AddLine(ITEM_LEVEL:format(item:GetCurrentItemLevel()))
    end)
end
if _G.TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)
else
    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    -- This is mostly world quest rewards:
    if GameTooltip.ItemTooltip then
        GameTooltip.ItemTooltip.Tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
end

-- Void Storage

ns:RegisterAddonHook("Blizzard_VoidStorageUI", function()
    local VOID_STORAGE_MAX = 80
    hooksecurefunc("VoidStorage_ItemsUpdate", function(doStorage, doContents)
        if not doContents then return end
        for i = 1, VOID_STORAGE_MAX do
            local itemID, textureName, locked, recentDeposit, isFiltered, quality = GetVoidItemInfo(VoidStorageFrame.page, i)
            local button = _G["VoidStorageStorageButton"..i]
            CleanButton(button)
            if itemID and db.bags then
                local link = GetVoidItemHyperlinkString(((VoidStorageFrame.page - 1) * VOID_STORAGE_MAX) + i)
                if link then
                    local item = Item:CreateFromItemLink(link)
                    UpdateButtonFromItem(button, item)
                end
            end
        end
    end)
end)

-- Inventorian
ns:RegisterAddonHook("Inventorian", function()
    local inv = LibStub("AceAddon-3.0", true):GetAddon("Inventorian", true)
    local function ToIndex(bag, slot) -- copied from inside Inventorian
        return (bag < 0 and bag * 100 - slot) or (bag * 100 + slot)
    end
    local function invContainerUpdateSlot(self, bag, slot)
        if not self.items[ToIndex(bag, slot)] then return end
        UpdateContainerButton(self.items[ToIndex(bag, slot)], bag, slot)
    end
    local function hookInventorian()
        hooksecurefunc(inv.bag.itemContainer, "UpdateSlot", invContainerUpdateSlot)
        hooksecurefunc(inv.bank.itemContainer, "UpdateSlot", invContainerUpdateSlot)
    end
    if inv.bag then
        hookInventorian()
    else
        hooksecurefunc(inv, "OnEnable", function()
            hookInventorian()
        end)
    end
end)

--Baggins:
ns:RegisterAddonHook("Baggins", function()
    hooksecurefunc(Baggins, "UpdateItemButton", function(baggins, bagframe, button, bag, slot)
        UpdateContainerButton(button, bag)
    end)
end)

--Bagnon:
ns:RegisterAddonHook("Bagnon", function()
    hooksecurefunc(Bagnon.Item, "Update", function(frame)
        local bag = frame:GetBag()
        UpdateContainerButton(frame, bag)
    end)
end)

--Combuctor (exactly same internals as Bagnon):
ns:RegisterAddonHook("Combuctor", function()
    hooksecurefunc(Combuctor.Item, "Update", function(frame)
        local bag = frame:GetBag()
        UpdateContainerButton(frame, bag)
    end)
end)

--LiteBag:
ns:RegisterAddonHook("LiteBag", function()
    _G.LiteBag_RegisterHook('LiteBagItemButton_Update', function(frame)
        local bag = frame:GetParent():GetID()
        UpdateContainerButton(frame, bag)
    end)
end)

-- Quick config:

_G["SLASH_".. myname:upper().."1"] = "/simpleilvl"
SlashCmdList[myname:upper()] = function(msg)
    msg = msg:trim()
    if msg:match("^quality") then
        local quality = msg:match("quality (.+)") or ""
        if quality:match("^%d+$") then
            quality = tonumber(quality)
        else
            quality = quality:lower()
            for label, value in pairs(Enum.ItemQuality) do
                if label:lower() == quality then
                    quality = value
                end
            end
        end
        if type(quality) ~= "number" then
            return ns.Print("Invalid item quality provided, should be a name or a number 0-8")
        end
        db.quality = quality
        return ns.Print("quality = ", _G["ITEM_QUALITY" .. db.quality .. "_DESC"])
    end
    if db[msg] ~= nil then
        db[msg] = not db[msg]
        return ns.Print(msg, '=', db[msg] and YES or NO)
    end
    if msg == "" then
        ns.Print(SHOW_ITEM_LEVEL)
        ns.Print('bags -', BAGSLOTTEXT, "-", db.bags and YES or NO)
        ns.Print('character -', ORDER_HALL_EQUIPMENT_SLOTS, "-", db.character and YES or NO)
        ns.Print('inspect -', INSPECT, "-", db.inspect and YES or NO)
        ns.Print('loot -', LOOT, "-", db.loot and YES or NO)
        ns.Print('upgrades - Upgrade arrows in bags', "-", db.upgrades and YES or NO)
        ns.Print('color - Color item level by item quality', "-", db.color and YES or NO)
        if isClassic then
            ns.Print('tooltip - Add the item level to tooltips', "-", db.tooltip and YES or NO)
        end
        ns.Print('quality - Minimum item quality to show for', "-", _G["ITEM_QUALITY" .. db.quality .. "_DESC"])
        ns.Print('equipmentonly - Only show on equippable items', "-", db.equipmentonly and YES or NO)
        ns.Print("To toggle: /simpleilvl [type]")
        ns.Print("To set a quality: /simpleilvl quality [quality]")
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
