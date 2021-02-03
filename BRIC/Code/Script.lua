-- Building_Template_Id is the Id of your building (see items.lua)
local Building_Template_Id = "AdvancedWasteRockProcessor"

local function FixIcons()
	-- local the building template
	local bt = BuildingTemplates[Building_Template_Id]

	-- building menu icon
	bt.display_icon = "UI/Icons/Buildings/waste_rock_processor.tga"

	-- encyclopedia entry icon
	bt.encyclopedia_image = "UI/Encyclopedia/WasteRockProcessor.tga"
	
	--upgrade 1 icon
	bt.upgrade1_icon = "UI/Icons/Upgrades/fueled_extractor_01.tga"

	-- local the class template
	local ct = ClassTemplates.Building[Building_Template_Id]

	-- pinned icon
	ct.display_icon = "UI/Icons/Buildings/waste_rock_processor.tga"
end

-- new games
OnMsg.CityStart = FixIcons
-- saved games
OnMsg.LoadGame = FixIcons