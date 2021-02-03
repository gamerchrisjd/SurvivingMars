local mod_ToxicRainStop
local mod_IceAsteroidsColdChanceMin
local mod_IceAsteroidsColdChanceMax
local mod_CrappySoil
local mod_NerfOpenFarms

-- fired when settings are changed/init
local function ModOptions()
  local preset = Presets.TerraformingParam.Default["Atmosphere"]
  for _, item in ipairs(preset.Threshold or empty_table) do
	if CurrentModOptions:GetProperty(item.Id) then
		item.Threshold = CurrentModOptions:GetProperty(item.Id)
		if item.Id == "ToxicRainStop" then
			mod_ToxicRainStop = item.Threshold
		end
	elseif item.Id == "AtmosphereBreathableWarning" then
		item.Threshold = CurrentModOptions:GetProperty("AtmosphereBreathable")		
	end
  end
  preset = Presets.TerraformingParam.Default["Temperature"]
  local atmos_breathe_temp = Min(CurrentModOptions:GetProperty("ColdWaveStop"), CurrentModOptions:GetProperty("AtmosphereBreathable"))
  for _, item in ipairs(preset.Threshold or empty_table) do
	if item.Id == "AtmosphereBreathable" or item.Id == "AtmosphereBreathableWarning" then
		item.Threshold = atmos_breathe_temp
	elseif CurrentModOptions:GetProperty(item.Id) then
		item.Threshold = CurrentModOptions:GetProperty(item.Id)
	end
  end
  mod_IceAsteroidsColdChanceMin = CurrentModOptions:GetProperty("IceAsteroidsColdChanceMin")
  mod_IceAsteroidsColdChanceMax = CurrentModOptions:GetProperty("IceAsteroidsColdChanceMax")
  mod_CrappySoil = CurrentModOptions:GetProperty("CrappySoil")
  mod_NerfOpenFarms = CurrentModOptions:GetProperty("NerfOpenFarms")
end

-- load default/saved settings
OnMsg.ModsReloaded = ModOptions

-- fired when option is changed
function OnMsg.ApplyModOptions(id)
	if id ~= CurrentModId then
		return
	end

	ModOptions()
end

-- set options on new/load game
OnMsg.CityStart = ModOptions
OnMsg.LoadGame = ModOptions

-- **** Seed Hacks ****

function VegetationTaskRequester:Done()
  if self.apply_cooldown and self.request:GetActualAmount() <= 0 then
    local q, r = WorldToHex(self:GetPos())
    local x, y = HexToStorage(q, r)
    local k = x + y * HexMapWidth
	--this is the only change - rather than allowing trees and bushes to be harvested every day, they are harvested in growth time + 1 day
	local growth_time = self.preset.growth_time
	if UICity:IsTechResearched("GrowthStimulators") then
		growth_time = MulDivRound(growth_time, 100, 140)
	end
    seed_cooldowns[k] = GameTime() + growth_time
  else
    self:MarkInGrid(false)
  end
  table.remove_entry(self.cc.promoted_trees, self)
  promoted_trees_count = promoted_trees_count - 1
end

function GetVegOutputAmount(preset, pos_obj)
	local sq = GetSoilQuality(WorldToHex(pos_obj))
	local bonus_perc = 0
	if preset.output_resource == "Food" then
		--the original, but bonus can now be negative for poor soil quality
		bonus_perc = Max((sq - preset.min_soil_quality) / 2, -100)  
	else
		--minus 50% effectiveness
		bonus_perc = Max((sq - preset.min_soil_quality) / 2 - 50, -100)  	 
	end
	return preset.output_amount + MulDivRound(preset.output_amount, bonus_perc, 100)
end

-- **** Special Project Stuff ****

