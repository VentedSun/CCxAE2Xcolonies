--[[
    In-Game Log Viewer Script for CC: Tweaked (ComputerCraft)
 
    This script displays log files on an attached monitor with scroll buttons.
    It automatically detects an attached monitor and loads the latest .log file
    from a specified directory.
 
    Instructions:
    1. Save this script to your in-game computer (e.g., as "logview.lua").
    2. Attach a monitor to your computer.
    3. Edit the `logDirectory` variable below to point to the folder containing your log files.
    4. Run the script: `logview`
--]]
 
-- ----------------------------
--      CONFIGURATION
-- ----------------------------
local logDirectory = "CCxM_logs/" -- TODO: Change this to your log directory path! (e.g., "/" for root, "my_app/logs/")
local logFilePattern = "latest.txt" -- Files ending with this will be considered log files.
 
local linesToDisplay = 0
local currentScrollOffset = 0 -- How many lines we've scrolled down from the top of the log
local logLines = {}           -- Table to store all lines from the log file
local actualLogFilePath = nil -- Will be set to the path of the loaded log file
 
local monitor = nil           -- Monitor peripheral object
local monWidth, monHeight = 0, 0
local detectedMonitorSide = nil -- Stores the side of the detected monitor
 
-- Button appearance and layout
local buttonWidth = 12
local buttonHeight = 3
local buttonTextColor = colors.white
local buttonBgColor = colors.blue
local buttonActiveBgColor = colors.lightBlue -- For when mouse hovers (optional)
 
local scrollUpButton = { text = "  Up  " } -- Text padded for centering
local scrollDownButton = { text = " Down " }
 
-- ----------------------------
--      HELPER FUNCTIONS
-- ----------------------------
 
--- Attempts to find and wrap the first available monitor peripheral.
-- @return boolean True if a monitor is found and wrapped, false otherwise.
local function findMonitor()
    local sides = peripheral.getNames()
    for i = 1, #sides do
        local side = sides[i]
        if peripheral.isPresent(side) and peripheral.getType(side) == "monitor" then
            monitor = peripheral.wrap(side)
            if monitor then
                monWidth, monHeight = monitor.getSize()
                detectedMonitorSide = side
                -- term.redirect(monitor) -- Uncomment if you want `print()` to go to the monitor
                print("Monitor found on side: " .. detectedMonitorSide)
                return true
            end
        end
    end
    print("Error: No monitor found attached to the computer.")
    return false
end
 
--- Finds the latest file matching a pattern in a given directory.
-- @param dirPath The path to the directory to search.
-- @param pattern The file extension or pattern to match (e.g., ".log").
-- @return string|nil The path to the latest file, or nil if no matching file is found.
local function findLatestLogFile(dirPath, pattern)
    if not fs.isDir(dirPath) then
        print("Error: Log directory not found or is not a directory: " .. dirPath)
        return nil
    end
 
    local files = fs.list(dirPath)
    local latestFile = nil
    local latestTimestamp = 0
 
    for i = 1, #files do
        local fileName = files[i]
        local filePath = fs.combine(dirPath, fileName)
 
        -- Check if it's a file and matches the pattern (ends with)
        if not fs.isDir(filePath) and string.sub(fileName, -string.len(pattern)) == pattern then
            local attributes = fs.attributes(filePath)
            if attributes and attributes.modification then
                if attributes.modification > latestTimestamp then
                    latestTimestamp = attributes.modification
                    latestFile = filePath
                end
            else
                print("Warning: Could not get attributes for: " .. filePath)
            end
        end
    end
 
    if latestFile then
        print("Latest log file found: " .. latestFile)
    else
        print("No log files matching pattern '" .. pattern .. "' found in directory: " .. dirPath)
    end
    return latestFile
end
 
 
--- Clears the monitor screen.
local function clearScreen()
    if monitor then
        monitor.setBackgroundColor(colors.black) -- Set default background
        monitor.clear()
        monitor.setCursorPos(1, 1)
    end
end
 
--- Writes text at a specific position on the monitor with specified colors.
-- @param x The x-coordinate.
-- @param y The y-coordinate.
-- @param text The text to write.
-- @param textColor (optional) The color for the text.
-- @param bgColor (optional) The color for the background.
local function writeAt(x, y, text, textColor, bgColor)
    if not monitor then return end
    monitor.setCursorPos(x, y)
    if textColor then monitor.setTextColor(textColor) end
    if bgColor then monitor.setBackgroundColor(bgColor) end
    monitor.write(text)
    -- Reset colors to default if they were changed for this write
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
end
 
