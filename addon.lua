local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")
local db
local isClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
ns.DEBUG = C_AddOns.GetAddOnMetadata(myname, "Version") == "@".."project-version@"

_G.SimpleItemLevel = {}

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
    if C_AddOns.IsAddOnLoaded(addon) then
        xpcall(callback, geterrorhandler())
    else
        hooks[addon] = callback
    end
end

local LAI = LibStub("LibAppropriateItems-1.0")

ns.soulboundAtlas = isClassic and "AzeriteReady" or "Soulbind-32x32" -- UF-SoulShard-Icon-2x
ns.upgradeAtlas = "poi-door-arrow-up"
ns.upgradeString = CreateAtlasMarkup(ns.upgradeAtlas)
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
    -- places
    character = true,
    inspect = true,
    bags = true,
    loot = true,
    flyout = true,
    tooltip = isClassic,
    characteravg = isClassic,
    inspectavg = true,
    -- equipmentonly = true,
    equipment = true,
    battlepets = true,
    reagents = false,
    misc = false,
    -- data points
    itemlevel = true,
    upgrades = true,
    missinggems = true,
    missingenchants = true,
    missingcharacter = true, -- missing on character-frame only
    bound = true,
    -- display
    color = true,
    -- Retail has Uncommon, BCC/Classic has Good
    quality = Enum.ItemQuality.Common or Enum.ItemQuality.Standard,
    -- appearance config
    font = "NumberNormal",
    position = "TOPRIGHT",
    positionup = "TOPLEFT",
    positionmissing = "LEFT",
    positionbound = "BOTTOMLEFT",
    scaleup = 1,
    scalebound = 1,
}

function ns:ADDON_LOADED(event, addon)
    if hooks[addon] then
        xpcall(hooks[addon], geterrorhandler())
        hooks[addon] = nil
    end
    if addon == myname then
        _G[myname.."DB"] = setmetatable(_G[myname.."DB"] or {}, {
            __index = ns.defaults,
        })
        db = _G[myname.."DB"]
        ns.db = db

        ns:SetupConfig()

        -- So our upgrade arrows can work reliably when opening inventories
        ns.CacheEquippedItems()
    end
end
ns:RegisterEvent("ADDON_LOADED")


local function ItemIsUpgrade(item)
    if not (item and LAI:IsAppropriate(item:GetItemID())) then
        return
    end
    -- Upgrade?
    if item:GetItemLocation() and item:GetItemLocation():IsEquipmentSlot() then
        -- This is meant to catch the character frame, to avoid rings/trinkets
        -- you've already got equipped showing as an upgrade since they're
        -- higher ilevel than your other ring/trinket
        return
    end
    local isUpgrade
    local itemLevel = item:GetCurrentItemLevel() or 0
    local _, _, _, equipLoc, _, itemClass, itemSubClass = C_Item.GetItemInfoInstant(item:GetItemID())
    ns.ForEquippedItems(equipLoc, function(equippedItem, slot)
        -- This *isn't* async, for flow reasons, so if the equipped items
        -- aren't yet cached the item might get incorrectly flagged as an
        -- upgrade.
        if equippedItem:IsItemEmpty() and slot == SLOT_OFFHAND then
            local mainhand = GetInventoryItemID("player", SLOT_MAINHAND)
            if mainhand then
                local invtype = select(4, C_Item.GetItemInfoInstant(mainhand))
                if invtype == "INVTYPE_2HWEAPON" then
                    return
                end
            end
        end
        if not equippedItem:IsItemDataCached() then
            -- don't claim an upgrade if we don't know
            return
        end
        -- fallbacks for the item levels; saw complaints of this erroring during initial login for people using Bagnon and AdiBags
        local equippedItemLevel = equippedItem:GetCurrentItemLevel() or 0
        if equippedItem:IsItemEmpty() or equippedItemLevel < itemLevel then
            isUpgrade = true
            local minLevel = select(5, C_Item.GetItemInfo(item:GetItemLink() or item:GetItemID()))
            if minLevel and minLevel > UnitLevel("player") then
                -- not equipable yet
            end
        end
    end)
    return isUpgrade
end
ns.ItemIsUpgrade = ItemIsUpgrade

