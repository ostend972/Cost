--[[

Wear and tear for the ToLiss A319/A320/A321 and A340

Gradually wears out the aircraft and engine.

By BK/RandomUser, 2023

Licensed under the EUPL v1.2
https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12

]]
--[[

SETTINGS

]]
-- This is the table that stores start values (which get overwritten from a persistence save file, if present)
-- DO NOT CHANGE THE ORDER OF THIS TABLE!
local ToLiss_Persistence_Data_Init = {  -- Container table for parameters
{"Age_Aircraft",-1},                     -- Start value for aircraft age (-1 to 2)
{"Age_Engines",-1},                       -- Start value for engine age (-1 to 2)
{"Autosave",1},                         -- 1 = Enables autosaving, saving in the interval specified by AutosaveInterval below
{"AutosaveInterval",300},               -- The interval (in seconds) at which the aircraft and engine age is automatically saved
{"Cash",200000},                        -- The current amount of cash in € or whatever currency you want
{"Cost_Aircraft",100000},               -- Cost of an aircraft overhaul
{"Cost_Engines",50000},                 -- Cost of an engine overhaul
{"Cost_FuelPerKg",0.92},                -- The cost of fuel per Kg in € or whatever currency you want
{"Currency","€"},                       -- The symbol, ISO code or name of the currency in use
{"Debug",0},                            -- 1 = Enable debug output as default
{"GradualAging",1},                     -- 1 = Near real-time aging (see UpdateInterval below); 2 = Only update age at aircraft change or X-Plane exit
{"Persistence",1},                      -- 0 = Disables persistence for aircraft and engine age (will only apply random start values); WILL STILL READ EXISTING PERSISTENCE FILES (WHEN PRESENT)!
{"RevenuePerKgPerHr",0.85},             -- The revenue per kg of payload per flight hour (adjusted for A321neo - higher capacity)
{"Strict",1},                           -- 1 = Less cheating possible by checking cash before overhauls and requiring having been airborne to cash in a flight's revenue
}
-- General
local Persistence_File = "WearAndTear.txt"  -- Name of the persistence file (stored in the livery's folder)
-- Starting values
local Random_Start_Vals = true              -- True = Randomize the starting values if no persistence file is present, False = Do not randomize, always start with brand new aircraft and engines.
local Aircraft_Start_Val = -1               -- Default starting value for the aircraft age without randomization (-1 = brand new; 2 = Worn out)
local Engine_Start_Val = -1                 -- Default starting value for the engine age without randomization (-1 = brand new; 2 = Worn out)
-- Aircraft aging time - Optimized for A321neo
local Aircraft_Wear_Time = 1200             -- Aircraft: Time (in hours) for new to worn out at KTAS = TAS_Max (A321neo has better durability)
local Engine_Wear_Time = 600                -- Engines: Time (in hours) for new to worn out at 100% N1 (NEO engines last longer)
-- Timers - Optimized for A321neo
local InitDelay = 1                         -- Delay (in seconds) before applying age values upon startup (reduced for faster initialization)
local UpdateInterval = 5                    -- Update interval (in seconds) for calculating age (with GradualAging = true) or flight time (with GradualAging = false)
--[[

SUBMODULES, DO NOT TOUCH

]]
ffi = require("ffi") -- LuaJIT FFI module
dofile("WearAndTear_Helpers.lua")  -- CORE COMPONENT; DO NOT CHANGE ORDER
--[[

VARIABLES, DO NOT CHANGE!

]]
--[[ Local to this Lua file, variables are passed to submodules as input parameters ]]
local ToLiss_Persistence_Data = { }     -- Actual table for the persistence data
local Persistence_FilePath = nil        -- Will contain the complete path to the persistence file
local ToLiss_AgeLimit = {Min=-1,Max=2}  -- Container table for the low and high limits for aircraft and engine age, see ToLiss manual
local ToLiss_Flight = {Airborne=0,EngineRunCounter=0,LockET=0,Payload=0,Phase="[None]",Refuel=0,RefuelCost=0,Revenue=0,Time=0,TimeAircraft=0,TimeEngine=0,OperatingCost=0,FuelConsumed=0,MaintenanceCost=0,CrewCost=0,AirportFees=0}   -- Table for various flight state things
local ToLiss_Max_TAS = 470              -- Maximum true air speed (A321neo can reach higher speeds)

-- Airline profiles based on real operational data 2024
local AIRLINE_PROFILES = {
    AIR_FRANCE = {
        fuel_efficiency = 1.0,
        maintenance_factor = 1.0,
        crew_cost_factor = 1.2,
        base_cost_per_hour = 4829,
        name = "Air France"
    },
    EASYJET = {
        fuel_efficiency = 0.95,
        maintenance_factor = 0.9,
        crew_cost_factor = 0.8,
        base_cost_per_hour = 10800,
        name = "EasyJet"
    },
    WIZZ_AIR = {
        fuel_efficiency = 0.85,
        maintenance_factor = 1.16,
        crew_cost_factor = 0.7,
        pw_grounding_risk = 0.20,
        base_cost_per_hour = 0, -- Calculated dynamically
        name = "Wizz Air"
    }
}

-- Airport fees based on real data (in EUR) - Expanded list for European operations
local AIRPORT_FEES = {
    CDG = 259,    -- Paris CDG, A320 >75T
    ORY = 210,    -- Paris Orly
    NCE = 65,     -- Nice, A320 25T
    MRS = 75,     -- Marseille, A320 25T
    TLS = 100,    -- Toulouse + 3 EUR/T (>24T)
    LYS = 85,     -- Lyon Saint-Exupéry
    BOD = 70,     -- Bordeaux Mérignac
    LIL = 70,     -- Lille Lesquin
    NTE = 78,     -- Nantes Atlantique
    SXB = 78,     -- Strasbourg Entzheim
    BSL = 82,     -- Bâle-Mulhouse EuroAirport
    BZR = 60,     -- Béziers Cap d'Agde
    FDF = 112,    -- Fort-de-France
    RUN = 110,    -- La Réunion
    TUF = 65,     -- Tours
    BIA = 68,     -- Bastia
    AJACCIO = 70, -- Ajaccio
    LHR = 450,    -- London Heathrow
    LGW = 380,    -- London Gatwick
    STN = 320,    -- London Stansted
    BCN = 180,    -- Barcelona
    MAD = 200,    -- Madrid
    AMS = 220,    -- Amsterdam
    FRA = 240,    -- Frankfurt
    MUC = 230,    -- Munich
    ZRH = 250,    -- Zurich
    GVA = 210,    -- Geneva
    BRU = 190,    -- Brussels
    DUB = 170,    -- Dublin
    CPH = 200,    -- Copenhagen
    OSL = 210,    -- Oslo
    ARN = 190,    -- Stockholm
    HEL = 180,    -- Helsinki
    VIE = 185,    -- Vienna
    PRG = 160,    -- Prague
    BUD = 150,    -- Budapest
    WAW = 140,    -- Warsaw
    LIS = 130,    -- Lisbon
    OPO = 120,    -- Porto
    ATH = 145,    -- Athens
    MLA = 135,    -- Malta
    DEFAULT = 150 -- Default airport fee
}

-- Fuel consumption by flight phase (kg/h) for A321neo
local FUEL_CONSUMPTION = {
    Taxi = 150,
    Climb = 4200,
    Cruise = 2500,
    Descent = 1800
}

-- Random events probabilities based on real operational data
local RANDOM_EVENTS = {
    APU_Failure = {probability = 1/2000, cost = 2500, duration = 2},
    Hydraulic_Issue = {probability = 1/5000, cost = 8000, duration = 2},
    PW_Engine_Failure = {probability = 1/1000, cost = 0, duration = 720}, -- 30 days immobilization
    ATC_Strike = {probability = 0.05, cost = 0, duration = 24} -- 24h delay
}

-- Component wear costs based on real maintenance data
local COMPONENT_WEAR = {
    Landing_Gear = {per_hour = 6, per_cycle = 107},
    APU = {per_hour = 15},
    Tires_Brakes = {per_cycle = 107},
    Engine_Overhaul = {cost = 45000, interval = 6000},
    C_Check = {cost = 350000, interval = 26000}
}
local ToLiss_MCDU_Perf = nil            -- The value of the performance parameter for the MCDU
local ToLiss_Menu_ID = nil              -- ID of the wear & tear menu within the aircraft menu
local ToLiss_Menu_Index = nil           -- Index of the main menu within the aircraft menu
local ToLiss_Menu_Items = { --Table for main menu items
"ToLiss Wear & Tear", -- Index 1
"Aircraft:",          -- Index 2
"Engines:",           -- Index 3
"[Separator]",        -- Index 4
"Flight Revenue:",    -- Index 5
"Refuel Cost:",       -- Index 6
"Cash:",              -- Index 7
"Operating Cost:",    -- Index 8
"Economic Dashboard", -- Index 9
"[Separator]",        -- Index 10
"MCDU PERF:",         -- Index 11
"[Separator]",        -- Index 12
"Debug",              -- Index 13
"Gradual Aging",      -- Index 14
"Persistence",        -- Index 15
"Autosave",           -- Index 16
"Strict Mode",        -- Index 17
"[Separator]",        -- Index 18
"Save Wear And Tear", -- Index 19
"Load Wear And Tear", -- Index 20
"Reset Wear And Tear", -- Index 21
}
local ToLiss_Menu_Pointer = ffi.new("const char") -- C pointer for the menu, used by the XPLM API
local ToLiss_OldVals = {Age={0,0},Cash=0,Fuel=0}      -- Stores old values for detemrining changes
--[[

DATAREFS

]]
simDR_AircraftAge = find_dataref("toliss_airbus/iscsinterface/aircraftAge")
simDR_APU_FF = find_dataref("AirbusFBW/APUFuelFlow")
simDR_Engine_FF = find_dataref("AirbusFBW/ENGFuelFlowArray")
simDR_EngineAge = find_dataref("toliss_airbus/iscsinterface/engineAge")
simDR_EngineRunning = find_dataref("sim/flightmodel2/engines/engine_is_burning_fuel")
simDR_ET_Hours = find_dataref("AirbusFBW/ClockETHours")
simDR_ET_Minutes = find_dataref("AirbusFBW/ClockETMinutes")
simDR_ET_Switch = find_dataref("AirbusFBW/ClockETSwitch")
simDR_FuelTotal = find_dataref("sim/flightmodel/weight/m_fuel_total")
simDR_LiveryPath = find_dataref("sim/aircraft/view/acf_livery_path")
simDR_Num_Engines = find_dataref("sim/aircraft/engine/acf_num_engines")
simDR_On_Ground = find_dataref("sim/flightmodel/failures/onground_any")
simDR_Station_Mass = find_dataref("sim/flightmodel/weight/m_stations")
simDR_TrueAirspeed = find_dataref("sim/flightmodel/position/true_airspeed")
simDR_ToLiss_N1 = find_dataref("AirbusFBW/anim/ENGN1Speed")
simDR_XPVersion = find_dataref("sim/version/xplane_internal_version")
if simDR_XPVersion >= 120000 then simDR_RelativePath = find_dataref("sim/aircraft/view/acf_relative_path") end -- Safeguard for XP11
--[[

FUNCTIONS

]]
--[[ Wrapper for the persistence file to handle empty livery paths ]]
function Check_LiveryPath()
    if simDR_XPVersion >= 120000 then
        if simDR_LiveryPath == "" then Persistence_FilePath = tostring(simDR_RelativePath):match("(.*[/\\])")..Persistence_File else Persistence_FilePath = simDR_LiveryPath..Persistence_File end
    else
        Persistence_FilePath = simDR_LiveryPath..Persistence_File -- X-Plane 11 only; DO NOT USE THE DEFAULT LIVERY
    end
end
--[[ Randomizes the starting values for engine damage ]]
function Randomize_Age()
    math.randomseed(os.time()) -- Prime Lua's random number generator using UNIX time
    Table_SetVal(ToLiss_Persistence_Data,"Age_Aircraft",math.random(ToLiss_AgeLimit.Min * 1000,ToLiss_AgeLimit.Max * 1000) / 1000)  -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    Table_SetVal(ToLiss_Persistence_Data,"Age_Engines",math.random(ToLiss_AgeLimit.Min * 1000,ToLiss_AgeLimit.Max * 1000) / 1000)  -- Generates a random number between lower and upper limit; must be multiplied with 10000 because Lua's RNG only supplies integers as result
    print("ToLiss Wear and Tear: Randomized start age for aircraft and engine (A: "..Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft")..", E: "..Table_GetVal(ToLiss_Persistence_Data,"Age_Engines")..").")
end
--[[ Convert input time from seconds to hours, then divide by age time to obtain fraction to apply to the range of ToLiss datarefs. Clamp to the min or max values of ToLiss' datartef range ]]
function ToLiss_Conv_TimeToAge(target,time,reftime)
     Table_SetVal(ToLiss_Persistence_Data,target,Clamp(Table_GetVal(ToLiss_Persistence_Data,target) + (time / 3600 / reftime * (ToLiss_AgeLimit.Max - ToLiss_AgeLimit.Min)),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max))
end
--[[ Determines accumulated wear time for this session ]]
function ToLiss_Calc_AgeOrTime()
    -- Aircraft, only ages when TAS > 100
    if simDR_TrueAirspeed > 100 then
        if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 1 then ToLiss_Conv_TimeToAge("Age_Aircraft",(UpdateInterval * simDR_TrueAirspeed / ToLiss_Max_TAS),Aircraft_Wear_Time) -- Calculate age offset directly, scales with ratio of TAS to max TAS
        else ToLiss_Flight.TimeAircraft = ToLiss_Flight.TimeAircraft + (UpdateInterval * simDR_TrueAirspeed / ToLiss_Max_TAS) end -- Aircraft usage time, scales with ratio of TAS to max TAS
    end
    -- Engines
    for i=0,(simDR_Num_Engines-1) do -- Loop though the engines by index (num_engines = 2 or 4, but index starts at zero)
        if simDR_EngineRunning[i] == 1 then
            if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 1 then ToLiss_Conv_TimeToAge("Age_Engines",(UpdateInterval / simDR_Num_Engines * (simDR_ToLiss_N1[i] / 100)),Engine_Wear_Time) -- Calculate age offset directly, scale with fraction of N1
            else ToLiss_Flight.TimeEngine = ToLiss_Flight.TimeEngine + (UpdateInterval / simDR_Num_Engines * (simDR_ToLiss_N1[i] / 100)) end -- Engine time; fraction of the interval because of multiple engines, scale with fraction of N1
        end
    end
    if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then
        print("ToLiss Wear and Tear: Age Delta Aircraft "..(Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft") - ToLiss_OldVals.Age[1])..", Engines: "..(Table_GetVal(ToLiss_Persistence_Data,"Age_Engines") - ToLiss_OldVals.Age[2]))
        ToLiss_OldVals.Age[1] = Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft") ToLiss_OldVals.Age[2] = Table_GetVal(ToLiss_Persistence_Data,"Age_Engines")
    end
    -- if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Aircraft wear time "..ToLiss_Flight.TimeAircraft.." s, engine wear time: "..ToLiss_Flight.TimeEngine.." s.") end
    if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 1 then ToLiss_Apply_Age() end -- Apply the new age values with gradial aging
end
--[[ Calculates the new age based on cumulated usage ]]
function ToLiss_Calc_AgeFromTime()
    ToLiss_Conv_TimeToAge("Age_Aircraft",ToLiss_Flight.TimeAircraft,Aircraft_Wear_Time)
    ToLiss_Conv_TimeToAge("Age_Engines",ToLiss_Flight.TimeEngine,Engine_Wear_Time)
    ToLiss_Apply_Age()
end
--[[ Calculates the PERF parameter for the MCDU ]]
function ToLiss_Calc_PERF()
    ToLiss_MCDU_Perf = Clamp(simDR_AircraftAge + simDR_EngineAge,(ToLiss_AgeLimit.Min * 2),(ToLiss_AgeLimit.Max * 2)) -- Clamping limits doubled from age limit because two parameters are taken into account
    if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: ToLiss MCDU data entry: DATA --> A/C STATUS --> CHG CODE: ARM --> PERF: /"..string.format("%.1f",ToLiss_MCDU_Perf)) end
end
--[[ Writes the aircraft and engine age to their datarefs ]]
function ToLiss_Apply_Age()
    simDR_AircraftAge = Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft")
    simDR_EngineAge = Table_GetVal(ToLiss_Persistence_Data,"Age_Engines")
    --if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Aircraft age is "..simDR_AircraftAge..", engine age is "..simDR_EngineAge) end
end
--[[ Determines the current change in fuel level ]]
function ToLiss_Calc_Refuel()
    local Total_FF = simDR_Engine_FF[0] + simDR_Engine_FF[1] + simDR_Engine_FF[2] + simDR_Engine_FF[3] + simDR_APU_FF
    --if ToLiss_Flight.EngineRunCounter == 0 then
    --if simDR_ET_Switch == 0 then
        if math.abs(simDR_FuelTotal - ToLiss_OldVals.Fuel) > (5 * Total_FF) then
            ToLiss_Flight.Refuel = ToLiss_Flight.Refuel + (simDR_FuelTotal - ToLiss_OldVals.Fuel)
            ToLiss_Flight.RefuelCost = math.ceil(ToLiss_Flight.Refuel * Table_GetVal(ToLiss_Persistence_Data,"Cost_FuelPerKg"))
            print("ToLiss Wear and Tear: Discovered artificial fuel level change of "..string.format("%.4f",(simDR_FuelTotal - ToLiss_OldVals.Fuel)).." kg (cumul "..string.format("%.3f",ToLiss_Flight.Refuel).." kg).")
        end
    --[[ elseif ToLiss_Flight.Refuel ~= 0 then
        Table_SetVal(ToLiss_Persistence_Data,"Cash",(Table_GetVal(ToLiss_Persistence_Data,"Cash") - ToLiss_Flight.RefuelCost))
        print("ToLiss Wear and Tear: Refueled "..string.format("%.2f",ToLiss_Flight.Refuel).." kg for "..ToLiss_Flight.RefuelCost.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency")..".")
        ToLiss_Flight.RefuelCost = 0
        ToLiss_Flight.Refuel = 0
    end ]]
    ToLiss_OldVals.Fuel = simDR_FuelTotal
end
--[[ Get the current payload ]]
function ToLiss_Calc_Payload()
    ToLiss_Flight.Payload = 0
    for i=1,8 do
        ToLiss_Flight.Payload = ToLiss_Flight.Payload + simDR_Station_Mass[i]
    end
    --print(ToLiss_Flight.Payload)
end
--[[ Pays out a flight ]]
function ToLiss_Finish_Flight()
    ToLiss_Flight.Time = 0
    ToLiss_Flight.Revenue = 0
    ToLiss_Flight.Refuel = 0
    ToLiss_Flight.RefuelCost = 0
    ToLiss_Flight.Airborne = 0
    if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Flight reset.") end
    ToLiss_CheckAndSavePersistence()
end
--[[ Prints the current flight phase to the dev console ]]
function ToLiss_PrintPhase()
    print("ToLiss Wear and Tear: Flight phase changed to: "..ToLiss_Flight.Phase)
end
--[[ Flight state tracker ]]
function ToLiss_Check_FlightState()
    -- Checks the amount of running engines
    ToLiss_Flight.EngineRunCounter = 0
    for i=0,(simDR_Num_Engines-1) do -- Loop though the engines by index (num_engines = 2 or 4, but index starts at zero)
        if simDR_EngineRunning[i] == 1 then
            ToLiss_Flight.EngineRunCounter = ToLiss_Flight.EngineRunCounter + 1
        end
    end
    -- Determine flight phase
    if simDR_On_Ground == 1 then
        if ToLiss_Flight.Airborne == 0 then
            if ToLiss_Flight.EngineRunCounter == 0 and ToLiss_Flight.Phase ~= "Parked Before Flight" then ToLiss_Flight.Phase = "Parked Before Flight" ToLiss_PrintPhase()  end
            if ToLiss_Flight.EngineRunCounter > 0 and ToLiss_Flight.Phase ~= "On Ground Before Flight" then ToLiss_Flight.Phase = "On Ground Before Flight" ToLiss_PrintPhase() end
        else
            if ToLiss_Flight.EngineRunCounter == 0 and ToLiss_Flight.Phase ~= "Parked After Flight" then ToLiss_Flight.Phase = "Parked After Flight" ToLiss_PrintPhase() end
            if ToLiss_Flight.EngineRunCounter > 0 and ToLiss_Flight.Phase ~= "On Ground After Flight" then ToLiss_Flight.Phase = "On Ground After Flight" ToLiss_PrintPhase() end
        end
    else
        if ToLiss_Flight.EngineRunCounter == 0 and ToLiss_Flight.Phase ~= "Apparently Both Engines Failed" then ToLiss_Flight.Phase = "Apparently Both Engines Failed" ToLiss_PrintPhase() end
        if ToLiss_Flight.EngineRunCounter > 0 and ToLiss_Flight.Phase ~= "In Flight" then ToLiss_Flight.Phase = "In Flight" ToLiss_PrintPhase() end
    end
    --
    -- Determine if flight was airborne
    if simDR_On_Ground == 0 and ToLiss_Flight.Airborne == 0 then ToLiss_Flight.Airborne = 1 end
    -- Track refueling
    ToLiss_Calc_Refuel()
    -- Checks if the elapsed time has been reset
    if ToLiss_Flight.LockET == 1 then
        if simDR_ET_Hours + (simDR_ET_Minutes / 60) <= 0.01 then ToLiss_Flight.LockET = 0 end
    end
end
--[[ Calculates payload revenue ]]
function ToLiss_Calc_Revenue()
    -- Calculate payload mass from payload stations 1 to 8 (0 is used for Neo engine weight compensation by ToLiss) when all engines are off
    if ToLiss_Flight.EngineRunCounter == 0 then
        ToLiss_Calc_Payload()
        -- Arrival items
        if ToLiss_Flight.Time > 0 and simDR_ET_Switch ~= 0 and ToLiss_OldVals.Cash ~= (Table_GetVal(ToLiss_Persistence_Data,"Cash") + ToLiss_Flight.Revenue) then
            if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 0 or (Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and ToLiss_Flight.Airborne ~= 0 and ToLiss_Flight.LockET == 0) then
                Table_SetVal(ToLiss_Persistence_Data,"Cash",(Table_GetVal(ToLiss_Persistence_Data,"Cash") + ToLiss_Flight.Revenue - ToLiss_Flight.RefuelCost))
                --Table_SetVal(ToLiss_Persistence_Data,"Cash",(Table_GetVal(ToLiss_Persistence_Data,"Cash") + ToLiss_Flight.Revenue))
                ToLiss_Flight.LockET = 1
                print("ToLiss Wear and Tear: Flight finished. Flight Revenue: "..ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency")..", Fuel Cost: "..ToLiss_Flight.RefuelCost.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." --> Net Result: "..(ToLiss_Flight.Revenue - ToLiss_Flight.RefuelCost).." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." --> New Cash Balance: "..Table_GetVal(ToLiss_Persistence_Data,"Cash").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"))
            end
            ToLiss_Finish_Flight()
            ToLiss_OldVals.Cash = Table_GetVal(ToLiss_Persistence_Data,"Cash")
        end
    elseif ToLiss_Flight.LockET == 0 then
        ToLiss_Flight.Time = simDR_ET_Hours + (simDR_ET_Minutes / 60)
        ToLiss_Flight.Revenue = math.ceil(Table_GetVal(ToLiss_Persistence_Data,"RevenuePerKgPerHr") * ToLiss_Flight.Payload * ToLiss_Flight.Time)
    end
end

--[[ Calculate operating costs based on flight phase and airline profile ]]
function ToLiss_Calc_Operating_Costs()
    local airline = "AIR_FRANCE" -- Default airline, can be changed based on livery or user selection
    local profile = AIRLINE_PROFILES[airline]
    
    -- Determine flight phase for fuel consumption
    local phase = "Taxi"
    if simDR_On_Ground == 0 then
        if simDR_TrueAirspeed < 250 then
            phase = "Climb"
        elseif simDR_TrueAirspeed >= 250 and simDR_TrueAirspeed < 400 then
            phase = "Cruise"
        else
            phase = "Descent"
        end
    end
    
    -- Calculate fuel cost based on phase and efficiency
    local fuel_consumption = FUEL_CONSUMPTION[phase] * (1 / profile.fuel_efficiency)
    ToLiss_Flight.FuelConsumed = ToLiss_Flight.FuelConsumed + (fuel_consumption / 3600) -- Convert kg/h to kg/s for per-second update
    
    -- Calculate maintenance cost based on wear
    local maintenance_cost = COMPONENT_WEAR.Landing_Gear.per_hour / 3600
    maintenance_cost = maintenance_cost + (COMPONENT_WEAR.APU.per_hour / 3600)
    ToLiss_Flight.MaintenanceCost = ToLiss_Flight.MaintenanceCost + (maintenance_cost * profile.maintenance_factor)
    
    -- Calculate crew cost based on airline factor
    local crew_cost = (profile.base_cost_per_hour * profile.crew_cost_factor) / 3600
    ToLiss_Flight.CrewCost = ToLiss_Flight.CrewCost + crew_cost
    
    -- Total operating cost for this update
    local operating_cost = (fuel_consumption / 3600 * Table_GetVal(ToLiss_Persistence_Data,"Cost_FuelPerKg")) + maintenance_cost + crew_cost
    ToLiss_Flight.OperatingCost = ToLiss_Flight.OperatingCost + operating_cost
    
    if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then
        print(string.format("ToLiss Wear and Tear: Operating costs - Fuel: %.2f, Maintenance: %.2f, Crew: %.2f, Total: %.2f",
            fuel_consumption / 3600 * Table_GetVal(ToLiss_Persistence_Data,"Cost_FuelPerKg"),
            maintenance_cost,
            crew_cost,
            operating_cost))
    end
end

--[[ Check for random events based on probabilities ]]
function ToLiss_Check_Random_Events()
    math.randomseed(os.time()) -- Ensure randomness
    local event_occurred = false
    
    for event_name, event_data in pairs(RANDOM_EVENTS) do
        if math.random() < event_data.probability then
            event_occurred = true
            print("ToLiss Wear and Tear: Random event occurred: " .. event_name)
            
            -- Apply event consequences
            if event_data.cost > 0 then
                Table_SetVal(ToLiss_Persistence_Data,"Cash", Table_GetVal(ToLiss_Persistence_Data,"Cash") - event_data.cost)
                print("ToLiss Wear and Tear: Event cost: " .. event_data.cost .. " " .. Table_GetVal(ToLiss_Persistence_Data,"Currency"))
            end
            
            if event_data.duration > 0 then
                print("ToLiss Wear and Tear: Event duration: " .. event_data.duration .. " hours of immobilization")
            end
            
            -- Break after first event to avoid multiple events at once
            break
        end
    end
    
    return event_occurred
end

--[[ Calculate airport fees based on destination ]]
function ToLiss_Calc_Airport_Fees(destination)
    local fee = AIRPORT_FEES.DEFAULT
    if AIRPORT_FEES[destination] ~= nil then
        fee = AIRPORT_FEES[destination]
    end
    ToLiss_Flight.AirportFees = fee
    print("ToLiss Wear and Tear: Airport fees for " .. destination .. ": " .. fee .. " " .. Table_GetVal(ToLiss_Persistence_Data,"Currency"))
    return fee
end

--[[ Update economic dashboard with performance indicators ]]
function ToLiss_Update_Economic_Dashboard()
    local total_hours = ToLiss_Flight.Time
    if total_hours > 0 then
        local cost_per_hour = ToLiss_Flight.OperatingCost / total_hours
        local revenue_per_hour = ToLiss_Flight.Revenue / total_hours
        local profit_per_hour = revenue_per_hour - cost_per_hour
        
        if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then
            print(string.format("ToLiss Wear and Tear: Economic metrics - Cost/hr: %.2f, Revenue/hr: %.2f, Profit/hr: %.2f",
                cost_per_hour, revenue_per_hour, profit_per_hour))
        end
    end
end

--[[ Autosaving function ]]
function ToLiss_SavePersistence()
    if Persistence_FilePath ~= nil then Persistence_Write(ToLiss_Persistence_Data,Persistence_FilePath) end
end
--[[ Checks the persistence and autosave state and calls the persistence save function ]]
function ToLiss_CheckAndSavePersistence()
    if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 1 then ToLiss_SavePersistence() end
end
--[[

MENU

]]
--[[ Menu callbacks. The functions to run or actions to do when picking any non-title and nonseparator item from the table above ]]
function ToLiss_Menu_Callbacks(itemref)
    for i=2,#ToLiss_Menu_Items do
        if itemref == ToLiss_Menu_Items[i] then
            if i == 2 then -- Overhaul Aircraft
                if ToLiss_Flight.EngineRunCounter == 0 and Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft") > ToLiss_AgeLimit.Min then
                    if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 0 or (Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and Table_GetVal(ToLiss_Persistence_Data,"Cash") > Table_GetVal(ToLiss_Persistence_Data,"Cost_Aircraft")) then
                        ToLiss_Flight.TimeAircraft = 0
                        Table_SetVal(ToLiss_Persistence_Data,"Age_Aircraft",ToLiss_AgeLimit.Min)
                        Table_SetVal(ToLiss_Persistence_Data,"Cash",(Table_GetVal(ToLiss_Persistence_Data,"Cash") - Table_GetVal(ToLiss_Persistence_Data,"Cost_Aircraft")))
                        print("ToLiss Wear and Tear: Overhauled Aircraft for "..Table_GetVal(ToLiss_Persistence_Data,"Cost_Aircraft").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency")..".")
                        ToLiss_CheckAndSavePersistence()
                        ToLiss_Apply_Age()
                        ToLiss_Calc_PERF()
                    end
                end
            end
            if i == 3 then -- Overhaul Engines
                if ToLiss_Flight.EngineRunCounter == 0 and Table_GetVal(ToLiss_Persistence_Data,"Age_Engines") > ToLiss_AgeLimit.Min then
                    if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 0 or (Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and Table_GetVal(ToLiss_Persistence_Data,"Cash") > Table_GetVal(ToLiss_Persistence_Data,"Cost_Engines")) then
                        ToLiss_Flight.TimeEngine = 0
                        Table_SetVal(ToLiss_Persistence_Data,"Age_Engines",ToLiss_AgeLimit.Min)
                        Table_SetVal(ToLiss_Persistence_Data,"Cash",(Table_GetVal(ToLiss_Persistence_Data,"Cash") - Table_GetVal(ToLiss_Persistence_Data,"Cost_Engines")))
                        print("ToLiss Wear and Tear: Overhauled Engines for "..Table_GetVal(ToLiss_Persistence_Data,"Cost_Engines").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency")..".")
                        ToLiss_CheckAndSavePersistence()
                        ToLiss_Apply_Age()
                        ToLiss_Calc_PERF()
                    end
                end
            end
            if i == 5 then -- Flight Revenue
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then ToLiss_Calc_Payload() end
            end
            if i == 6 then -- Refuel Cost
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then ToLiss_Flight.RefuelCost = 0 ToLiss_Flight.Refuel = 0 end
            end
            if i == 9 then -- MCDU PERF
                ToLiss_Calc_PERF()
            end
            if i == 11 then -- Debug
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Debug",1) else Table_SetVal(ToLiss_Persistence_Data,"Debug",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 12 then -- Gradual Aging
                if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 0 then Table_SetVal(ToLiss_Persistence_Data,"GradualAging",1) else Table_SetVal(ToLiss_Persistence_Data,"GradualAging",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 13 then -- Persistence
                if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Persistence",1) else Table_SetVal(ToLiss_Persistence_Data,"Persistence",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 14 then -- Autosave
                if Table_GetVal(ToLiss_Persistence_Data,"Autosave") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Autosave",1) else Table_SetVal(ToLiss_Persistence_Data,"Autosave",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 15 then -- Strict mode
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Strict",1) else Table_SetVal(ToLiss_Persistence_Data,"Strict",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 17 then -- Save
                ToLiss_SavePersistence()
            end
            if i == 18 then -- Load
                Persistence_Read(Persistence_FilePath,ToLiss_Persistence_Data)
                ToLiss_Apply_Age()
                ToLiss_Calc_PERF()
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Persistence data applied.") end
            end
            if i == 19 then -- Reset
                Table_Copy(ToLiss_Persistence_Data_Init,ToLiss_Persistence_Data)
                if Random_Start_Vals == true then Randomize_Age() end
                ToLiss_Apply_Age()
                ToLiss_Calc_PERF()
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Persistence data reset.") end
            end
            ToLiss_Menu_Watchdog(ToLiss_Menu_Items,i)
        end
    end
end
--[[ Menu watchdog that is used to check an item or change its prefix ]]
function ToLiss_Menu_Watchdog(intable,index)
    if index == 2 then -- Overhaul Aircraft
        if ToLiss_Flight.EngineRunCounter == 0 then
            if Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft") > ToLiss_AgeLimit.Min then
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and Table_GetVal(ToLiss_Persistence_Data,"Cash") < Table_GetVal(ToLiss_Persistence_Data,"Cost_Aircraft") then
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"No Cash to Overhaul (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable)
                else
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"Overhaul for "..Table_GetVal(ToLiss_Persistence_Data,"Cost_Aircraft").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable)
                end
            else
                Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"No Need to Overhaul (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable)
            end
        end
        if ToLiss_Flight.EngineRunCounter > 0 then Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"Operating (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Aircraft"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable) end
    end
    if index == 3 then -- Overhaul Engines
        if ToLiss_Flight.EngineRunCounter == 0 then
            if Table_GetVal(ToLiss_Persistence_Data,"Age_Engines") > ToLiss_AgeLimit.Min then
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and Table_GetVal(ToLiss_Persistence_Data,"Cash") < Table_GetVal(ToLiss_Persistence_Data,"Cost_Engines") then
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"No Cash to Overhaul (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Engines"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable)
                else
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"Overhaul for "..Table_GetVal(ToLiss_Persistence_Data,"Cost_Engines").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Engines"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable)
                end
            else
                Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"No Need to Overhaul (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Engines"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable)
            end
        end
        if ToLiss_Flight.EngineRunCounter > 0 then Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"Operating (Wear: "..Verbalize_Wear(Table_GetVal(ToLiss_Persistence_Data,"Age_Engines"),ToLiss_AgeLimit.Min,ToLiss_AgeLimit.Max)..")",intable) end
    end
    if index == 5 then -- Flight revenue
        if ToLiss_Flight.Revenue == 0 then
            if ToLiss_Flight.Payload > 0 then
                if ToLiss_Flight.LockET == 0 then
                    if simDR_ET_Switch ~= 0 and ToLiss_Flight.EngineRunCounter == 0 then Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"[Start Engines and Elapsed Time]",intable) end
                    if simDR_ET_Switch == 0 and ToLiss_Flight.EngineRunCounter == 0 then Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"[Start Engines]",intable) end
                    if simDR_ET_Switch ~= 0 and ToLiss_Flight.EngineRunCounter > 0 then Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"[Start Elapsed Time]",intable) end
                else Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"[Reset Elapsed Time!]",intable) end
            else
                Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"[No Payload]",intable)
            end
        else
            if simDR_ET_Switch == 0 and ToLiss_Flight.EngineRunCounter > 0 then
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and ToLiss_Flight.Airborne == 0 then
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (In Progress; Get Airborne!)",intable)
                else
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (In Progress)",intable)
                end
            end
            if simDR_ET_Switch == 0 and ToLiss_Flight.EngineRunCounter == 0 then
                Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"[Stop Elapsed Time]",intable)
            end
            if simDR_ET_Switch ~= 0 and ToLiss_Flight.EngineRunCounter > 0 then
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and ToLiss_Flight.Airborne == 0 then
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (ET Stopped; Get Airborne!)",intable)
                else
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (ET Stopped)",intable)
                end
            end
            if simDR_ET_Switch ~= 0 and ToLiss_Flight.EngineRunCounter == 0 then
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and ToLiss_Flight.Airborne == 0 then
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (Arrived; No Payout!)",intable)
                else
                    Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.Revenue.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency").." (Arrived)",intable)
                end
            end
        end
    end
    if index == 6 then -- Refuel cost
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.RefuelCost.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"),intable)
    end
    if index == 7 then -- Cash
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,Table_GetVal(ToLiss_Persistence_Data,"Cash").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"),intable)
    end
    if index == 9 then -- MCDU PERF
        if ToLiss_MCDU_Perf ~= nil then Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,string.format("%.1f",ToLiss_MCDU_Perf),intable) else Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"-.-",intable) end
    end
    if index == 11 then -- Debug
        if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
    if index == 12 then -- Gradual Aging
        if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
    if index == 13 then -- Persistence
        if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
    if index == 14 then -- Autosave
        if Table_GetVal(ToLiss_Persistence_Data,"Autosave") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index," (Interval: "..Table_GetVal(ToLiss_Persistence_Data,"AutosaveInterval").." s)",intable)
    end
    if index == 8 then -- Operating Cost
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,string.format("%.2f",ToLiss_Flight.OperatingCost).." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"),intable)
    end
    if index == 9 then -- Economic Dashboard
        local total_hours = ToLiss_Flight.Time
        if total_hours > 0 then
            local cost_per_hour = ToLiss_Flight.OperatingCost / total_hours
            local revenue_per_hour = ToLiss_Flight.Revenue / total_hours
            local profit_per_hour = revenue_per_hour - cost_per_hour
            Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,string.format("Cost/hr: %.2f, Profit/hr: %.2f", cost_per_hour, profit_per_hour),intable)
        else
            Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"No flight data",intable)
        end
    end
    if index == 17 then -- Strict Mode
        if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
