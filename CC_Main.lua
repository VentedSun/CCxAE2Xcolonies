---@diagnostic disable: undefined-global
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
 
--** ULTIMATE CC X MINECOLONIES PROGRAM                  **--
 
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
 
----------------------------------------------------------------------------
 
----------------------------------------------------------------------------
--* VARIABLES
----------------------------------------------------------------------------
 
local refreshInterval = 10 
local bShowInGameLog = false 
local logFileName = "CCxM"
 
----------------------------------------------------------------------------
--* LOG  (FATAL ERROR WARN_ INFO_ DEBUG TRACE)
----------------------------------------------------------------------------
 
local VERSION = 1.24 -- Optimized peripheral checks, restored startup display style
local logCounter = 0
 
function logToFile(message, level, bPrint)
    level = level or "INFO_"
    bPrint = bPrint or bShowInGameLog
 
    local logFolder = logFileName .. "_logs"
    local logFilePath = logFolder .. "/" .. logFileName .. "_log_latest.txt"
 
    if not fs.exists(logFolder) then
        local success, err = pcall(function() fs.makeDir(logFolder) end)
        if not success then
            print(string.format("Failed to create log folder: %s", err))
            return
        end
    end
 
    local success, err = pcall(function()
        local logFile = fs.open(logFilePath, "a")
        if logFile then
            logFile.writeLine(string.format("[%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message))
            logFile.close()
        else
            error("Unable to open log file.")
        end
    end)
 
    if not success then
        print(string.format("Error writing to log file: %s", err))
        return
    end
 
    if bPrint then
        if level == "ERROR" or level == "FATAL" then print("") end
        print(string.format("[%s] %s", level, message))
        if level == "ERROR" or level == "FATAL" then print("") end
    end
 
    logCounter = (logCounter or 0) + 1
    if logCounter >= 250 then
        rotateLogs(logFolder, logFilePath)
        logCounter = 0
    end
end
 
function rotateLogs(logFolder, logFilePath)
    local maxLogs = 5
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local archivedLog = string.format("%s/log_%s.txt", logFolder, timestamp)
 
    local success, err = pcall(function()
        if fs.exists(logFilePath) then
            fs.move(logFilePath, archivedLog)
        end
    end)
    if not success then
        print(string.format("Failed to rotate log file: %s", err))
        return
    end
 
    local logs = fs.list(logFolder)
    table.sort(logs)
    while #logs > maxLogs do
        local oldestLog = logFolder .. "/" .. logs[1]
        local deleteSuccess, deleteErr = pcall(function() fs.delete(oldestLog) end)
        if not deleteSuccess then
            print(string.format("Failed to delete old log file: %s", deleteErr))
            break
        end
        table.remove(logs, 1)
    end
end
 
----------------------------------------------------------------------------
--* ERROR-HANDLING FUNCTION
----------------------------------------------------------------------------
 
function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        if type(result) == "string" and result == "Terminated" then
            error("Terminated", 0) 
        end
        logToFile((result or "Unknown error"), "ERROR", true)
        return false, result
    end
    return true, result
end
 
----------------------------------------------------------------------------
--* NBT TO SNBT STRING CONVERSION HELPER (SIMPLIFIED)
-- ... (This section is unchanged)
----------------------------------------------------------------------------
function convertNbtToSnbtString(nbtTable)
    if type(nbtTable) ~= "table" then
        logToFile("convertNbtToSnbtString: Input is not a table, returning nil. Type: " .. type(nbtTable), "WARN_")
        return nil
    end
    if next(nbtTable) == nil then
        logToFile("convertNbtToSnbtString: Input table is empty, returning empty SNBT string '{}'.", "DEBUG")
        return "{}"
    end

    local parts = {}
    for key, value in pairs(nbtTable) do
        local keyStr = tostring(key) 

        if type(value) == "string" then
            local escapedValue = string.gsub(value, "\\", "\\\\")
            escapedValue = string.gsub(escapedValue, "\"", "\\\"")
            table.insert(parts, string.format("%s:\"%s\"", keyStr, escapedValue))
        elseif type(value) == "number" then
            table.insert(parts, string.format("%s:%s", keyStr, tostring(value)))
        elseif type(value) == "boolean" then
            table.insert(parts, string.format("%s:%s", keyStr, tostring(value)))
        elseif keyStr == "textureData" and type(value) == "table" then
            local textureParts = {}
            for texKey, texValue in pairs(value) do
                if type(texValue) == "string" then
                    local escapedTexKey = string.gsub(tostring(texKey), "\\", "\\\\")
                    escapedTexKey = string.gsub(escapedTexKey, "\"", "\\\"")
                    local escapedTexValue = string.gsub(texValue, "\\", "\\\\")
                    escapedTexValue = string.gsub(escapedTexValue, "\"", "\\\"")
                    table.insert(textureParts, string.format("\"%s\":\"%s\"", escapedTexKey, escapedTexValue))
                else
                    logToFile("convertNbtToSnbtString: Non-string value found in textureData for key '" .. tostring(texKey) .. "'. Skipping.", "WARN_")
                end
            end
            table.insert(parts, string.format("%s:{%s}", keyStr, table.concat(textureParts, ",")))
        else
            logToFile(string.format("convertNbtToSnbtString: Unsupported type '%s' for key '%s' or unhandled complex table. Value: %s", type(value), keyStr, tableToString(value)), "WARN_")
        end
    end
    local snbtString = "{" .. table.concat(parts, ",") .. "}"
    logToFile("convertNbtToSnbtString: Converted NBT table to SNBT string: " .. snbtString, "TRACE")
    return snbtString
end

----------------------------------------------------------------------------
--* GENERIC HELPER FUNCTIONS
-- ... (This section is unchanged)
----------------------------------------------------------------------------
 
local function trimLeadingWhitespace(str)
    return str:match("^%s*(.*)$")
end
 
function getLastWord(str)
    local words = {}
    for word in string.gmatch(str, "%S+") do
        table.insert(words, word)
    end
    return words[#words] or "" 
end
 
function tableToString(tbl, indent)
    indent = indent or 0
    if type(tbl) ~= "table" then return tostring(tbl) end 
    local result_string = string.rep("  ", indent) .. "{\n"
    for key, value in pairs(tbl) do
        local formattedKey = type(key) == "string" and string.format("%q", key) or tostring(key)
        if type(value) == "table" then
            result_string = result_string ..
                string.rep("  ", indent + 1) ..
                "[" .. formattedKey .. "] = " .. tableToString(value, indent + 1) .. ",\n"
        else
            local formattedValue = type(value) == "string" and string.format("%q", value) or tostring(value)
            result_string = result_string ..
                string.rep("  ", indent + 1) .. "[" .. formattedKey .. "] = " .. formattedValue .. ",\n"
        end
    end
    return result_string .. string.rep("  ", indent) .. "}"
end
 
function writeToLogFile(fileName, armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list)
    local success, file_or_err = pcall(io.open, fileName, "w")
    if not success then
        logToFile("Could not open file for writing: " .. fileName .. " Error: " .. tostring(file_or_err), "ERROR", true)
        return
    end
    local file = file_or_err
 
    file:write("Armor List:\n")
    file:write(tableToString(armor_list) .. "\n\n")
    file:write("Tools List:\n")
    file:write(tableToString(tools_list) .. "\n\n")
    file:write("Other Equipment List:\n")
    file:write(tableToString(other_equipment_list) .. "\n\n")

    file:write("Standard Builder List:\n")
    file:write(tableToString(builder_list_standard) .. "\n\n")
    file:write("Domum Builder List:\n")
    file:write(tableToString(builder_list_domum) .. "\n\n")
    file:write("Others List:\n")
    file:write(tableToString(others_list) .. "\n\n")
    file:close()
end
 
local function ensure_width(line, width, pos)
    width = width or term.getSize()
    line = tostring(line)
    
    if pos ~= "left" then
        if #line > width then
          line = line:sub(1, width)
        end
        if #line < width then
            line = line .. (" "):rep(width - #line)
        end
    end
    return line
end

--[[----------------------------------------------------------------------------
--* VANILLA EQUIPMENT ID MAPPING 
-- ... (This section is unchanged)
----------------------------------------------------------------------------]]
local function getBaseEquipmentType(requestName)
    local knownTypes = {
        "Helmet", "Chestplate", "Leggings", "Boots",
        "Sword", "Pickaxe", "Axe", "Shovel", "Hoe", "Shears", "Bow"
    }
    local lowerRequestName = string.lower(requestName or "") 
    for _, typeName in ipairs(knownTypes) do
        if string.find(lowerRequestName, string.lower(typeName)) then
            return typeName 
        end
    end
    logToFile("getBaseEquipmentType: Could not determine base type from '" .. tostring(requestName) .. "'", "DEBUG")
    return getLastWord(requestName or "") 
end

local function getVanillaEquivalentId(baseEquipmentType, materialLevel)
    if not baseEquipmentType or baseEquipmentType == "" or not materialLevel then return nil end

    local baseTypeLower = string.lower(baseEquipmentType)
    local materialLower = string.lower(materialLevel)

    local vanillaPrefix = "minecraft:"
    local materialPrefix = ""
    local itemSuffix = ""

    if materialLower == "diamond" then materialPrefix = "diamond_"
    elseif materialLower == "iron" then materialPrefix = "iron_"
    elseif materialLower == "chain" or materialLower == "chainmail" then materialPrefix = "chainmail_"
    elseif materialLower == "stone" then materialPrefix = "stone_"
    elseif materialLower == "wood" or materialLower == "wooden" then materialPrefix = "wooden_"
    else
        logToFile("getVanillaEquivalentId: Material level '" .. materialLevel .. "' not mapped for standard vanilla items (excluding gold).", "DEBUG")
        return nil 
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
    elseif baseTypeLower == "bow" then return vanillaPrefix .. "bow" 
    else
        logToFile("getVanillaEquivalentId: Unsupported base equipment type '" .. baseEquipmentType .. "' for vanilla mapping.", "DEBUG")
        return nil 
    end
    
    if (materialPrefix == "chainmail_") and 
       (itemSuffix == "sword" or itemSuffix == "pickaxe" or itemSuffix == "axe" or 
        itemSuffix == "shovel" or itemSuffix == "hoe") then
        logToFile("getVanillaEquivalentId: Chainmail tools like '" .. itemSuffix .. "' do not exist in vanilla.", "DEBUG")
        return nil
    end
    
    if materialLower == "leather" and (itemSuffix == "helmet" or itemSuffix == "chestplate" or itemSuffix == "leggings" or itemSuffix == "boots") then
        return vanillaPrefix .. "leather_" .. itemSuffix 
    end

    return vanillaPrefix .. materialPrefix .. itemSuffix
end
 
----------------------------------------------------------------------------
--* CHECK REQUIREMENTS 
----------------------------------------------------------------------------
 
local monitor = peripheral.find("monitor")
local colony
local bridge
local storage
 
function getPeripheral(type)
    local p = peripheral.find(type)
    if not p then
        logToFile(type .. " peripheral not found.", "WARN_", true) 
        return nil
    end
    logToFile(type .. " peripheral found.") 
    return p
end
 
function updatePeripheralMonitor()
    monitor = getPeripheral("monitor")
    return monitor ~= nil
end
 
function checkMonitorSize()
    if not monitor then return false end
    monitor.setTextScale(0.5)
    local width, height = monitor.getSize()
    if width < 79 or height < 38 then
        logToFile("Use more Monitors! (min 4x3)", "WARN_", true) 
        return false
    end
    return true
end
 
function updatePeripheralColonyIntegrator()
    colony = getPeripheral("colonyIntegrator")
    return colony ~= nil
end
 
function getStorageBridge()
    local meBridgeP = getPeripheral("meBridge")
    if meBridgeP then return meBridgeP end
    local rsBridgeP = getPeripheral("rsBridge")
    if rsBridgeP then return rsBridgeP end
    logToFile("Neither ME Storage Bridge nor RS Storage Bridge found.", "WARN_", true) 
    return nil
end
 
function updatePeripheralStorageBridge()
    bridge = getStorageBridge()
    return bridge ~= nil
end
 
function autodetectStorage()
    for _, side in pairs(peripheral.getNames()) do
        if peripheral.hasType(side, "inventory") then
            logToFile("Storage detected on " .. side)
            return side
        end
    end
    logToFile("No storage container detected!", "WARN_", true) 
    return nil
end
 
function updatePeripheralStorage()
    storage = autodetectStorage()
    return storage ~= nil
end
 
----------------------------------------------------------------------------
-- MONITOR DASHBOARD NAME 
-- ... (This section is unchanged)
----------------------------------------------------------------------------
local dashboardName = "MineColonies DASHBOARD"
local rainbowColors = {
    colors.red, colors.orange, colors.yellow,
    colors.green, colors.cyan, colors.blue,
    colors.purple, colors.magenta, colors.pink
}
 
function monitorDisplayDashboardName(mon, y, text, colorsTable)
    if not mon then return end
    local w, _ = mon.getSize()
    local x = math.floor((w - #text) / 2) + 1
    for i = 1, #text do
        local char = text:sub(i, i)
        local colorIdx = ((i-1) % #colorsTable) + 1
        mon.setTextColor(colorsTable[colorIdx])
        mon.setCursorPos(x + i - 1, y)
        mon.write(char)
    end
end
 
function dashboardGenerateTransitionColors(progress, length)
    local colorsTable = {}
    local threshold = math.floor(progress * length)
    for i = 1, length do
        colorsTable[i] = (i <= threshold) and colors.orange or colors.white
    end
    return colorsTable
end
 
function dashboardGenerateRainbowColors(baseColors, length)
    local result = {}
    for i = 1, length do
        result[i] = baseColors[((i - 1) % #baseColors) + 1]
    end
    return result
end
 
function monitorDashboardName() 
    if not monitor then return end 
    local localStartTime = os.clock()
    local y = 1
    local animationCycleDuration = 5.0 
    local transitionEndTime = animationCycleDuration * 0.7
    
    while true do
        local currentElapsedTime = os.clock() - localStartTime
        
        if currentElapsedTime < transitionEndTime then
            local progress = currentElapsedTime / transitionEndTime
            local colorsTable = dashboardGenerateTransitionColors(progress, #dashboardName)
            monitorDisplayDashboardName(monitor, y, dashboardName, colorsTable)
        else
            local rainbowPhaseDuration = animationCycleDuration - transitionEndTime
            local rainbowProgress = (currentElapsedTime - transitionEndTime) / rainbowPhaseDuration
            local rainbowIdxStart = math.floor(rainbowProgress * #rainbowColors * 2)
            
            local tempRainbowColors = {}
            for i=1, #dashboardName do
                table.insert(tempRainbowColors, rainbowColors[ ((rainbowIdxStart + i -1) % #rainbowColors) +1 ])
            end
            monitorDisplayDashboardName(monitor, y, dashboardName, tempRainbowColors)
        end
        
        if currentElapsedTime >= animationCycleDuration then
            break 
        end
        
        sleep(0.05) 
    end
end
 
----------------------------------------------------------------------------
--* ART
-- ... (This section is unchanged)
----------------------------------------------------------------------------
local artUltimateCCxM_Logo = [[
 _   _ _ _   _                 _
| | | | | |_(_)_ __ ___   __ _| |_ ___
| | | | | __| | '_ ` _ \ / _` | __/ _ \
| |_| | | |_| | | | | | | (_| | ||  __/
 \____|_____|_|_| |_|___|_____|\__\___|
 / ___/ ___|__  __|  \/  (_)_ __   ___
| |  | |    \ \/ /| |\/| | | '_ \ / _ \
| |__| |___  >  < | |  | | | | | |  __/
 \____\____|/_/\_\|_|  |_|_|_| |_|\___|
 / ___|___ | | ___  _ __ (_) ___  ___
| |   / _ \| |/ _ \| '_ \| |/ _ \/ __|
| |__| (_) | | (_) | | | | |  __/\__ \
 \____\___/|_|\___/|_| \_| |___/||___/
]]
----------------------------------------------------------------------------
--* MONITOR OR TERMINAL OUTPUT
-- ... (This section is unchanged)
----------------------------------------------------------------------------
function resetDefault(screen)
    if not screen then return end
    screen.setTextColor(colors.white)
    screen.setBackgroundColor(colors.black)
    screen.setCursorPos(1, 1)
    screen.clear()
end
 
function drawLoadingBar(screen, x, y, width, progress, bgColor, barColor)
    if not screen then return end
    local originalBg = screen.getBackgroundColor()
    local originalFg = screen.getTextColor()
 
    screen.setBackgroundColor(bgColor or colors.gray)
    screen.setCursorPos(x, y)
    screen.write(string.rep(" ", width))
 
    local filledWidth = math.floor(progress * width)
    if filledWidth > 0 then
      screen.setCursorPos(x, y)
      screen.setBackgroundColor(barColor or colors.green)
      screen.write(string.rep(" ", filledWidth))
    end
    
    screen.setBackgroundColor(originalBg)
    screen.setTextColor(originalFg)
end
----------------------------------------------------------------------------
--* MONITOR OUTPUT
-- ... (This section is unchanged)
----------------------------------------------------------------------------
function monitorDisplayArt(asciiArt, mon_)
    if not mon_ then return end
    resetDefault(mon_)
    mon_.setTextScale(1)
    local x, y = 1, 2
    for line in asciiArt:gmatch("[^\n]+") do
        mon_.setCursorPos(x, y)
        mon_.write(line)
        y = y + 1
    end
end
 
function monitorLoadingAnimation()
    if not monitor then return end
    resetDefault(monitor)
    monitor.setTextScale(1)
    local w, h = monitor.getSize()
    local barWidth = math.floor(w * 0.9)
    local barX = math.floor((w - barWidth) / 2) + 1
    local barY = 17
 
    monitorDisplayArt(artUltimateCCxM_Logo, monitor)
 
    local barSpeed = 30
    for i = 0, barSpeed do
        drawLoadingBar(monitor, barX, barY, barWidth, i / barSpeed, colors.gray, colors.orange)
        sleep(0.1) 
    end
    resetDefault(monitor)
    monitor.setTextScale(0.5)
end
 
function monitorPrintText(y, pos, text, ...)
    if not monitor then return end
    local w, h = monitor.getSize()
    local fg = monitor.getTextColor()
    local bg = monitor.getBackgroundColor()
    text = tostring(text)
    local x_coord = 1
 
    if pos == "left" then
        x_coord = 4
        text = ensure_width(text, math.floor(w / 2) - 2, pos)
    elseif pos == "center" then
        text = ensure_width(text, w - 2, pos)
        x_coord = math.floor((w - #text) / 2) + 1
    elseif pos == "right" then
        text = ensure_width(text, math.floor(w / 2) - 2, pos)
        x_coord = w - #text - 2
    elseif pos == "middle" then
        text = ensure_width(text, w - 2, pos)
        x_coord = math.floor((w - #text) / 2) + 1
        y = math.floor(h / 2) - 2
    end
 
    if select("#", ...) > 0 then monitor.setTextColor(select(1, ...)) end
    if select("#", ...) > 1 then monitor.setBackgroundColor(select(2, ...)) end
 
    monitor.setCursorPos(x_coord, y)
    monitor.write(text)
    monitor.setTextColor(fg)
    monitor.setBackgroundColor(bg)
end
 
function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    if not monitor then return end
    monitor.setBackgroundColor(bcolor)
    for xPos = xMin, xMax, 1 do
        monitor.setCursorPos(xPos, yMin)
        monitor.write(" ")
    end
    for yPos = yMin, yMax, 1 do
        monitor.setCursorPos(xMin, yPos)
        monitor.write(" ")
        monitor.setCursorPos(xMax, yPos)
        monitor.write(" ")
    end
    for xPos = xMin, xMax, 1 do
        monitor.setCursorPos(xPos, yMax)
        monitor.write(" ")
    end
    monitor.setCursorPos(xMin + 2, yMin)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(tcolor)
    monitor.write(" ")
    monitor.write(title)
    monitor.write(" ")
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
end
 
function monitorDashboardRequests(armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list)
    if not monitor then return end
    local x_size, y_size = monitor.getSize()
 
    local armor_count = #armor_list
    local tools_count = #tools_list
    local other_equip_count = #other_equipment_list
    local standard_builder_count = #builder_list_standard
    local domum_builder_count = #builder_list_domum
    local others_count = #others_list

    local total_equipment_lines = armor_count + tools_count + other_equip_count
    if armor_count > 0 and (tools_count > 0 or other_equip_count > 0) then total_equipment_lines = total_equipment_lines + 1 end 
    if tools_count > 0 and other_equip_count > 0 then total_equipment_lines = total_equipment_lines + 1 end 


    local actual_standard_builder_lines = math.ceil(standard_builder_count / 2)
    local actual_domum_builder_lines = domum_builder_count
    local actual_builder_lines = actual_standard_builder_lines + actual_domum_builder_lines
    
    if actual_standard_builder_lines > 0 and actual_domum_builder_lines > 0 then
        actual_builder_lines = actual_builder_lines + 1 
    end
 
    local estimated_box_height = (total_equipment_lines + actual_builder_lines + others_count) + 11 
    if armor_count > 0 then estimated_box_height = estimated_box_height + 1 end 
    if tools_count > 0 then estimated_box_height = estimated_box_height + 1 end 
    if other_equip_count > 0 then estimated_box_height = estimated_box_height + 1 end 

    estimated_box_height = math.min(estimated_box_height, y_size -1)
 
    drawBox(2, x_size - 1, 3, estimated_box_height, "REQUESTS", colors.gray, colors.purple)
 
    local current_y = 5
    
    monitorPrintText(current_y, "center", "Builder", colors.orange)
    current_y = current_y + 1
 
    local i = 1
    while i <= standard_builder_count do
        if current_y >= estimated_box_height -1 then break end
        local currentItem = builder_list_standard[i]
        local nextItem = builder_list_standard[i+1]

        if nextItem and (i+1 <= standard_builder_count) then
             monitorPrintText(current_y, "left", (currentItem.provided .. "/" .. currentItem.count .. " " .. currentItem.name), currentItem.displayColor)
             monitorPrintText(current_y, "right", (nextItem.provided .. "/" .. nextItem.count .. " " .. nextItem.name), nextItem.displayColor)
             i = i + 2
        else 
             monitorPrintText(current_y, "left", (currentItem.provided .. "/" .. currentItem.count .. " " .. currentItem.name), currentItem.displayColor)
             i = i + 1
        end
        current_y = current_y + 1
    end

    if actual_standard_builder_lines > 0 and actual_domum_builder_lines > 0 then
        if current_y < estimated_box_height -1 then current_y = current_y + 1 end
    end
    
    for _, item in ipairs(builder_list_domum) do
        if current_y >= estimated_box_height -1 then break end
        monitorPrintText(current_y, "left", (item.provided .. "/" .. item.count .. " " .. item.name), item.displayColor)
        current_y = current_y + 1
    end
    
    current_y = current_y + 1 
    if armor_count > 0 and current_y < estimated_box_height -1 then
      monitorPrintText(current_y, "center", "Armor", colors.orange)
      current_y = current_y + 1
      for _, item in ipairs(armor_list) do
          if current_y >= estimated_box_height -1 then break end
          monitorPrintText(current_y, "left", item.name, item.displayColor) 
          monitorPrintText(current_y, "right", item.target, colors.lightGray)
          current_y = current_y + 1
      end
      if tools_count > 0 or other_equip_count > 0 then current_y = current_y + 1 end 
    end

    if tools_count > 0 and current_y < estimated_box_height -1 then
      monitorPrintText(current_y, "center", "Tools", colors.orange)
      current_y = current_y + 1
      for _, item in ipairs(tools_list) do
          if current_y >= estimated_box_height -1 then break end
          monitorPrintText(current_y, "left", item.name, item.displayColor) 
          monitorPrintText(current_y, "right", item.target, colors.lightGray)
          current_y = current_y + 1
      end
       if other_equip_count > 0 then current_y = current_y + 1 end 
    end
    
    if other_equip_count > 0 and current_y < estimated_box_height -1 then
      monitorPrintText(current_y, "center", "Other Equipment", colors.orange)
      current_y = current_y + 1
      for _, item in ipairs(other_equipment_list) do
          if current_y >= estimated_box_height -1 then break end
          monitorPrintText(current_y, "left", item.name, item.displayColor) 
          monitorPrintText(current_y, "right", item.target, colors.lightGray)
          current_y = current_y + 1
      end
    end
 
    current_y = current_y + 1
    if current_y < estimated_box_height -1 then
      monitorPrintText(current_y, "center", "Other Requests", colors.orange)
      current_y = current_y + 1
      for _, item in ipairs(others_list) do
          if current_y >= estimated_box_height -1 then break end
          monitorPrintText(current_y, "left", (item.provided .. "/" .. item.count .. " " .. item.name), item.displayColor)
          monitorPrintText(current_y, "right", item.target, colors.lightGray)
          current_y = current_y + 1
      end
    end
end
 
----------------------------------------------------------------------------
--* TERMINAL OUTPUT
----------------------------------------------------------------------------
local termWidth, termHeight
local needTermDrawRequirements = true
local needTermDrawRequirements_executed = false 
local isInitialBoot = true 

function termDisplayArt(asciiArt)
    term.clear()
    local x, y = 6, 2
    for line in asciiArt:gmatch("[^\n]+") do
        term.setCursorPos(x, y)
        term.write(line)
        y = y + 1
    end
end
 
function termLoadingAnimation()
    resetDefault(term)
    termWidth, termHeight = term.getSize()
    local barWidth = math.floor(termWidth * 0.8)
    local barX = math.floor((termWidth - barWidth) / 2) + 1
    local barY = math.floor(termHeight * 0.9)
 
    term.setTextColor(colors.orange)
    term.setCursorPos(1, 1)
    termDisplayArt(artUltimateCCxM_Logo)
 
    local barSpeed = 25
    for i = 0, barSpeed do
        drawLoadingBar(term, barX, barY, barWidth, i / barSpeed, colors.gray, colors.orange)
        sleep(0.05) 
    end
    resetDefault(term)
end
 
function termDrawProgramReq_helper(y, isRequirementMet)
    if isRequirementMet then
        term.setTextColor(colors.green)
        term.setCursorPos(49, y)
        term.write("[O]")
    else
        term.setTextColor(colors.red)
        term.setCursorPos(49, y)
        term.write("[X]")
    end
    term.setTextColor(colors.white)
end
 
function termDrawProgramReq_Header(quickDraw)
    termWidth, termHeight = term.getSize()
    local text_Divider = "-------------------------------------------------------"
    term.setCursorPos(math.floor((termWidth - #text_Divider) / 2) + 1, 4)
    term.write(text_Divider)
    local text_Requirements = "\187 Program Requirements \171"
    term.setCursorPos(math.floor((termWidth - #text_Requirements) / 2) + 1, 2)
    if quickDraw then 
        term.write(text_Requirements)
    else
        textutils.slowWrite(text_Requirements, 16)
    end
end
 
function termDrawCheckRequirements(isStartup)
    if not needTermDrawRequirements_executed then
        term.clear()
        termDrawProgramReq_Header(isStartup) 
        
        -- Draw all static labels once when the screen is first set up
        term.setCursorPos(2, 6); term.write("\16 Monitor attached")
        term.setCursorPos(2, 8); term.write("\16 Monitor size (min 4x3)")
        term.setCursorPos(2, 10); term.write("\16 Colony Integrator attached")
        term.setCursorPos(2, 12); term.write("\16 Colony Integrator in a colony")
        term.setCursorPos(2, 14); term.write("\16 ME or RS Bridge attached")
        term.setCursorPos(2, 16); term.write("\16 Storage/Warehouse attached")
        needTermDrawRequirements_executed = true -- Set after labels are drawn
    end
    termWidth, termHeight = term.getSize() 
 
    local allRequirementsMet = true
    local monitorOk, monitorSizeOk, colonyIntegratorOk, colonyInColonyOk, bridgeOk, storageOk = false, false, false, false, false, false

    monitorOk = updatePeripheralMonitor()
    if monitorOk then monitorSizeOk = checkMonitorSize() else monitorSizeOk = false end
    
    colonyIntegratorOk = updatePeripheralColonyIntegrator()
    if colonyIntegratorOk and colony then colonyInColonyOk = colony.isInColony() else colonyInColonyOk = false end

    bridgeOk = updatePeripheralStorageBridge()
    storageOk = updatePeripheralStorage()

    termDrawProgramReq_helper(6, monitorOk)
    termDrawProgramReq_helper(8, monitorOk and monitorSizeOk) 
    
    termDrawProgramReq_helper(10, colonyIntegratorOk)
    termDrawProgramReq_helper(12, colonyIntegratorOk and colonyInColonyOk) 

    termDrawProgramReq_helper(14, bridgeOk)
    termDrawProgramReq_helper(16, storageOk)

    allRequirementsMet = monitorOk and monitorSizeOk and colonyIntegratorOk and colonyInColonyOk and bridgeOk and storageOk
 
    if allRequirementsMet then
        needTermDrawRequirements = false 
        isInitialBoot = false 
        local text_Fullfilled = "Requirements fullfilled"
        term.setCursorPos(math.floor((termWidth - #text_Fullfilled) / 2), 19)
        term.setTextColor(colors.green)
        if isStartup then 
            sleep(0.1); term.write(text_Fullfilled); term.write(" . . ."); sleep(0.2)
        else
            term.write(text_Fullfilled .. " . . .") 
        end
        resetDefault(term)
        return true
    end
    return false
end
 
function termShowLog() 
    termWidth, termHeight = term.getSize()
    term.setCursorPos(1, 1); term.clearLine()
    term.setCursorPos(1, 2); term.clearLine()
    term.setCursorPos(1, 3); term.clearLine()
    local text_Divider = "-------------------------------------------------------"
    term.setCursorPos(math.floor((termWidth - #text_Divider) / 2) + 1, 4)
    term.write(text_Divider)
    local text_LogTitle = "\187 MineColonies Logs \171   v" .. VERSION
    term.setCursorPos(math.floor((termWidth - #text_LogTitle) / 2) + 1, 2)
    textutils.slowWrite(text_LogTitle, 16) 
end
 
----------------------------------------------------------------------------
--* MINECOLONIES
-- ... (This section is unchanged)
----------------------------------------------------------------------------
function removeNamespace(itemName)
    if type(itemName) ~= "string" then return tostring(itemName) end
    local colonIndex = string.find(itemName, ":")
    if colonIndex then
        return string.sub(itemName, colonIndex + 1)
    end
    return itemName
end
 
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
 
function colonyCategorizeRequests()
    local armor_list = {}            
    local tools_list = {}            
    local other_equipment_list = {}  
    local builder_list_standard = {} 
    local builder_list_domum = {}    
    local others_list = {}           
 
    if not colony then
        logToFile("Colony Integrator not available for categorizing requests.", "WARN_", true)
        return armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list
    end
 
    local success, requests = safeCall(colony.getRequests)
    if not success or not requests or #requests == 0 then
        logToFile("Failed to get colony requests or no requests found.", "INFO_")
        return armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list
    end
 
    for _, req in ipairs(requests) do
        if not req.items or not req.items[1] then
            logToFile("Skipping request due to missing item data: " .. tableToString(req), "DEBUG")
            goto continue_categorize_loop
        end
 
        local name_from_req = req.name or "Unknown" 
        local target = req.target or ""
        local desc = req.desc or ""
        local count = req.count or 0
        local item_displayName = trimLeadingWhitespace(req.items[1].displayName or name_from_req)
        local item_name_raw = req.items[1].name or "" 
        local itemIsGenerallyEquipment = isEquipment(desc) 
        
        local nbtToStore = req.items[1].nbt
        local fingerprintToStore = req.items[1].fingerprint
        local formattedName = name_from_req 
        local isDomumOrnamentumItem = string.find(item_name_raw, "domum_ornamentum:", 1, true) == 1

        local itemEntry = {
            name = formattedName, 
            target = target, 
            count = count, 
            item_displayName = item_displayName,
            item_name_raw = item_name_raw, 
            item_name = item_name_raw,     
            desc = desc, 
            provided = 0, 
            isCraftable = false,
            displayColor = colors.white, 
            level = "Any Level", 
            nbtData = nbtToStore,
            fingerprint = fingerprintToStore
        }

        if string.find(target, "Builder", 1, true) then
            if isDomumOrnamentumItem then
                local blockType = removeNamespace(item_name_raw)
                local textureData = nbtToStore and nbtToStore["textureData"]
                local textureDataSize = 0
                if type(textureData) == 'table' then
                    for _ in pairs(textureData) do textureDataSize = textureDataSize + 1 end
                end
     
                if textureDataSize == 1 and nbtToStore and nbtToStore.type then
                    local singleMaterial = "UnknownMaterial"
                    if type(textureData) == 'table' then
                        for _, mat_val in pairs(textureData) do singleMaterial = removeNamespace(tostring(mat_val)); break end
                    end
                    local style = tostring(nbtToStore.type):gsub("_", " ") :gsub("^%l", string.upper):gsub("%s%l", function(c) return string.upper(c) end)
                    itemEntry.name = string.format("%s (%s, %s)", item_displayName, style, singleMaterial) 
                elseif textureDataSize == 2 and nbtToStore then
                    local materialsExtracted = {}
                    if type(textureData) == 'table' then
                        local matKeys = {}
                        for k_mat in pairs(textureData) do table.insert(matKeys, k_mat) end
                        if matKeys[1] then table.insert(materialsExtracted, removeNamespace(tostring(textureData[matKeys[1]]))) end
                        if matKeys[2] then table.insert(materialsExtracted, removeNamespace(tostring(textureData[matKeys[2]]))) end
                    end
                    if #materialsExtracted == 2 then
                         itemEntry.name = string.format("%s (%s, %s, %s)", item_displayName, blockType, materialsExtracted[1], materialsExtracted[2]) 
                    else
                         itemEntry.name = string.format("%s (%s, MaterialsErr)", item_displayName, blockType) 
                         logToFile("Domum 2-mat block " .. item_displayName .. " issue extracting 2 materials.", "WARN_")
                    end
                else
                    itemEntry.name = string.format("%s (%s, NBT_Err)", item_displayName, blockType) 
                    logToFile("Unhandled Domum block: " .. item_displayName .. " textureDataSize: " .. textureDataSize .. " NBT: " .. tableToString(nbtToStore or {}), "WARN_")
                end
                table.insert(builder_list_domum, itemEntry)
            else
                itemEntry.name = name_from_req 
                table.insert(builder_list_standard, itemEntry)
            end
        elseif itemIsGenerallyEquipment then 
            local levelTable = {
                ["and with maximal level: Leather"] = "Leather", ["and with maximal level: Stone"] = "Stone",
                ["and with maximal level: Chain"] = "Chain", ["and with maximal level: Gold"] = "Gold",
                ["and with maximal level: Iron"] = "Iron", ["and with maximal level: Diamond"] = "Diamond",
                ["with maximal level: Wood or Gold"] = "Wood or Gold" 
            }
            local extractedLevel = "Any Level" 
            for pattern, mappedLevel in pairs(levelTable) do
                if string.find(desc, pattern) then 
                    extractedLevel = mappedLevel
                    break 
                end
            end
            if extractedLevel == "Any Level" then 
                if string.find(desc, "Diamond") then extractedLevel = "Diamond"
                elseif string.find(desc, "Iron") then extractedLevel = "Iron"
                elseif string.find(desc, "Chain") then extractedLevel = "Chain"
                elseif string.find(desc, "Stone") then extractedLevel = "Stone" 
                elseif string.find(desc, "Gold") then extractedLevel = "Gold"
                elseif string.find(desc, "Leather") then extractedLevel = "Leather"
                elseif string.find(desc, "Wood") then extractedLevel = "Wood"
                end
            end

            itemEntry.level = extractedLevel 
            itemEntry.name = extractedLevel .. " " .. name_from_req 
            
            local baseType = getBaseEquipmentType(name_from_req)
            if baseType == "Helmet" or baseType == "Chestplate" or baseType == "Leggings" or baseType == "Boots" then
                table.insert(armor_list, itemEntry)
            elseif baseType == "Pickaxe" or baseType == "Axe" or baseType == "Shovel" or baseType == "Hoe" or baseType == "Sword" then
                table.insert(tools_list, itemEntry)
            elseif baseType == "Bow" or baseType == "Shears" then
                 table.insert(other_equipment_list, itemEntry)
            else
                logToFile("Unknown equipment type for categorization: " .. name_from_req .. " (Base: " .. baseType .. "). Adding to Other Equipment as fallback.", "WARN_")
                table.insert(other_equipment_list, itemEntry) 
            end
        else
            itemEntry.name = name_from_req 
            table.insert(others_list, itemEntry)
        end
        ::continue_categorize_loop::
    end
    return armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list
end
 
----------------------------------------------------------------------------
--* STORAGE SYSTEM REQUEST AND SEND
-- ... (This section is unchanged from 1.23)
----------------------------------------------------------------------------
local b_craftEquipment = true
local item_quantity_field = nil
 
function equipmentCraft(formatted_request_name, request_level, original_item_id_from_colony)
    local baseType = getBaseEquipmentType(formatted_request_name)
    if not baseType or baseType == "" then
        logToFile("equipmentCraft: Could not determine base equipment type from formatted name: '" .. formatted_request_name .. "'. Not crafting.", "WARN_")
        return original_item_id_from_colony, false 
    end

    if baseType == "Bow" then
        logToFile("equipmentCraft: Request is for a Bow. Targeting vanilla minecraft:bow.", "INFO_")
        return "minecraft:bow", true
    end
    if baseType == "Shears" then
        logToFile("equipmentCraft: Request is for Shears. Targeting vanilla minecraft:shears.", "INFO_")
        return "minecraft:shears", true
    end

    if baseType == "Pickaxe" or baseType == "Axe" or baseType == "Shovel" then
        local paxelMaterial = nil
        local rl_lower = string.lower(request_level or "")
        if rl_lower == "diamond" then paxelMaterial = "diamond"
        elseif rl_lower == "iron" then paxelMaterial = "iron"
        elseif rl_lower == "stone" then paxelMaterial = "stone"
        elseif rl_lower == "wood" or rl_lower == "wooden" then paxelMaterial = "wood"
        elseif rl_lower == "gold" or rl_lower == "golden" then paxelMaterial = "gold"
        end

        if paxelMaterial then
            local paxelId = "mekanismtools:" .. paxelMaterial .. "_paxel"
            logToFile("equipmentCraft: Substituting " .. formatted_request_name .. " (Level: " .. request_level .. ") with MEKANISM PAXEL: " .. paxelId, "INFO_")
            return paxelId, true
        else
            logToFile("equipmentCraft: Request for " .. baseType .. " of level '" .. request_level .. "' does not map to a supported Mekanism Paxel tier. Falling back to vanilla/original.", "INFO_")
        end
    end

    local targetVanillaId = getVanillaEquivalentId(baseType, request_level)
    if targetVanillaId then
        logToFile("equipmentCraft: For request '" .. formatted_request_name .. "' (Level: " .. request_level .. "), determined target VANILLA item: " .. targetVanillaId, "INFO_")
        return targetVanillaId, true 
    else
        logToFile("equipmentCraft: Request '" .. formatted_request_name .. "' (Level: " .. request_level .. ") does not map to a craftable vanilla equivalent or supported paxel. Original ID: "..original_item_id_from_colony..". Not crafting.", "INFO_")
        return original_item_id_from_colony, false 
    end
end
 
function detectQuantityFieldOnce(itemName, nbtTable, fingerprint)
    if item_quantity_field then return item_quantity_field end 
 
    local spec
    if fingerprint then
        spec = {fingerprint = fingerprint}
    else
        spec = {name = itemName}
        if nbtTable then 
            local nbtString = convertNbtToSnbtString(nbtTable)
            if nbtString then spec.nbt = nbtString end
        end
    end
 
    local success, itemDataResult = safeCall(bridge.getItem, spec)
    if success and itemDataResult then
        if type(itemDataResult.amount) == "number" then item_quantity_field = "amount"; return "amount" end
        if type(itemDataResult.count) == "number" then item_quantity_field = "count"; return "count" end
        logToFile("Could not detect quantity field (amount/count) for " .. itemName .. ". Spec: " ..tableToString(spec), "WARN_")
    else
        logToFile("Failed to getItem for quantity field detection: " .. itemName .. ". Error: " ..tostring(itemDataResult) .. ". Spec: " .. tableToString(spec), "WARN_")
    end
    logToFile("Defaulting quantity field to 'amount' for " .. itemName, "DEBUG")
    item_quantity_field = "amount" 
    return item_quantity_field
end
 
function storageSystemHandleRequests(request_list, list_name_for_logging) 
    list_name_for_logging = list_name_for_logging or "UnknownList"
    if not bridge or not storage then
        logToFile("Bridge or storage not available for handling requests ("..list_name_for_logging..").", "WARN_", true)
        return
    end
    if not request_list or #request_list == 0 then
        return
    end
    logToFile("Processing request list: " .. list_name_for_logging .. " (" .. #request_list .. " items)", "INFO_")


    for _, item in ipairs(request_list) do
        local itemToRequest = item.item_name_raw 
        local nbtTableForRequest = item.nbtData   
        local fingerprintForRequest = item.fingerprint 
        local canCraftThisItemBasedOnRules = true 
        local isDomumItem = string.find(item.item_name_raw, "domum_ornamentum:", 1, true) == 1
        
        local useOriginalNbtAndFingerprint = fingerprintForRequest ~= nil

        if isDomumItem then
            logToFile("Processing Domum Request: " .. item.item_displayName, "DEBUG", bShowInGameLog)
            logToFile("  Original Raw ID: " .. item.item_name_raw, "DEBUG", bShowInGameLog)
        end
 
        if (list_name_for_logging == "Armor" or list_name_for_logging == "Tools" or list_name_for_logging == "OtherEquipment") and b_craftEquipment then 
            local potentialTargetItem, tierCraftableByRules
            potentialTargetItem, tierCraftableByRules = equipmentCraft(item.name, item.level, item.item_name_raw)

            if tierCraftableByRules then
                if potentialTargetItem ~= item.item_name_raw then
                    logToFile("  EquipmentCraft ("..list_name_for_logging.."): Mapped '"..item.item_name_raw.."' to TARGET '" .. potentialTargetItem .. "'. Will use this for AE2.", "INFO_")
                    itemToRequest = potentialTargetItem
                    useOriginalNbtAndFingerprint = false 
                    nbtTableForRequest = nil          
                    fingerprintForRequest = nil       
                else
                    logToFile("  EquipmentCraft ("..list_name_for_logging.."): Target '" .. itemToRequest .. "' is same as original. Tier rules allow. Using original NBT/FP if present.", "INFO_")
                end
                canCraftThisItemBasedOnRules = true
            else
                logToFile("  EquipmentCraft ("..list_name_for_logging.."): Rules prevent crafting for: " .. item.name .. " (Level: " .. item.level .. ", Original ID: " .. item.item_name_raw .. ")", "INFO_")
                canCraftThisItemBasedOnRules = false
                useOriginalNbtAndFingerprint = false 
            end
        elseif (list_name_for_logging == "Armor" or list_name_for_logging == "Tools" or list_name_for_logging == "OtherEquipment") and not b_craftEquipment then
            canCraftThisItemBasedOnRules = false 
            logToFile("  Master equipment crafting switch b_craftEquipment is OFF. Cannot craft: ".. item.item_displayName, "INFO_")
            useOriginalNbtAndFingerprint = false 
        end
        
        local qtyField = detectQuantityFieldOnce(itemToRequest, (useOriginalNbtAndFingerprint and nbtTableForRequest) or nil, (useOriginalNbtAndFingerprint and fingerprintForRequest) or nil)
        if isDomumItem then logToFile("  Using Qty Field: " .. qtyField .. " for item: " .. itemToRequest, "DEBUG", bShowInGameLog) end
        
        local itemData, itemStoredSystem, itemIsCraftableSystemAE
        local getItemSpec = { name = itemToRequest } 

        if useOriginalNbtAndFingerprint and fingerprintForRequest then 
            getItemSpec.fingerprint = fingerprintForRequest
            if isDomumItem or item.equipment then logToFile("  Calling bridge.getItem with fingerprint spec: " .. tableToString(getItemSpec), "DEBUG", bShowInGameLog) end
        else
            if not useOriginalNbtAndFingerprint and nbtTableForRequest then
                 local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                 if nbtString then getItemSpec.nbt = nbtString end
            elseif useOriginalNbtAndFingerprint and nbtTableForRequest and not fingerprintForRequest then
                 local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                 if nbtString then getItemSpec.nbt = nbtString end
            end
            if isDomumItem or item.equipment then logToFile("  Calling bridge.getItem for '"..itemToRequest.."' with name/NBT string spec: " .. tableToString(getItemSpec), "DEBUG", bShowInGameLog) end
        end
        
        local successGetItem, resultGetItem = safeCall(bridge.getItem, getItemSpec)
 
        if successGetItem and resultGetItem then
            itemData = resultGetItem
            itemStoredSystem = itemData[qtyField] or 0
            itemIsCraftableSystemAE = itemData.isCraftable 
            if isDomumItem or item.equipment then logToFile("  bridge.getItem result for '"..itemToRequest.."' - Stored: " .. itemStoredSystem .. ", AE Craftable: " .. tostring(itemIsCraftableSystemAE), "DEBUG", bShowInGameLog) end
        else
            logToFile(item.item_displayName .. " (target ID: "..itemToRequest..", FP: "..tostring(fingerprintForRequest)..") not in system or error. getItemSpec: " .. tableToString(getItemSpec) .. " Err: " .. tostring(resultGetItem), "WARN_", true)
            item.displayColor = colors.red
            goto continue_request_loop 
        end
        
        item.isCraftable = itemIsCraftableSystemAE 
 
        if itemStoredSystem > 0 then
            local countToExport = item.count - item.provided
            if countToExport > 0 then
                local exportSpec = { name = itemToRequest, count = countToExport }

                if useOriginalNbtAndFingerprint and fingerprintForRequest then
                    exportSpec.fingerprint = fingerprintForRequest
                    if isDomumItem or item.equipment then logToFile("  Calling bridge.exportItemToPeripheral with fingerprint spec: " .. tableToString(exportSpec), "DEBUG", bShowInGameLog) end
                else
                    if not useOriginalNbtAndFingerprint and nbtTableForRequest then 
                         local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                         if nbtString then exportSpec.nbt = nbtString end
                    elseif useOriginalNbtAndFingerprint and nbtTableForRequest and not fingerprintForRequest then
                         local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                         if nbtString then exportSpec.nbt = nbtString end
                    end
                    if isDomumItem or item.equipment then logToFile("  Calling bridge.exportItemToPeripheral for '"..itemToRequest.."' with name/NBT string spec: " .. tableToString(exportSpec), "DEBUG", bShowInGameLog) end
                end
                
                local successExport, exportedResult = safeCall(bridge.exportItemToPeripheral, exportSpec, storage)
                
                if successExport and exportedResult then
                    local exportedAmountValue = 0
                    if type(exportedResult) == "number" then
                        exportedAmountValue = exportedResult
                    elseif type(exportedResult) == "table" and exportedResult[qtyField] then
                        exportedAmountValue = exportedResult[qtyField]
                    elseif type(exportedResult) == "table" and exportedResult["count"] then 
                        exportedAmountValue = exportedResult["count"]
                    elseif type(exportedResult) == "table" and exportedResult["amount"] then 
                        exportedAmountValue = exportedResult["amount"]
                    else
                        logToFile("Unexpected result type/structure from exportItemToPeripheral for " .. item.item_displayName .. " ("..itemToRequest.."): " .. type(exportedResult) .. " Value: " .. tableToString(exportedResult or {}), "WARN_", bShowInGameLog)
                    end
                    item.provided = item.provided + (tonumber(exportedAmountValue) or 0)
                    if isDomumItem or item.equipment then logToFile("  Exported: " .. exportedAmountValue .. " of "..itemToRequest..", New Provided: " .. item.provided, "DEBUG", bShowInGameLog) end
                else
                    logToFile("Failed to export " .. item.item_displayName .. " (as "..itemToRequest.."). exportSpec: " .. tableToString(exportSpec) .. " Err: " .. tostring(exportedResult), "WARN_", true)
                end
            end
        end
 
        if item.provided >= item.count then
            item.displayColor = colors.green
        else 
            local currentItemInSystem = itemStoredSystem
            if item.provided > 0 and item.provided < item.count then 
                local recheckSpec = { name = itemToRequest }
                if useOriginalNbtAndFingerprint and fingerprintForRequest then 
                    recheckSpec.fingerprint = fingerprintForRequest
                elseif useOriginalNbtAndFingerprint and nbtTableForRequest and not fingerprintForRequest then 
                    local nbtString = convertNbtToSnbtString(nbtTableForRequest)
                    if nbtString then recheckSpec.nbt = nbtString end
                end
                local successRecheck, recheckResultData = safeCall(bridge.getItem, recheckSpec)
                if successRecheck and recheckResultData then
                    currentItemInSystem = recheckResultData[qtyField] or 0
                end
            end
 
            if item.provided < item.count and currentItemInSystem == 0 and not item.isCraftable then 
                 item.displayColor = colors.red 
            else 
                 item.displayColor = colors.yellow 
            end
        end
        
        if item.provided < item.count and item.isCraftable and canCraftThisItemBasedOnRules then
            local nbtStringToCraft = nil
            if itemToRequest == item.item_name_raw and nbtTableForRequest then
                 nbtStringToCraft = convertNbtToSnbtString(nbtTableForRequest)
            elseif isDomumItem and nbtTableForRequest then 
                 nbtStringToCraft = convertNbtToSnbtString(nbtTableForRequest)
            end

            local isItemCraftingSpec = { name = itemToRequest }
            if nbtStringToCraft then isItemCraftingSpec.nbt = nbtStringToCraft end

            if isDomumItem or item.equipment or nbtStringToCraft then logToFile("  Calling bridge.isItemCrafting for '"..itemToRequest.."' with spec: " .. tableToString(isItemCraftingSpec), "DEBUG", bShowInGameLog) end
            local successCraftingCheck, isCurrentlyCrafting = safeCall(bridge.isItemCrafting, isItemCraftingSpec)
 
            if successCraftingCheck and isCurrentlyCrafting then
                item.displayColor = colors.blue 
                if isDomumItem or item.equipment or nbtStringToCraft then logToFile("  Item '"..itemToRequest.."' is already crafting.", "DEBUG", bShowInGameLog) end
            else 
                local craftSpec = { name = itemToRequest, count = item.count - item.provided }
                if nbtStringToCraft then craftSpec.nbt = nbtStringToCraft end

                if isDomumItem or item.equipment or nbtStringToCraft then logToFile("  Calling bridge.craftItem for '"..itemToRequest.."' with spec: " .. tableToString(craftSpec), "DEBUG", bShowInGameLog) end
                local successCraft, craftInitiateResult = safeCall(bridge.craftItem, craftSpec)
                if successCraft and craftInitiateResult then 
                    item.displayColor = colors.blue 
                    logToFile("Crafting initiated for: " .. item.item_displayName .. " (as " .. itemToRequest .. ")", "INFO_", bShowInGameLog)
                else
                    logToFile("Crafting request failed for " .. item.item_displayName .. " (as " .. itemToRequest .. "). craftSpec: " .. tableToString(craftSpec) .. " Err: " ..tostring(craftInitiateResult), "WARN_", true)
                    if item.provided == 0 then item.displayColor = colors.red else item.displayColor = colors.yellow end
                end
            end
        elseif item.provided < item.count and not item.isCraftable then 
             item.displayColor = colors.red 
             if item.equipment then logToFile("  Cannot craft "..item.item_displayName.." (target ID: "..itemToRequest.."): AE system reports not craftable.", "INFO_", bShowInGameLog) end
        elseif item.provided < item.count and item.isCraftable and not canCraftThisItemBasedOnRules then 
             if item.equipment then logToFile("  Skipping crafting for equipment (script rules prevent crafting this tier): " .. item.item_displayName .. " (requested as " .. item.level .. ", evaluated to not craft " .. itemToRequest .. ")", "INFO_", bShowInGameLog) end
             if item.provided == 0 then item.displayColor = colors.yellow else item.displayColor = colors.yellow end
        end
        ::continue_request_loop::
    end
end
 
----------------------------------------------------------------------------
--* MAIN LOGIC FUNCTIONS
----------------------------------------------------------------------------
 
function updatePeripheralAll(isStartup)
    local allOk = true
    if not updatePeripheralMonitor() then allOk = false end
    if allOk and not checkMonitorSize() then allOk = false end 
    if not updatePeripheralColonyIntegrator() then allOk = false end
    if allOk and colony and not colony.isInColony() then allOk = false end 
    if not updatePeripheralStorageBridge() then allOk = false end
    if not updatePeripheralStorage() then allOk = false end
    
    needTermDrawRequirements = not allOk 
 
    while needTermDrawRequirements do
        logToFile("Peripheral check loop: Some requirements not met. Re-checking...", "INFO_") 
        if not termDrawCheckRequirements(isStartup and isInitialBoot) then 
            sleep(1) 
        else
            needTermDrawRequirements = false 
        end
    end
    isInitialBoot = false 
end
 
function requestAndFulfill()
    local armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list = colonyCategorizeRequests()
    
    storageSystemHandleRequests(armor_list, "Armor")
    storageSystemHandleRequests(tools_list, "Tools")
    storageSystemHandleRequests(other_equipment_list, "OtherEquipment")
    storageSystemHandleRequests(builder_list_standard, "StandardBuilder") 
    storageSystemHandleRequests(builder_list_domum, "DomumBuilder")    
    storageSystemHandleRequests(others_list, "OtherColony")
    
    return armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list
end
 
function monitorShowDashboard(armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list)
    if not monitor then return end
    monitor.clear()
    monitorDashboardRequests(armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list)
    monitorDashboardName() 
end
 
----------------------------------------------------------------------------
--* MAIN
----------------------------------------------------------------------------
 
function main()
    logToFile("Script starting... Version: " .. VERSION, "INFO_") 
    termWidth, termHeight = term.getSize()
    logToFile("Terminal loading animation starting...", "INFO_") 
    termLoadingAnimation() 
    logToFile("Terminal loading animation finished.", "INFO_") 

    logToFile("Initial peripheral check starting...", "INFO_") 
    updatePeripheralAll(true) 
    logToFile("Initial peripheral check finished.", "INFO_") 

    logToFile("Monitor loading animation starting...", "INFO_") 
    monitorLoadingAnimation() 
    logToFile("Monitor loading animation finished.", "INFO_") 
 
    logToFile("Entering main loop...", "INFO_") 
    while true do
        -- updatePeripheralAll(false) -- REMOVED from main loop for performance
        if bShowInGameLog then termShowLog() end
        
        local armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list = requestAndFulfill() 
        monitorShowDashboard(armor_list, tools_list, other_equipment_list, builder_list_standard, builder_list_domum, others_list) 
        
        sleep(0.5) 
    end
end
 
main()