-- TODO: this is a good candidate for caching results...
local function DetailsFromItemInstant(item)
    if not item or item:IsItemEmpty() then return {} end
    -- print("DetailsFromItem", item:GetItemLink())
    local itemLevel = item:GetCurrentItemLevel()
    local quality = item:GetItemQuality()
    local itemLink = item:GetItemLink()
    if itemLink and itemLink:match("battlepet:") then
        -- special case for caged battle pets
        local _, speciesID, level, breedQuality = ns.GetLinkValues(itemLink)
        if speciesID and level and breedQuality then
            itemLevel = tonumber(level)
            quality = tonumber(breedQuality)
        end
    end
    return {
        level = itemLevel,
        quality = quality,
        link = itemLink,
    }
end
ns.DetailsFromItemInstant = DetailsFromItemInstant

local function DetailsFromItem(item)
    if not item or item:IsItemEmpty() then return {} end
    local details = DetailsFromItemInstant(item)
    details.missingGems = ns.ItemHasEmptySlots(details.link)
    details.missingEnchants = ns.ItemIsMissingEnchants(details.link)
    details.upgrade = ItemIsUpgrade(item)

    if C_Item.IsItemBindToAccountUntilEquip and details.link then
        -- 11.0.2 adds this, which works on any item:
        details.warboundUntilEquip = C_Item.IsItemBindToAccountUntilEquip(details.link)
    end
    if item:IsItemInPlayersControl() then
        local itemLocation = item:GetItemLocation()
        -- this only works on items in our control:
        details.warboundUntilEquip = C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(itemLocation)
        details.bound = C_Item.IsBound(itemLocation)
        if details.bound then
            -- As of 11.0.0 blizzard has created Enum.ItemBind entries for
            -- warbound, but never uses them. Zepto worked out that we can
            -- use "can I put it in the warbank?" as a proxy to distinguish,
            -- even when we're not at the bank.
            -- TODO: occasionally check whether the bindTypes start getting
            -- returned via `select (14, C_Item.GetItemInfo(details.link)) == 7/8/9`
            details.warbound = C_Bank and C_Bank.IsItemAllowedInBankType and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation)
        end
    end

    return details
end
ns.DetailsFromItem = DetailsFromItem

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
        button.simpleilvlup:SetSize(10, 10)
        -- MiniMap-PositionArrowUp?
        button.simpleilvlup:SetAtlas("poi-door-arrow-up")
        button.simpleilvlup:Hide()

        button.simpleilvlmissing = overlayFrame:CreateFontString(nil, "OVERLAY")
        button.simpleilvlmissing:Hide()

        button.simpleilvlbound = overlayFrame:CreateTexture(nil, "OVERLAY")
        button.simpleilvlbound:SetSize(10, 10)
        button.simpleilvlbound:SetAtlas(ns.soulboundAtlas) -- Soulbind-32x32
        button.simpleilvlbound:Hide()

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
    button.simpleilvlup:SetScale(db.scaleup)

    button.simpleilvlmissing:ClearAllPoints()
    button.simpleilvlmissing:SetPoint(db.positionmissing, unpack(ns.PositionOffsets[db.positionmissing]))
    button.simpleilvlmissing:SetFont([[Fonts\ARIALN.TTF]], 11, "OUTLINE,MONOCHROME")

    button.simpleilvlbound:ClearAllPoints()
    button.simpleilvlbound:SetPoint(db.positionbound, unpack(ns.PositionOffsets[db.positionbound]))
    button.simpleilvlbound:SetScale(db.scalebound)
end
ns.PrepareItemButton = PrepareItemButton

local blank = {}
local function CleanButton(button, suppress)
    suppress = suppress or blank
    if button.simpleilvl and not suppress.level then button.simpleilvl:Hide() end
    if button.simpleilvlup and not suppress.upgrade then button.simpleilvlup:Hide() end
    if button.simpleilvlmissing and not suppress.missing then button.simpleilvlmissing:Hide() end
    if button.simpleilvlbound and not suppress.bound then button.simpleilvlbound:Hide() end
end
ns.CleanButton = CleanButton

function ns.RefreshOverlayFrames()
    for button in pairs(ns.frames) do
        PrepareItemButton(button)
    end
end