function MarsSpecialProject:NewGetRocketResources()
	local project = Presets.POI.Default[self.project_id]
	local resources = project and project.rocket_required_resources or empty_table
	local result = {}
	--local changes_terra_params = (project.terraforming_changes and next(project.terraforming_changes))
	--use the id we were spawned with rather than actual completed count since some projects can spawn multiple times at once
	local completed_count = tonumber(string.match(self.id, "%d+")) or 0
	-- if g_SpecialProjectCompleted then
		-- completed_count = (g_SpecialProjectCompleted[self.project_id] or 0)
	-- end
	for _,res in ipairs(resources) do
		local resource = res.resource
		local amount = res.amount
		if project.is_terraforming then
			if resource=="Fuel" then
				if self.project_id=="CloudSeeding" then
					--25% increase for the second repeat, 150% of original from then on
					amount = Min(4+completed_count,6)*res.amount/4
					--this covers magnetic shield and space mirror - these seemed a bit cheap when it came to fuel
				elseif project.consume_rocket and amount < 400*const.ResourceScale then
					amount = amount+15*const.ResourceScale
				elseif self.project_id=="CaptureIceAsteroids" then
					amount = res.amount*(10+completed_count)/10
				else
					--+10% increase for the first 2 repeats
					if self.project_id=="ImportGreenhouseGases" then
						amount = res.amount*(10+Min(2, completed_count))/10
					end
					--start to increase after the 5th repeat, in 20% increments
					if completed_count > 5 then
						local increment = 1
						for i = 1, completed_count - 5 do
							if i >= increment or self.project_id=="SeedVegetation" then
								amount = amount + res.amount/5
								increment = increment * 2
							end
						end
					end
				end
				--10% funding cost increase each repeat
			elseif resource=="Funding" then
				amount = (10+completed_count)*res.amount/10
				--Seed vegetation uses 100 more seeds the first 2 repeats, 60 more seeds until the 12th repeat, 50 more seeds each time after that
			elseif resource=="Seeds" then
				amount = res.amount+(Min(completed_count,2)*40+Min(completed_count,12)*10+completed_count*50)*const.ResourceScale
				--25% increase in polymer cost for cloud seeding each time it's repeated
			elseif self.project_id=="CloudSeeding" then
				amount = (5+completed_count)*res.amount/4								
				-- --+5 machine parts each 3 times the project is completed
			elseif self.project_id=="CaptureIceAsteroids" then
				amount = res.amount+((5*Min(completed_count,3))/3+(5*Clamp(completed_count-3,0,2))/2+5*Max(completed_count-5,0))*const.ResourceScale
				-- --space mirror increase in metals and electronics cost
			elseif "LaunchSpaceMirror" then
				if resource=="Electronics" then
					amount = (5*res.amount)/3				
				elseif resource=="Metals" then
					amount = (3*res.amount)/2
				end
			end
		end
		result[#result+1]=PlaceObj('ResourceAmount', {
			'resource', resource,
			'amount', amount,
		})
	end
	return result
end

MarsSpecialProject.GetRocketResources = MarsSpecialProject.NewGetRocketResources

local function GetIceAsteroidsColdWaveChance()
	--TODO: Get these from mod options
	local min_chance = mod_IceAsteroidsColdChanceMin
	local max_chance = mod_IceAsteroidsColdChanceMax
	min_chance = Min(min_chance, MulDivRound(min_chance, g_SpecialProjectCompleted["CaptureIceAsteroids"], 5))
	local variable_chance = Min(g_SpecialProjectCompleted["CaptureIceAsteroids"]*20, 100-GetTerraformParamPct("Temperature"))
	return min_chance + MulDivRound(variable_chance, max_chance-min_chance, 100)
end

local function AreBetterProjectsEnabled()
	local status = UICity.tech_status["ProjectInitiative"]
	return not status or status.researched
end

