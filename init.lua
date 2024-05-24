-- imports
local core_mainmenu = require("core_mainmenu")
local lib_helpers = require("solylib.helpers")
local lib_menu = require("solylib.menu")
local lib_items = require("solylib.items.items")
local lib_characters = require("solylib.characters")
local lib_items_list = require("solylib.items.items_list")
local lib_items_cfg = require("solylib.items.items_configuration")
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
local cache_bank = nil
local saved_inventory_file = nil
local saved_bank_file = nil

local bankFilePath = "addons/Bank Connector/bank/saved_bank.txt"
local inventoryFilePath = "addons/Bank Connector/inventory/saved_inventory.txt"

local _PlayerArray = 0x00A94254
local _PlayerIndex = 0x00A9C4F4

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

function ReadFileToTable(file_path)
    local table = {}
    
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Could not open file"
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Split the content by newline characters
    for line in string.gmatch(content, "[^\r\n]+") do
        table[#table + 1] = { line = line }
    end
    
    return table
end

local function ConnectInventory(save, index)
    index = index or lib_items.Me
    if current_time > last_bank_time + update_delay or last_inventory_index ~= index or cache_inventory == nil then
        cache_inventory = lib_items.GetInventory(index)
        last_inventory_index = index
        last_inventory_time = current_time
    end

    if not saved_inventory_file then
        saved_inventory_file, err = ReadFileToTable(inventoryFilePath)
        if err then
            print("Error: ", err)
            print("No File Exists. Writing an inventory file")
            local itemCount = table.getn(cache_inventory.items)
            for i=1,itemCount,1 do
                items.ProcessItem(cache_inventory.items[i], false, true, "Inventory")
            end

            local item = {}
            item.data = {0}
            item.data[1] = 4
            item.meseta = cache_inventory.meseta

            items.ProcessItem(item, false, true, "Inventory")
        end
    else
        local savedInventoryStr = ""
        local cachedInventoryStr = ""

        for _, row in ipairs(saved_inventory_file) do
            savedInventoryStr = savedInventoryStr..row.line.."\n"
        end

        local itemCount = table.getn(cache_inventory.items)
        for i=1,itemCount,1 do
            cachedInventoryStr = cachedInventoryStr..items.ProcessItem(cache_inventory.items[i], false, false, "Inventory").."\n"
        end
        cachedInventoryStr =  cachedInventoryStr.. "Meseta: "..cache_inventory.meseta.."\n"
        if cachedInventoryStr ~= savedInventoryStr then
            print("updating inventory file")
            local file = io.open("addons/Bank Connector/inventory/saved_inventory.txt", "w+")
            io.output(file)
            io.write(cachedInventoryStr)
            io.close(file)
            saved_inventory_file, err = ReadFileToTable(inventoryFilePath)
        end
    end
end

local function ConnectBank(save)
    if  current_time > last_bank_time + update_delay or cache_bank == nil then
        cache_bank = lib_items.GetBank()
        last_bank_time = current_time
    end

    if not saved_bank_file then
        saved_bank_file, err = ReadFileToTable(bankFilePath)
        if err then
            print("Error: ", err)
            print("No File Exists. Writing a bank file")
            local itemCount = table.getn(cache_bank.items)
            for i=1,itemCount,1 do
                items.ProcessItem(cache_bank.items[i], false, true, "Bank")
            end

            local item = {}
            item.data = {0}
            item.data[1] = 4
            item.meseta = cache_bank.meseta

            items.ProcessItem(item, false, true, "Bank")
        end
    else
        local savedBankStr = ""
        local cachedBankStr = ""

        for _, row in ipairs(saved_bank_file) do
            savedBankStr = savedBankStr..row.line.."\n"
        end

        local itemCount = table.getn(cache_bank.items)
        for i=1,itemCount,1 do
            cachedBankStr = cachedBankStr..items.ProcessItem(cache_bank.items[i], false, false, "Bank").."\n"
        end
        cachedBankStr =  cachedBankStr.. "Meseta: "..cache_bank.meseta.."\n"
        if cachedBankStr ~= savedBankStr then
            print("updating bank file")
            local file = io.open("addons/Bank Connector/bank/saved_bank.txt", "w+")
            io.output(file)
            io.write(cachedBankStr)
            io.close(file)
            saved_bank_file, err = ReadFileToTable(bankFilePath)
        end
    end
end

function ConnectAddon()
    local playerIndex = pso.read_u32(_PlayerIndex)
    local playerAddr = pso.read_u32(_PlayerArray + 4 * playerIndex)
    local save = false

    if playerAddr ~= 0 and lib_characters.GetCurrentFloorSelf() ~= lobby then
        ConnectInventory(save, lib_items.Me)
        ConnectBank(save)
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