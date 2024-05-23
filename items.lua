local lib_helpers = require("solylib.helpers")
local lib_unitxt = require("solylib.unitxt")
local lib_characters = require("solylib.characters")
local lib_items = require("solylib.items.items")
local lib_items_list = require("solylib.items.items_list")
local lib_items_cfg = require("solylib.items.items_configuration")

local bankDirectory        = "addons/Bank Connector/bank/"
local inventoryDirectory   = "addons/Bank Connector/inventory/"
local currentBankFile      = ""
local currentInventoryFile = ""

local function TrimString(text, length)
    -- default to "???" to prevent crashing for techniques when doing Alt+Backspace
    text = text or "???"
    local result = text;
    if length > 0 then
        result = string.sub(text, 0, length)
        local strLength = string.len(text)
        strLength = strLength - 3
        if length < strLength then
            result = result .. "..."
        end
    end
    return result
end

local function writeArmorStats(item, floor)
    local result = ""

    result = result .. "["

    local statColor
    if item.armor.dfp == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. item.armor.dfp
    result = result .. "/"
    if item.armor.dfpMax == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. item.armor.dfpMax
    result = result .. " | "
    if item.armor.evp == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. item.armor.evp
    result = result .. "/"
    if item.armor.evpMax == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. item.armor.evpMax
    result = result .. "] "

    return result
end

