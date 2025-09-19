--[[

Wear and tear for the ToLiss A319/A320/A321 and A340

Gradually wears out the aircraft and engine.

By BK/RandomUser, 2023

Licensed under the EUPL v1.2
https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12

]]
--[[

FFI INITIALIZATION

]]
ToLiss_XPLM = nil  -- Define namespace for XPLM library
--[[ Load XPLM library ]]
if ffi.os == "Windows" then ToLiss_XPLM = ffi.load("XPLM_64")  -- Windows 64bit
elseif ffi.os == "Linux" then ToLiss_XPLM = ffi.load("Resources/plugins/XPLM_64.so")  -- Linux 64bit (Requires "Resources/plugins/" for some reason)
elseif ffi.os == "OSX" then ToLiss_XPLM = ffi.load("Resources/plugins/XPLM.framework/XPLM") -- 64bit MacOS (Requires "Resources/plugins/" for some reason)
else return
end
--[[ Add C definitions to FFI ]]
ffi.cdef([[
/* XPLMUtilities*/
typedef void *XPLMCommandRef;
/* XPLMMenus */
typedef int XPLMMenuCheck;
typedef void *XPLMMenuID;
typedef void (*XPLMMenuHandler_f)(void *inMenuRef,void *inItemRef);
XPLMMenuID XPLMFindPluginsMenu(void);
XPLMMenuID XPLMFindAircraftMenu(void);
XPLMMenuID XPLMCreateMenu(const char *inName, XPLMMenuID inParentMenu, int inParentItem, XPLMMenuHandler_f inHandler,void *inMenuRef);
void XPLMDestroyMenu(XPLMMenuID inMenuID);
void XPLMClearAllMenuItems(XPLMMenuID inMenuID);
int XPLMAppendMenuItem(XPLMMenuID inMenu,const char *inItemName,void *inItemRef,int inDeprecatedAndIgnored);
int XPLMAppendMenuItemWithCommand(XPLMMenuID inMenu,const char *inItemName,XPLMCommandRef inCommandToExecute);
void XPLMAppendMenuSeparator(XPLMMenuID inMenu);
void XPLMSetMenuItemName(XPLMMenuID inMenu,int inIndex,const char *inItemName,int inForceEnglish);
void XPLMCheckMenuItem(XPLMMenuID inMenu,int index,XPLMMenuCheck inCheck);
void XPLMCheckMenuItemState(XPLMMenuID inMenu,int index,XPLMMenuCheck *outCheck);
void XPLMEnableMenuItem(XPLMMenuID inMenu,int index,int enabled);
void XPLMRemoveMenuItem(XPLMMenuID inMenu,int inIndex);
]])
--[[ Checks if the FFI has loaded correctly ]]
function ToLiss_FFI_CheckInit()
    --[[ Print initialization result ]]
    if ToLiss_XPLM ~= nil then print("ToLiss Wear and Tear: FFI initialized") end
    print("ToLiss Wear and Tear: Operating system detected as "..ffi.os)
end
--[[

FUNCTIONS

]]
--[[ Gets a value from the second column of a table-subtable construct by name of the subtable (always the first element) or by the index of the subtable ]]
function Table_GetVal(intable,target)
    -- Target is the name of a subtable
    if type(target) == "string" then
        for i=1,#intable do
            if intable[i][1] == target then
                return intable[i][2]
            end
        end
    end
    -- Target is a table index
    if type(target) == "number" then
        return intable[target][2]
    end
end
--[[ Sets a value in the second column of a table-subtable construct by name of the subtable (always the first element) or by the index of the subtable ]]
function Table_SetVal(intable,target,newval)
    -- Target is the name of a subtable
    if type(target) == "string" then
        for i=1,#intable do
            if intable[i][1] == target then intable[i][2] = newval end
        end
    end
    -- Target is a table index
    if type(target) == "number" then
        intable[target][2] = newval
    end