end
--[[ Build logic for the main menu ]]
function ToLiss_Menu_Build()
    local Menu_Indices = {}
    for i=2,#ToLiss_Menu_Items do Menu_Indices[i] = 0 end
    if ToLiss_XPLM ~= nil then
        ToLiss_Menu_Index = ToLiss_XPLM.XPLMAppendMenuItem(ToLiss_XPLM.XPLMFindAircraftMenu(),ToLiss_Menu_Items[1],ffi.cast("void *","None"),1)
        ToLiss_Menu_ID = ToLiss_XPLM.XPLMCreateMenu(ToLiss_Menu_Items[1],ToLiss_XPLM.XPLMFindAircraftMenu(),ToLiss_Menu_Index,function(inMenuRef,inItemRef) ToLiss_Menu_Callbacks(inItemRef) end,ffi.cast("void *",ToLiss_Menu_Pointer))
        for i=2,#ToLiss_Menu_Items do
            if ToLiss_Menu_Items[i] ~= "[Separator]" then
                ToLiss_Menu_Pointer = ToLiss_Menu_Items[i]
                Menu_Indices[i] = ToLiss_XPLM.XPLMAppendMenuItem(ToLiss_Menu_ID,ToLiss_Menu_Items[i],ffi.cast("void *",ToLiss_Menu_Pointer),1)
            else
                ToLiss_XPLM.XPLMAppendMenuSeparator(ToLiss_Menu_ID)
            end
        end
        for i=2,#ToLiss_Menu_Items do
            if ToLiss_Menu_Items[i] ~= "[Separator]" then
                ToLiss_Menu_Watchdog(ToLiss_Menu_Items,i)
            end
        end
        print("ToLiss Wear and Tear: Menu initialized")
    end
