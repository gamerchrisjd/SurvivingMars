-- **** Building Changes ****

function OnMsg.ClassesPostprocess()
	BuildingTemplates.CoreHeatConvector.electricity_consumption = 80000
	BuildingTemplates.CoreHeatConvector.maintenance_resource_amount = 3000
	BuildingTemplates.CoreHeatConvector.construction_cost_Metals = 120000
	BuildingTemplates.CoreHeatConvector.construction_cost_Polymers = 80000
	BuildingTemplates.OpenFarm.electricity_consumption = 5000
	BuildingTemplates.OpenFarm.maintenance_resource_type  = "MachineParts"
	BuildingTemplates.GHGFactory.maintenance_threshold_base = 72000
	BuildingTemplates.GHGFactory.consumption_amount = 6000
	BuildingTemplates.CarbonateProcessor.maintenance_resource_amount = 5000
	BuildingTemplates.CarbonateProcessor.consumption_amount = 30000
	BuildingTemplates.CarbonateProcessor.construction_cost_MachineParts = 80000
	BuildingTemplates.CarbonateProcessor.construction_cost_Metals = 100000
	BuildingTemplates.CarbonateProcessor.suspend_on_dust_storm = true
	BuildingTemplates.ForestationPlant.upgrade1_id = "Forestation_Amplify"
	BuildingTemplates.ForestationPlant.upgrade1_display_name = T(587908642055, "Amplify")
    BuildingTemplates.ForestationPlant.upgrade1_description = T(11910, "+<upgrade1_mul_value_1>% faster terraforming; +<power(upgrade1_add_value_2)> Consumption.")
	BuildingTemplates.ForestationPlant.upgrade1_icon = "UI/Icons/Upgrades/amplify_01.tga"
    BuildingTemplates.ForestationPlant.upgrade1_upgrade_cost_Polymers = 5000
    BuildingTemplates.ForestationPlant.upgrade1_mod_label_1 = "ForestationPlant"
	BuildingTemplates.ForestationPlant.upgrade1_mod_prop_id_1 = "terraforming_boost_sol"
	BuildingTemplates.ForestationPlant.upgrade1_mul_value_1 = 50
	BuildingTemplates.ForestationPlant.upgrade1_mod_label_2 = "ForestationPlant"
    BuildingTemplates.ForestationPlant.upgrade1_mod_prop_id_2 = "electricity_consumption"
    BuildingTemplates.ForestationPlant.upgrade1_add_value_2 = 10000
	BuildingTemplates.ForestationPlant.upgrade1_mod_label_3 = "ForestationPlant"
    BuildingTemplates.ForestationPlant.upgrade1_mod_prop_id_3 = "vegetation_interval"
    BuildingTemplates.ForestationPlant.upgrade1_add_value_3 = -7
end

function OnMsg.LoadGame()
	-- To get carbonate processor change to apply to existing games
	g_SuspendLabels = {}
	for id, bld in pairs(BuildingTemplates) do
		if bld.suspend_on_dust_storm then
			g_SuspendLabels[#g_SuspendLabels + 1] = id
		end
	end
	if IsTechResearched("TerraformingAmplification") then
		UICity:UnlockUpgrade("Forestation_Amplify")
	end
end

function OnMsg.TechResearched(tech_id)
	if tech_id == "TerraformingAmplification" then
		UICity:UnlockUpgrade("Forestation_Amplify")
	end
end

--Carbonate Processor output reduced when atmos is greater than vegetation, up to 50%
function CarbonateProcessor:NewGetTerraformingBoostSol()
	local penalty_pct = Clamp(100+(GetTerraformParam("Atmosphere")-GetTerraformParam("Vegetation"))/const.TerraformingScale,100,200)
	--*10 to so that result is rounded to nearest 0.01%
	return MulDivRound(self.terraforming_boost_sol,10,penalty_pct)*10
end

CarbonateProcessor.GetTerraformingBoostSol = CarbonateProcessor.NewGetTerraformingBoostSol

function CarbonateProcessor:Consume_Production(for_amount_to_produce, delim)
	--Ignore delim, consume amount is per 0.4% not per 1%
	return HasConsumption.Consume_Production(self, for_amount_to_produce, self["base_terraforming_boost_sol"])
end

--GHG Factory: 
--5x boost is gradually lost from 20-25%
--Loses 0.01 effectiveness for every 5% temperature rise after that
--During cold wave 0.05 if temp < 25, 0.01 otherwise
local orig_GetTerraformingBoostSol = GHGFactory.GetTerraformingBoostSol
function GHGFactory:NewGetTerraformingBoostSol()
    local result = orig_GetTerraformingBoostSol(self)
	local temp = GetTerraformParamPct("Temperature")
	if temp < 25 then
		result = Min(result, self.terraforming_boost_sol * (26-temp))		
	else
		result = (self.terraforming_boost_sol*Max(1,(5-(temp-25)/10)))/5
	end
	if g_ColdWave then
		result = Max(result, self.terraforming_boost_sol)/5
	end
	return result
end

GHGFactory.GetTerraformingBoostSol = GHGFactory.NewGetTerraformingBoostSol

function GHGFactory:Consume_Production(for_amount_to_produce, delim)
	--Ignore delim, consume amount is per 0.25% not per 1%
	return HasConsumption.Consume_Production(self, for_amount_to_produce, self["base_terraforming_boost_sol"]*self.initial_temp_boost_coef)
end

--ForestationPlants can contribute 40% to vegetation in total - negate any increase from seed vegetation
function ForestationPlant:NewGetTerraformingBoostSol()
	local threshold = self.vegetation_terraforming_threshold
	if g_SpecialProjectCompleted then
		threshold = threshold + (g_SpecialProjectCompleted["SeedVegetation"] or 0)*5000
	end
	if GetTerraformParam(self.terraforming_param) < threshold then
		return self.terraforming_boost_sol
	end
	return 0
end

ForestationPlant.GetTerraformingBoostSol = ForestationPlant.NewGetTerraformingBoostSol
