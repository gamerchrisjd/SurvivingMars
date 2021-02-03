return {
PlaceObj('ModItemCode', {
	'name', "Buildings",
	'FileName', "Code/Buildings.lua",
}),
PlaceObj('ModItemCode', {
	'FileName', "Code/Script.lua",
}),
PlaceObj('ModItemOptionNumber', {
	'name', "AtmosphereBreathable",
	'DisplayName', "Atmosphere Breathable",
	'Help', "Atmosphere Breathable at this percent atmosphere",
	'DefaultValue', 95,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "AtmosphereCleared",
	'DisplayName', "Blue Skies",
	'Help', "Blues skies at this percent atmosphere",
	'DefaultValue', 60,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "ColdAreaStop",
	'DisplayName', "Cold Areas Melt",
	'Help', "Cold Areas start to melt at this percent temperature",
	'DefaultValue', 70,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "ColdWaveStop",
	'DisplayName', "Cold Waves Stop",
	'Help', "Cold Waves stop at this percent temperature",
	'DefaultValue', 66,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "DustStormStop",
	'DisplayName', "Dust Storms Stop",
	'Help', "Dust Storms stop at this percent atmosphere",
	'DefaultValue', 66,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "IceAsteroidsColdChanceMax",
	'DisplayName', "Ice Asteroids Cold Wave Max Chance",
	'Help', "Maximum chance for Ice Asteroids special project to trigger a cold wave (when temperature=0)",
	'DefaultValue', 95,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "IceAsteroidsColdChanceMin",
	'DisplayName', "Ice Asteroids Cold Wave Min Chance",
	'Help', "Minimum chance for Ice Asteroids special project to trigger a cold wave (when temperature=100)",
	'DefaultValue', 5,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "MeteorStormStop",
	'DisplayName', "Meteor Storms Stop",
	'Help', "Meteor Storms stop at this percent atmosphere",
	'DefaultValue', 80,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "ToxicRainStart",
	'DisplayName', "Toxic Rains Start",
	'Help', "Toxic Rain starts at this percent atmosphere",
	'DefaultValue', 10,
}),
PlaceObj('ModItemOptionNumber', {
	'name', "ToxicRainStop",
	'DisplayName', "Toxic Rains Stop",
	'Help', "Toxic Rain stops at this percent atmosphere",
	'DefaultValue', 70,
}),
PlaceObj('ModItemOptionToggle', {
	'name', "NerfOpenFarms",
	'DisplayName', "Nerf Open Farms",
	'Help', "Open farms plant crops more slowly, and open farm crops can die due to disasters, the farm not working, poor soil quality, or crops not being harvested quickly enough.",
}),
PlaceObj('ModItemOptionToggle', {
	'name', "CrappySoil",
	'DisplayName', "Crappy Soil & More Toxic Rain",
	'Help', "Soil quality drops when terraforming parameters are low, and toxic rains my start and random without warning",
}),
}