--- Draws a single button.
-- @param x The x-coordinate of the button's top-left corner.
-- @param y The y-coordinate of the button's top-left corner.
-- @param width The width of the button.
-- @param height The height of the button.
-- @param label The text label for the button.
-- @param isHovering (optional) Boolean, true if mouse is over button.
local function drawButton(x, y, width, height, label, isHovering)
    if not monitor then return end
 
    local currentBg = isHovering and buttonActiveBgColor or buttonBgColor
    local currentText = buttonTextColor
 
    -- Draw button background
    monitor.setBackgroundColor(currentBg)
    for i = 0, height - 1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", width))
    end
 
    -- Draw button label (centered)
    local labelX = x + math.floor((width - #label) / 2)
    local labelY = y + math.floor((height - 1) / 2)
    writeAt(labelX, labelY, label, currentText, currentBg)
end
 
--- Loads the specified log file into the logLines table.
-- @param filePath The path to the log file.
-- @return boolean True if successful, false otherwise.
local function loadLogFile(filePath)
    logLines = {} -- Clear previous log lines
    currentScrollOffset = 0
    actualLogFilePath = filePath -- Store the path of the file being loaded
 
    if not fs.exists(filePath) then
        if monitor then
            writeAt(1, 1, "Error: Log file not found:", colors.red)
            writeAt(1, 2, filePath, colors.yellow)
        else
            print("Error: Log file not found at: " .. filePath)
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
            print("Error opening log file '" .. filePath .. "': " .. (err or "unknown error"))
        end
        return false
    end
 
    local line = file.readLine()
    while line do
        table.insert(logLines, line)
        line = file.readLine()
    end
    file.close()
    return true
end
 
-- ----------------------------
--      UI DRAWING FUNCTIONS
-- ----------------------------
 
--- Sets up button positions based on monitor dimensions.
local function setupButtonLayout()
    -- Scroll Up Button
    scrollUpButton.x = monWidth - buttonWidth
    scrollUpButton.y = 1
    scrollUpButton.width = buttonWidth
    scrollUpButton.height = buttonHeight
 
    -- Scroll Down Button
    scrollDownButton.x = monWidth - buttonWidth
    scrollDownButton.y = scrollUpButton.y + buttonHeight + 1 -- Place below scroll up, with a 1-line gap
    scrollDownButton.width = buttonWidth
    scrollDownButton.height = buttonHeight
 
    -- Adjust linesToDisplay if buttons take up too much vertical space
    if scrollDownButton.y + scrollDownButton.height > monHeight then
        print("Warning: Monitor is very short. Button layout might be cramped.")
        linesToDisplay = math.max(1, scrollUpButton.y - 2)
    else
        linesToDisplay = monHeight
    end
end
 
 
--- Draws the entire UI (log content and buttons).
-- @param mouseX (optional) Current mouse X for hover effects.
-- @param mouseY (optional) Current mouse Y for hover effects.
local function drawUI(mouseX, mouseY)
    if not monitor then return end
    clearScreen()
 
    -- Display the name of the loaded log file
    if actualLogFilePath then
        local fileNameOnly = fs.getName(actualLogFilePath)
        local title = "Log: " .. fileNameOnly
        -- Truncate title if too long
        if #title > monWidth - buttonWidth - 3 then
             title = string.sub(title, 1, monWidth - buttonWidth - 6) .. "..."
        end
        writeAt(1,1, title, colors.cyan)
    end
 
 
    -- Calculate the width available for log lines
    local logDisplayWidth = monWidth - buttonWidth - 2 -- -2 for a small margin from buttons
    local logDisplayStartY = 1 -- Start log display on line 1
    if actualLogFilePath then logDisplayStartY = 2 end -- Start on line 2 if title is shown
 
    -- Display log lines
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
    for i = 0, linesToDisplay - logDisplayStartY do -- Adjust loop for available lines
        local lineIndex = currentScrollOffset + i + 1
        local displayY = logDisplayStartY + i
 
        if displayY > monHeight then break end -- Don't draw past monitor height
 
        if lineIndex <= #logLines then
            local line = logLines[lineIndex]
            local displayLine = string.sub(line, 1, logDisplayWidth)
            monitor.setCursorPos(1, displayY)
            monitor.write(displayLine)
        else
            monitor.setCursorPos(1, displayY)
            monitor.write(string.rep(" ", logDisplayWidth)) -- Clear line
        end
    end
 
    -- Draw Buttons with hover effect
    local upHover = mouseX and mouseY and
                    mouseX >= scrollUpButton.x and mouseX < scrollUpButton.x + scrollUpButton.width and
                    mouseY >= scrollUpButton.y and mouseY < scrollUpButton.y + scrollUpButton.height
    drawButton(scrollUpButton.x, scrollUpButton.y, scrollUpButton.width, scrollUpButton.height, scrollUpButton.text, upHover)
 
    local downHover = mouseX and mouseY and
                      mouseX >= scrollDownButton.x and mouseX < scrollDownButton.x + scrollDownButton.width and
                      mouseY >= scrollDownButton.y and mouseY < scrollDownButton.y + scrollDownButton.height
    drawButton(scrollDownButton.x, scrollDownButton.y, scrollDownButton.width, scrollDownButton.height, scrollDownButton.text, downHover)
 
    monitor.setCursorPos(monWidth, monHeight) -- Move cursor out of the way
end
 
-- ----------------------------
--      EVENT HANDLING
-- ----------------------------
 
--- Handles scroll up action.
local function scrollUp()
    if currentScrollOffset > 0 then
        currentScrollOffset = currentScrollOffset - 1
        drawUI()
    end
end
 
--- Handles scroll down action.
local function scrollDown()
    local maxScroll = #logLines - (linesToDisplay - (actualLogFilePath and 1 or 0))
    if #logLines > 0 and currentScrollOffset < maxScroll then
        currentScrollOffset = currentScrollOffset + 1
        drawUI()
    end
end
 
--- Checks if a click (or touch) event is within a button's bounds.
-- @param clickX The x-coordinate of the click.
-- @param clickY The y-coordinate of the click.
-- @param button The button table (must have .x, .y, .width, .height).
-- @return boolean True if the click is within the button, false otherwise.
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
        print("Log viewer requires a monitor. Exiting.")
        term.setTextColor(colors.white)
        return
    end
 
    term.clear() -- Clear the computer's own terminal
    term.setCursorPos(1,1)
    print("Log Viewer running. Output is on monitor: " .. detectedMonitorSide)
    print("Press Ctrl+T to terminate.")
 
    local targetLogFile = findLatestLogFile(logDirectory, logFilePattern)
 
    if not targetLogFile then
        if monitor then
            clearScreen()
            writeAt(1, 1, "No log files found in:", colors.orange)
            writeAt(1, 2, logDirectory .. " (pattern: *" .. logFilePattern .. ")", colors.yellow)
            writeAt(1, monHeight, "Press any key to exit.", colors.yellow)
            os.pullEvent("key")
        else
            print("No log files found. Exiting.")
        end
        return
    end
 
    if not loadLogFile(targetLogFile) then
        if monitor then
            -- Errors already shown by loadLogFile
            writeAt(1, monHeight, "Press any key to exit.", colors.yellow)
            os.pullEvent("key")
        end
        return
    end
    
    setupButtonLayout() -- Setup button positions after monitor size is known
 
    if #logLines == 0 then
        if monitor then
            writeAt(1, 1, "Log file is empty:", colors.yellow)
            writeAt(1, 2, fs.getName(actualLogFilePath), colors.white)
        end
    end
    
    drawUI() -- Initial draw
 
    -- Main event loop
    local running = true
    local mouseX, mouseY -- Track mouse position for hover
    while running do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
 
        if event == "key" then
            -- You could add key-based scrolling here, e.g., page up/down
            -- if keys.getName(p1) == "pageUp" then scrollUp() scrollUp() end
            -- if keys.getName(p1) == "pageDown" then scrollDown() scrollDown() end
        elseif event == "monitor_touch" or event == "mouse_click" then
            local clickX, clickY
            local eventMonitorSide = p1
 
            if event == "monitor_touch" then
                if eventMonitorSide == detectedMonitorSide then -- Ensure touch is on our monitor
                    clickX, clickY = p2, p3
                end
            else -- mouse_click
                -- For mouse_click, the monitor isn't specified by side in the event,
                -- so we assume it's for the active window/monitor.
                clickX, clickY = p2, p3
            end
 
            if clickX and clickY then
                if isClickOnButton(clickX, clickY, scrollUpButton) then
                    scrollUp()
                elseif isClickOnButton(clickX, clickY, scrollDownButton) then
                    scrollDown()
                end
            end
        elseif event == "mouse_scroll" then
            local direction, scrollX, scrollY = p1, p2, p3
            -- Check if scroll event is over the log area (optional, could scroll anywhere)
            -- if scrollX < scrollUpButton.x then -- Basic check: not over buttons
                if direction < 0 then -- Scroll wheel up
                    for _ = 1, 2 do scrollUp() end -- Scroll a bit faster with wheel
                elseif direction > 0 then -- Scroll wheel down
                    for _ = 1, 2 do scrollDown() end
                end
            -- end
        elseif event == "mouse_move" then
            mouseX, mouseY = p2, p3
            drawUI(mouseX, mouseY) -- Redraw for hover effects
 
        elseif event == "term_resize" then
            -- This event is for the computer's own terminal, not usually the peripheral monitor.
            -- However, if the monitor was somehow tied to term_resize (e.g. advanced setups),
            -- you might need to re-check monitor.getSize().
            -- For standard CC:T monitors, their size is fixed once placed.
            -- If using something like Plethora's Advanced Monitors that can be resized in-world,
            -- you'd need a different event or periodic check.
            if monitor and monitor.isColor then -- Check if monitor object is still valid
                local newWidth, newHeight = monitor.getSize()
                if newWidth ~= monWidth or newHeight ~= monHeight then
                    monWidth, monHeight = newWidth, newHeight
                    print("Monitor dimensions changed. Re-initializing layout.")
                    setupButtonLayout()
                    drawUI(mouseX, mouseY)
                end
            end
        end
        -- Ctrl+T (terminate) is handled by the OS automatically.
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
    -- If term was redirected, set it back
    -- term.redirect(term.native())
end
print("Log viewer exited.")
