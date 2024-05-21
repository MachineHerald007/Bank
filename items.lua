local lib_helpers = require("solylib.helpers")
local lib_unitxt = require("solylib.unitxt")
local lib_characters = require("solylib.characters")
local lib_items = require("solylib.items.items")
local lib_items_list = require("solylib.items.items_list")
local lib_items_cfg = require("solylib.items.items_configuration")

local overrideAlphaPercent = 1
local TextCCallback        = nil
local bankDirectory        = "addons/Bank Connector/bank/"
local inventoryDirectory   = "addons/Bank Connector/inventory/"
local currentBankFile      = ""
local currentInventoryFile = ""

-- Wrapper function to simplify color changes.
local function TextCWrapper(newLine, col, fmt, ...)
    -- Update the color if one was specified here.
    col = col or 0xFFFFFFFF

    local rgb = bit.band(col, 0x00FFFFFF)
    local oldAlpha = bit.rshift(col, 24)
    local newAlpha = math.floor(oldAlpha * overrideAlphaPercent)
    col = bit.bor(bit.lshift(newAlpha, 24), rgb)

    return lib_helpers.TextC(newLine, col, fmt, ...)
end

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

    result = result .. TextCWrapper(false, lib_items_cfg.white, "[")

    local statColor
    if item.armor.dfp == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. TextCWrapper(false, statColor, "%i", item.armor.dfp)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "/")
    if item.armor.dfpMax == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. TextCWrapper(false, statColor, "%i", item.armor.dfpMax)
    result = result .. TextCWrapper(false, lib_items_cfg.white, " | ")
    if item.armor.evp == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. TextCWrapper(false, statColor, "%i", item.armor.evp)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "/")
    if item.armor.evpMax == 0 then
        statColor = lib_items_cfg.grey
    else
        statColor = lib_items_cfg.armorStats
    end
    result = result .. TextCWrapper(false, statColor, "%i", item.armor.evpMax)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")

    return result
end

local function ProcessWeapon(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.weaponName
    local item_cfg = lib_items_list.t[item.hex]

    -- if options.showEquippedItems then
    --     if item.equipped then
    --         TextCWrapper(false, lib_items_cfg.white, "[")
    --         TextCWrapper(false, lib_items_cfg.itemEquipped, "E")
    --         TextCWrapper(false, lib_items_cfg.white, "] ")
    --     end
    -- end

    if item.weapon.wrapped or item.weapon.untekked then
        result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
        if item.weapon.wrapped and item.weapon.untekked then
            result = result .. TextCWrapper(false, lib_items_cfg.weaponUntekked, "W|U")
        elseif item.weapon.wrapped then
            result = result .. TextCWrapper(false, lib_items_cfg.weaponUntekked, "W")
        elseif item.weapon.untekked then
            result = result .. TextCWrapper(false, lib_items_cfg.weaponUntekked, "U")
        end
        result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")
    end

    if item.weapon.isSRank then
        result = result .. TextCWrapper(false, lib_items_cfg.weaponSRankTitle, "S-RANK ")
        result = result .. TextCWrapper(false, lib_items_cfg.weaponSRankName, "%s ", item.name)
        result = result .. TextCWrapper(false, lib_items_cfg.weaponSRankCustomName, "%s ", item.weapon.nameSrank)

        if item.weapon.grind > 0 then
            result = result .. TextCWrapper(false, lib_items_cfg.weaponGrind, "+%i ", item.weapon.grind)
        end

        if item.weapon.specialSRank ~= 0 then
            result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
            result = result .. TextCWrapper(false, lib_items_cfg.weaponSRankSpecial[item.weapon.specialSRank], lib_unitxt.GetSRankSpecialName(item.weapon.specialSRank))
            result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")
        end
    else
        result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(item.name, 0))

        if item.weapon.grind > 0 then
            result = result .. TextCWrapper(false, lib_items_cfg.weaponGrind, "+%i ", item.weapon.grind)
        end

        if item.weapon.special ~= 0 then
            result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
            result = result .. TextCWrapper(false, lib_items_cfg.weaponSpecial[item.weapon.special + 1], lib_unitxt.GetSpecialName(item.weapon.special))
            result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")
        end

        result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
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

            result = result .. TextCWrapper(false, statColor, "%i", stat)

            if i < 5 then
                result = result .. TextCWrapper(false, lib_items_cfg.white, "/")
            else
                result = result .. TextCWrapper(false, lib_items_cfg.white, "|")
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
        result = result .. TextCWrapper(false, statColor, "%i", stat)
        result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")

        if item.kills ~= 0 then
            result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
            result = result .. TextCWrapper(false, lib_items_cfg.weaponKills, "%iK", item.kills)
            result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")
        end
    end

    return result
