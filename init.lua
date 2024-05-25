-- imports
local core_mainmenu = require("core_mainmenu")
local lib_helpers = require("solylib.helpers")
local lib_items = require("solylib.items.items")
local lib_characters = require("solylib.characters")
local items = require("Bank Connector.items")
local cfg = require("Bank Connector.configuration")

-- options
local optionsLoaded, options = pcall(require, "Bank Connector.options")
local optionsFileName = "addons/Bank Connector/options.lua"
local firstPresent = true
local ConfigurationWindow

if optionsLoaded then
    options.configurationEnableWindow = options.configurationEnableWindow == nil and true or options.configurationEnableWindow
    options.enable = options.enable == nil and true or options.enable
    options.Changed = options.Changed or false
    options.updateThrottle = lib_helpers.NotNilOrDefault(options.updateThrottle, 0)
else
    options = {
        configurationEnableWindow = true,
        enable = true,
        Changed = false,
        updateThrottle = 0
    }
end

local lobby = 15
local current_time = 0
local update_delay = (options.updateThrottle * 1000)
local last_inventory_index = -1
local last_inventory_time = 0
local last_bank_time = 0
local cache_inventory = nil
local cachedInventoryStr = ""
local cache_bank = nil
local cachedBankStr = ""
local saved_inventory_file = nil
local saved_bank_file = nil

local bankFilePath = "addons/Bank Connector/bank/saved_bank.txt"
local inventoryFilePath = "addons/Bank Connector/inventory/saved_inventory.txt"

local _PlayerArray = 0x00A94254
local _PlayerIndex = 0x00A9C4F4

local function Save(cache_str, file_path, callback)
    local file = io.open(file_path, "w+")
    if file ~= nil then
        io.output(file)
        io.write(cache_str)
        io.close(file)
        callback()
    end
end

local function SaveOptions(options)
    local file = io.open(optionsFileName, "w")
    if file ~= nil then
        io.output(file)

        io.write("return {\n")
        io.write(string.format("  configurationEnableWindow = %s,\n", tostring(options.configurationEnableWindow)))
        io.write(string.format("  enable = %s,\n", tostring(options.enable)))
        io.write(string.format("  Changed = %s,\n", tostring(options.Changed)))
        io.write(string.format("  updateThrottle = %s,\n", tostring(options.updateThrottle)))
        io.write("}\n")

        io.close(file)
    end
end

local function ReadFile(file_path)    
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Could not open file"
    end
    
    local content = file:read("*all")
    file:close()
    return content
end

local function GetCharacterData(playerAddr, type)
    local character = {
        name = lib_characters.GetPlayerName(playerAddr),
        class = lib_characters.GetPlayerClass(playerAddr),
        section_id = lib_characters.GetPlayerSectionID(playerAddr),
        level = lib_characters.GetPlayerLevel(playerAddr)
    }
    local str = "[CHARACTER] \n"
    local orderedKeys = {"name", "class", "section_id", "level"}
    for _, key in ipairs(orderedKeys) do
        str = str .. key .. ": " .. tostring(character[key]) .. "\n"
    end
    str = str .. "\n"
    str = str .. "[" .. type .. "] \n"
    return str
end

local function ParseCacheTable(cache)
    local str = ""
    local itemCount = table.getn(cache.items)
    for i=1,itemCount,1 do
        str = str .. items.ProcessItem(cache.items[i], false) .. "\n"
    end
    str = str .. "Meseta: " .. cache.meseta .. "\n"
    return str
end

local function ConnectInventory(index, playerData)
    index = index or lib_items.Me
    
    if current_time > last_bank_time + update_delay or last_inventory_index ~= index or cache_inventory == nil then
        cache_inventory = lib_items.GetInventory(index)
        last_inventory_index = index
        last_inventory_time = current_time
    end

    if not saved_inventory_file then
        saved_inventory_file, err = ReadFile(inventoryFilePath)
        if err then
            print("Error: ", err)
            print("No File Exists. Writing an inventory file")
            cachedInventoryStr = playerData .. ParseCacheTable(cache_inventory)
            Save(cachedInventoryStr, inventoryFilePath, function()
                saved_inventory_file = ReadFile(inventoryFilePath)
            end)
        end
    else
        cachedInventoryStr = playerData .. ParseCacheTable(cache_inventory)
        if cachedInventoryStr ~= saved_inventory_file then
            Save(cachedInventoryStr, inventoryFilePath, function()
                saved_inventory_file, err = ReadFile(inventoryFilePath)
            end)
        end
    end
end

local function ConnectBank(playerData)
    if current_time > last_bank_time + update_delay or cache_bank == nil then
        cache_bank = lib_items.GetBank()
        last_bank_time = current_time
    end

    if not saved_bank_file then
        saved_bank_file, err = ReadFile(bankFilePath)
        if err then
            print("Error: ", err)
            print("No File Exists. Writing a bank file")
            cachedBankStr = playerData .. ParseCacheTable(cache_bank)
            Save(cachedBankStr, bankFilePath, function()
                saved_bank_file, err = ReadFile(bankFilePath)
            end)
        end
    else
        cachedBankStr = playerData .. ParseCacheTable(cache_bank)
        if cachedBankStr ~= saved_bank_file then
            Save(cachedBankStr, bankFilePath, function()
                saved_bank_file, err = ReadFile(bankFilePath)
            end)
        end
    end
end

function ConnectAddon()
    local playerIndex = pso.read_u32(_PlayerIndex)
    local playerAddr = pso.read_u32(_PlayerArray + 4 * playerIndex)
    
    if playerAddr ~= 0 and lib_characters.GetCurrentFloorSelf() ~= lobby then
        ConnectInventory(lib_items.Me, GetCharacterData(playerAddr, "INVENTORY"))
        ConnectBank(GetCharacterData(playerAddr, "BANK"))
    end
end

-- config setup and drawing
local function present()
	if options.configurationEnableWindow then
		ConfigurationWindow.open = true
		options.configurationEnableWindow = false
	end

	ConfigurationWindow.Update()
	if ConfigurationWindow.changed then
		ConfigurationWindow.changed = false
		SaveOptions(options)
	end

	--- Update timer for update throttle
	current_time = pso.get_tick_count()

	if options.enable == false then
		return
    else
        ConnectAddon()
	end

	if firstPresent then
		firstPresent = false
	end
end

local function init()
	ConfigurationWindow = cfg.ConfigurationWindow(options, false)

	local function mainMenuButtonHandler()
		ConfigurationWindow.open = not ConfigurationWindow.open
	end

	core_mainmenu.add_button("Bank Connector", mainMenuButtonHandler)

	return {
		name = "Bank Connector",
		version = "1.0.0",
		author = "Machine Herald",
		description = "Updates your banking info.",
		present = present
	}
end

return {
	__addon = {
		init = init
	}
}