local function AddLevelToButton(button, details)
    if not (db.itemlevel and details.level) then
        return button.simpleilvl:Hide()
    end
    local r, g, b = C_Item.GetItemQualityColor(db.color and details.quality or 1)
    button.simpleilvl:SetText(details.level or '?')
    button.simpleilvl:SetTextColor(r, g, b)
    button.simpleilvl:Show()
end
local function AddUpgradeToButton(button, details)
    if not (db.upgrades and details.upgrade) then
        return button.simpleilvlup:Hide()
    end
    local minLevel = select(5, C_Item.GetItemInfo(details.link))
    if minLevel and minLevel > UnitLevel("player") then
        button.simpleilvlup:SetVertexColor(1, 0, 0)
    else
        button.simpleilvlup:SetVertexColor(1, 1, 1)
    end
    button.simpleilvlup:Show()
end
local function AddMissingToButton(button, details)
    local missingGems = db.missinggems and details.missingGems
    local missingEnchants =  db.missingenchants and details.missingEnchants
    button.simpleilvlmissing:SetFormattedText("%s%s", missingGems and ns.gemString or "", missingEnchants and ns.enchantString or "")
    button.simpleilvlmissing:Show()
end

local function ColorFrameByBinding(frame, details)
    -- returns bool, whether is bound in some way
    if details.bound then
        if details.warbound then
            frame:SetVertexColor(0.5, 1, 0) -- green
        else
            frame:SetVertexColor(1, 1, 1) -- blue
        end
        return true
    elseif details.warboundUntilEquip then
        -- once you equip it the label changes to soulbound, but this property remains
        frame:SetVertexColor(1, 0.5, 1) -- pale purple
        return true
    end
    return false
end
local function AddBoundToButton(button, details)
    if not db.bound then
        return button.simpleilvlbound and button.simpleilvlbound:Hide()
    end
    if ColorFrameByBinding(button.simpleilvlbound, details) then
        button.simpleilvlbound:Show()
    end
end
local function ShouldShowOnItem(item)
    local quality = item:GetItemQuality() or -1
    if quality < db.quality then
        return false
    end
    local _, _, _, equipLoc, _, itemClass, itemSubClass = C_Item.GetItemInfoInstant(item:GetItemID())
    if (
        itemClass == Enum.ItemClass.Weapon or
        itemClass == Enum.ItemClass.Armor or
        (itemClass == Enum.ItemClass.Gem and itemSubClass == Enum.ItemGemSubclass.Artifactrelic)
    ) then
        return db.equipment
    end
    if item:GetItemID() == 82800 then
        -- Pet Cage
        return db.battlepets
    end
    if select(17, C_Item.GetItemInfo(item:GetItemID())) then
        return db.reagents
    end
    return db.misc
end
local function UpdateButtonFromItem(button, item, variant, suppress, extradetails)
    if not item or item:IsItemEmpty() then
        return
    end
    suppress = suppress or blank
    item:ContinueOnItemLoad(function()
        if not ShouldShowOnItem(item) then return end
        PrepareItemButton(button)
        local details = DetailsFromItem(item)
        if extradetails then MergeTable(details, extradetails) end
        if not suppress.level then AddLevelToButton(button, details) end
        if not suppress.upgrade then AddUpgradeToButton(button, details) end
        if not suppress.bound then AddBoundToButton(button, details) end
        if (variant == "character" or variant == "inspect" or not db.missingcharacter) then
            if not suppress.missing then AddMissingToButton(button, details) end
        end
    end)
    return true
end
ns.UpdateButtonFromItem = UpdateButtonFromItem

