local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")
local db
local isClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE

local SLOT_MAINHAND = GetInventorySlotInfo("MainHandSlot")
local SLOT_OFFHAND = GetInventorySlotInfo("SecondaryHandSlot")

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

ns.upgradeString = CreateAtlasMarkup("poi-door-arrow-up")
ns.gemString = CreateAtlasMarkup(isClassic and "worldquest-icon-jewelcrafting" or "jailerstower-score-gem-tooltipicon") -- Professions-ChatIcon-Quality-Tier5-Cap
ns.enchantString = RED_FONT_COLOR:WrapTextInColorCode("E")
ns.Fonts = {
    HighlightSmall = GameFontHighlightSmall,
    Normal = GameFontNormalOutline,
    Large = GameFontNormalLargeOutline,
    Huge = GameFontNormalHugeOutline,
    NumberNormal = NumberFontNormal,
    NumberNormalSmall = NumberFontNormalSmall,
}
ns.PositionOffsets = {
    TOPLEFT = {2, -2},
    TOPRIGHT = {-2, -2},
    BOTTOMLEFT = {2, 2},
    BOTTOMRIGHT = {-2, 2},
    BOTTOM = {0, 2},
    TOP = {0, -2},
    LEFT = {2, 0},
    RIGHT = {-2, 0},
    CENTER = {0, 0},
}

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
    missinggems = true,
    missingenchants = true,
    -- appearance config
    font = "NumberNormal",
    position = "TOPRIGHT",
    positionup = "TOPLEFT",
    positionmissing = "LEFT",
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

ns.frames = {} -- TODO: should I make this a FramePool now?
local function PrepareItemButton(button)
    if not button.simpleilvl then
        local overlayFrame = CreateFrame("FRAME", nil, button)
        overlayFrame:SetAllPoints()
        overlayFrame:SetFrameLevel(button:GetFrameLevel() + 1)
        button.simpleilvloverlay = overlayFrame

        button.simpleilvl = overlayFrame:CreateFontString(nil, "OVERLAY")
        button.simpleilvl:Hide()

        button.simpleilvlup = overlayFrame:CreateTexture(nil, "OVERLAY")
        button.simpleilvlup:SetSize(8, 8)
        -- MiniMap-PositionArrowUp?
        button.simpleilvlup:SetAtlas("poi-door-arrow-up")
        button.simpleilvlup:Hide()

        button.simpleilvlmissing = overlayFrame:CreateFontString(nil, "OVERLAY")
        button.simpleilvlmissing:Hide()

        ns.frames[button] = overlayFrame
    end
    button.simpleilvloverlay:SetFrameLevel(button:GetFrameLevel() + 1)

    -- Apply appearance config:
    button.simpleilvl:ClearAllPoints()
    button.simpleilvl:SetPoint(db.position, unpack(ns.PositionOffsets[db.position]))
    button.simpleilvl:SetFontObject(ns.Fonts[db.font] or NumberFontNormal)
    -- button.simpleilvl:SetJustifyH('RIGHT')
    button.simpleilvlup:ClearAllPoints()
    button.simpleilvlup:SetPoint(db.positionup, unpack(ns.PositionOffsets[db.positionup]))

    button.simpleilvlmissing:ClearAllPoints()
    button.simpleilvlmissing:SetPoint(db.positionmissing, unpack(ns.PositionOffsets[db.positionmissing]))
    button.simpleilvlmissing:SetFont([[Fonts\ARIALN.TTF]], 11, "OUTLINE,MONOCHROME")
end
ns.PrepareItemButton = PrepareItemButton

local function CleanButton(button)
    if button.simpleilvl then button.simpleilvl:Hide() end
    if button.simpleilvlup then button.simpleilvlup:Hide() end
    if button.simpleilvlmissing then button.simpleilvlmissing:Hide() end
end
ns.CleanButton = CleanButton

function ns.RefreshOverlayFrames()
    for button in pairs(ns.frames) do
        PrepareItemButton(button)
    end
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
    if item:GetItemLocation() and item:GetItemLocation():IsEquipmentSlot() then
        -- This is meant to catch the character frame, to avoid rings/trinkets
        -- you've already got equipped showing as an upgrade since they're
        -- higher ilevel than your other ring/trinket
        return
    end
    ns.ForEquippedItems(equipLoc, function(equippedItem, slot)
        if equippedItem:IsItemEmpty() and slot == SLOT_OFFHAND then
            local mainhand = GetInventoryItemID("player", SLOT_MAINHAND)
            if mainhand then
                local invtype = select(4, GetItemInfoInstant(mainhand))
                if invtype == "INVTYPE_2HWEAPON" then
                    return
                end
            end
        end
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
local function AddMissingToButton(button, itemLink)
    if not itemLink then
        return button.simpleilvlmissing and button.simpleilvlmissing:Hide()
    end
    PrepareItemButton(button)
    local missingGems = db.missinggems and ns.ItemHasEmptySlots(itemLink)
    local missingEnchants =  db.missingenchants and ns.ItemIsMissingEnchants(itemLink)
    -- print(itemLink, missingEnchants, missingGems)
    button.simpleilvlmissing:SetFormattedText("%s%s", missingGems and ns.gemString or "", missingEnchants and ns.enchantString or "")
    button.simpleilvlmissing:Show()
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
    if not item or item:IsItemEmpty() then
        return
    end
    item:ContinueOnItemLoad(function()
        if not ShouldShowOnItem(item) then return end
        local itemID = item:GetItemID()
        local link = item:GetItemLink()
        local _, _, _, equipLoc, _, itemClass, itemSubClass = GetItemInfoInstant(itemID)
        local minLevel = link and select(5, GetItemInfo(link or itemID))
        AddLevelToButton(button, item:GetCurrentItemLevel(), item:GetItemQuality())
        AddUpgradeToButton(button, item, equipLoc, minLevel)
        AddMissingToButton(button, link)
    end)
end
ns.UpdateButtonFromItem = UpdateButtonFromItem

-- Character frame:

local function UpdateItemSlotButton(button, unit)
    CleanButton(button)
    local key = unit == "player" and "character" or "inspect"
    if not db[key] then
        return
    end
    local slotID = button:GetID()

    if (slotID >= INVSLOT_FIRST_EQUIPPED and slotID <= INVSLOT_LAST_EQUIPPED) then
        local item
        if unit == "player" then
            item = Item:CreateFromEquipmentSlot(slotID)
        else
            local itemID = GetInventoryItemID(unit, slotID)
            local itemLink = GetInventoryItemLink(unit, slotID)
            if itemLink or itemID then
                item = itemLink and Item:CreateFromItemLink(itemLink) or Item:CreateFromItemID(itemID)
            end
        end
        UpdateButtonFromItem(button, item)
    end
end
hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    UpdateItemSlotButton(button, "player")
end)
-- and the inspect frame
ns:RegisterAddonHook("Blizzard_InspectUI", function()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, InspectFrame.unit or "target")
    end)
