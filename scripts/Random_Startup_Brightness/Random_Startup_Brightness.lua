--[[

Startup DU Brightness Randomizer ToLiSS A319/A320/A321 and A340

Randomizes the brightness of the DUs at flight start

By BK/RandomUser, 2023

Licensed under the EUPL v1.2
https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12

]]
--[[

SETTINGS

]]
local Enable = false        -- False = Script disabled
local Limits = {0.2,1.0}    -- Range, in which the DU brightness is randomized
local Delay = 1             -- Delay, in seconds, before brightrness values are applied
--[[

DATAREFS

]]
simDR_DU_Brightness = find_dataref("AirbusFBW/DUBrightness") -- Display units, incl. MCDU
simDR_Pan_Brightness = find_dataref("AirbusFBW/PanelBrightnessLevel") -- Main panel integ light
simDR_OHP_Brightness = find_dataref("AirbusFBW/OHPBrightnessLevel") -- Overhead integ light
simDR_Pan_Flood_Brightness = find_dataref("AirbusFBW/PanelFloodBrightnessLevel") -- Panel flood
simDR_Ped_Flood_Brightness = find_dataref("AirbusFBW/PedestalFloodBrightnessLevel") -- Pedestal flood
simDR_Dome_Sw = find_dataref("ckpt/oh/domeLight/anim")
simDR_StbyCompass_Sw = find_dataref("ckpt/oh/stbyCompass/anim")
simDR_ConsFloodL_Sw = find_dataref("ckpt/lights/consoleSwitchLeft/anim") -- Console/Floor light left
simDR_ConsFloodR_Sw = find_dataref("ckpt/lights/consoleSwitchRight/anim") -- Console/Floor light right
--[[

FUNCTIONS

]]
function Randomize_Brightness()
    math.randomseed(os.time()) -- Prime Lua's random number generator using UNIX time
    for i=0,7 do -- Length of the DU brightness dref is 7
        simDR_DU_Brightness[i] = math.random(Limits[1] * 100,Limits[2] * 100) / 100 -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    end
    simDR_OHP_Brightness = math.random(Limits[1] * 100,Limits[2] * 100) / 100 -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    simDR_Pan_Brightness = math.random(Limits[1] * 100,Limits[2] * 100) / 100 -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    simDR_ConsFloodL_Sw = math.random(0,2)
    simDR_ConsFloodR_Sw = math.random(0,2)
    simDR_Dome_Sw = math.random(0,2)
    simDR_StbyCompass_Sw = math.random(0,1)
    simDR_Pan_Flood_Brightness = math.random(Limits[1] * 100,Limits[2] * 100) / 100 -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    simDR_Ped_Flood_Brightness = math.random(Limits[1] * 100,Limits[2] * 100) / 100 -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    print("ToLiSS Random Startup Brightness: Random brightness applied.")
end
--[[

X-PLANE WRAPPERS

]]
--[[ X-Plane session start ]]
function flight_start()
    if Enable == true then run_after_time(Randomize_Brightness,Delay) end
end