end
--[[

TIMERS

]]
--[[ DEBUG ONLY! ]]
function Print_Structure()
    for i=1,#ToLiss_Persistence_Data do
        print(ToLiss_Persistence_Data[i][2])
    end
end
--[[ 1 Second main timer loop ]]
function ToLiss_MainTimer()
    -- Menu related
    for i=2,#ToLiss_Menu_Items do
        if ToLiss_Menu_Items[i] ~= "[Separator]" then
            ToLiss_Menu_Watchdog(ToLiss_Menu_Items,i)
        end
    end
    -- Checks the flight state
    ToLiss_Check_FlightState()
    -- Flight revenue calculation
    ToLiss_Calc_Revenue()
    -- Calculate operating costs
    ToLiss_Calc_Operating_Costs()
    -- Check for random events (once per minute to avoid spamming)
    if os.time() % 60 == 0 then
        ToLiss_Check_Random_Events()
    end
    -- Update economic dashboard
    ToLiss_Update_Economic_Dashboard()
    --Print_Structure()
end
--[[ Function for the fuel init delay timer ]]
function ToLiss_DelayedInit()
    ToLiss_OldVals.Cash = Table_GetVal(ToLiss_Persistence_Data,"Cash")
    ToLiss_OldVals.Fuel = simDR_FuelTotal
    run_at_interval(ToLiss_MainTimer,1)
    print("ToLiss Wear and Tear: Delayed initialization completed.")
