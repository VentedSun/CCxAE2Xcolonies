-- MineColonies Equipment Request Viewer
 
-- Version 1.2 - Added vanilla equivalent ID display for equipment
 
-- Displays equipment requests from a colonyIntegrator on an attached monitor with scrolling.
 
 
 
--[[----------------------------------------------------------------------------
 
--* CONFIGURATION
 
----------------------------------------------------------------------------]]
 
local REFRESH_INTERVAL = 5 -- Seconds between data refreshes
 
local MONITOR_TEXT_SCALE = 0.5
 
local BUTTON_WIDTH = 7
 
local BUTTON_HEIGHT = 3 -- Height of the scroll buttons
 
local BUTTON_COLOR_BG = colors.gray
 
local BUTTON_COLOR_FG = colors.white
 
local BUTTON_COLOR_BG_HOVER = colors.lightGray -- Not implemented in this version, but placeholder
 
local BUTTON_TEXT_UP = " UP  "
 
local BUTTON_TEXT_DOWN = "DOWN "
 
 
 
--[[----------------------------------------------------------------------------
 
--* GLOBAL VARIABLES
 
----------------------------------------------------------------------------]]
 
local mon = nil
 
local monitorSide = nil -- Stores the side name of the monitor being used
 
local colony = nil
 
local equipmentRequests = {}
 
local scrollOffset = 0
 
local itemsPerPage = 0
 
local termWidth, termHeight -- For computer's terminal, if needed for messages
 
 
 
--[[----------------------------------------------------------------------------
 
--* UTILITY FUNCTIONS
 
----------------------------------------------------------------------------]]
 
 
 
local function logError(message)
 
    print("ERROR: " .. tostring(message))
 
end
 
 
 
local function logInfo(message)
 
    print("INFO: " .. tostring(message))
 
end
 
 
 
function safeCall(func, ...)
 
    local success, result = pcall(func, ...)
 
    if not success then
 
        if type(result) == "string" and result == "Terminated" then
 
            error("Terminated", 0)
 
        end
 
        logError("safeCall failed: " .. tostring(result))
 
        return false, result
 
    end
 
    return true, result
 
end
 
 
 
local function trim(s)
 
  return s:match("^%s*(.-)%s*$")
 
end
 
 
 
