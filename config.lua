local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local isClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE

local function makeFontString(frame, label, indented)
    local text = frame:CreateFontString(nil, "OVERLAY", indented and "GameFontNormalSmall" or "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetText(label)
    if indented then
        text:SetPoint("LEFT", frame, (15 + 37), 0) -- indent variant
    else
        text:SetPoint("LEFT", frame, 37, 0)
    end
    text:SetPoint("RIGHT", frame, "CENTER", -85, 0)

    return text
end

local function makeTitle(parent, text)
    local title = CreateFrame("Frame", nil, parent)
    title.Text = makeFontString(title, text)
    title:SetSize(280, 26)
    title:SetPoint("RIGHT", parent)
    return title
end

local function makeSlider(parent, key, label, minValue, maxValue, step, formatter, callback, indented)
    local frame = CreateFrame("Frame", nil, parent)
    -- frame:EnableMouse(true)
    frame.Slider = CreateFrame("Slider", nil, frame)
    frame.Slider:SetObeyStepOnDrag(true)
    frame.Slider:SetOrientation("HORIZONTAL")
    frame.Slider.Left = frame.Slider:CreateTexture()
    frame.Slider.Left:SetPoint("LEFT")
    frame.Slider.Right = frame.Slider:CreateTexture()
    frame.Slider.Right:SetPoint("RIGHT")
    frame.Slider.Middle = frame.Slider:CreateTexture()
    frame.Slider.Middle:SetPoint("TOPLEFT", frame.Slider.Left, "TOPRIGHT")
    frame.Slider.Middle:SetPoint("TOPRIGHT", frame.Slider.Right, "TOPLEFT")
    frame.Slider.Thumb = frame.Slider:CreateTexture()
    frame.Slider:SetThumbTexture(frame.Slider.Thumb)
    frame.Slider:SetSize(200, 19)

    frame.Slider.Left:SetAtlas("Minimal_SliderBar_Left", true)
    frame.Slider.Right:SetAtlas("Minimal_SliderBar_Right", true)
    frame.Slider.Middle:SetAtlas("_Minimal_SliderBar_Middle", true)
    frame.Slider.Thumb:SetAtlas("Minimal_SliderBar_Button", true)

    -- frame.Slider:SetPoint("TOPLEFT", frame, 19)
    -- frame.Slider:SetPoint("BOTTOMRIGHT", frame, -19)
    formatter = formatter or function(value) return string.format("%.1f", value) end
    frame.FormatValue = function(self, value)
        frame.RightText:SetText(formatter(value))
        frame.RightText:Show()
    end
    frame.Slider:SetScript("OnValueChanged", function(slider, value)
        frame:FormatValue(value)
        ns.db[key] = value
        if callback then callback(key, value) end
    end)
    frame.Slider:SetScript("OnMouseDown", function(slider)
        if slider:IsEnabled() then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    frame.OnStepperClicked = function(self, forward)
        local value = self.Slider:GetValue()
        if forward then
            self.Slider:SetValue(value + self.Slider:GetValueStep())
        else
            self.Slider:SetValue(value - self.Slider:GetValueStep())
        end

        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    frame.Back = CreateFrame("Button", nil, frame)
    frame.Back:SetSize(11, 19)
    frame.Back:SetPoint("RIGHT", frame.Slider, "LEFT", -4, 0)
    frame.Back.Background = frame.Back:CreateTexture(nil, "BACKGROUND")
    frame.Back.Background:SetPoint("CENTER")
    frame.Back:SetScript("OnClick", function() frame:OnStepperClicked(false) end)
    frame.Forward = CreateFrame("Button", nil, frame)
    frame.Forward:SetSize(11, 19)
    frame.Forward:SetPoint("LEFT", frame.Slider, "RIGHT", 4, 0)
    frame.Forward.Background = frame.Forward:CreateTexture(nil, "BACKGROUND")
    frame.Forward.Background:SetPoint("CENTER")
    frame.Forward:SetScript("OnClick", function() frame:OnStepperClicked(true) end)

    frame.Back.Background:SetAtlas("Minimal_SliderBar_Button_Left", true)
    frame.Forward.Background:SetAtlas("Minimal_SliderBar_Button_Right", true)

    frame.RightText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.RightText:SetPoint("LEFT", frame.Slider, "RIGHT", 25, 0)

    frame.Slider:SetWidth(250)
    frame.Slider:SetPoint("LEFT", frame, "CENTER", -80, 3)
    frame.Text = makeFontString(frame, label, indented)
    frame:SetSize(280, 26)

    frame:SetScript("OnShow", function(self)
        if self.initialized then return end
        local value = ns.db[key]
        local steps = (step and (maxValue - minValue) / step) or 100
        self.Slider:SetMinMaxValues(minValue, maxValue)
        self.Slider:SetValueStep((maxValue - minValue) / steps)
        self.Slider:SetValue(value)
        self:FormatValue(value)
        self.initialized = true
    end)

    frame:SetPoint("RIGHT", parent)

    return frame
end

local function makeDropdown(parent, key, label, values, callback)
    local frame = CreateFrame("Frame", nil, parent)
    frame.Dropdown = CreateFrame("Frame", myname .. "Options" .. key .. "Dropdown", frame, "UIDropDownMenuTemplate")
    frame.Dropdown:SetPoint("LEFT", frame, "CENTER", -110, 3)
    frame.Dropdown:HookScript("OnShow", function()
        if frame.initialize then return end
        UIDropDownMenu_Initialize(frame.Dropdown, function()
            for k, v in pairs(values) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v
                info.value = k
                info.func = function(self)
                    ns.db[key] = self.value
                    UIDropDownMenu_SetSelectedValue(frame.Dropdown, self.value)
                    if callback then callback(key, self.value) end
                end
                UIDropDownMenu_AddButton(info)
            end
            UIDropDownMenu_SetSelectedValue(frame.Dropdown, ns.db[key])
        end)
    end)
    UIDropDownMenu_SetWidth(frame.Dropdown, 280)

    frame.Text = makeFontString(frame, label, true)

    frame:SetPoint("RIGHT", parent)

    frame:SetSize(280, 26)

    return frame
end

local makeCheckbox
do
    local function checkboxGetValue(self) return ns.db[self.key] end
    local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
    local function checkboxSetValue(self, checked)
        ns.db[self.key] = checked
        if self.callback then self.callback(self.key, checked) end
    end
    local function checkboxOnClick(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self:SetValue(checked)
    end
    local function checkboxOnEnter(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, self.tooltipOwnerPoint or "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
        end
        if self.tooltipRequirement then
            GameTooltip:AddLine(self.tooltipRequirement, 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end
    function makeCheckbox(parent, key, label, description, callback)
        local frame = CreateFrame("Frame", nil, parent)
        local check = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
        check.key = key
        check.callback = callback
        check.GetValue = checkboxGetValue
        check.SetValue = checkboxSetValue
        check:SetScript('OnShow', checkboxSetChecked)
        check:SetScript("OnClick", checkboxOnClick)
        check:SetScript("OnEnter", checkboxOnEnter)
        check:SetScript("OnLeave", GameTooltip_Hide)
        check.tooltipText = label
        check.tooltipRequirement = description
        check:SetPoint("LEFT", frame, "CENTER", -90, 0)
        frame.Check = check

        frame.Text = makeFontString(frame, label, true)

        frame:SetPoint("RIGHT", parent)

        frame:SetSize(280, 26)

        return frame
    end
end
local function makeCheckboxList(parent, checkboxes, previous, callback)
    for _, data in ipairs(checkboxes) do
        local control
        if data[1] then
            control = makeCheckbox(parent, data[1], data[2], data[3], callback)
        else
            control = makeTitle(parent, data[2])
        end
        control:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
        previous = control
    end
    return previous
end

local function button_onenter(self)
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    ContainerFrameItemButton_CalculateItemTooltipAnchors(self, GameTooltip)

    local link = self:GetItemLink()
    if link then
        GameTooltip:SetHyperlink(self:GetItemLink())
    else
        GameTooltip:AddLine(RETRIEVING_ITEM_INFO, 1, 0, 0)
    end

    GameTooltip:Show()
end
local function makeItemButton(parent)
    local button = CreateFrame(isClassic and "BUTTON" or "ItemButton", nil, parent, isClassic and "ItemButtonTemplate" or nil)
    -- classic
    if not button.SetItem then
        function button:SetItem(item)
            local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(item)
            if itemID then
                self.itemID = itemID
                SetItemButtonTexture(button, icon)
            end
        end
        function button:GetItemID()
            return self.itemID
        end
        function button:GetItemLink()
            return select(2, C_Item.GetItemInfo(self.itemID))
        end
    end
    button:SetScript("OnEnter", button_onenter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function makeConfigPanel(id, name, parent, parentname)
    local frame

    frame = CreateFrame("Frame")
    frame.OnCommit = function() end
    frame.OnDefault = function() end
    frame.OnRefresh = function() end

    local category, layout
    if parent then
        local parentcategory = Settings.GetCategory(parent)
        category, layout = Settings.RegisterCanvasLayoutSubcategory(parentcategory, frame, name)
    else
        category, layout = Settings.RegisterCanvasLayoutCategory(frame, name)
        Settings.RegisterAddOnCategory(category)
    end
    category.ID = id
    layout:AddAnchorPoint("TOPLEFT", 10, -10)
    layout:AddAnchorPoint("BOTTOMRIGHT", -10, 10)

    frame:Hide()
    return frame
end

-- actual config panel:
function ns:SetupConfig()
    local demoButtons = {}
    local function refresh(_, value)
        ns.RefreshOverlayFrames()
        for itemID, button in pairs(demoButtons) do
            ns.CleanButton(button)
            ns.UpdateButtonFromItem(button, Item:CreateFromItemID(itemID), "character")
        end
    end

    do
        local frame = makeConfigPanel(myname, myfullname)
        local title = makeTitle(frame, SHOW_ITEM_LEVEL)
        title:SetPoint("TOPLEFT", frame)

        local checkboxes = {
            {"bags", BAGSLOTTEXT},
            {"character", ORDER_HALL_EQUIPMENT_SLOTS},
            {"flyout", "Equipment flyouts"},
            {"inspect", INSPECT},
            {"loot", LOOT},
            {"characteravg", "Character average item level"},
            {"inspectavg", "Inspect average item level"},
        }
        if isClassic or ns.db.tooltip then
            table.insert(checkboxes, {"tooltip", "Item tooltips", "Add the item level to tooltips"})
        end

        local last = makeCheckboxList(frame, checkboxes, title, refresh)

        last = makeCheckboxList(frame, {
            {false, "Selectiveness"},
            {"equipment", "Show on equippable items"},
            {"battlepets", "Show on battle pets"},
            {"reagents", "Show on crafting reagents"},
            {"misc", "Show on anything else"},
        }, last, refresh)

        local values = {}
        for label, value in pairs(Enum.ItemQuality) do
            values[value] = label
        end
        local quality = makeDropdown(frame, "quality", "Minimum item quality to show", values, refresh)
        quality:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)

        -- Settings.OpenToCategory(myname)
    end

    do
        local frame = makeConfigPanel(myname.."_appearance", APPEARANCE_LABEL, myname, myfullname)
        local demo = CreateFrame("Frame", nil, frame)

        demo:SetPoint("TOPLEFT", frame)
        demo:SetPoint("RIGHT", frame)
        demo:SetHeight(43)

        demo:SetScript("OnShow", function()
            local previousButton
            for _, itemID in ipairs(isClassic and {19019, 19364, 10328, 11122, 23192, 7997, 14047} or {120978, 186414, 195527, 194065, 197957, 77256, 86079, 44168}) do
                local button = makeItemButton(demo)
                if not previousButton then
                    button:SetPoint("TOPLEFT", 112, -2)
                else
                    button:SetPoint("TOPLEFT", previousButton, "TOPRIGHT", 2, 0)
                end
                button:SetItem(itemID)
                ns.UpdateButtonFromItem(button, Item:CreateFromItemID(itemID), "character")
                demoButtons[itemID] = button
                previousButton = button
            end
            demo:SetScript("OnShow", nil)
        end)

        local title = makeTitle(frame, APPEARANCE_LABEL)
        -- title:SetPoint("TOPLEFT", frame)
        title:SetPoint("TOPLEFT", demo, "BOTTOMLEFT", 0, -4)

        local fonts = {}
        for k,v in pairs(ns.Fonts) do
            fonts[k] = k
        end
        local font = makeDropdown(frame, "font", "Font", fonts, refresh)
        font:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

        local positions = {}
        for k,v in pairs(ns.PositionOffsets) do
            positions[k] = k
        end
        local position = makeDropdown(frame, "position", "Position of item level", positions, refresh)
        position:SetPoint("TOPLEFT", font, "BOTTOMLEFT", 0, -4)
        local positionup = makeDropdown(frame, "positionup", "Position of upgrade indicator", positions, refresh)
        positionup:SetPoint("TOPLEFT", position, "BOTTOMLEFT", 0, -4)

        local positionmissing = makeDropdown(frame, "positionmissing", "Position of missing indicator", positions, refresh)
        positionmissing:SetPoint("TOPLEFT", positionup, "BOTTOMLEFT", 0, -4)
        local scaleup = makeSlider(frame, "scaleup", "Size of upgrade indicator", 0.5, 3, 0.1, nil, refresh, true)
        scaleup:SetPoint("TOPLEFT", positionmissing, "BOTTOMLEFT", 0, -4)

        local positionbound = makeDropdown(frame, "positionbound", "Position of soulbound indicator", positions, refresh)
        positionbound:SetPoint("TOPLEFT", scaleup, "BOTTOMLEFT", 0, -4)
        local scalebound = makeSlider(frame, "scalebound", "Size of soulbound indicator", 0.5, 3, 0.1, nil, refresh, true)
        scalebound:SetPoint("TOPLEFT", positionbound, "BOTTOMLEFT", 0, -4)

        makeCheckboxList(frame, {
            {false, DISPLAY_HEADER},
            {"itemlevel", SHOW_ITEM_LEVEL, "Do you want to disable the core feature of this addon? Maybe."},
            {"upgrades", ("Flag upgrade items (%s)"):format(ns.upgradeString)},
            {"missinggems", ("Flag items missing gems (%s)"):format(ns.gemString)},
            {"missingenchants", ("Flag items missing enchants (%s)"):format(ns.enchantString)},
            {"missingcharacter", "...missing gems/enchants on the character frame only?"},
            {"bound", ("Flag items that are %s (%s)"):format(ITEM_SOULBOUND, CreateAtlasMarkup(ns.soulboundAtlas)), "Only on items you control; bags and character"},
            {"color", "Color item level by item quality"},
        }, scalebound, refresh)
    end
end

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
        ns.db.quality = quality
        return ns.Print("quality = ", _G["ITEM_QUALITY" .. ns.db.quality .. "_DESC"])
    end
    if ns.db[msg] ~= nil then
        ns.db[msg] = not ns.db[msg]
        return ns.Print(msg, '=', ns.db[msg] and YES or NO)
    end
    if msg == "" then
        Settings.OpenToCategory(myname)
    end
end