end
--[[

X-PLANE WRAPPERS

]]
--[[ X-Plane session start ]]
function flight_start()
    Table_Copy(ToLiss_Persistence_Data_Init,ToLiss_Persistence_Data)
    ToLiss_FFI_CheckInit() -- DO NOT TOUCH
    Check_LiveryPath()
    if Persistence_FilePath ~= nil then
        local file2 = io.open(Persistence_FilePath, "r") -- Check if persistence file exists
        if file2 then
            Persistence_Read(Persistence_FilePath,ToLiss_Persistence_Data)
            file2:close()
        elseif Random_Start_Vals == true then
            Randomize_Age()
        else
            if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Set aircraft and engine age to brand new.") end
        end
        run_after_time(ToLiss_Apply_Age,InitDelay)
        run_after_time(ToLiss_Calc_PERF,(InitDelay+1)) -- Calculates PERF for the MCDU after applying age
        if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Persistence data applied.") end
        --[[ Autosave timer ]]
        if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 1 and Table_GetVal(ToLiss_Persistence_Data,"Autosave") == 1 and Table_GetVal(ToLiss_Persistence_Data,"AutosaveInterval") > 0 then run_at_interval(ToLiss_SavePersistence,Table_GetVal(ToLiss_Persistence_Data,"AutosaveInterval")) print("ToLiss Wear and Tear: Autosave timer started (interval: "..Table_GetVal(ToLiss_Persistence_Data,"AutosaveInterval").." s).") end
    end
    run_after_time(ToLiss_DelayedInit,InitDelay)
    ToLiss_Menu_Build() -- Build Wear And Tear menu
    if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 then
        if simDR_ET_Switch == 0 and ToLiss_Flight.EngineRunCounter == 0 or (simDR_ET_Switch ~= 0 and ToLiss_Flight.EngineRunCounter == 0 and (simDR_ET_Hours + (simDR_ET_Minutes / 60)) > 0) then ToLiss_Flight.LockET = 1 end
    end
end
--[[ Main timer ]]
run_at_interval(ToLiss_Calc_AgeOrTime,UpdateInterval)
--[[ X-Plane session end/ user aircraft unload ]]
function aircraft_unload() -- Currently not needed
    if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 0 then ToLiss_Calc_AgeFromTime() end
    if Persistence_FilePath ~= nil and Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 1 then
        Persistence_Write(ToLiss_Persistence_Data,Persistence_FilePath)
    end
    Menu_CleanUp(ToLiss_Menu_ID,ToLiss_Menu_Index)
end
