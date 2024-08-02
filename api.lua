local myname, ns = ...
local continuableContainer

_G.SimpleItemLevel.API = {}


local function itemFromArg(item)
    -- take an Item or item link and returns a non-empty Item or nil
    if not item then return end
    if type(item) == "string" then
        item = Item:CreateFromItemLink(item)
    end
    if item:IsItemEmpty() then
        return
    end
    return item
end


-- Finds the item level for an item
--
-- This is almost the same as item:GetCurrentItemLevel, but it handles
-- giving caged battle pets a level as well.
--
-- `item` is an item link or an Item. Note: an Item created from
--     an itemID may be inaccurate due to item scaling.
-- Returns number or nil
SimpleItemLevel.API.ItemLevel = function(item)
    item = itemFromArg(item)
    local details = ns.DetailsFromItemInstant(item)
    return details.level
end


-- Colorizes an item's level
--
-- `item` is an item link or an Item. Note: an Item created from
--     an itemID may be inaccurate due to item scaling.
-- Returns string, will be "|cffffffff?|r" if an invalid item is given
SimpleItemLevel.API.ItemLevelColorized = function(item)
    item = itemFromArg(item)
    local details = ns.DetailsFromItemInstant(item)
    local color = ITEM_QUALITY_COLORS[details.quality or 1]
    return color.hex .. (details.level or "?") .. "|r"
end


-- Tests whether an item is an upgrade compared to current equipment
--
-- `item` is an item link or an Item. Note: an Item created from
--     an itemID may be inaccurate due to item scaling.
-- Returns boolean
SimpleItemLevel.API.ItemIsUpgrade = function(item)
    item = itemFromArg(item)
    return ns.ItemIsUpgrade(item)
end

-- Tests whether an item is an upgrade compared to current equipment
--
-- Does all necessary data-caching for the items involved. This has more
-- overhead, but guarantees that you'll get an accurate result.
--
-- `item` is an item link or an Item. Note: an Item created from
--     an itemID may be inaccurate due to item scaling.
-- `callback` is a function which will be passed a boolean `isUpgrade`
SimpleItemLevel.API.ItemIsUpgradeAsync = function(item, callback)
    if not continuableContainer then
        continuableContainer = ContinuableContainer:Create()
    end
    item = itemFromArg(item)
    if not item then
        return callback(false)
    end

    continuableContainer:AddContinuable(item)

    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(item:GetItemID())
    ns.ForEquippedItems(equipLoc, function(equippedItem, slot)
        if not equippedItem:IsItemEmpty() then
            continuableContainer:AddContinuable(equippedItem)
        end
    end)

    continuableContainer:ContinueOnLoad(function()
        callback(SimpleItemLevel.API.ItemIsUpgrade(item))
    end)
end