end)

-- Equipment flyout in character frame

if _G.EquipmentFlyout_DisplayButton then
    hooksecurefunc("EquipmentFlyout_DisplayButton", function(button, paperDollItemSlot)
        -- print("EquipmentFlyout_DisplayButton", button, paperDollItemSlot)
        CleanButton(button)
        if not db.character then return end
        local location = button.location
        if not location then return end
        if location >= EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION then return end
        local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location)
        local item
        if bags then
            item = Item:CreateFromBagAndSlot(bag, slot)
        elseif not voidStorage then -- player or bank
            item = Item:CreateFromEquipmentSlot(slot)
        else
            local itemID = EquipmentManager_GetItemInfoByLocation(location)
            if itemID then
                item = Item:CreateFromItemID(itemID)
            end
        end
        if item then
            UpdateButtonFromItem(button, item)
        end
    end)
end

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
        local button = self.items[ToIndex(bag, slot)]
        if not button then return end
        if button:IsCached() then
            local item
            local icon, count, locked, quality, readable, lootable, link, noValue, itemID, isBound = button:GetInfo()
            if link then
                item = Item:CreateFromItemLink(link)
            elseif itemID then
                item = Item:CreateFromItemID(itemID)
            end
            UpdateButtonFromItem(button, item)
        else
            UpdateContainerButton(button, bag, slot)
        end
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
            return callback(item, slot)
        end
        item:ContinueOnItemLoad(function() callback(item, slot) end)
    end
    ns.ForEquippedItems = function(equipLoc, callback)
        ForEquippedItem(EquipLocToSlot1[equipLoc], callback)
        ForEquippedItem(EquipLocToSlot2[equipLoc], callback)
    end
end

do
    -- could arguably also do TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.GemSocket, ...)
    local t = {}
    function ns.ItemHasEmptySlots(itemLink)
        wipe(t)
        local stats = GetItemStats(itemLink, t)
        local slots = 0
        for label, stat in pairs(stats) do
            if label:match("EMPTY_SOCKET_") then
                slots = slots + 1
            end
        end
        if slots == 0 then return false end
        local gem1, gem2, gem3, gem4 = select(4, strsplit(":", itemLink))
        local gems = (gem1 ~= "" and 1 or 0) + (gem2 ~= "" and 1 or 0) + (gem3 ~= "" and 1 or 0) + (gem4 ~= "" and 1 or 0)
        return slots > gems
    end
    local enchantable = isClassic and {
        INVTYPE_HEAD = true,
        INVTYPE_SHOULDER = true,
        INVTYPE_CHEST = true,
        INVTYPE_ROBE = true,
        INVTYPE_LEGS = true,
        INVTYPE_FEET = true,
        INVTYPE_WRIST = true,
        INVTYPE_HAND = true,
        INVTYPE_FINGER = true,
        INVTYPE_CLOAK = true,
        INVTYPE_WEAPON = true,
        INVTYPE_SHIELD = true,
        INVTYPE_2HWEAPON = true,
        INVTYPE_WEAPONMAINHAND = true,
        INVTYPE_RANGED = true,
        INVTYPE_RANGEDRIGHT = true,
        INVTYPE_WEAPONOFFHAND = true,
        INVTYPE_HOLDABLE = true,
    } or {
        -- retail
        INVTYPE_CHEST = true,
        INVTYPE_ROBE = true,
        INVTYPE_FEET = true,
        INVTYPE_WRIST = true,
        INVTYPE_HAND = true,
        INVTYPE_FINGER = true,
        INVTYPE_CLOAK = true,
        INVTYPE_WEAPON = true,
        -- INVTYPE_SHIELD = true, -- ...are there?
        INVTYPE_2HWEAPON = true,
        INVTYPE_WEAPONMAINHAND = true,
        INVTYPE_RANGED = true,
        INVTYPE_RANGEDRIGHT = true,
        INVTYPE_WEAPONOFFHAND = true,
        INVTYPE_HOLDABLE = true,
    }
    function ns.ItemIsMissingEnchants(itemLink)
        if not itemLink then return false end
        local equipLoc = select(4, GetItemInfoInstant(itemLink))
        if not enchantable[equipLoc] then return false end
        local enchantID = select(3, strsplit(":", itemLink))
        if enchantID == "" then return true end
        return false
    end
end