end

local function ProcessFrame(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.armorName
    local item_cfg = lib_items_list.t[item.hex]

    -- if options.showEquippedItems then
    --     if item.equipped then
    --         TextCWrapper(false, lib_items_cfg.white, "[")
    --         TextCWrapper(false, lib_items_cfg.itemEquipped, "E")
    --         TextCWrapper(false, lib_items_cfg.white, "] ")
    --     end
    -- end

    result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(item.name, 0))
    result = result .. writeArmorStats(item)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
    result = result .. TextCWrapper(false, lib_items_cfg.armorSlots, "%iS", item.armor.slots)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")

    return result
end
local function ProcessBarrier(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.armorName
    local item_cfg = lib_items_list.t[item.hex]

    -- if options.showEquippedItems then
    --     if item.equipped then
    --         TextCWrapper(false, lib_items_cfg.white, "[")
    --         TextCWrapper(false, lib_items_cfg.itemEquipped, "E")
    --         TextCWrapper(false, lib_items_cfg.white, "] ")
    --     end
    -- end

    result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(item.name, 0))
    result = result .. writeArmorStats(item)

    return result
end
local function ProcessUnit(item, floor)
    local result = ""
    local nameColor = lib_items_cfg.unitName
    local item_cfg = lib_items_list.t[item.hex]

    -- if options.showEquippedItems then
    --     if item.equipped then
    --         TextCWrapper(false, lib_items_cfg.white, "[")
    --         TextCWrapper(false, lib_items_cfg.itemEquipped, "E")
    --         TextCWrapper(false, lib_items_cfg.white, "] ")
    --     end
    -- end

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

    result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(nameStr, 0))

    if item.kills ~= 0 then
        result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
        result = result .. TextCWrapper(false, lib_items_cfg.weaponKills, "%iK", item.kills)
        result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")
    end

    return result
end
local function ProcessMag(item, fromMagWindow)
    local result = ""
    local nameColor = lib_items_cfg.magName
    local item_cfg = lib_items_list.t[item.hex]
    
    result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(item.name, 0))
    
    result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
    result = result .. TextCWrapper(false, lib_items_cfg.magStats, "%.2f", item.mag.def)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "/")
    result = result .. TextCWrapper(false, lib_items_cfg.magStats, "%.2f", item.mag.pow)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "/")
    result = result .. TextCWrapper(false, lib_items_cfg.magStats, "%.2f", item.mag.dex)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "/")
    result = result .. TextCWrapper(false, lib_items_cfg.magStats, "%.2f", item.mag.mind)
    result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")

    result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
    result = result .. TextCWrapper(false, lib_items_cfg.magPB, lib_unitxt.GetPhotonBlastName(item.mag.pbL, true))
    result = result .. TextCWrapper(false, lib_items_cfg.white, "|")
    result = result .. TextCWrapper(false, lib_items_cfg.magPB, lib_unitxt.GetPhotonBlastName(item.mag.pbC, true))
    result = result .. TextCWrapper(false, lib_items_cfg.white, "|")
    result = result .. TextCWrapper(false, lib_items_cfg.magPB, lib_unitxt.GetPhotonBlastName(item.mag.pbR, true))
    result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")

    result = result .. TextCWrapper(false, lib_items_cfg.white, "[")
    result = result .. TextCWrapper(false, lib_items_cfg.magColor, lib_unitxt.GetMagColor(item.mag.color))
    result = result .. TextCWrapper(false, lib_items_cfg.white, "] ")

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
        result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(item.name, 0))
        result = result .. TextCWrapper(false, lib_items_cfg.techLevel, "Lv%i ", item.tool.level)
    else
        result = result .. TextCWrapper(false, nameColor, "%s ", TrimString(item.name, 0))
        if item.tool.count > 0 then
            result = result .. TextCWrapper(false, lib_items_cfg.toolAmount, "x%i ", item.tool.count)
        end
    end

    return result
end
local function ProcessMeseta(item)
    local result = ""
    result = result .. TextCWrapper(false, lib_items_cfg.mesetaName, "%s ", item.name)
    result = result .. TextCWrapper(false, lib_items_cfg.mesetaAmount, "%i ", item.meseta)
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

        currentFile = directory..os.date('%Y%m%d_%H%M%S')..filename
        local file = io.open(currentFile, "a")
        io.output(file)
        io.write(itemStr .. "\n")
        io.close(file)
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