local continuableContainer
local function AddAverageLevelToFontString(unit, fontstring)
    if not fontstring then return end
    if not continuableContainer then
        continuableContainer = ContinuableContainer:Create()
    end
    fontstring:Hide()
    local key = unit == "player" and "character" or "inspect"
    if not db[key .. "avg"] then
        return
    end
    local mainhandEquipLoc, offhandEquipLoc
    local items = {}
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        -- shirt and tabard don't count
        if slot ~= INVSLOT_BODY and slot ~= INVSLOT_TABARD then
            local itemID = GetInventoryItemID(unit, slot)
            local itemLink = GetInventoryItemLink(unit, slot)
            if itemLink or itemID then
                local item = itemLink and Item:CreateFromItemLink(itemLink) or Item:CreateFromItemID(itemID)
                continuableContainer:AddContinuable(item)
                table.insert(items, item)
                -- slot bookkeeping
                local equipLoc = select(4, C_Item.GetItemInfoInstant(itemLink or itemID))
                if slot == INVSLOT_MAINHAND then mainhandEquipLoc = equipLoc end
                if slot == INVSLOT_OFFHAND then offhandEquipLoc = equipLoc end
            end
        end
    end
    local numSlots
    if mainhandEquipLoc and offhandEquipLoc then
        numSlots = 16
    else
        local isFuryWarrior = select(2, UnitClass(unit)) == "WARRIOR"
        if unit == "player" then
            isFuryWarrior = isFuryWarrior and IsSpellKnown(46917) -- knows titan's grip
        else
            isFuryWarrior = isFuryWarrior and _G.GetInspectSpecialization and GetInspectSpecialization(unit) == 72
        end
        -- unit is holding a one-handed weapon, a main-handed weapon, or a 2h weapon while Fury: 16 slots
        -- otherwise 15 slots
        local equippedLocation = mainhandEquipLoc or offhandEquipLoc
        numSlots = (
            equippedLocation == "INVTYPE_WEAPON" or
            equippedLocation == "INVTYPE_WEAPONMAINHAND" or
            (equippedLocation == "INVTYPE_2HWEAPON" and isFuryWarrior)
        ) and 16 or 15
    end
    if pcall(GetInventorySlotInfo, "RANGEDSLOT") then
         -- ranged slot exists until Pandaria
        numSlots = numSlots + 1
    end
    continuableContainer:ContinueOnLoad(function()
        local totalLevel = 0
        for _, item in ipairs(items) do
            totalLevel = totalLevel + item:GetCurrentItemLevel()
        end
        fontstring:SetFormattedText(ITEM_LEVEL, totalLevel / numSlots)
        fontstring:Show()
    end)
end

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
        UpdateButtonFromItem(button, item, key)
    end
end

do
    local levelUpdater = CreateFrame("Frame")
    levelUpdater:SetScript("OnUpdate", function(self)
        if not self.avglevel then
            if _G.CharacterModelFrame then
                self.avglevel = CharacterModelFrame:CreateFontString(nil, "OVERLAY")
                self.avglevel:SetPoint("BOTTOMLEFT", 5, 35)
            elseif _G.CharacterModelScene then
                self.avglevel = CharacterModelScene:CreateFontString(nil, "OVERLAY")
                self.avglevel:SetPoint("BOTTOM", 0, 20)
            end
            if self.avglevel then
                self.avglevel:SetFontObject(NumberFontNormal) -- GameFontHighlightSmall isn't bad
            end
        end
        AddAverageLevelToFontString("player", self.avglevel)
        self:Hide()
    end)
    levelUpdater:Hide()

    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, "player")
        levelUpdater:Show()
    end)
end

-- and the inspect frame
ns:RegisterAddonHook("Blizzard_InspectUI", function()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        UpdateItemSlotButton(button, InspectFrame.unit or "target")
    end)
    local avglevel
    hooksecurefunc("InspectPaperDollFrame_UpdateButtons", function()
        if not avglevel then
            avglevel = InspectModelFrame:CreateFontString(nil, "OVERLAY")
            avglevel:SetFontObject(NumberFontNormal)
            avglevel:SetPoint("BOTTOM", 0, isClassic and 0 or 20)
        end
        AddAverageLevelToFontString(InspectFrame.unit or "target", avglevel)
    end)
end)

-- Equipment flyout in character frame