function OnMsg.SpecialProjectCompleted(project_id)
	print(project_id .. " completed")
	--chance to trigger cold wave on ice asteroids completed
	if project_id=="CaptureIceAsteroids" then
		--chance to trigger == current water percent
		local cold_chance = GetIceAsteroidsColdWaveChance()
		if cold_chance > UICity:Random(100) then
			g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day = g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day + 1
			if g_ColdWave and g_ColdWaveStartTime and g_ColdWaveEndTime then
				local temp = GetTerraformParam("Temperature")					
				SetTerraformParam("Temperature"	, Max(0,temp-1000) )
				ExtendColdWave(DataInstances.MapSettings_ColdWave["ColdWave_Low"].min_duration)
			else
				CreateGameTimeThread(function()
					local warn_time = GetDisasterWarningTime()
					local loop_count = 0
					--wait for any current disaster to finish (or at least 1 hour)
					--if a cold wave starts, then just extend that
					repeat
						Sleep(const.HourDuration)
						if warn_time > const.DayDuration then
							warn_time = warn_time - const.HourDuration
						end
						if loop_count % 24 == 0 then
							g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day = g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day + 1
						end
						loop_count = loop_count + 1
						if g_ColdWave and g_ColdWaveStartTime and g_ColdWaveEndTime then
							break
						end
					until not (IsDisasterPredicted() or IsDisasterActive())
					if g_ColdWave and g_ColdWaveStartTime and g_ColdWaveEndTime then
						local temp = GetTerraformParam("Temperature")					
						SetTerraformParam("Temperature"	, Max(0,temp-1000) )
						ExtendColdWave(DataInstances.MapSettings_ColdWave["ColdWave_Low"].min_duration)
					else
						--Start with little warning (but at least 1 day)
						local start_time = GameTime()
						local wait_time = Max(const.DayDuration, UICity:Random(warn_time))
						warn_time = Min(warn_time, wait_time)
						g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day = g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day + wait_time/const.DayDuration
						--Wait until it's time to show a warning
						while GameTime() - start_time <= wait_time - warn_time do
							Sleep(const.HourDuration)
							if IsDisasterPredicted() or IsDisasterActive() then
								break
							end
						end
						--in the unlikely event that another disaster started while we waited then quit
						if not (IsDisasterPredicted() or IsDisasterActive()) then
							--Show a warning and wait
							AddDisasterNotification("ColdWave2", {start_time = GameTime(), expiration = warn_time, early_warning = GetEarlyWarningText(warn_time) , num_of_sensors = GetTowerCountText() })
							ShowDisasterDescription("ColdWave")
							Sleep(wait_time - (GameTime() - start_time))
							--One final check that no disaster is currently active (shouldn't happen)
							if not IsDisasterActive() then
								if ColdWavesDisabled then
									CreateGameTimeThread(function()
										local setting = mapdata.MapSettings_ColdWave
										local data = DataInstances.MapSettings_ColdWave
										local cold_wave = data[setting]
										cold_wave = OverrideDisasterDescriptor(cold_wave)
										StartColdWave(cold_wave or data["ColdWave_VeryLow"])
									end)
								else
									--trigger in the main loop/normal way
									Msg("TriggerColdWave")
								end						
							end
						end
					end
				end)
			end
		end
	elseif project_id=="SeedVegetation" and AreBetterProjectsEnabled() then
		--Vegetation bloom, roughly eqaul to what happens when key vegetation terraforming thresholds are reached
		local veg_pct = GetTerraformParamPct("Vegetation")
		local sq = veg_pct
		local range = (veg_pct >= 60) and 160 or (70 + veg_pct)
		local min_amount = (veg_pct >= 60) and 8 or 4
		local max_amount = (veg_pct >= 60) and 10 or 5
		local min_spawn = (veg_pct >= 60) and 160 or (50 + veg_pct)
		local max_spawn = (veg_pct >= 60) and 400 or 200
		local veggies = {}
		if veg_pct >= 90 then
			veggies = {"Tree","Tree","Broadleaf","Bush","Grass"}
		elseif veg_pct >= 50 then	
			veggies = {"Lichen","Grass","Grass","Bush"}		
			if veg_pct >= 75 then
				veggies[#veggies+1] = "Tree"
			end
		else
			veggies = {"Lichen","Lichen","Lichen"}
			if veg_pct >= 30 then
				veggies[#veggies+1] = "Grass"
			end
		end
		AddVegFocus(min_amount, max_amount, (range/2) * guim, range * guim, 0, sq * const.SoilGridScale, min_spawn, max_spawn, veggies)
	end
end

function OnMsg.ExpeditionSent(rocket)
	local project = rocket.expedition.project
	--delay capture ice asteroids respawning
	if project and project.project_id=="CaptureIceAsteroids" and GetIceAsteroidsColdWaveChance() > 0 then
		local nextIdx = g_SpecialProjectSpawnNextIdx["CaptureIceAsteroids"]
		if nextIdx and nextIdx > 0 then
			--this will be modified depending on the outcome of the mission (i.e whether it triggered a cold wave or not)
			g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day = Max(g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day, UICity.day + 5)
		end
	end
end

--Try to spawn CaptureIceAsteroids a little early if we delayed it before
function OnMsg.ExpeditionReturned(rocket)
	local project = rocket.expedition.project
	if project then
		if project.project_id=="CaptureIceAsteroids" then
			TrytoSpawnSpecialProject(Presets.POI.Default["CaptureIceAsteroids"], UICity.day+1)
		elseif AreBetterProjectsEnabled() then
			--spawn another project if none are currently available. Ignores projects like cloud seeding which don't change terra parameters
			--will also not apply to space mirror as time between spawns is too large (it's mainly for seed vegetation)
			if project.terraforming_changes and next(project.terraforming_changes) then
				local has_spot = false
				for idx = #MarsScreenLandingSpots, 1, -1 do
					local spot = MarsScreenLandingSpots[idx]
					if spot and spot.spot_type=="project" and spot.project_id==project.project_id then
						has_spot = true
						break
					end
				end
				if not has_spot then
					TrytoSpawnSpecialProject(Presets.POI.Default[project.project_id], UICity.day+15)
				end
			end
		end
	end
end

--Drop temperature and delay ice asteroids respawning until the cold wave is (nearly) over
function OnMsg.ColdWave()
	if g_ColdWaveEndTime and g_SpecialProjectNextSpawn["CaptureIceAsteroids"] then
		g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day = Max(g_SpecialProjectNextSpawn["CaptureIceAsteroids"].day, UICity.day + (g_ColdWaveEndTime-GameTime())/const.DayDuration)
	end
	local temp = GetTerraformParam("Temperature")
	SetTerraformParam("Temperature"	, Max((temp*9)/10,temp-1000) )
end

--Old seed hack seems to have caused issue loading the right amount of seeds for expeditions
--allow a tolerance of 0.05
--keeping this even though the hack has been fixed now
function RocketExpedition:HasCargoSpaceLeft()
	for i = 1, #(self.export_requests or empty_table) do
		if self.export_requests[i]:GetActualAmount() > const.ResourceScale/20 then
			return true
		end
	end
end

-- **** NewDay Soil Quaity Descrease ****

function OnMsg.NewDay(day)
	if mod_CrappySoil then
		local waterPct = GetTerraformParamPct("Water")
		local tempPct = GetTerraformParamPct("Temperature")
		local atmosPct = GetTerraformParamPct("Atmosphere")
		--Make the soil crappy when terraforming parameters are low
		local avg_soil_quality = 0
		local forest_plants = UICity.labels.ForestationPlant or ""
		if #forest_plants > 0 then
			for i = 1, #forest_plants do
				local obj = forest_plants[i]
				avg_soil_quality = avg_soil_quality + obj:GetAvgSoilQualityInRange()
			end
			avg_soil_quality = avg_soil_quality / #forest_plants
		end
		local open_farms = UICity.labels.OpenFarm or ""
		--Use actual open farm average soil quality instead?
		avg_soil_quality = avg_soil_quality + #open_farms
		local rand = IsDisasterActive() and 0 or UICity:Random(10)
		if avg_soil_quality > rand then
			local change = 0
			if waterPct < 10 then
				change = change - 1
			end
			--too little for rain
			if tempPct < 40 then
				if avg_soil_quality >= 10 then
					change = change - 1
				end
				--too little for liquid water
				if tempPct < 25 then
					change = change - 1
				end
			end
			--too little for rain
			if atmosPct < 40 then
				if avg_soil_quality >= 10 then
					change = change - 1
				end
				--too little even for toxic rain
				if atmosPct < 25 then
					change = change - 1
				end
			end
			change = Max(change,rand-avg_soil_quality)
			if change ~= 0 then
				if change < -1 and UICity:Random(avg_soil_quality) >= 10+rand and not IsDisasterActive() and not IsDisasterPredicted() and atmosPct < mod_ToxicRainStop and tempPct >= 25 and waterPct >= 5 then
					CreateGameTimeThread(function()
						Sleep(UICity:Random(const.DayDuration))
						if not (IsDisasterActive() or IsDisasterPredicted()) then
							CheatRainsDisaster("Toxic_VeryLow")
						end
					end)
				else
					dbg_ChangeSoilQuality(change)
				end
			end
		end
	end
end

-- **** NewHour Crop Death ****

--Three ways to kill crops
--1. During cold waves and when the farm isn't working for any reason (including suspended during toxic rain and dust storms), kill some crops at random
--2. Also kill some if soil quality is bad, but don't further reduce soil quality in this case
--3. if the spot we choose at random conatins a fully grown crop, then kill it
function OnMsg.NewHour()
	if mod_NerfOpenFarms then
		local open_farms = UICity.labels.OpenFarm or ""
		local grown_mask = 16
		local VegetationGrid = VegetationGrid
		for i = 1, #open_farms do
			local obj = open_farms[i]
			for j = 1, 3 do
				if (j==1 and g_ColdWave) or 
					(j==2 and obj:GetAvgSoilQualityInRange() < UICity:Random(100)) or 
					not obj.working or j==3 then
					
					local killPos = GetRandomPassableAround(obj:GetPos(), obj:GetMaxRadius()+const.HexSize)
					local q, r = WorldToHex(killPos)
					local doKill = j~=3
					local soil_loss = const.SoilGridScale
					if not doKill then
						local x, y = HexToStorage(q, r)
						local data = VegetationGrid:get(x, y)
						doKill = data & grown_mask == grown_mask
					end
					if doKill then
						KillVegetationInCircle(killPos, UICity:Random(3,10)*guim)
						if obj.suspended or g_ColdWave then 
							soil_loss = soil_loss*5
						elseif not obj.working then
							soil_loss = soil_loss*3
						elseif j==2 then
							soil_loss = 0
						end
						if soil_loss~=0 then
							SoilAdd(q, r, -soil_loss, HexSurroundingsCheckShape)
							OnSoilGridChanged()
						end
					end
				end
			end
		end
	end
end

function OnMsg.BuildingInit(bld)
	if bld and mod_NerfOpenFarms then
		if IsKindOf(bld, "OpenFarm") then
			bld.vegetation_interval = 9	--3x original
		end
	end
end

--Add additional atmosphere loss based on how much higher atmosphere is to vegetation
function GetSolAtmosphereDecay()
	local thres_pct = GetTerraformingThreshold("Atmosphere", "AtmosphereDecay")
	local thres = MulDivRound(thres_pct, MaxTerraformingValue, 100)
	local div = MaxTerraformingValue - thres
	local min = const.Terraforming.Decay_AtmosphereTP_Min
	local max = const.Terraforming.Decay_AtmosphereTP_Max
	local reduct = GetAtmosphereDecayReduct()
	local magnetic_shield = const.Terraforming.Decay_AtmosphereSP_MagneticShield
	local param = GetTerraformParam("Atmosphere")
	local magnetic_shield_projects = magnetic_shield * (g_SpecialProjectCompleted and GetMagneticShieldsCount() or 0)
	--above is original code
	local result = min + MulDivRound(max - min, param - thres, div)	--original atmos loss
	--add up to 2% based on how much higher atmosphere is to vegetation (0.02% loss per 1% difference)
	local additional_pct = Max(0,(GetTerraformParam("Atmosphere")-GetTerraformParam("Vegetation"))/const.TerraformingScale)
	result = result + (max * additional_pct) / 100
	--allow reductions to apply to both
	return Max(0,result - reduct - magnetic_shield_projects)
end

--debugging
-- function OnMsg.TerraformThresholdPassed(threshold, value)
	-- print(threshold .. " set to " .. tostring(value))
	-- FlushLogFile()
-- end

function OnMsg.MilestoneCompleted(id)
	if id=="LiquidWater" then
		g_Consts.ApplicantsPoolStartingSize = g_Consts.ApplicantsPoolStartingSize + 10
		AddCustomOnScreenNotification("TerraBonus1", "Terraforming Bonus", "Applicant pool size increased by 10", "UI/Icons/Notifications/New/cold_wave_3.tga")
	elseif id=="FirstRainfall" then
		g_Consts.ApplicantsPoolStartingSize = g_Consts.ApplicantsPoolStartingSize + 10
		AddCustomOnScreenNotification("TerraBonus1", "Terraforming Bonus", "Applicant pool size increased by 10", "UI/Icons/Notifications/New/rains_3.tga")
	elseif id=="BreathableAtmosphere" then
		g_Consts.ApplicantsPoolStartingSize = g_Consts.ApplicantsPoolStartingSize + 10
		AddCustomOnScreenNotification("TerraBonus1", "Terraforming Bonus", "Applicant pool size increased by 10", "UI/Icons/Notifications/New/atmospheric_3.tga")
	end
end
