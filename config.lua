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

local function makeSlider(parent, key, label, minValue, maxValue, step, formatter)
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

local function makeDropdown(parent, key, label, values)
    local frame = CreateFrame("Frame", nil, parent)
    frame.Dropdown = CreateFrame("Frame", myname .. "Options" .. key .. "Dropdown", frame, "UIDropDownMenuTemplate")
    frame.Dropdown:SetPoint("LEFT", frame, "CENTER", -110, 3)
    frame.Dropdown:HookScript("OnShow", function()
        if frame.initialize then return end
        UIDropDownMenu_Initialize(frame.Dropdown, function()
            for k, v in pairs(values) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v .. " " .. CreateAtlasMarkup(k)
                info.value = k
                info.func = function(self)
                    ns.db[key] = self.value
                    UIDropDownMenu_SetSelectedValue(frame.Dropdown, self.value)
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
    local function checkboxSetValue(self, checked) ns.db[self.key] = checked end
    local function checkboxOnClick(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self:SetValue(checked)
    end
    function makeCheckbox(parent, key, label, description, getValue, setValue)
        local frame = CreateFrame("Frame", nil, parent)
        local check = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
        check.key = key
        check.GetValue = getValue or checkboxGetValue
        check.SetValue = setValue or checkboxSetValue
        check:SetScript('OnShow', checkboxSetChecked)
        check:SetScript("OnClick", checkboxOnClick)
        -- check.label = _G[check:GetName() .. "Text"]
        -- check.label:SetText(label)
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

-- actual config panel:

local frame

if _G.Settings then
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

local title = CreateFrame("Frame", nil, frame)
title.Text = makeFontString(title, SHOW_ITEM_LEVEL)
title:SetSize(280, 26)
title:SetPoint("TOPLEFT", frame)
title:SetPoint("RIGHT", frame)

local checkboxes = {
    {"bags", BAGSLOTTEXT},
    {"character", ORDER_HALL_EQUIPMENT_SLOTS},
    {"inspect", INSPECT},
    {"loot", LOOT},
    {false, DISPLAY_HEADER},
    {"upgrades", "Upgrade arrows in bags"},
    {"color", "Color item level by item quality"},
    {"equipmentonly", "Only show on equippable items"},
}
if isClassic then
    table.insert(checkboxes, {"tooltip", "Add the item level to tooltips"})
end

local previous = title
for _, data in ipairs(checkboxes) do
    if data[1] then
        local control = makeCheckbox(frame, unpack(data))
        control:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
        previous = control
    else
        local heading = CreateFrame("Frame", nil, frame)
        heading.Text = makeFontString(heading, data[2])
        heading:SetSize(280, 26)
        heading:SetPoint("RIGHT", frame)
        heading:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
        previous = heading
    end
end

local values = {}
for label, value in pairs(Enum.ItemQuality) do
    values[value] = label
end
local quality = makeDropdown(frame, "quality", "Minimum item quality to show", values)
quality:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)

-- local pointless = makeSlider(frame, "pointless", "Pointless slider", 1, 20, 1)
-- pointless:SetPoint("TOPLEFT", quality, "BOTTOMLEFT", 0, -4)

-- Settings.OpenToCategory(myname)
