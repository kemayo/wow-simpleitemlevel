local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

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

local function makeSlider(parent, key, label, minValue, maxValue, step, formatter, callback)
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
    if isClassic then
        frame.Slider.Left:SetTexture([[Interface\Buttons\UI-SilverButtonLG-Left-Up]])
        frame.Slider.Left:SetSize(11, 17)
        frame.Slider.Left:SetPoint("TOP", 0, -4)
        frame.Slider.Right:SetTexture([[Interface\Buttons\UI-SilverButtonLG-Right-Up]])
        frame.Slider.Right:SetSize(11, 17)
        frame.Slider.Right:SetPoint("TOP", 0, -4)
        frame.Slider.Middle:SetTexture([[Interface\Buttons\UI-SilverButtonLG-Mid-Up]])
        frame.Slider.Middle:SetHeight(17)
        frame.Slider.Middle:SetPoint("TOP", 0, -4)
        -- frame.Slider.Thumb:SetTexture([[Interface\Buttons\UI-SliderBar-Button-Horizontal]])
        frame.Slider.Thumb:SetTexture([[Interface\COMMON\Indicator-Yellow]]) -- Gray, Red
        frame.Slider.Thumb:SetSize(24, 24)
    else
        frame.Slider.Left:SetAtlas("Minimal_SliderBar_Left", true)
        frame.Slider.Right:SetAtlas("Minimal_SliderBar_Right", true)
        frame.Slider.Middle:SetAtlas("_Minimal_SliderBar_Middle", true)
        frame.Slider.Thumb:SetAtlas("Minimal_SliderBar_Button", true)
    end
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
        print("OnStepperClicked", forward)
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

    if isClassic then
        frame.Back.Background:SetAtlas("BackArrow-Brown", true)
        frame.Forward.Background:SetAtlas("BackArrow-Brown", true)
        frame.Forward.Background:SetRotation(math.pi)
    else
        frame.Back.Background:SetAtlas("Minimal_SliderBar_Button_Left", true)
        frame.Forward.Background:SetAtlas("Minimal_SliderBar_Button_Right", true)
    end

    frame.RightText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.RightText:SetPoint("LEFT", frame.Slider, "RIGHT", 25, 0)

    frame.Slider:SetWidth(250)
    frame.Slider:SetPoint("LEFT", frame, "CENTER", -80, 3)
    frame.Text = makeFontString(frame, label)
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
        check:SetPoint("LEFT", frame, "CENTER", -90, 3)
        frame.Check = check

        frame.Text = makeFontString(frame, label, true)

        frame:SetPoint("RIGHT", parent)

        frame:SetSize(280, 26)

        return frame
    end
end

local function makeTitle(parent, text)
    local title = CreateFrame("Frame", nil, parent)
    title.Text = makeFontString(title, text)
    title:SetSize(280, 26)
    title:SetPoint("RIGHT", parent)
    return title
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
            local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = GetItemInfoInstant(item)
            if itemID then
                self.itemID = itemID
                SetItemButtonTexture(button, icon)
            end
        end
        function button:GetItemID()
            return self.itemID
        end
        function button:GetItemLink()
            return select(2, GetItemInfo(self.itemID))
        end
    end
    button:SetScript("OnEnter", button_onenter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- actual config panel:

local frame

if _G.Settings and type(_G.Settings) == "table" and _G.Settings.RegisterAddOnCategory then
    frame = CreateFrame("Frame")
    frame.OnCommit = function() end
    frame.OnDefault = function() end
    frame.OnRefresh = function() end

    local category, layout = Settings.RegisterCanvasLayoutCategory(frame, myfullname)
    category.ID = myname
    layout:AddAnchorPoint("TOPLEFT", 10, -10)
    layout:AddAnchorPoint("BOTTOMRIGHT", -10, 10)

    Settings.RegisterAddOnCategory(category)
else
    frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    frame.name = myname
    InterfaceOptions_AddCategory(frame)
end
frame:Hide()

do
    local demo = CreateFrame("Frame", nil, frame)
    if isClassic then
        demo:SetPoint("TOPLEFT", frame, 0, -8)
    else
        demo:SetPoint("TOPLEFT", frame)
    end
    demo:SetPoint("RIGHT", frame)
    demo:SetHeight(43)

    local demoButtons = {}
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
            ns.UpdateButtonFromItem(button, Item:CreateFromItemID(itemID))
            demoButtons[itemID] = button
            previousButton = button
        end
        demo:SetScript("OnShow", nil)
    end)

    local function refresh(_, value)
        ns.RefreshOverlayFrames()
        for itemID, button in pairs(demoButtons) do
            ns.CleanButton(button)
            ns.UpdateButtonFromItem(button, Item:CreateFromItemID(itemID))
        end
    end

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

    local checkboxes = {
        {false, SHOW_ITEM_LEVEL},
        {"bags", BAGSLOTTEXT},
        {"character", ORDER_HALL_EQUIPMENT_SLOTS},
        {"inspect", INSPECT},
        {"loot", LOOT},
        {false, DISPLAY_HEADER},
        {"upgrades", ("Flag upgrade items (%s)"):format(ns.upgradeString)},
        {"missinggems", ("Flag items missing gems (%s)"):format(ns.gemString)},
        {"missingenchants", ("Flag items missing enchants (%s)"):format(ns.enchantString)},
        {"color", "Color item level by item quality"},
        {"equipmentonly", "Only show on equippable items"},
    }
    if isClassic then
        table.insert(checkboxes, {"tooltip", "Add the item level to tooltips"})
    end

    local previous = positionmissing
    for _, data in ipairs(checkboxes) do
        local control
        if data[1] then
            control = makeCheckbox(frame, data[1], data[2], data[3], refresh)
        else
            control = makeTitle(frame, data[2])
        end
        control:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
        previous = control
    end

    local values = {}
    for label, value in pairs(Enum.ItemQuality) do
        values[value] = label
    end
    local quality = makeDropdown(frame, "quality", "Minimum item quality to show", values, refresh)
    quality:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)

    -- local pointless = makeSlider(frame, "pointless", "Pointless slider", 1, 20, 1)
    -- pointless:SetPoint("TOPLEFT", quality, "BOTTOMLEFT", 0, -4)

    -- Settings.OpenToCategory(myname)
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
        if InterfaceOptionsFrame_Show then
            InterfaceOptionsFrame_Show()
            InterfaceOptionsFrame_OpenToCategory(myname)
        else
            Settings.OpenToCategory(myname)
        end
    end
end