end
-- [[ Copies a table and its subtables ]]
function Table_Copy(intable,outtable)
    for i=1,#intable do
        --print("Input "..i..": "..table.concat(intable[i],","))
        if type(intable[i]) == "table" then
            outtable[i] = { }
            for j=1,#intable[i] do
                outtable[i][j] = intable[i][j]
            end
        else
            outtable[(#outtable+1)] = intable[i]
        end
        --print("Output "..#outtable..": "..table.concat(outtable[#outtable],","))
    end
    -- Cut length of output table to input table, if necessary
    if #outtable > #intable then
        for i=(#intable+1),#outtable do
            table.remove(outtable,i)
        end
    end
    if #intable == #outtable then
        if Table_GetVal(intable,"Debug") == 1 then print("ToLiss Wear and Tear: Successfully copied table.") end
    end
end
--[[ Ensures that a number does not exceed a given range ]]
function Clamp(invar,min,max)
    local outvar = 0
    if invar < min then outvar = min elseif invar > max then outvar = max else outvar = invar end
    return outvar
end
--[[ Splits a line at the designated delimiter, returns a table ]]
function SplitString(input,delim)
    local output = {}
    --print("Line splitting in: "..input)
    for i in string.gmatch(input,delim) do table.insert(output,i) end
    --print("Line splitting out: "..table.concat(output,",",1,#output))
    return output
end
--[[ Saves the persistence data file ]]
function Persistence_Write(intable,outfile)
    local file = io.open(outfile, "w")
    for i=1,#intable do
        file:write(table.concat(intable[i],"=")..":"..type(intable[i][2]).."\n")
    end
    if Table_GetVal(intable,"Debug") == 1 then if file:seek("end") > 0 then print("ToLiss Wear and Tear: Persistence data written.") else print("Wear and Tear: Persistence data write error!") end end
    file:close()
end
--[[ Reads the persistence data file ]]
function Persistence_Read(infile,outtable)
    local file = io.open(infile, "r") -- Check if file exists
    if file then
        for line in file:lines() do
            if string.match(line,"^[^#]") then
            local splitline = SplitString(line,"([^=]+)")
                --print(splitline[1].." is "..splitline[2])
                for i=1,#outtable do
                    if outtable[i][1] == splitline[1] then
                        local splitline2 = SplitString(splitline[2],"([^:]+)")
                        if splitline2[2] == "string" then outtable[i][2] = tostring(splitline2[1]) end
                        if splitline2[2] == "number" then outtable[i][2] = tonumber(splitline2[1]) end
                        --print("ToLiss Wear and Tear: "..outtable[i][1].." changed to "..outtable[i][2])
                    end
                end
            end
        end
        if Table_GetVal(outtable,"Debug") == 1 then print("ToLiss Wear and Tear: Persistence loaded.") end
        file:close()
    else
        if Table_GetVal(outtable,"Debug") == 1 then print("ToLiss Wear and Tear: No persistence file found; starting values applied.") end
    end
end
--[[ Verbalizes an amount of wear ]]
function Verbalize_Wear(input,min,max)
    local outputstring
    if input == min then outputstring = "Brand New"
    elseif input > min and input <= min + 0.5 then outputstring = "Very Slight" -- -0.999... to -0.5
    elseif input > min and input <= min + 1.0 then outputstring = "Slight" -- -0.499... to 0
    elseif input > min and input <= min + 1.5 then outputstring = "Below Medium" -- 0.000...1 to 0.5
    elseif input > min and input <= min + 2.0 then outputstring = "Above Medium" -- 0.500...1 to 1.0
    elseif input > min and input <= min + 2.5 then outputstring = "Heavy" -- 1.000...1 to 1.5
    elseif input > min and input < min + 3.0 then outputstring = "Very Heavy" -- 1.500...1 to 1.999
    elseif input == max then outputstring = "Worn Out" end
    return outputstring
end
--[[ Menu item prefix name change ]]
function Menu_ChangeItemPrefix(menu_id,index,prefix,intable)
    --LogOutput("Plopp: "..","..index..","..prefix..","..table.concat(intable,":"))
    ToLiss_XPLM.XPLMSetMenuItemName(menu_id,index-2,prefix.." "..intable[index],1)
end
--[[ Menu item suffix name change ]]
function Menu_ChangeItemSuffix(menu_id,index,suffix,intable)
    --LogOutput("Plopp: "..","..index..","..prefix..","..table.concat(intable,":"))
    ToLiss_XPLM.XPLMSetMenuItemName(menu_id,index-2,intable[index].." "..suffix,1)
end
--[[ Menu item check status change ]]
function Menu_CheckItem(menu_id,index,state)
    index = index - 2
    local out = ffi.new("XPLMMenuCheck[1]")
    ToLiss_XPLM.XPLMCheckMenuItemState(menu_id,index,ffi.cast("XPLMMenuCheck *",out))
    if tonumber(out[0]) == 0 then ToLiss_XPLM.XPLMCheckMenuItem(menu_id,index,1) end
    if state == "Activate" and tonumber(out[0]) ~= 2 then ToLiss_XPLM.XPLMCheckMenuItem(menu_id,index,2)
    elseif state == "Deactivate" and tonumber(out[0]) ~= 1 then ToLiss_XPLM.XPLMCheckMenuItem(menu_id,index,1)
    end
end
--[[ Menu cleanup upon script reload or session exit ]]
function Menu_CleanUp(menu_id,menu_index)
   if ToLiss_Airline_Menu_ID ~= nil then ToLiss_XPLM.XPLMDestroyMenu(ToLiss_Airline_Menu_ID) end
   if ToLiss_CI_Menu_ID ~= nil then ToLiss_XPLM.XPLMDestroyMenu(ToLiss_CI_Menu_ID) end
   if menu_id ~= nil then ToLiss_XPLM.XPLMClearAllMenuItems(menu_id) ToLiss_XPLM.XPLMDestroyMenu(menu_id) end
   if menu_index ~= nil then ToLiss_XPLM.XPLMRemoveMenuItem(ToLiss_XPLM.XPLMFindAircraftMenu(),menu_index) end
end
