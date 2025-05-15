-- Script to refresh CC_Main.lua from GitHub

local url = "https://raw.githubusercontent.com/VentedSun/CCxAE2Xcolonies/refs/heads/main/CC_Main.lua"
local fileName = "CC_Main.lua"

-- Check if the HTTP API is enabled
if not http then
    printError("HTTP API is not enabled.")
    printError("Please enable it in the ComputerCraft config (http_enable=true).")
    return
end

print("Attempting to download the latest version of " .. fileName .. "...")

-- Use shell.run to execute the wget program
-- This will overwrite the existing file with the new one
local success = shell.run("wget", url, fileName)

if success then
    print(fileName .. " has been updated successfully!")
else
    printError("Failed to download " .. fileName .. ".")
    printError("Check the URL and your internet connection.")
    printError("Ensure http_enable is true in the ComputerCraft config.")
end
