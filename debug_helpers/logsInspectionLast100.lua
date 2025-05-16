--[[
    In-Game Log Viewer Script for CC: Tweaked (ComputerCraft)
 
    This script displays log files on an attached monitor with scroll buttons.
    It automatically detects an attached monitor and loads the latest .log file
    from a specified directory, showing only the last N lines.
 
    Instructions:
    1. Save this script to your in-game computer (e.g., as "logview.lua").
    2. Attach a monitor to your computer.
    3. Edit the `logDirectory` variable below to point to the folder containing your log files.
    4. Run the script: `logview`
--]]
 
-- ----------------------------
--      CONFIGURATION
-- ----------------------------
local logDirectory = "CCxM_logs/" -- TODO: Change this to your log directory path!
local logFilePattern = "latest.txt" -- Files ending with this will be considered log files.
local MAX_LINES_FROM_FILE = 100    -- MODIFIED: Only process and display the last 100 lines from the file.
 
local linesToDisplayOnScreen = 0 -- How many lines fit on the monitor page
local currentScrollOffset = 0    -- How many lines we've scrolled down within the MAX_LINES_FROM_FILE
local logLines = {}              -- Table to store the last MAX_LINES_FROM_FILE from the log file
local actualLogFilePath = nil    -- Will be set to the path of the loaded log file
 
local monitor = nil           -- Monitor peripheral object
local monWidth, monHeight = 0, 0
local detectedMonitorSide = nil -- Stores the side of the detected monitor
 
-- Button appearance and layout
local buttonWidth = 12
local buttonHeight = 3
local buttonTextColor = colors.white
local buttonBgColor = colors.blue
local buttonActiveBgColor = colors.lightBlue 
 
local scrollUpButton = { text = "  Up  " } 
local scrollDownButton = { text = " Down " }
 
-- ----------------------------
--      HELPER FUNCTIONS
-- ----------------------------
 
local function logErrorToTerminal(message) -- Renamed to avoid conflict if this script is part of a larger system
    print("ERROR: " .. tostring(message))
end

local function logInfoToTerminal(message)
    print("INFO: " .. tostring(message))
end
 
--- Attempts to find and wrap the first available monitor peripheral.
local function findMonitor()
    local sides = peripheral.getNames()
    for i = 1, #sides do
        local side = sides[i]
        if peripheral.isPresent(side) and peripheral.getType(side) == "monitor" then
            monitor = peripheral.wrap(side)
            if monitor then
                monWidth, monHeight = monitor.getSize()
                detectedMonitorSide = side
                logInfoToTerminal("Monitor found on side: " .. detectedMonitorSide)
                return true
            end
        end
    end
    logErrorToTerminal("No monitor found attached to the computer.")
    return false
end
 
--- Finds the latest file matching a pattern in a given directory.
local function findLatestLogFile(dirPath, pattern)
    if not fs.isDir(dirPath) then
        logErrorToTerminal("Log directory not found or is not a directory: " .. dirPath)
        return nil
    end
 
    local files = fs.list(dirPath)
    local latestFile = nil
    local latestTimestamp = 0
 
    for i = 1, #files do
        local fileName = files[i]
        local filePath = fs.combine(dirPath, fileName)
 
        if not fs.isDir(filePath) and string.sub(fileName, -string.len(pattern)) == pattern then
            local attributes = fs.attributes(filePath)
            if attributes and attributes.modification then
                if attributes.modification > latestTimestamp then
                    latestTimestamp = attributes.modification
                    latestFile = filePath
                end
            else
                logInfoToTerminal("Warning: Could not get attributes for: " .. filePath)
            end
        end
    end
 
    if latestFile then
        logInfoToTerminal("Latest log file found: " .. latestFile)
    else
        logErrorToTerminal("No log files matching pattern '" .. pattern .. "' found in directory: " .. dirPath)
    end
    return latestFile
end
 
--- Clears the monitor screen.
local function clearScreen()
    if monitor then
        monitor.setBackgroundColor(colors.black) 
        monitor.setTextColor(colors.white)
        monitor.setTextScale(0.5) -- Ensure text scale is set
        monitor.clear()
        monitor.setCursorPos(1, 1)
    end
end
 
--- Writes text at a specific position on the monitor with specified colors.
local function writeAt(x, y, text, textColor, bgColor)
    if not monitor then return end
    monitor.setCursorPos(x, y)
    if textColor then monitor.setTextColor(textColor) end
    if bgColor then monitor.setBackgroundColor(bgColor) end
    monitor.write(text)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
end
 
