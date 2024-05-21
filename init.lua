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
local lib_theme_loaded, lib_theme = pcall(require, "Theme Editor.theme")

-- options
local optionsLoaded, options = pcall(require, "Bank Connector.options")
local optionsFileName = "addons/Bank Connector/options.lua"
local firstPresent = true
local ConfigurationWindow

if optionsLoaded then
	options.configurationEnableWindow = options.configurationEnableWindow == nil and true or options.configurationEnableWindow
	options.enable = options.enable == nil and true or options.enable
	options.EnableWindow = options.EnableWindow == nil and true or options.EnableWindow
	options.useCustomTheme = options.useCustomTheme == nil and false or options.useCustomTheme
	options.NoTitleBar = options.NoTitleBar or ""
	options.NoResize = options.NoResize or ""
	options.Transparent = options.Transparent == nil and false or options.Transparent
	options.fontScale = options.fontScale or 1.0
	options.X = options.X or 100
	options.Y = options.Y or 100
	options.Width = options.Width or 150
	options.Height = options.Height or 80
	options.Changed = options.Changed or false
	options.HighContrast = options.HighContrast == nil and false or options.HighContrast
	options.updateThrottle = lib_helpers.NotNilOrDefault(options.updateThrottle, 0)
else
	options = {
		configurationEnableWindow = true,
		enable = true,
		EnableWindow = true,
		useCustomTheme = false,
		NoTitleBar = "",
		NoResize = "",
		Transparent = false,
		fontScale = 1.0,
		X = 100,
		Y = 100,
		Width = 150,
		Height = 80,
		Changed = false,
		HighContrast = false,
		updateThrottle = 0
	}
end

local current_time = 0
local update_delay = (options.updateThrottle * 1000)
local last_inventory_index = -1
local last_inventory_time = 0
local last_bank_time = 0
local cache_inventory = nil
local cache_bank = nil

local bankFileExists = false
local inventoryFileExists = false

local _PlayerArray = 0x00A94254
local _PlayerIndex = 0x00A9C4F4
local _SideMessage = pso.base_address + 0x006AECC8

local function SaveOptions(options)
	local file = io.open(optionsFileName, "w")
	if file ~= nil then
		io.output(file)

		io.write("return {\n")
		io.write(string.format("  configurationEnableWindow = %s,\n", tostring(options.configurationEnableWindow)))
		io.write(string.format("  enable = %s,\n", tostring(options.enable)))
		io.write("\n")
		io.write(string.format("  EnableWindow = %s,\n", tostring(options.EnableWindow)))
		io.write(string.format("  useCustomTheme = %s,\n", tostring(options.useCustomTheme)))
		io.write(string.format("  NoTitleBar = \"%s\",\n", options.NoTitleBar))
		io.write(string.format("  NoResize = \"%s\",\n", options.NoResize))
		io.write(string.format("  Transparent = %s,\n", tostring(options.Transparent)))
		io.write(string.format("  fontScale = %s,\n", tostring(options.fontScale)))
		io.write(string.format("  X = %s,\n", tostring(options.X)))
		io.write(string.format("  Y = %s,\n", tostring(options.Y)))
		io.write(string.format("  Width = %s,\n", tostring(options.Width)))
		io.write(string.format("  Height = %s,\n", tostring(options.Height)))
		io.write(string.format("  Changed = %s,\n", tostring(options.Changed)))
		io.write(string.format("  HighContrast = %s,\n", tostring(options.HighContrast)))
		io.write("}\n")

		io.close(file)
	end
end

local function getSideMessage()
    local ptr = pso.read_u32(_SideMessage)
    if ptr ~= 0 then
        local text = pso.read_wstr(ptr + 0x14, 0xFF)
        return text
    end
    return ""
end

local function parseSideMessage(text)
    if text:find("Bank: Character") then
        bankState = "Character"
    end
    if text:find("Bank: Shared") then
        bankState = "Shared"
    end
    return
end

local function SaveCharData(player, bank)
    local char_info = player.name.."/"..player.slot
    local CharSaveFileName = "addons/Bank Connector/data/".. char_info ..".txt"
    local file = io.open(CharSaveFileName, "w+")

    io.output(file)
    io.write("char data")
    io.close(file)
end

local function SaveSharedBank(bank)
    local SharedBankFileName = "addons/Bank Connector/data/shared_bank.txt"
    local file = io.open(SharedBankFileName, "w+")

    io.output(file)
    io.write("shared bank data")
    io.close(file)
end


local function ConnectInventory(save, index)
    index = index or lib_items.Me
    if last_inventory_time + update_delay < current_time or last_inventory_index ~= index or cache_inventory == nil then
        cache_inventory = lib_items.GetInventory(index)
        last_inventory_index = index
        last_inventory_time = current_time
    end

    local itemCount = table.getn(cache_inventory.items)
    if not inventoryFileExists then
        for i=1,itemCount,1 do
            items.ProcessItem(cache_inventory.items[i], false, true, "Inventory")
        end
        inventoryFileExists = true
    end
end

-- need to call process item here and pass in save to write to file
local function ConnectBank(save)
    if last_bank_time + update_delay < current_time or cache_bank == nil then
        cache_bank = lib_items.GetBank()
        last_bank_time = current_time
    end

    local itemCount = table.getn(cache_bank.items)
    if not bankFileExists then
        for i=1,itemCount,1 do
            -- if cache_bank.items[i].tool and cache_bank.items[i].tool.count ~= nil then
            --     print(cache_bank.items[i].name.." "..cache_bank.items[i].tool.count)
            -- else
            --     print(cache_bank.items[i].name)
            -- end

            items.ProcessItem(cache_bank.items[i], false, true, "Bank")
        end
        bankFileExists = true
    end
end

function ConnectAddon()
	local playerIndex = pso.read_u32(_PlayerIndex)
	local playerAddr = pso.read_u32(_PlayerArray + 4 * playerIndex)
    local save = false
    
	if playerAddr ~= 0 then
        parseSideMessage(getSideMessage())
        ConnectInventory(save, lib_items.Me)
        ConnectBank(save)
	else
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
	end

	if lib_theme_loaded and options.useCustomTheme then
		lib_theme.Push()
	end

	if options.Transparent == true then
		imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
	end

	if options.EnableWindow then
		if firstPresent or options.Changed then
			options.Changed = false

			imgui.SetNextWindowPos(options.X, options.Y, "Always")
			imgui.SetNextWindowSize(options.Width, options.Height, "Always");
		end

		if imgui.Begin("Bank Connector Viewer", nil, { options.NoTitleBar, options.NoResize }) then
			imgui.SetWindowFontScale(options.fontScale)
			ConnectAddon()
		end
		imgui.End()
	end

	if options.Transparent == true then
		imgui.PopStyleColor()
	end

	if lib_theme_loaded and options.useCustomTheme then
		lib_theme.Pop()
	end

	if firstPresent then
		firstPresent = false
	end
end

local function init()
	ConfigurationWindow = cfg.ConfigurationWindow(options, lib_theme_loaded)

	local function mainMenuButtonHandler()
		ConfigurationWindow.open = not ConfigurationWindow.open
	end

	core_mainmenu.add_button("Bank Connector", mainMenuButtonHandler)

	if lib_theme_loaded == false then
		print("Bank Connector : lib_theme couldn't be loaded")
	end

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