local myname, ns = ...
if GetLocale() ~= "zhTW" then return end

local L = ns.L

-- Where to show item levels
L["   show levels inside the frame"] = "   在框內顯示等級"
L["Equipment flyouts"] = "裝備飛出選單"
L["Character average item level"] = "角色平均物品等級"
L["Inspect average item level"] = "觀察平均物品等級"
L["Item tooltips"] = "物品提示"

-- Selectiveness
L["Selectiveness"] = "選擇性"
L["Show on equippable items"] = "顯示於可裝備物品"
L["Show on battle pets"] = "顯示於戰寵"
L["Show on crafting reagents"] = "顯示於製作材料"
L["Show on anything else"] = "顯示於其他物品"
L["Minimum item quality to show"] = "顯示的最低物品品質"

-- Appearance
L["Font"] = "字型"
L["Position of item level"] = "物品等級位置"
L["Position of upgrade indicator"] = "升級指示位置"
L["Position of missing indicator"] = "缺失指示位置"
L["Size of upgrade indicator"] = "升級指示大小"
L["Position of soulbound indicator"] = "靈魂綁定指示位置"
L["Size of soulbound indicator"] = "靈魂綁定指示大小"

-- Flags
L["Color item level by item quality"] = "依物品品質著色物品等級"
L["Color item border by item quality"] = "依物品品質著色物品邊框"
L["Flag upgrade items (%s)"] = "標記可升級物品 (%s)"
L["Flag items missing gems (%s)"] = "標記缺失寶石的物品 (%s)"
L["Flag items missing enchants (%s)"] = "標記缺失附魔的物品 (%s)"
L["Flag items that are %s (%s)"] = "標記為%s (%s) 的物品"

-- Descriptions
L["Instead of being overlaid on the item"] = "而非覆蓋在物品上"
L["Add the item level to tooltips"] = "在提示中加入物品等級"
L["Do you want to disable the core feature of this addon? Maybe."] = "你確定要停用本插件的核心功能嗎？也許吧。"
L["...missing gems/enchants on the character frame only?"] = "…只在角色裝備框顯示缺失的寶石／附魔？"
L["Only on items you control; bags and character"] = "僅限你擁有的物品；背包與角色"

-- Slash command
L["Invalid item quality provided, should be a name or a number 0-8"] = "物品品質無效，請輸入名稱或 0 到 8 的數字"

-- Dropdown values: fonts
L["HighlightSmall"] = "小高亮"
L["Normal"] = "標準"
L["Large"] = "大"
L["Huge"] = "特大"
L["NumberNormal"] = "數字標準"
L["NumberNormalSmall"] = "數字小"

-- Dropdown values: positions
L["TOPLEFT"] = "左上"
L["TOPRIGHT"] = "右上"
L["BOTTOMLEFT"] = "左下"
L["BOTTOMRIGHT"] = "右下"
L["BOTTOM"] = "下方"
L["TOP"] = "上方"
L["LEFT"] = "左方"
L["RIGHT"] = "右方"
L["CENTER"] = "中央"

-- Dropdown values: item quality (Enum.ItemQuality labels)
L["Poor"] = "粗糙"
L["Common"] = "普通"
L["Uncommon"] = "優良"
L["Rare"] = "稀有"
L["Epic"] = "史詩"
L["Legendary"] = "傳說"
L["Artifact"] = "神器"
L["Heirloom"] = "傳家寶"
L["WoWToken"] = "時光徽章"
