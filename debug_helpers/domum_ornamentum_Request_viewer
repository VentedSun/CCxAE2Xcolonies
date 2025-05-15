--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
 
--** DOMUM NBT DEBUGGER SCRIPT (Monitor Output - Full Item Data) **--
 
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
 
-- This script connects to a Colony Integrator, fetches requests, and
 
-- prints all available data for each item whose name starts with "domum_ornamentum:"
 
-- to a connected monitor.
 
-- It pauses after each identified Domum request to allow inspection.
 
 
 
-- Global variable for the monitor
 
local mon = peripheral.find("monitor")
 
local currentMonitorLine = 1 -- To keep track of the current line on the monitor
 
 
 
-- Function to print to monitor and handle line advancement
 
local function monitorPrint(text)
 
    if not mon then
 
        print("Error: Monitor not found. Cannot print to monitor.")
 
        return
 
    end
 
    if text == nil then text = "nil" end -- Ensure text is printable
 
    
 
    -- Split text by newlines to handle them correctly
 
    for line in string.gmatch(text, "[^\r\n]+") do
 
        mon.setCursorPos(1, currentMonitorLine)
 
        mon.clearLine() -- Clear the line before writing to prevent overlap
 
        mon.write(line)
 
        currentMonitorLine = currentMonitorLine + 1
 
        
 
        -- Check if we've reached the bottom of the monitor
 
        local _, monHeight = mon.getSize()
 
        if currentMonitorLine > monHeight then
 
            -- If we're at the bottom, pause, clear, and reset cursor
 
            mon.setCursorPos(1, monHeight)
 
            mon.write("--- Press Enter to continue ---")
 
            read() -- Wait for user input
 
            mon.clear()
 
            currentMonitorLine = 1
 
        end
 
    end
 
end
 
 
 
-- Function to find a peripheral by type
 
function findPeripheral(type)
 
    local p = peripheral.find(type)
 
    if not p then
 
        monitorPrint("Error: " .. type .. " peripheral not found.")
 
        return nil
 
    end
 
    monitorPrint(type .. " peripheral found.")
 
    return p
 
end
 
 
 
-- Helper function to print table contents (useful for debugging)
 
function dump(o, indent)
 
    indent = indent or ""
 
    local nextIndent = indent .. "  "
 
    if type(o) == 'table' then
 
        local s = indent .. '{\n'
 
        local first = true -- To avoid trailing comma in simple list-like tables if we were to build it differently
 
        for k,v in pairs(o) do
 
            -- Check if key is a string and quote it, otherwise just use tostring
 
            local key_str = type(k) == 'string' and '"'..k..'"' or tostring(k)
 
            s = s .. nextIndent .. '['..key_str..'] = ' .. dump(v, nextIndent) .. ',\n'
 
        end
 
        return s .. indent .. '}'
 
    else
 
        -- Quote strings when they are values
 
        if type(o) == "string" then
 
            return '"' .. tostring(o) .. '"'
 
        end
 
        return tostring(o)
 
    end
 
end
 
 
 
-- Main debugging function
 
function debugDomumNBT()
 
    if not mon then
 
        print("FATAL: Monitor not found. Please connect a monitor and restart the script.")
 
        return
 
    end
 
 
 
    -- Clear the monitor and set initial cursor position
 
    mon.clear()
 
    mon.setTextScale(0.5) -- Optional: use smaller text for more info
 
    currentMonitorLine = 1
 
    mon.setCursorPos(1, currentMonitorLine)
 
 
 
    monitorPrint("Domum NBT Debugger Initializing (Full Item Data)...")
 
 
 
    local colony = findPeripheral("colonyIntegrator")
 
 
 
    if not colony then
 
        monitorPrint("Exiting due to missing Colony Integrator.")
 
        return -- Exit if Colony Integrator is not found
 
    end
 
 
 
    monitorPrint("\nFetching colony requests...")
 
 
 
    local requests = colony.getRequests()
 
 
 
    if not requests or #requests == 0 then
 
        monitorPrint("No active requests found.")
 
        return
 
    end
 
 
 
    monitorPrint("--- Active Requests (" .. #requests .. " total) ---")
 
 
 
    local domumCount = 0
 
    for i, req in ipairs(requests) do
 
        -- Ensure req.items exists and has at least one item before trying to access it
 
        if not req.items or not req.items[1] then
 
            monitorPrint(string.format("\n--- Skipping Request %d of %d: Invalid/Empty item data ---", i, #requests))
 
            goto continue -- Skips to the end of the loop iteration for this request
 
        end
 
 
 
        local itemName = req.items[1].displayName or req.name or "Unknown Item"
 
        local rawItemName = req.items[1].name or "" -- Get the raw item name for the check
 
 
 
        -- Check if the raw item name starts with "domum_ornamentum:"
 
        if string.find(rawItemName, "domum_ornamentum:", 1, true) == 1 then
 
            domumCount = domumCount + 1
 
            monitorPrint(string.format("\n--- Domum Request %d (Overall %d/%d): %s ---", domumCount, i, #requests, itemName))
 
 
 
            -- Print all data for the item req.items[1]
 
            monitorPrint("  Full item data for '" .. itemName .. "':")
 
            local itemDataString = dump(req.items[1]) -- Dump the entire item sub-table
 
            monitorPrint(itemDataString) -- monitorPrint will handle newlines within itemDataString
 
            
 
            -- Pause for input after finding a Domum request
 
            monitorPrint("\nPress Enter in terminal to view next Domum request...")
 
            read() -- Wait for any input (reads from computer terminal)
 
        end
 
        ::continue:: -- Label for goto statement
 
    end
 
 
 
    monitorPrint("\n--- End of Domum Requests ---")
 
    if domumCount == 0 then
 
        monitorPrint("No Domum_Ornamentum requests found in the active list.")
 
    else
 
        monitorPrint("Found " .. domumCount .. " Domum_Ornamentum requests.")
 
    end
 
    monitorPrint("\nDebug session finished. Press Enter in terminal to exit.")
 
    read()
 
end
 
 
 
-- Run the debugger
 
debugDomumNBT()
