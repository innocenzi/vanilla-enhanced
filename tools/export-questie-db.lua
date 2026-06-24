local args = {...}

local function arg_value(name)
    for index = 1, #args do
        if args[index] == name then
            return args[index + 1]
        end
    end
end

local out_path = arg_value("--out")
local questie_ref = arg_value("--questie-ref") or "unknown"
local questie_commit = arg_value("--questie-commit") or "unknown"
local expansion = arg_value("--expansion") or "TBC"
local locale = arg_value("--locale") or "frFR"

if not out_path then
    error("Usage: lua tools/export-questie-db.lua --out normalized.json [--questie-ref ref] [--questie-commit sha] [--expansion TBC] [--locale frFR]")
end

if expansion ~= "TBC" then
    error("Only TBC export is currently supported")
end

if locale ~= "frFR" then
    error("Only frFR locale export is currently supported")
end

package.path = table.concat({
    "./?.lua",
    "./?/init.lua",
    "./cli/?.lua",
    package.path,
}, ";")

loadstring = loadstring or load
unpack = unpack or table.unpack
getfenv = getfenv or function()
    return _G
end
setfenv = setfenv or function(fn)
    return fn
end

if not package.preload["bit32"] then
    package.preload["bit32"] = function()
        local mask = 0xffffffff
        return {
            band = function(...)
                local result = mask
                for index = 1, select("#", ...) do
                    result = result & select(index, ...)
                end
                return result
            end,
            bor = function(...)
                local result = 0
                for index = 1, select("#", ...) do
                    result = result | select(index, ...)
                end
                return result
            end,
            bxor = function(...)
                local result = 0
                for index = 1, select("#", ...) do
                    result = result ~ select(index, ...)
                end
                return result
            end,
            bnot = function(value)
                return (~value) & mask
            end,
            lshift = function(value, disp)
                return (value << disp) & mask
            end,
            rshift = function(value, disp)
                return (value & mask) >> disp
            end,
            arshift = function(value, disp)
                return value >> disp
            end,
        }
    end
end

local function json_escape(value)
    local replacements = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }

    return value:gsub("[\\\"\b\f\n\r\t]", replacements):gsub("[%z\1-\31]", function(char)
        return string.format("\\u%04x", string.byte(char))
    end)
end

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        if type(left) == type(right) then
            return left < right
        end
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function is_contiguous_array(tbl)
    local count = 0
    local max_index = 0
    for key in pairs(tbl) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false, 0
        end
        count = count + 1
        if key > max_index then
            max_index = key
        end
    end
    return count == max_index, max_index
end