local function ProcessWeapon(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.weaponName
    local item_cfg = lib_items_list.t[item.hex]

    if item.equipped then
        result = result .. "["
        result = result .. "E"
        result = result .. "] "
    end

    if item.weapon.wrapped or item.weapon.untekked then
        result = result .. "["
        if item.weapon.wrapped and item.weapon.untekked then
            result = result .. "W|U"
        elseif item.weapon.wrapped then
            result = result .. "W"
        elseif item.weapon.untekked then
            result = result .. "U"
        end
        result = result .. "] "
    end

    if item.weapon.isSRank then
        result = result .. "S-RANK "
        result = result .. item.name
        result = result .. item.weapon.nameSrank

        if item.weapon.grind > 0 then
            result = result .. item.weapon.grind .. " "
        end

        if item.weapon.specialSRank ~= 0 then
            result = result .. "["
            result = result .. lib_unitxt.GetSRankSpecialName(item.weapon.specialSRank)
            result = result .. "] "
        end
    else
        result = result .. TrimString(item.name, 0) .. " "

        if item.weapon.grind > 0 then
            result = result .. "+" .. item.weapon.grind .. " "
        end

        if item.weapon.special ~= 0 then
            result = result .. "["
            result = result .. lib_unitxt.GetSpecialName(item.weapon.special)
            result = result .. "] "
        end

        result = result .. "["
        for i=2,5,1 do
            local stat = item.weapon.stats[i]
            local statColor = lib_items_cfg.grey
            for i2=1,table.getn(lib_items_cfg.weaponAttributes),5 do
                if stat <= lib_items_cfg.weaponAttributes[i2] then
                    statColor = lib_items_cfg.weaponAttributes[i2 + (i-1)]
                end
            end
            if item.weapon.statpresence[i - 1] == 1 and item.weapon.stats[i] == 0 then
                statColor = lib_items_cfg.red
            end

            result = result .. stat

            if i < 5 then
                result = result .. "/"
            else
                result = result .. "|"
            end
        end

        local stat = item.weapon.stats[6]
        local statColor = lib_items_cfg.grey
        for i2=1,table.getn(lib_items_cfg.weaponHit),2 do
            if stat <= lib_items_cfg.weaponHit[i2] then
                statColor = lib_items_cfg.weaponHit[i2 + 1]
            end
        end
        if item.weapon.statpresence[5] == 1 and item.weapon.stats[6] == 0 then
            statColor = lib_items_cfg.red
        end
        result = result .. stat
        result = result .. "] "

        if item.kills ~= 0 then
            result = result .. "["
            result = result .. item.kills
            result = result .. "] "
        end
    end

    return result
end

local function ProcessFrame(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.armorName
    local item_cfg = lib_items_list.t[item.hex]

    if item.equipped then
        result = result .. "["
        result = result .. "E"
        result = result .. "] "
    end

    result = result .. TrimString(item.name, 0) .. " "
    result = result .. writeArmorStats(item)
    result = result .. "["
    result = result .. item.armor.slots .. "S"
    result = result .. "] "

    return result
end
local function ProcessBarrier(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.armorName
    local item_cfg = lib_items_list.t[item.hex]

    if item.equipped then
        result = result .. "["
        result = result .. "E"
        result = result .. "] "
    end

    result = result .. TrimString(item.name, 0) .. " "
    result = result .. writeArmorStats(item)

    return result
end
local function ProcessUnit(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.unitName
    local item_cfg = lib_items_list.t[item.hex]

    if item.equipped then
        result = result .. "["
        result = result .. "E"
        result = result .. "] "
    end

    local nameStr = item.name

    if item.unit.mod == 0 then
    elseif item.unit.mod == -2 then
        nameStr = nameStr .. "--"
    elseif item.unit.mod == -1 then
        nameStr = nameStr .. "-"
    elseif item.unit.mod == 1 then
        nameStr = nameStr .. "+"
    elseif item.unit.mod == 2 then
        nameStr = nameStr .. "++"
    end

    result = result .. TrimString(nameStr, 0) .. " "

    if item.kills ~= 0 then
        result = result .. "["
        result = result .. item.kills
        result = result .. "] "
    end

    return result
end
local function ProcessMag(item, fromMagWindow)
    local result = ""
    local nameColor = lib_items_cfg.magName
    local item_cfg = lib_items_list.t[item.hex]
    
    result = result .. TrimString(item.name, 0) .. " "
    
    result = result .. "["
    result = result .. string.format("%.2f", item.mag.def)
    result = result .. "/"
    result = result .. string.format("%.2f", item.mag.pow)
    result = result .. "/"
    result = result .. string.format("%.2f", item.mag.dex)
    result = result .. "/"
    result = result .. string.format("%.2f", item.mag.mind)
    result = result .. "] "

    result = result .. "["
    result = result .. lib_unitxt.GetPhotonBlastName(item.mag.pbL, true)
    result = result .. "|"
    result = result .. lib_unitxt.GetPhotonBlastName(item.mag.pbC, true)
    result = result .. "|"
    result = result .. lib_unitxt.GetPhotonBlastName(item.mag.pbR, true)
    result = result .. "] "

    result = result .. "["
    result = result .. lib_unitxt.GetMagColor(item.mag.color)
    result = result .. "] "

    return result
end
local function ProcessTool(item, floor)
    local result = ""
    local nameColor
    local item_cfg = lib_items_list.t[item.hex]

    if item.data[2] == 2 then
        nameColor = lib_items_cfg.techName
    else
        nameColor = lib_items_cfg.toolName
    end

    if item_cfg ~= nil and item_cfg[1] ~= 0 then
        nameColor = item_cfg[1]
    end

    if item.data[2] == 2 then
        result = result .. TrimString(item.name, 0) .. " "
        result = result .. "Lv" .. item.tool.level
    else
        result = result .. TrimString(item.name, 0) .. " "
        if item.tool.count > 0 then
            result = result .. "x" .. item.tool.count .. " "
        end
    end

    return result
end
local function ProcessMeseta(item)
    local result = ""
    result = result .. "Meseta: "..item.meseta
    return result
end

local function ProcessItem(item, floor, save, state)
	floor = floor or false
    save = save or false
    fromMagWindow = fromMagWindow or false

    local itemStr = ""
    if item.data[1] == 0 then
        itemStr = ProcessWeapon(item, floor)
    elseif item.data[1] == 1 then
        if item.data[2] == 1 then
            itemStr = ProcessFrame(item, floor)
        elseif item.data[2] == 2 then
            itemStr = ProcessBarrier(item, floor)
        elseif item.data[2] == 3 then
            itemStr = ProcessUnit(item, floor)
        end
    elseif item.data[1] == 2 then
        itemStr = ProcessMag(item, fromMagWindow)
    elseif item.data[1] == 3 then
        itemStr = ProcessTool(item, floor)
    elseif item.data[1] == 4 then
        itemStr = ProcessMeseta(item)
    end

    if save then
        local directory = ""
        local filename = ""
        local currentFile = ""

        if state == "Bank" then
            directory = bankDirectory
            filename = "saved_bank.txt"
        end

        if state == "Inventory" then
            directory = inventoryDirectory
            filename = "saved_inventory.txt"
        end

        currentFile = directory..filename
        local file = io.open(currentFile, "a")
        io.output(file)
        io.write(itemStr .. "\n")
        io.close(file)
    else
        return itemStr
    end
end

local function ProcessInventory(index, state)
	index = index or lib_items.Me
	if state.last_inventory_time + state.update_delay < state.current_time or state.last_inventory_index ~= index or state.cache_inventory == nil then
		state.cache_inventory = lib_items.GetInventory(index)
		state.last_inventory_index = index
		state.last_inventory_time = state.current_time
	end

	local itemCount = table.getn(state.cache_inventory.items)
	for i = 1, itemCount, 1 do
		ProcessItem(state.cache_inventory.items[i], false)
	end
end

local function ProcessBank(save)
    if last_bank_time + update_delay < current_time or cache_bank == nil then
        cache_bank = lib_items.GetBank()
        last_bank_time = current_time
    end
    local itemCount = table.getn(cache_bank.items)

    for i=1,itemCount,1 do
        ProcessItem(cache_bank.items[i], false, save)
    end
end

local function ProcessFloor(state, options)
	if state.last_floor_time + state.update_delay < state.current_time or state.cache_floor == nil then
		state.cache_floor = lib_items.GetItemList(lib_items.NoOwner, options.invertItemList)
		state.last_floor_time = state.current_time
	end

	local itemCount = table.getn(state.cache_floor)
	for i = 1, itemCount, 1 do
		ProcessItem(state.cache_floor[i], true, state)
	end
end

return {
    ProcessWeapon = ProcessWeapon,
    ProcessTool = ProcessTool,
    ProcessUnit = ProcessUnit,
    ProcessFrame = ProcessFrame,
    ProcessBarrier = ProcessBarrier,
    ProcessItem = ProcessItem,
    ProcessInventory = ProcessInventory,
    ProcessBank = ProcessBank,
    ProcessFloor = ProcessFloor
}