function getLastWord(str)
 
    local words = {}
 
    for word in string.gmatch(str, "%S+") do
 
        table.insert(words, word)
 
    end
 
    return words[#words] or "" -- Return last word or empty string
 
end
 
 
 
function tableToString(tbl, indent)
 
    indent = indent or 0
 
    if type(tbl) ~= "table" then return tostring(tbl) end
 
    if next(tbl) == nil then return "{}" end
 
 
 
    local parts = {}
 
    for k, v in pairs(tbl) do
 
        local keyStr = type(k) == "string" and string.format("%q", k) or tostring(k)
 
        local valStr
 
        if type(v) == "table" then
 
            valStr = "{...}" 
 
        elseif type(v) == "string" then
 
            valStr = string.format("%q", v)
 
        else
 
            valStr = tostring(v)
 
        end
 
        table.insert(parts, string.format("%s=%s", keyStr, valStr))
 
    end
 
    return "{ " .. table.concat(parts, ", ") .. " }"
 
end
 
 
 
--[[----------------------------------------------------------------------------
 
--* VANILLA EQUIPMENT ID MAPPING
 
----------------------------------------------------------------------------]]
 
-- Tries to determine the base equipment type (e.g., "Helmet", "Pickaxe")
 
-- from a request name like "Chain Helmet" or "Diamond Pickaxe".
 
local function getBaseEquipmentType(requestName)
 
    local knownTypes = {
 
        "Helmet", "Chestplate", "Leggings", "Boots",
 
        "Sword", "Pickaxe", "Axe", "Shovel", "Hoe", "Shears", "Bow"
 
    }
 
    local lowerRequestName = string.lower(requestName)
 
    for _, typeName in ipairs(knownTypes) do
 
        if string.find(lowerRequestName, string.lower(typeName)) then
 
            return typeName -- Return in original casing for map lookup
 
        end
 
    end
 
    logInfo("getBaseEquipmentType: Could not determine base type from '" .. requestName .. "'")
 
    return getLastWord(requestName) -- Fallback to last word if no known type found
 
end
 
 
 
-- Maps a base equipment type and material level to a vanilla Minecraft ID.
 
-- Returns the vanilla ID string or nil if no mapping exists.
 
local function getVanillaEquivalentId(baseEquipmentType, materialLevel)
 
    if not baseEquipmentType or not materialLevel then return nil end
 
 
 
    local baseTypeLower = string.lower(baseEquipmentType)
 
    local materialLower = string.lower(materialLevel)
 
 
 
    local vanillaPrefix = "minecraft:"
 
    local materialPrefix = ""
 
    local itemSuffix = ""
 
 
 
    if materialLower == "diamond" then materialPrefix = "diamond_"
 
    elseif materialLower == "iron" then materialPrefix = "iron_"
 
    elseif materialLower == "chain" or materialLower == "chainmail" then materialPrefix = "chainmail_" -- Accept both
 
    else
 
        logInfo("getVanillaEquivalentId: Unsupported material level '" .. materialLevel .. "' for vanilla mapping.")
 
        return nil -- Material not supported for vanilla crafting by this script
 
    end
 
 
 
    if baseTypeLower == "helmet" then itemSuffix = "helmet"
 
    elseif baseTypeLower == "chestplate" then itemSuffix = "chestplate"
 
    elseif baseTypeLower == "leggings" then itemSuffix = "leggings"
 
    elseif baseTypeLower == "boots" then itemSuffix = "boots"
 
    elseif baseTypeLower == "sword" then itemSuffix = "sword"
 
    elseif baseTypeLower == "pickaxe" then itemSuffix = "pickaxe"
 
    elseif baseTypeLower == "axe" then itemSuffix = "axe"
 
    elseif baseTypeLower == "shovel" then itemSuffix = "shovel"
 
    elseif baseTypeLower == "hoe" then itemSuffix = "hoe"
 
    else
 
        logInfo("getVanillaEquivalentId: Unsupported base equipment type '" .. baseEquipmentType .. "' for vanilla mapping.")
 
        return nil -- Type not supported
 
    end
 
    
 
    -- Special case for chainmail tools (they don't exist)
 
    if materialPrefix == "chainmail_" and 
 
       (itemSuffix == "sword" or itemSuffix == "pickaxe" or itemSuffix == "axe" or 
 
        itemSuffix == "shovel" or itemSuffix == "hoe") then
 
        logInfo("getVanillaEquivalentId: Chainmail tools like '" .. itemSuffix .. "' do not exist in vanilla.")
 
        return nil
 
    end
 
 
 
    return vanillaPrefix .. materialPrefix .. itemSuffix
 
end
 
 
 
--[[----------------------------------------------------------------------------
 
--* PERIPHERAL SETUP
 
----------------------------------------------------------------------------]]
 
function setupPeripherals()
 
    logInfo("Setting up peripherals...")
 
    
 
    local sides = peripheral.getNames()
 
    local foundMonitor = false
 
    for i = 1, #sides do
 
        local side = sides[i]
 
        if peripheral.getType(side) == "monitor" then
 
            local wrappedMonitor = peripheral.wrap(side)
 
            if wrappedMonitor then
 
                mon = wrappedMonitor
 
                monitorSide = side
 
                logInfo("Monitor found on side: " .. monitorSide)
 
                foundMonitor = true
 
                break
 
            end
 
        end
 
    end
 
 
 
    if not foundMonitor then
 
        logError("No monitor found attached to the computer.")
 
        mon = nil 
 
        monitorSide = nil
 
        return false
 
    end
 
 
 
    colony = peripheral.find("colonyIntegrator")
 
    if not colony then
 
        logError("No colonyIntegrator found.")
 
        return false
 
    end
 
    if not colony.getRequests then
 
        logError("Found peripheral is not a valid colonyIntegrator (missing getRequests).")
 
        colony = nil 
 
        return false
 
    end
 
    logInfo("Colony Integrator found.")
 
    return true
 
end
 
 
 
--[[----------------------------------------------------------------------------
 
--* DATA FETCHING AND PROCESSING
 
----------------------------------------------------------------------------]]
 
 
 
local function isEquipment(desc)
 
    if type(desc) ~= "string" then return false end
 
    local equipmentKeywords = {
 
        "Sword ", "Bow ", "Pickaxe ", "Axe ", "Shovel ", "Hoe ", "Shears ",
 
        "Helmet ", "Chestplate ", "Leggings ", "Boots "
 
    }
 
    for _, keyword in ipairs(equipmentKeywords) do
 
        if string.find(desc, keyword) then
 
            return true
 
        end
 
    end
 
    return false
 
end
 
 
 
function fetchEquipmentRequests()
 
    if not colony then
 
        logError("Colony integrator not available to fetch requests.")
 
        equipmentRequests = {}
 
        return
 
    end
 
 
 
    local success, allRequests = safeCall(colony.getRequests)
 
    if not success or not allRequests then
 
        logError("Failed to get requests from colony integrator.")
 
        equipmentRequests = {}
 
        return
 
    end
 
 
 
    local currentEquipment = {}
 
    for _, req in ipairs(allRequests) do
 
        if req.items and req.items[1] and isEquipment(req.desc or "") then
 
            local originalRawName = req.items[1].name or "unknown:id"
 
            local requestName = req.name or (req.items[1].displayName or "Unknown Item") -- Use req.name as primary source for type
 
 
 
            local itemEntry = {
 
                displayName = trim(req.items[1].displayName or requestName),
 
                originalRawName = originalRawName, -- Keep original for reference if needed
 
                rawName = originalRawName, -- This will be updated to vanilla if possible
 
                count = req.count or 0,
 
                needed = req.count or 0, 
 
                targetName = req.target or "Unknown Target",
 
                description = req.desc or "No description",
 
                nbt = req.items[1].nbt,
 
                fingerprint = req.items[1].fingerprint,
 
                level = "Any Level" -- Default level
 
            }
 
            
 
            local levelTable = {
 
                ["and with maximal level: Leather"] = "Leather", ["and with maximal level: Stone"] = "Stone",
 
                ["and with maximal level: Chain"] = "Chain", ["and with maximal level: Gold"] = "Gold",
 
                ["and with maximal level: Iron"] = "Iron", ["and with maximal level: Diamond"] = "Diamond",
 
                ["with maximal level: Wood or Gold"] = "Wood or Gold"
 
            }
 
            local extractedLevel = "Any Level"
 
            for pattern, mappedLevel in pairs(levelTable) do
 
                if string.find(itemEntry.description, pattern) then
 
                    extractedLevel = mappedLevel
 
                    break
 
                end
 
            end
 
             if extractedLevel == "Any Level" then 
 
                if string.find(itemEntry.description, "Diamond") then extractedLevel = "Diamond"
 
                elseif string.find(itemEntry.description, "Iron") then extractedLevel = "Iron"
 
                elseif string.find(itemEntry.description, "Chain") then extractedLevel = "Chain"
 
                -- Add more explicit checks if needed
 
                end
 
            end
 
            itemEntry.level = extractedLevel
 
            
 
            -- Attempt to get vanilla equivalent ID
 
            local baseType = getBaseEquipmentType(requestName) -- Use req.name for type extraction
 
            if baseType and extractedLevel ~= "Any Level" then
 
                local vanillaId = getVanillaEquivalentId(baseType, extractedLevel)
 
                if vanillaId then
 
                    itemEntry.rawName = vanillaId -- Update rawName to the vanilla ID for display
 
                    logInfo("Mapped '" .. requestName .. "' (Level: " .. extractedLevel .. ", Original ID: " .. originalRawName .. ") to Vanilla ID: " .. vanillaId)
 
                else
 
                    logInfo("No direct vanilla mapping for '" .. requestName .. "' (Level: " .. extractedLevel .. ", BaseType: " .. baseType .. "). Displaying original ID: " .. originalRawName)
 
                end
 
            else
 
                 logInfo("Could not determine base type or level for '" .. requestName .. "' for vanilla mapping. Displaying original ID: " .. originalRawName)
 
            end
 
 
 
            itemEntry.formattedName = extractedLevel .. " " .. requestName
 
 
 
            table.insert(currentEquipment, itemEntry)
 
        end
 
    end
 
    equipmentRequests = currentEquipment
 
    logInfo("Fetched " .. #equipmentRequests .. " equipment requests.")
 
end
 
 
 
--[[----------------------------------------------------------------------------
 
--* MONITOR DISPLAY FUNCTIONS
 
----------------------------------------------------------------------------]]
 
 
 
function clearMonitor()
 
    if not mon then return end
 
    mon.setTextScale(MONITOR_TEXT_SCALE)
 
    mon.setBackgroundColor(colors.black)
 
    mon.setTextColor(colors.white)
 
    mon.clear()
 
end
 
 
 
function drawScrollButtons()
 
    if not mon then return end
 
    local w, h = mon.getSize()
 
 
 
    mon.setCursorPos(w - BUTTON_WIDTH + 1, 1)
 
    mon.setBackgroundColor(BUTTON_COLOR_BG)
 
    mon.setTextColor(BUTTON_COLOR_FG)
 
    for i = 1, BUTTON_HEIGHT do
 
        mon.setCursorPos(w - BUTTON_WIDTH + 1, i)
 
        mon.write(string.rep(" ", BUTTON_WIDTH))
 
    end
 
    mon.setCursorPos(w - BUTTON_WIDTH + math.floor((BUTTON_WIDTH - #BUTTON_TEXT_UP)/2) +1 , math.floor(BUTTON_HEIGHT/2)+1)
 
    mon.write(BUTTON_TEXT_UP)
 
 
 
    mon.setCursorPos(w - BUTTON_WIDTH + 1, h - BUTTON_HEIGHT + 1)
 
    mon.setBackgroundColor(BUTTON_COLOR_BG)
 
    mon.setTextColor(BUTTON_COLOR_FG)
 
    for i = 1, BUTTON_HEIGHT do
 
        mon.setCursorPos(w - BUTTON_WIDTH + 1, h - BUTTON_HEIGHT + i)
 
        mon.write(string.rep(" ", BUTTON_WIDTH))
 
    end
 
    mon.setCursorPos(w - BUTTON_WIDTH + math.floor((BUTTON_WIDTH - #BUTTON_TEXT_DOWN)/2) +1, h - BUTTON_HEIGHT + math.floor(BUTTON_HEIGHT/2)+1)
 
    mon.write(BUTTON_TEXT_DOWN)
 
 
 
    mon.setBackgroundColor(colors.black) 
 
    mon.setTextColor(colors.white)       
 
end
 
 
 
function displayRequests()
 
    if not mon then return end
 
    clearMonitor()
 
    drawScrollButtons()
 
 
 
    local w, h = mon.getSize()
 
    local displayWidth = w - BUTTON_WIDTH - 1 
 
    local currentY = 1
 
    local linesPerItemEstimate = 5 
 
 
 
    itemsPerPage = math.floor((h - 2) / linesPerItemEstimate) 
 
    if itemsPerPage < 1 then itemsPerPage = 1 end
 
 
 
    mon.setCursorPos(1, currentY)
 
    mon.setTextColor(colors.orange)
 
    mon.write("MineColonies Equipment Requests (" .. (#equipmentRequests > 0 and scrollOffset + 1 or 0) .. "-" .. math.min(scrollOffset + itemsPerPage, #equipmentRequests) .. "/" .. #equipmentRequests .. ")")
 
    currentY = currentY + 2
 
    mon.setTextColor(colors.white)
 
 
 
    if #equipmentRequests == 0 then
 
        mon.setCursorPos(2, currentY)
 
        mon.write("No equipment requests found.")
 
        return
 
    end
 
 
 
    for i = scrollOffset + 1, math.min(scrollOffset + itemsPerPage, #equipmentRequests) do
 
        if currentY > h - 1 then break end 
 
 
 
        local item = equipmentRequests[i]
 
        
 
        mon.setCursorPos(2, currentY)
 
        mon.setTextColor(colors.yellow)
 
        local nameLine = string.format("[%d] %s", item.needed, item.formattedName)
 
        mon.write(nameLine:sub(1, displayWidth -1))
 
        currentY = currentY + 1
 
        if currentY > h -1 then break end
 
 
 
        mon.setCursorPos(3, currentY)
 
        mon.setTextColor(colors.lightGray)
 
        -- Display the (potentially vanilla) rawName here
 
        local targetLine = string.format("ID: %s | For: %s", item.rawName, item.targetName) 
 
        mon.write(targetLine:sub(1, displayWidth-1))
 
        currentY = currentY + 1
 
        if currentY > h-1 then break end
 
        
 
        mon.setCursorPos(3, currentY)
 
        mon.setTextColor(colors.cyan)
 
        local descSnippet = item.description:gsub("[\r\n]", " "):sub(1, displayWidth - 10) .. (#item.description > displayWidth - 10 and "..." or "")
 
        mon.write("Desc: " .. descSnippet)
 
        currentY = currentY + 1
 
        if currentY > h-1 then break end
 
 
 
        local extraInfo = ""
 
        if item.nbt and next(item.nbt) then 
 
            extraInfo = extraInfo .. "NBT: " .. tableToString(item.nbt)
 
        end
 
        if item.fingerprint then
 
            if extraInfo ~= "" then extraInfo = extraInfo .. " | " end
 
            extraInfo = extraInfo .. "FP: " .. item.fingerprint:sub(1,10) .. "..." 
 
        end
 
        
 
        if extraInfo ~= "" then
 
            mon.setCursorPos(3, currentY)
 
            mon.setTextColor(colors.purple)
 
            mon.write(extraInfo:sub(1, displayWidth-1))
 
            currentY = currentY + 1
 
            if currentY > h-1 then break end
 
        end
 
 
 
        mon.setCursorPos(2, currentY)
 
        mon.setTextColor(colors.gray)
 
        mon.write(string.rep("-", displayWidth - 2))
 
        currentY = currentY + 1
 
        if currentY > h then break end 
 
    end
 
end
 
 
 
 
 
--[[----------------------------------------------------------------------------
 
--* EVENT HANDLING AND MAIN LOOP
 
----------------------------------------------------------------------------]]
 
function handleTouch(x, y)
 
    if not mon then return false end
 
    local w, h = mon.getSize()
 
 
 
    if x >= (w - BUTTON_WIDTH + 1) and x <= w and y >= 1 and y <= BUTTON_HEIGHT then
 
        if scrollOffset > 0 then
 
            scrollOffset = scrollOffset - 1
 
            return true 
 
        end
 
    end
 
 
 
    if x >= (w - BUTTON_WIDTH + 1) and x <= w and y >= (h - BUTTON_HEIGHT + 1) and y <= h then
 
        if scrollOffset < (#equipmentRequests - itemsPerPage) and #equipmentRequests > itemsPerPage then
 
            scrollOffset = scrollOffset + 1
 
            return true 
 
        end
 
    end
 
    return false 
 
end
 
 
 
function main()
 
    termWidth, termHeight = term.getSize()
 
    if not setupPeripherals() then
 
        logError("Failed to initialize peripherals. Exiting.")
 
        return
 
    end
 
 
 
    logInfo("Equipment Viewer Started. Using monitor on side: " .. (monitorSide or "unknown") .. ". Refresh: " .. REFRESH_INTERVAL .. "s.")
 
    
 
    fetchEquipmentRequests() 
 
    displayRequests()        
 
 
 
    local lastRefresh = os.clock()
 
 
 
    while true do
 
        local eventData = {os.pullEvent()} 
 
        local event = eventData[1]
 
 
 
        local redrawNeeded = false
 
 
 
        if event == "terminate" then
 
            logInfo("Termination signal received. Exiting.")
 
            break
 
        elseif event == "monitor_touch" then
 
            local touchedSide, touchX, touchY = eventData[2], eventData[3], eventData[4]
 
            if monitorSide and monitorSide == touchedSide then 
 
                if handleTouch(touchX, touchY) then
 
                    redrawNeeded = true
 
                end
 
            end
 
        end
 
 
 
        if (os.clock() - lastRefresh) >= REFRESH_INTERVAL then
 
            logInfo("Refreshing request data...")
 
            local oldRequestCount = #equipmentRequests
 
            
 
            fetchEquipmentRequests()
 
            
 
            if #equipmentRequests ~= oldRequestCount then
 
                if scrollOffset + itemsPerPage > #equipmentRequests and #equipmentRequests > 0 then
 
                    scrollOffset = math.max(0, #equipmentRequests - itemsPerPage)
 
                elseif #equipmentRequests == 0 then
 
                    scrollOffset = 0
 
                end
 
            end
 
            if scrollOffset < 0 then scrollOffset = 0 end
 
 
 
            redrawNeeded = true
 
            lastRefresh = os.clock()
 
        end
 
 
 
        if redrawNeeded then
 
            displayRequests()
 
        end
 
        
 
        if event ~= "timer" and event ~= "monitor_touch" then 
 
             sleep(0.1)
 
        end
 
    end
 
 
 
    if mon then
 
        mon.setBackgroundColor(colors.black)
 
        mon.setTextColor(colors.white)
 
        mon.clear()
 
        mon.setCursorPos(1,1)
 
        mon.write("Equipment Viewer Terminated.")
 
    end
 
    logInfo("Equipment Viewer Terminated.")
 
end
 
 
 
main()
