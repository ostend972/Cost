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
-- {"RevenuePerKgPerHr",0.85},             -- The revenue per kg of payload per flight hour (adjusted for A321neo - higher capacity) -- This is now obsolete
{"Strict",1},                           -- 1 = Less cheating possible by checking cash before overhauls and requiring having been airborne to cash in a flight's revenue
{"AirlineProfile","AIR_FRANCE"},        -- The currently selected airline profile
{"CostIndex", 20},                      -- The current Cost Index (0-99)
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
local ToLiss_Flight = {Airborne=0,EngineRunCounter=0,LockET=0,Payload=0,Phase="[None]",Refuel=0,RefuelCost=0,Revenue=0,Time=0,TimeAircraft=0,TimeEngine=0,OperatingCost=0,FuelConsumed=0,MaintenanceCost=0,CrewCost=0,AirportFees=0,Origin="----",Destination="----"}   -- Table for various flight state things
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
local ToLiss_Airline_Menu_ID = nil      -- ID of the airline profile submenu
local ToLiss_CI_Menu_ID = nil           -- ID of the Cost Index submenu
local ToLiss_Menu_Index = nil           -- Index of the main menu within the aircraft menu
local ToLiss_Menu_Items = { --Table for main menu items, DO NOT CHANGE ORDER WITHOUT UPDATING CALLBACKS
"ToLiss Wear & Tear", -- Index 1
"Aircraft:",          -- Index 2
"Engines:",           -- Index 3
"[Separator]",        -- Index 4
"Airline Profile:",   -- Index 5
"Cost Index:",        -- Index 6
"[Separator]",        -- Index 7
"Import SimBrief Plan",-- Index 8
"Refuel Cost:",       -- Index 9
"Cash:",              -- Index 10
"Operating Cost:",    -- Index 11
"Economic Dashboard", -- Index 12
"[Separator]",        -- Index 13
-- "MCDU PERF:",         -- Index 14 - Obsolete, now automated
"Debug",              -- Index 14
"Gradual Aging",      -- Index 15
"Persistence",        -- Index 16
"Autosave",           -- Index 17
"Strict Mode",        -- Index 18
"[Separator]",        -- Index 19
"Save Wear And Tear", -- Index 20
"Load Wear And Tear", -- Index 21
"Reset Wear And Tear",-- Index 22
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

-- MCDU Automation DataRefs (based on user prompt)
simDR_MCDU_PerfFactor = find_dataref("sim/cockpit2/engine/EGT_correction") -- For PERF factor
simDR_MCDU_IdleFactor = find_dataref("sim/cockpit2/fmc/idle_factor")      -- For IDLE factor
--[[

FUNCTIONS

]]
--[[ Automatically calculates and sets MCDU PERF and IDLE factors ]]
function ToLiss_Automate_MCDU_Config()
    -- Calculate PERF factor based on total wear, clamped to a realistic range (-2 to +3)
    local perf_factor = Clamp(simDR_AircraftAge + simDR_EngineAge, -2.0, 3.0)

    -- Calculate IDLE factor, scaled proportionally to PERF, clamped to a realistic range (-1 to +1)
    local idle_factor = Clamp(perf_factor / 3.0, -1.0, 1.0)

    -- Write to datarefs
    if simDR_MCDU_PerfFactor and simDR_MCDU_IdleFactor then
        simDR_MCDU_PerfFactor = perf_factor
        simDR_MCDU_IdleFactor = idle_factor
        if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then
            print(string.format("ToLiss Wear and Tear: MCDU Auto-Config - PERF Factor set to %.2f, IDLE Factor set to %.2f", perf_factor, idle_factor))
        end
    else
        if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then
            print("ToLiss Wear and Tear: MCDU Auto-Config - Could not find PERF/IDLE datarefs.")
        end
    end
end
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
    ToLiss_Flight.Revenue = 0 -- Obsolete, but reset for cleanliness
    ToLiss_Flight.Refuel = 0
    ToLiss_Flight.RefuelCost = 0
    ToLiss_Flight.Airborne = 0
    ToLiss_Flight.OperatingCost=0
    ToLiss_Flight.FuelConsumed=0
    ToLiss_Flight.MaintenanceCost=0
    ToLiss_Flight.CrewCost=0
    ToLiss_Flight.AirportFees=0
    if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Flight data reset for next leg.") end
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
--[[ Handles end-of-flight economic calculations ]]
function ToLiss_Handle_EndOfFlight_Economics()
    -- This function should only run once at the end of a flight.
    -- Condition: Flight has happened (airborne), now on ground, engines off.
    if ToLiss_Flight.Phase == "Parked After Flight" and ToLiss_Flight.LockET == 0 then
        if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 1 and ToLiss_Flight.Airborne == 0 then
            print("ToLiss Wear and Tear: Flight finished without being airborne. No costs processed.")
            ToLiss_Finish_Flight() -- Reset for next flight
            return
        end

        -- 1. Calculate Airport Fees for origin and destination
        local origin_fee = ToLiss_Calc_Airport_Fees(ToLiss_Flight.Origin)
        local destination_fee = ToLiss_Calc_Airport_Fees(ToLiss_Flight.Destination)
        ToLiss_Flight.AirportFees = origin_fee + destination_fee

        -- 2. Calculate Total Flight Cost
        -- OperatingCost has been accumulated during the flight.
        -- RefuelCost has been accumulated during ground operations.
        -- AirportFees has just been calculated.
        local total_cost = ToLiss_Flight.OperatingCost + ToLiss_Flight.RefuelCost + ToLiss_Flight.AirportFees

        -- 3. Deduct costs from cash
        local initial_cash = Table_GetVal(ToLiss_Persistence_Data,"Cash")
        Table_SetVal(ToLiss_Persistence_Data,"Cash", initial_cash - total_cost)

        -- 4. Print detailed summary
        print("==================== FLIGHT COST SUMMARY ====================")
        print(string.format("ToLiss Wear and Tear: Flight Finished."))
        print(string.format("  - Accumulated Operating Costs: %.2f %s", ToLiss_Flight.OperatingCost, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
        print(string.format("  - Fueling Costs: %.2f %s", ToLiss_Flight.RefuelCost, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
        print(string.format("  - Airport Fees: %.2f %s", ToLiss_Flight.AirportFees, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
        print(string.format("  --------------------------------------------------"))
        print(string.format("  - TOTAL FLIGHT COST: %.2f %s", total_cost, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
        print(string.format("  - Initial Cash: %.2f %s", initial_cash, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
        print(string.format("  - New Cash Balance: %.2f %s", Table_GetVal(ToLiss_Persistence_Data,"Cash"), Table_GetVal(ToLiss_Persistence_Data,"Currency")))
        print("=============================================================")

        -- 5. Lock and reset for next flight
        ToLiss_Flight.LockET = 1 -- Lock to prevent this block from running again
        ToLiss_Finish_Flight()
        ToLiss_OldVals.Cash = Table_GetVal(ToLiss_Persistence_Data,"Cash")
    end

    -- This part tracks the flight time, which is still useful for the dashboard
    if ToLiss_Flight.EngineRunCounter > 0 and ToLiss_Flight.LockET == 0 then
        ToLiss_Flight.Time = simDR_ET_Hours + (simDR_ET_Minutes / 60)
    end
end

--[[ Calculate operating costs based on flight phase and airline profile ]]
function ToLiss_Calc_Operating_Costs()
    local airline = Table_GetVal(ToLiss_Persistence_Data,"AirlineProfile") -- Get currently selected airline
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
    
    -- Calculate fuel cost based on phase, efficiency, and Cost Index
    local ci = Table_GetVal(ToLiss_Persistence_Data, "CostIndex")
    local ci_fuel_factor = 1 + (ci - 20) * 0.003 -- +/- 3% consumption per 10 points away from CI 20.
    local fuel_consumption = (FUEL_CONSUMPTION[phase] * ci_fuel_factor) * (1 / profile.fuel_efficiency)
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
--[[ Autosaving function ]]
function ToLiss_SavePersistence()
    if Persistence_FilePath ~= nil then Persistence_Write(ToLiss_Persistence_Data,Persistence_FilePath) end
end
--[[ Checks the persistence and autosave state and calls the persistence save function ]]
function ToLiss_CheckAndSavePersistence()
    if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 1 then ToLiss_SavePersistence() end
end
--[[

SIMBRIEF INTEGRATION

]]
-- Load required libraries in protected mode
local socket_ok, socket = pcall(require, "socket.http")
local xml2lua_ok, xml2lua = pcall(require, "xml2lua")
local handler_ok, handler = pcall(require, "xmlhandler.tree")
local ltn12_ok, ltn12 = pcall(require, "ltn12")

--[[ Function to fetch XML from SimBrief URL ]]
function fetchSimBriefXML(url)
    if not socket_ok or not ltn12_ok then
        print("ToLiss Wear and Tear: ERROR - socket.http or ltn12 library not found. SimBrief integration disabled.")
        return nil
    end

    local response_body = {}
    local res, code = socket.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }

    if code == 200 then
        print("ToLiss Wear and Tear: SimBrief XML downloaded successfully.")
        return table.concat(response_body)
    else
        print("ToLiss Wear and Tear: ERROR - Failed to download SimBrief XML. HTTP Code: "..tostring(code))
        return nil
    end
end

--[[ Function to parse SimBrief XML data ]]
function parseSimBriefXML(xml_data)
    if not xml2lua_ok or not handler_ok then
        print("ToLiss Wear and Tear: ERROR - xml2lua or xmlhandler.tree not found. SimBrief integration disabled.")
        return nil
    end

    local parser = xml2lua.parser(handler)
    local ok, result = pcall(parser.parse, parser, xml_data)

    if ok and handler.root and handler.root.OFP and handler.root.OFP[1] then
        print("ToLiss Wear and Tear: SimBrief XML parsed successfully.")
        return handler.root.OFP[1]
    else
        print("ToLiss Wear and Tear: ERROR - Failed to parse SimBrief XML.")
        print(tostring(result)) -- Print error for debugging
        return nil
    end
end

--[[ Main function to read URL from file and integrate SimBrief data ]]
function ToLiss_Integrate_SimBrief_From_File()
    local url_file_path = "scripts/WearAndTear/simbrief_url.txt"
    local file = io.open(url_file_path, "r")

    if not file then
        print("ToLiss Wear and Tear: ERROR - Could not find simbrief_url.txt in "..url_file_path)
        return
    end

    local url = file:read("*a")
    file:close()
    url = string.gsub(url, "%s+", "") -- Trim whitespace

    if url == "" then
        print("ToLiss Wear and Tear: ERROR - simbrief_url.txt is empty.")
        return
    end

    print("ToLiss Wear and Tear: Starting SimBrief import from URL: " .. url)
    local xml_data = fetchSimBriefXML(url)
    if not xml_data then return end

    local ofp = parseSimBriefXML(xml_data)
    if not ofp then return end

    -- Extract and apply data
    if ofp.general and ofp.general.costindex then
        local ci = tonumber(ofp.general.costindex)
        if ci then
            Table_SetVal(ToLiss_Persistence_Data, "CostIndex", Clamp(ci, 0, 99))
            print("ToLiss Wear and Tear: SimBrief -> Cost Index set to " .. ci)
        end
    end

    if ofp.departure and ofp.departure.icao_code then
        ToLiss_Flight.Origin = ofp.departure.icao_code
        print("ToLiss Wear and Tear: SimBrief -> Origin set to " .. ToLiss_Flight.Origin)
    end

    if ofp.arrival and ofp.arrival.icao_code then
        ToLiss_Flight.Destination = ofp.arrival.icao_code
        print("ToLiss Wear and Tear: SimBrief -> Destination set to " .. ToLiss_Flight.Destination)
    end

    print("ToLiss Wear and Tear: SimBrief data integration complete.")
    ToLiss_CheckAndSavePersistence()
end


--[[

MENU

]]
--[[ Callback for the airline selection submenu ]]
function ToLiss_Airline_Menu_Callbacks(itemref)
    local airline_name_clicked = ffi.string(itemref)
    for profile_key, profile_data in pairs(AIRLINE_PROFILES) do
        if profile_data.name == airline_name_clicked then
            Table_SetVal(ToLiss_Persistence_Data, "AirlineProfile", profile_key)
            print("ToLiss Wear and Tear: Airline Profile changed to " .. profile_data.name)
            ToLiss_CheckAndSavePersistence() -- Save the change immediately
            break
        end
    end
end

--[[ Callback for the Cost Index submenu ]]
function ToLiss_CI_Menu_Callbacks(itemref)
    local action = ffi.string(itemref)
    local current_ci = Table_GetVal(ToLiss_Persistence_Data, "CostIndex")
    local change = tonumber(string.match(action, "[%+%-%d]+"))

    if change then
        local new_ci = Clamp(current_ci + change, 0, 99)
        Table_SetVal(ToLiss_Persistence_Data, "CostIndex", new_ci)
        print("ToLiss Wear and Tear: Cost Index set to " .. new_ci)
        ToLiss_CheckAndSavePersistence()
    end
end

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
                        ToLiss_Automate_MCDU_Config()
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
                        ToLiss_Automate_MCDU_Config()
                    end
                end
            end
            -- Index 5, 6 are submenus
            if i == 8 then -- Import SimBrief Plan
                ToLiss_Integrate_SimBrief_From_File()
            end
            if i == 9 then -- Refuel Cost
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then ToLiss_Flight.RefuelCost = 0 ToLiss_Flight.Refuel = 0 end
            end
            if i == 12 then -- Economic Dashboard
                print("================== LIVE ECONOMIC DASHBOARD ==================")
                print(string.format(" Flight: %s -> %s", ToLiss_Flight.Origin, ToLiss_Flight.Destination))
                print(string.format(" Flight Time (so far): %.2f hours", ToLiss_Flight.Time))
                print(string.format(" --- Accumulated Costs ---"))
                print(string.format("   - Fuel: %.2f %s (%.2f kg)", (ToLiss_Flight.FuelConsumed * Table_GetVal(ToLiss_Persistence_Data,"Cost_FuelPerKg")), Table_GetVal(ToLiss_Persistence_Data,"Currency"), ToLiss_Flight.FuelConsumed))
                print(string.format("   - Maintenance: %.2f %s", ToLiss_Flight.MaintenanceCost, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
                print(string.format("   - Crew: %.2f %s", ToLiss_Flight.CrewCost, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
                print(string.format(" ----------------------------------------------------"))
                print(string.format(" TOTAL OPERATING COST (so far): %.2f %s", ToLiss_Flight.OperatingCost, Table_GetVal(ToLiss_Persistence_Data,"Currency")))
                print("==========================================================")
            end
            -- Index 14 (MCDU PERF) is removed
            if i == 14 then -- Debug
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Debug",1) else Table_SetVal(ToLiss_Persistence_Data,"Debug",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 15 then -- Gradual Aging
                if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 0 then Table_SetVal(ToLiss_Persistence_Data,"GradualAging",1) else Table_SetVal(ToLiss_Persistence_Data,"GradualAging",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 16 then -- Persistence
                if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Persistence",1) else Table_SetVal(ToLiss_Persistence_Data,"Persistence",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 17 then -- Autosave
                if Table_GetVal(ToLiss_Persistence_Data,"Autosave") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Autosave",1) else Table_SetVal(ToLiss_Persistence_Data,"Autosave",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 18 then -- Strict mode
                if Table_GetVal(ToLiss_Persistence_Data,"Strict") == 0 then Table_SetVal(ToLiss_Persistence_Data,"Strict",1) else Table_SetVal(ToLiss_Persistence_Data,"Strict",0) ToLiss_CheckAndSavePersistence() end
            end
            if i == 20 then -- Save
                ToLiss_SavePersistence()
            end
            if i == 21 then -- Load
                Persistence_Read(Persistence_FilePath,ToLiss_Persistence_Data)
                ToLiss_Apply_Age()
                ToLiss_Automate_MCDU_Config()
                if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then print("ToLiss Wear and Tear: Persistence data applied.") end
            end
            if i == 22 then -- Reset
                Table_Copy(ToLiss_Persistence_Data_Init,ToLiss_Persistence_Data)
                if Random_Start_Vals == true then Randomize_Age() end
                ToLiss_Apply_Age()
                ToLiss_Automate_MCDU_Config()
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
    if index == 5 then -- Airline Profile
        local current_profile_key = Table_GetVal(ToLiss_Persistence_Data,"AirlineProfile")
        local current_profile_name = AIRLINE_PROFILES[current_profile_key].name
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"["..current_profile_name.."]",intable)

        if ToLiss_Airline_Menu_ID ~= nil then
            local airline_index = 0
            -- This relies on pairs iterating in a consistent order.
            for key, profile in pairs(AIRLINE_PROFILES) do
                if key == current_profile_key then
                    ToLiss_XPLM.XPLMCheckMenuItem(ToLiss_Airline_Menu_ID, airline_index, 2) -- xplm_Menu_Checked
                else
                    ToLiss_XPLM.XPLMCheckMenuItem(ToLiss_Airline_Menu_ID, airline_index, 1) -- xplm_Menu_Unchecked
                end
                airline_index = airline_index + 1
            end
        end
    end
    if index == 6 then -- Cost Index
        local current_ci = Table_GetVal(ToLiss_Persistence_Data, "CostIndex")
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"["..current_ci.."]",intable)
    end
    -- index 8 is the import button, no watchdog needed.
    if index == 9 then -- Refuel cost
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,ToLiss_Flight.RefuelCost.." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"),intable)
    end
    if index == 10 then -- Cash
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,Table_GetVal(ToLiss_Persistence_Data,"Cash").." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"),intable)
    end
    if index == 11 then -- Operating Cost
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,string.format("%.2f",ToLiss_Flight.OperatingCost).." "..Table_GetVal(ToLiss_Persistence_Data,"Currency"),intable)
    end
    if index == 12 then -- Economic Dashboard
        local total_hours = ToLiss_Flight.Time
        if total_hours > 0 then
            local cost_per_hour = ToLiss_Flight.OperatingCost / total_hours
            Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,string.format("Cost/hr: %.2f", cost_per_hour),intable)
        else
            Menu_ChangeItemSuffix(ToLiss_Menu_ID,index,"No flight data",intable)
        end
    end
    -- index 14 (MCDU PERF) is removed
    if index == 14 then -- Debug
        if Table_GetVal(ToLiss_Persistence_Data,"Debug") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
    if index == 15 then -- Gradual Aging
        if Table_GetVal(ToLiss_Persistence_Data,"GradualAging") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
    if index == 16 then -- Persistence
        if Table_GetVal(ToLiss_Persistence_Data,"Persistence") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
    end
    if index == 17 then -- Autosave
        if Table_GetVal(ToLiss_Persistence_Data,"Autosave") == 1 then Menu_CheckItem(ToLiss_Menu_ID,index,"Activate") else Menu_CheckItem(ToLiss_Menu_ID,index,"Deactivate") end
        Menu_ChangeItemSuffix(ToLiss_Menu_ID,index," (Interval: "..Table_GetVal(ToLiss_Persistence_Data,"AutosaveInterval").." s)",intable)
    end
    if index == 18 then -- Strict Mode
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

                if ToLiss_Menu_Items[i] == "Airline Profile:" then
                    ToLiss_Airline_Menu_ID = ToLiss_XPLM.XPLMCreateMenu("Airline Profile:", ToLiss_Menu_ID, Menu_Indices[i]-2, function(inMenuRef,inItemRef) ToLiss_Airline_Menu_Callbacks(inItemRef) end, ffi.cast("void *", "airline_submenu"))
                    for _, profile_data in pairs(AIRLINE_PROFILES) do
                        ToLiss_XPLM.XPLMAppendMenuItem(ToLiss_Airline_Menu_ID, profile_data.name, ffi.cast("void *", profile_data.name), 1)
                    end
                end

                if ToLiss_Menu_Items[i] == "Cost Index:" then
                    ToLiss_CI_Menu_ID = ToLiss_XPLM.XPLMCreateMenu("Cost Index:", ToLiss_Menu_ID, Menu_Indices[i]-2, function(inMenuRef,inItemRef) ToLiss_CI_Menu_Callbacks(inItemRef) end, ffi.cast("void *", "ci_submenu"))
                    local ci_actions = {"CI +10", "CI -10", "CI +1", "CI -1"}
                    for _, action in ipairs(ci_actions) do
                        ToLiss_XPLM.XPLMAppendMenuItem(ToLiss_CI_Menu_ID, action, ffi.cast("void *", action), 1)
                    end
                end
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
    -- Handles end-of-flight economics
    ToLiss_Handle_EndOfFlight_Economics()
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
        run_after_time(ToLiss_Automate_MCDU_Config,(InitDelay+1)) -- Automatically configure MCDU
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