if _G.EquipmentFlyout_DisplayButton then
    local function ItemFromEquipmentFlyoutDisplayButton(button)
        local flyoutSettings = EquipmentFlyoutFrame.button:GetParent().flyoutSettings
        if flyoutSettings.useItemLocation then
            local itemLocation = button:GetItemLocation()
            if itemLocation then
                return Item:CreateFromItemLocation(itemLocation)
            end
        else
            local location = button.location
            if not location then return end
            if location >= EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION then return end
            local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location)
            if type(voidStorage) ~= "boolean" then
                -- classic compatibility: no voidStorage returns, so shuffle everything down by one
                -- returns either `player, bank, bags (true), slot, bag` or `player, bank, bags (false), location`
                slot, bag = voidStorage, slot
            end
            if bags then
                return Item:CreateFromBagAndSlot(bag, slot)
            elseif not voidStorage then -- player or bank
                return Item:CreateFromEquipmentSlot(slot)
            else
                local itemID = EquipmentManager_GetItemInfoByLocation(location)
                if itemID then
                    return Item:CreateFromItemID(itemID)
                end
            end
        end
    end
    hooksecurefunc("EquipmentFlyout_UpdateItems", function()
        local flyoutSettings = EquipmentFlyoutFrame.button:GetParent().flyoutSettings
        for i, button in ipairs(EquipmentFlyoutFrame.buttons) do
            CleanButton(button)
            if db.flyout and button:IsShown() then
                local item = ItemFromEquipmentFlyoutDisplayButton(button)
                if item then
                    UpdateButtonFromItem(button, item, "character")
                end
            end
        end
    end)
end

-- Bags:

local function UpdateContainerButton(button, bag, slot)
    CleanButton(button)
    if not db.bags then
        return
    end
    slot = slot or button:GetID()
    if not (bag and slot) then
        return
    end
    local item = Item:CreateFromBagAndSlot(bag, slot or button:GetID())
    UpdateButtonFromItem(button, item, "bags")
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
    for _, frame in ipairs((ContainerFrameContainer or UIParent).ContainerFrames) do
        hooksecurefunc(frame, "UpdateItems", update)
    end
end

-- Main bank frame, bankbags are covered by containerframe above
hooksecurefunc("BankFrameItemButton_Update", function(button)
    if not button.isBag then
        UpdateContainerButton(button, button:GetParent():GetID())
    end
end)

if _G.AccountBankPanel then
    -- Warband bank
    local lastButtons = {} -- needed as of 11.0.0, see below for why
    local update = function(frame)
        table.wipe(lastButtons)
        for itemButton in frame:EnumerateValidItems() do
            UpdateContainerButton(itemButton, itemButton:GetBankTabID(), itemButton:GetContainerSlotID())
            table.insert(lastButtons, itemButton)
        end
    end
    -- Initial load and switching tabs
    hooksecurefunc(AccountBankPanel, "GenerateItemSlotsForSelectedTab", update)
    -- Moving items
    hooksecurefunc(AccountBankPanel, "RefreshAllItemsForSelectedTab", update)
    hooksecurefunc(AccountBankPanel, "SetItemDisplayEnabled", function(_, state)
        -- Papering over a Blizzard bug: when you open the "buy" tab, they
        -- call this which releases the itembuttons from the pool... but
        -- doesn't *hide* them, so they're all still there with the buy panel
        -- sitting one layer above them.
        -- I sadly need to remember the buttons, because once it released them
        -- they're no longer available via EnumerateValidItems.
        if state == false then
            for _, itemButton in ipairs(lastButtons) do
                CleanButton(itemButton)
            end
        end
    end)
end

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
                UpdateButtonFromItem(button, Item:CreateFromItemLink(link), "loot")
            end
        end
    end)
else
    -- Dragonflight
    local ITEM_LEVEL_PATTERN = ITEM_LEVEL:gsub("%%d", "(%%d+)")
    local function itemLevelFromLootTooltip(slot)
        -- GetLootSlotLink doesn't give a link for the scaled item you'll
        -- actually loot. As such, we can fall back on tooltip scanning to
        -- extract the real level. This is only going to work on
        -- weapons/armor, but conveniently that's the things that get scaled!
        if not _G.C_TooltipInfo then return end -- in case we get a weird Classic update...
        local info = C_TooltipInfo.GetLootItem(slot)
        if info and info.lines and info.lines[2] and info.lines[2].type == Enum.TooltipDataLineType.None then
            return tonumber(info.lines[2].leftText:match(ITEM_LEVEL_PATTERN))
        end
    end

    local function handleSlot(frame)
        if not frame.Item then return end
        CleanButton(frame.Item)
        if not db.loot then return end
        local data = frame:GetElementData()
        if not (data and data.slotIndex) then return end
        local link = GetLootSlotLink(data.slotIndex)
        if link then
            UpdateButtonFromItem(frame.Item, Item:CreateFromItemLink(link), "loot", nil, {
                level = itemLevelFromLootTooltip(data.slotIndex),
            })
        end
    end
    LootFrame.ScrollBox:RegisterCallback("OnUpdate", function(...)
        LootFrame.ScrollBox:ForEachFrame(handleSlot)
    end)