local function encode_json(value, path)
    path = path or "$"
    local value_type = type(value)
    if value_type == "nil" then
        return "null"
    end
    if value_type == "boolean" then
        return value and "true" or "false"
    end
    if value_type == "number" then
        return tostring(value)
    end
    if value_type == "string" then
        return "\"" .. json_escape(value) .. "\""
    end
    if value_type ~= "table" then
        error("Cannot JSON encode " .. value_type .. " at " .. path)
    end

    local is_array, max_index = is_contiguous_array(value)
    local parts = {}
    if is_array then
        for index = 1, max_index do
            parts[#parts + 1] = encode_json(value[index], path .. "[" .. index .. "]")
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    for _, key in ipairs(sorted_keys(value)) do
        parts[#parts + 1] = encode_json(tostring(key), path .. ".<key>") .. ":" .. encode_json(value[key], path .. "." .. tostring(key))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function write_file(path, contents)
    local file, err = io.open(path, "wb")
    if not file then
        error(err)
    end
    file:write(contents)
    file:close()
end

local function load_private_table(module, key)
    local source = module.private and module.private[key]
    if type(source) ~= "string" then
        return {}
    end
    return assert(loadstring(source))()
end

local function overlay(base, override)
    for key, value in pairs(override or {}) do
        base[key] = value
    end
    return base
end

local function materialize_lookup(value)
    if type(value) == "function" then
        return value()
    end
    return value or {}
end

local function materialize_blacklist(value)
    local blacklist = {}

    for quest_id, flag in pairs(value or {}) do
        if flag then
            blacklist[quest_id] = true
        end
    end

    return blacklist
end

local function load_extra_objective_translations()
    dofile("Localization/Translations/ExtraObjectives/ClassicObjectives.lua")
    dofile("Localization/Translations/ExtraObjectives/TbcObjectives.lua")
end

require("cli.dump")
WOW_PROJECT_ID = 5

dofile("cli/apiMocks.lua")
GetLocale = function()
    return locale
end
UnitFactionGroup = function()
    return "Horde"
end
GetBuildInfo = function()
    return "2.5.1", "38644", "May 11 2021", 20501
end
UnitLevel = function()
    return 70
end
GetMaxPlayerLevel = function()
    return 70
end

local loadTOC = require("cli.loadTOC")
loadTOC("Questie-BCC.toc")

Questie.Debug = function() end
Questie.Error = function(_, text, ...)
    error(tostring(text))
end
Questie.Warning = function(_, text, ...)
    -- Questie's own CLI validators print warnings and continue.
end

Questie.db = {
    char = {
        showEventQuests = false,
        hidden = {},
        complete = {},
    },
    global = {},
    profile = {},
}
QuestieConfig = {}

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
local QuestieQuestBlacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
local l10n = QuestieLoader:ImportModule("l10n")
local DropDB = QuestieLoader:ImportModule("DropDB")

l10n:SetUILocale(locale)
load_extra_objective_translations()

QuestieDB.npcData = assert(loadstring(QuestieDB.npcData))()
QuestieDB.objectData = assert(loadstring(QuestieDB.objectData))()
QuestieDB.questData = assert(loadstring(QuestieDB.questData))()
QuestieDB.itemData = assert(loadstring(QuestieDB.itemData))()

Questie:SetIcons()
ZoneDB:Initialize()

QuestieCorrections:Initialize({
    npcData = QuestieDB.npcData,
    objectData = QuestieDB.objectData,
    itemData = QuestieDB.itemData,
    questData = QuestieDB.questData,
})

local QuestieDBCompiler = QuestieLoader:ImportModule("DBCompiler")
QuestieDBCompiler:Compile(function() end)
QuestieDB:Initialize()
QuestieDBCompiler:ValidateObjects()
QuestieDBCompiler:ValidateItems()
QuestieDBCompiler:ValidateNPCs()
QuestieDBCompiler:ValidateQuests()

dofile("Localization/lookups/TBC/lookupQuests/" .. locale .. ".lua")
dofile("Localization/lookups/TBC/lookupNpcs/" .. locale .. ".lua")
dofile("Localization/lookups/TBC/lookupObjects/" .. locale .. ".lua")
dofile("Localization/lookups/TBC/lookupItems/" .. locale .. ".lua")

local area_to_ui = overlay(
    load_private_table(ZoneDB, "areaIdToUiMapId"),
    load_private_table(ZoneDB, "areaIdToUiMapIdOverride")
)
local parent_area = overlay(
    load_private_table(ZoneDB, "subZoneToParentZone"),
    load_private_table(ZoneDB, "subZoneToParentZoneOverride")
)

local function collect_dungeon_zone_ids()
    local ids = {}
    local dungeon_zones = l10n.zoneCategoryLookup and l10n.zoneCategoryLookup[8] or {}

    for area_id in pairs(dungeon_zones) do
        ids[area_id] = true
    end

    for area_id, dungeon in pairs(ZoneDB:GetDungeons() or {}) do
        ids[area_id] = true
        if type(dungeon) == "table" and type(dungeon[2]) == "number" then
            ids[dungeon[2]] = true
        end
    end

    return ids
end

local function collect_dungeon_zone_map_ids()
    local map_ids = {}
    for area_id, dungeon in pairs(ZoneDB:GetDungeons() or {}) do
        if type(dungeon) == "table" then
            local ui_map_id = area_to_ui[area_id]
            if type(ui_map_id) == "number" then
                map_ids[area_id] = ui_map_id
            end
            if type(dungeon[2]) == "number" then
                map_ids[dungeon[2]] = ui_map_id or area_to_ui[dungeon[2]]
            end
        end
    end

    return map_ids
end

local dungeon_zone_ids = collect_dungeon_zone_ids()
local dungeon_zone_map_ids = collect_dungeon_zone_map_ids()

DropDB:Initialize()

local function collect_item_drop_rates()
    local rates = {}
    local npc_drops_key = QuestieDB.itemKeys.npcDrops

    for item_id, item in pairs(QuestieDB.itemData or {}) do
        local npc_drops = type(item) == "table" and item[npc_drops_key] or nil
        if type(npc_drops) == "table" then
            for _, npc_id in pairs(npc_drops) do
                if type(npc_id) == "number" then
                    local drop_rate_data = QuestieDB.GetItemDroprate(item_id, npc_id)
                    local drop_rate = type(drop_rate_data) == "table" and drop_rate_data[1] or nil
                    if type(drop_rate) == "number" then
                        rates[item_id] = rates[item_id] or {}
                        rates[item_id][npc_id] = drop_rate
                    end
                end
            end
        end
    end

    return rates
end

local normalized = {
    meta = {
        source = "Questie",
        questieRef = questie_ref,
        questieCommit = questie_commit,
        expansion = expansion,
        locale = locale,
        correctionsApplied = true,
    },
    keys = {
        quests = QuestieDB.questKeys,
        npcs = QuestieDB.npcKeys,
        objects = QuestieDB.objectKeys,
        items = QuestieDB.itemKeys,
    },
    zones = {
        areaToUi = area_to_ui,
        parentArea = parent_area,
        dungeonZoneIds = dungeon_zone_ids,
        dungeonZoneMapIds = dungeon_zone_map_ids,
    },
    blacklist = {
        quests = materialize_blacklist(QuestieQuestBlacklist:Load()),
    },
    data = {
        quests = QuestieDB.questData,
        npcs = QuestieDB.npcData,
        objects = QuestieDB.objectData,
        items = QuestieDB.itemData,
    },
    dropRates = {
        items = collect_item_drop_rates(),
    },
    locale = {
        quests = materialize_lookup(l10n.questLookup[locale]),
        npcs = materialize_lookup(l10n.npcNameLookup[locale]),
        objects = materialize_lookup(l10n.objectLookup[locale]),
        items = materialize_lookup(l10n.itemLookup[locale]),
    },
}

write_file(out_path, encode_json(normalized))