--- Draws a single button.
local function drawButton(x, y, width, height, label, isHovering)
    if not monitor then return end
 
    local currentBg = isHovering and buttonActiveBgColor or buttonBgColor
    local currentText = buttonTextColor
 
    monitor.setBackgroundColor(currentBg)
    for i = 0, height - 1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", width))
    end
 
    local labelX = x + math.floor((width - #label) / 2)
    local labelY = y + math.floor((height - 1) / 2)
    writeAt(labelX, labelY, label, currentText, currentBg)
end

-- ADDED: Function to get the last N lines from a table of lines
local function getLastNLines(allLinesTable, numLines)
    if not allLinesTable then return {} end
    local totalLinesInTable = #allLinesTable
    if totalLinesInTable <= numLines then
        return allLinesTable 
    else
        local startIdx = totalLinesInTable - numLines + 1
        local selectedLines = {}
        for i = startIdx, totalLinesInTable do
            table.insert(selectedLines, allLinesTable[i])
        end
        return selectedLines
    end
end
 
--- Loads the specified log file into the logLines table (last MAX_LINES_FROM_FILE).
local function loadLogFile(filePath)
    logLines = {} 
    currentScrollOffset = 0
    actualLogFilePath = filePath 
 
    if not fs.exists(filePath) then
        if monitor then
            writeAt(1, 1, "Error: Log file not found:", colors.red)
            writeAt(1, 2, filePath, colors.yellow)
        else
            logErrorToTerminal("Log file not found at: " .. filePath)
        end
        return false
    end
 
    local file, err = fs.open(filePath, "r")
    if not file then
        if monitor then
            writeAt(1, 1, "Error opening log file:", colors.red)
            writeAt(1, 2, err or "unknown error", colors.yellow)
            writeAt(1, 3, "Path: " .. filePath, colors.yellow)
        else
            logErrorToTerminal("Error opening log file '" .. filePath .. "': " .. (err or "unknown error"))
        end
        return false
    end
 
    local allFileLines = {} -- Temporary table to hold all lines from file
    local line = file.readLine()
    while line do
        table.insert(allFileLines, line)
        line = file.readLine()
    end
    file.close()

    logInfoToTerminal("Total lines read from file: " .. #allFileLines)
    logLines = getLastNLines(allFileLines, MAX_LINES_FROM_FILE) -- MODIFIED: Get only last N lines
    logInfoToTerminal("Storing last " .. #logLines .. " lines for display.")
    
    return true
end
 
-- ----------------------------
--      UI DRAWING FUNCTIONS
-- ----------------------------
 
local function setupButtonLayout()
    scrollUpButton.x = monWidth - buttonWidth
    scrollUpButton.y = 1
    scrollUpButton.width = buttonWidth
    scrollUpButton.height = buttonHeight
 
    scrollDownButton.x = monWidth - buttonWidth
    scrollDownButton.y = scrollUpButton.y + buttonHeight + 1 
    scrollDownButton.width = buttonWidth
    scrollDownButton.height = buttonHeight
 
    -- Calculate how many lines can be displayed on screen
    local headerSpace = 1 -- For title/status line
    local availableHeightForLogs = monHeight - headerSpace
    linesToDisplayOnScreen = math.max(1, availableHeightForLogs)
end
 
 
local function drawUI(mouseX, mouseY)
    if not monitor then return end
    clearScreen()
 
    local title = "Log Viewer"
    if actualLogFilePath then
        local fileNameOnly = fs.getName(actualLogFilePath)
        title = "Log: " .. fileNameOnly .. " (Last " .. MAX_LINES_FROM_FILE .. ")"
        if #title > monWidth - buttonWidth - 3 then
             title = string.sub(title, 1, monWidth - buttonWidth - 6) .. "..."
        end
    end
    writeAt(1,1, title, colors.cyan)
 
    local logDisplayWidth = monWidth - buttonWidth - 2 
    local logDisplayStartY = 2 -- Start log display on line 2 (after title)
 
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)

    if #logLines == 0 then
        writeAt(1, logDisplayStartY, "No log lines to display or file empty.", colors.yellow)
    else
        for i = 0, linesToDisplayOnScreen - 1 do 
            local lineIndexInFilteredList = currentScrollOffset + i + 1
            local displayY = logDisplayStartY + i
 
            if displayY > monHeight then break end 
 
            if lineIndexInFilteredList <= #logLines then
                local line = logLines[lineIndexInFilteredList]
                local displayLine = string.sub(line, 1, logDisplayWidth)
                monitor.setCursorPos(1, displayY)
                monitor.write(displayLine)
            else
                -- No more lines to display in the current view, clear the rest of the page
                monitor.setCursorPos(1, displayY)
                monitor.write(string.rep(" ", logDisplayWidth)) 
            end
        end
    end
 
    local upHover = mouseX and mouseY and
                    mouseX >= scrollUpButton.x and mouseX < scrollUpButton.x + scrollUpButton.width and
                    mouseY >= scrollUpButton.y and mouseY < scrollUpButton.y + scrollUpButton.height
    drawButton(scrollUpButton.x, scrollUpButton.y, scrollUpButton.width, scrollUpButton.height, scrollUpButton.text, upHover)
 
    local downHover = mouseX and mouseY and
                      mouseX >= scrollDownButton.x and mouseX < scrollDownButton.x + scrollDownButton.width and
                      mouseY >= scrollDownButton.y and mouseY < scrollDownButton.y + scrollDownButton.height
    drawButton(scrollDownButton.x, scrollDownButton.y, scrollDownButton.width, scrollDownButton.height, scrollDownButton.text, downHover)
 
    monitor.setCursorPos(monWidth, monHeight) 
end
 
-- ----------------------------
--      EVENT HANDLING
-- ----------------------------
 
local function scrollUp()
    if currentScrollOffset > 0 then
        currentScrollOffset = currentScrollOffset - 1
        drawUI()
    end
end
 
local function scrollDown()
    -- Calculate max possible scroll offset based on the filtered logLines and screen height
    local maxVisibleOnScreen = linesToDisplayOnScreen
    if #logLines > maxVisibleOnScreen then
        if currentScrollOffset < (#logLines - maxVisibleOnScreen) then
            currentScrollOffset = currentScrollOffset + 1
            drawUI()
        end
    end
end
 
local function isClickOnButton(clickX, clickY, buttonDef)
    return  clickX >= buttonDef.x and clickX < (buttonDef.x + buttonDef.width) and
            clickY >= buttonDef.y and clickY < (buttonDef.y + buttonDef.height)
end
 
-- ----------------------------
--      INITIALIZATION & MAIN LOOP
-- ----------------------------
local function main()
    if not findMonitor() then
        term.setTextColor(colors.red)
        logErrorToTerminal("Log viewer requires a monitor. Exiting.")
        term.setTextColor(colors.white)
        return
    end
 
    term.clear() 
    term.setCursorPos(1,1)
    logInfoToTerminal("Log Viewer running. Output is on monitor: " .. detectedMonitorSide)
    logInfoToTerminal("Press Ctrl+T to terminate.")
 
    local targetLogFile = findLatestLogFile(logDirectory, logFilePattern)
 
    if not targetLogFile then
        if monitor then
            clearScreen()
            writeAt(1, 1, "No log files found in:", colors.orange)
            writeAt(1, 2, logDirectory .. " (pattern: *" .. logFilePattern .. ")", colors.yellow)
            writeAt(1, monHeight, "Press any key to exit.", colors.yellow)
            os.pullEvent("key")
        else
            logErrorToTerminal("No log files found. Exiting.")
        end
        return
    end
 
    if not loadLogFile(targetLogFile) then
        if monitor then
            writeAt(1, monHeight, "Press any key to exit.", colors.yellow)
            os.pullEvent("key")
        end
        return
    end
    
    setupButtonLayout() 
    
    drawUI() 
 
    local running = true
    local mouseX, mouseY 
    while running do
        local eventData = {os.pullEvent()}
        local event = eventData[1]
 
        if event == "terminate" then
            running = false
            break
        end

        if event == "key" then
            -- Example: PageUp/PageDown for faster scrolling
            if eventData[2] == keys.pageUp then
                for _ = 1, math.max(1, linesToDisplayOnScreen -1) do scrollUp() end
            elseif eventData[2] == keys.pageDown then
                 for _ = 1, math.max(1, linesToDisplayOnScreen -1) do scrollDown() end
            end
        elseif event == "monitor_touch" or event == "mouse_click" then
            local clickX, clickY
            local eventMonitorSide = eventData[2] -- For monitor_touch, p1 is side
 
            if event == "monitor_touch" then
                if eventMonitorSide == detectedMonitorSide then 
                    clickX, clickY = eventData[3], eventData[4] -- p2, p3 are x,y for monitor_touch
                end
            else -- mouse_click (p1 is button, p2 is x, p3 is y)
                clickX, clickY = eventData[3], eventData[4]
            end
 
            if clickX and clickY then
                if isClickOnButton(clickX, clickY, scrollUpButton) then
                    scrollUp()
                elseif isClickOnButton(clickX, clickY, scrollDownButton) then
                    scrollDown()
                end
            end
        elseif event == "mouse_scroll" then
            local direction = eventData[2] -- p1 is direction for mouse_scroll
            if direction < 0 then 
                for _ = 1, 2 do scrollUp() end 
            elseif direction > 0 then 
                for _ = 1, 2 do scrollDown() end
            end
        elseif event == "mouse_move" then
            mouseX, mouseY = eventData[3], eventData[4] -- p2,p3 are x,y for mouse_move
            drawUI(mouseX, mouseY) 
        elseif event == "term_resize" then
            if monitor and monitor.isColor then 
                local newWidth, newHeight = monitor.getSize()
                if newWidth ~= monWidth or newHeight ~= monHeight then
                    monWidth, monHeight = newWidth, newHeight
                    logInfoToTerminal("Monitor dimensions changed. Re-initializing layout.")
                    setupButtonLayout()
                    drawUI(mouseX, mouseY)
                end
            end
        end
    end
end
 
-- Run the main function
main()
 
-- Cleanup when the program exits
if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    monitor.setCursorPos(1,1)
    monitor.write("Log viewer exited.")
    sleep(1)
    monitor.clear()
end
logInfoToTerminal("Log viewer exited.")