end

-- Tooltip

local OnTooltipSetItem = function(self)
    if not db.tooltip then return end
    local item
    if self.GetItem then
        local _, itemLink =  self:GetItem()
        if not itemLink then return end
        item = Item:CreateFromItemLink(itemLink)
    elseif self.GetPrimaryTooltipData then
        local data = self:GetPrimaryTooltipData()
        if data and data.guid and data.type == Enum.TooltipDataType.Item then
            item = Item:CreateFromItemGUID(data.guid)
        end
    end
    if not item or item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        self:AddLine(ITEM_LEVEL:format(item:GetCurrentItemLevel()))
    end)
end
if _G.C_TooltipInfo then
    -- Cata-classic has TooltipDataProcessor, but doesn't actually use the new tooltips
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
                    UpdateButtonFromItem(button, item, "bags")
                end
            end
        end
    end)
end)

-- Guild Bank

ns:RegisterAddonHook("Blizzard_GuildBankUI", function()
    hooksecurefunc(GuildBankFrame, "Update", function(self)
        if self.mode ~= "bank" then return end
        local tab = GetCurrentGuildBankTab()
        for _, column in ipairs(self.Columns) do
            for _, button in ipairs(column.Buttons) do
                CleanButton(button)
                local link = GetGuildBankItemLink(tab, button:GetID())
                if link then
                    local item = Item:CreateFromItemLink(link)
                    UpdateButtonFromItem(button, item, "bags")
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
            CleanButton(button)
            UpdateButtonFromItem(button, item, "bags")
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
do
    local function bagbrother_button(button)
        CleanButton(button)
        if not db.bags then
            return
        end
        local bag = button:GetBag()
        if type(bag) ~= "number" or button:GetClassName() ~= "BagnonContainerItem" then
            local info = button:GetInfo()
            if info and info.hyperlink then
                local item = Item:CreateFromItemLink(info.hyperlink)
                UpdateButtonFromItem(button, item, "bags")
            end
            return
        end
        UpdateContainerButton(button, bag)
    end
    ns:RegisterAddonHook("Bagnon", function()
        hooksecurefunc(Bagnon.Item, "Update", bagbrother_button)
    end)

    --Bagnonium (exactly same internals as Bagnon):
    ns:RegisterAddonHook("Bagnonium", function()
        hooksecurefunc(Bagnonium.Item, "Update", bagbrother_button)
    end)

    --Combuctor (exactly same internals as Bagnon):
    ns:RegisterAddonHook("Combuctor", function()
        hooksecurefunc(Combuctor.Item, "Update", bagbrother_button)
    end)
end

--LiteBag:
ns:RegisterAddonHook("LiteBag", function()
    _G.LiteBag_RegisterHook('LiteBagItemButton_Update', function(frame)
        local bag = frame:GetParent():GetID()
        UpdateContainerButton(frame, bag)
    end)
end)

-- Baganator
ns:RegisterAddonHook("Baganator", function()
    local function textInit(itemButton)
        local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        text.sizeFont = true
        return text
    end
    -- Note to self: Baganator API update function returns are tri-state:
    -- true: something to show
    -- false: nothing to show
    -- nil: call this again soon (probably because of item-caching)
    local function onUpdate(callback)
        return function(cornerFrame, details)
            if not details.itemLink then return false end
            local button = cornerFrame:GetParent():GetParent()
            local item
            -- If we have a container-item, we should use that because it's needed for soulbound detection
            local bag, slot = button:GetParent():GetID(), button:GetID()
            -- print("SetItemDetails", details.itemLink, bag, slot)
            if bag and slot and slot ~= 0 then
                item = Item:CreateFromBagAndSlot(bag, slot)
            elseif details.itemLink then
                item = Item:CreateFromItemLink(details.itemLink)
            end
            if not item then return false end -- no item, go away
            if not item:IsItemDataCached() then return nil end -- item isn't cached, come back in a second
            local data = DetailsFromItem(item)
            return callback(cornerFrame, item, data, details)
        end
    end
    Baganator.API.RegisterCornerWidget("sIlvl: Item Level", "simpleitemlevel-ilvl",
        onUpdate(function(cornerFrame, item, data, details)
            cornerFrame:SetText(data.level)
            if db.color and data.quality then
                local r, g, b = C_Item.GetItemQualityColor(data.quality)
                cornerFrame:SetTextColor(r, g, b)
            else
                cornerFrame:SetTextColor(1, 1, 1)
            end
            return true
        end),
        textInit, {default_position = "top_right", priority = 1}
    )
    Baganator.API.RegisterCornerWidget("sIlvl: Upgrade", "simpleitemlevel-upgrade",
        onUpdate(function(cornerFrame, item, data, details)
            if data.upgrade then
                local minLevel = select(5, C_Item.GetItemInfo(item:GetItemLink() or item:GetItemID()))
                if minLevel and minLevel > UnitLevel("player") then
                    cornerFrame:SetVertexColor(1, 0, 0)
                else
                    cornerFrame:SetVertexColor(1, 1, 1)
                end
                return true
            end
            return false
        end),
        function (itemButton)
            local texture = itemButton:CreateTexture(nil, "ARTWORK")
            texture:SetAtlas(ns.upgradeAtlas)
            texture:SetSize(11, 11)
            return texture
        end,
        {default_position = "top_left", priority = 1}
    )
    Baganator.API.RegisterCornerWidget("sIlvl: Soulbound", "simpleitemlevel-bound",
        onUpdate(function(cornerFrame, item, data, details)
            return ColorFrameByBinding(cornerFrame, data)
        end),
        function (itemButton)
            local texture = itemButton:CreateTexture(nil, "ARTWORK")
            texture:SetAtlas(ns.soulboundAtlas)
            texture:SetSize(12, 12)
            return texture
        end, {default_position = "bottom_left", priority = 1}
    )
    Baganator.API.RegisterCornerWidget("sIlvl: Missing", "simpleitemlevel-missing",
        onUpdate(function(cornerFrame, item, data, details)
            if db.missingcharacter then return false end
            local missingGems = db.missinggems and data.missingGems
            local missingEnchants =  db.missingenchants and data.missingEnchants
            if missingGems or missingEnchants then
                cornerFrame:SetFormattedText("%s%s", missingGems and ns.gemString or "", missingEnchants and ns.enchantString or "")
                return true
            end
            return false
        end),
        textInit, {default_position = "bottom_right", priority = 2}
    )
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
        return callback(item, slot)
    end
    ns.ForEquippedItems = function(equipLoc, callback)
        ForEquippedItem(EquipLocToSlot1[equipLoc], callback)
        ForEquippedItem(EquipLocToSlot2[equipLoc], callback)
    end
end

ns.CacheEquippedItems = function()
    for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
end

do
    -- could arguably also do TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.GemSocket, ...)
    local GetItemStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    function ns.ItemHasEmptySlots(itemLink)
        if not itemLink then return end
        local stats = GetItemStats(itemLink)
        if not stats then return false end -- caged battle pets, mostly
        local slots = 0
        for label, stat in pairs(stats) do
            if label:match("EMPTY_SOCKET_") then
                slots = slots + 1
            end
        end
        if slots == 0 then return false end
        local gem1, gem2, gem3, gem4 = select(4, ns.GetLinkValues(itemLink))
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
        INVTYPE_LEGS = true,
        INVTYPE_FEET = true,
        INVTYPE_WRIST = true,
        INVTYPE_FINGER = true,
        INVTYPE_CLOAK = true,
        INVTYPE_WEAPON = true,
        INVTYPE_2HWEAPON = true,
        INVTYPE_WEAPONMAINHAND = true,
        INVTYPE_RANGED = true,
        INVTYPE_RANGEDRIGHT = true,
        INVTYPE_WEAPONOFFHAND = true,
    }
    function ns.ItemIsMissingEnchants(itemLink)
        if not itemLink then return false end
        local equipLoc = select(4, C_Item.GetItemInfoInstant(itemLink))
        if not enchantable[equipLoc] then return false end
        local enchantID = select(3, ns.GetLinkValues(itemLink))
        if enchantID == "" then return true end
        return false
    end
end

ns.GetLinkValues = function(link)
    local linkType, linkOptions, displayText = LinkUtil.ExtractLink(link)
    return linkType, strsplit(":", linkOptions)
end
