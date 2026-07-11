local function AssertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local bags = {
    settings = { highlightRecentItems = true },
}

_G.VanillaEnhanced = {
    GetModule = function(_, key)
        if key == "bags" then
            return bags
        end
    end,
}

local inventory = {}
local slotCounts = {}

local function SetSlot(bagID, slot, link, count, locked, itemID)
    inventory[bagID] = inventory[bagID] or {}
    local resolvedItemID = itemID or (link and tonumber(string.match(link, "item:(%d+)")))
    inventory[bagID][slot] = (link or resolvedItemID) and {
        hyperlink = link,
        itemID = resolvedItemID,
        iconFileID = 1,
        stackCount = count or 1,
        isLocked = locked == true,
    } or nil
end

local function ResetScenario()
    inventory = {}
    slotCounts = {}
    bags.recentItemSnapshot = nil
    bags.recentItemQuantities = nil
    bags.recentItemSlots = nil
    bags.sorting = nil
    bags.updateQueued = nil
end

function bags:GetSettings()
    return self.settings
end

function bags:IsSortEnabled()
    return true
end

function bags:QueueUpdate()
    self.updateQueued = true
end

bags.Api = {}
function bags.Api:GetContainerNumSlots(bagID)
    if slotCounts[bagID] ~= nil then
        return slotCounts[bagID]
    end
    return 4
end
function bags.Api:GetContainerItemInfo(bagID, slot)
    return inventory[bagID] and inventory[bagID][slot]
end
function bags.Api:GetContainerItemLink(bagID, slot)
    local item = self:GetContainerItemInfo(bagID, slot)
    return item and item.hyperlink
end
function bags.Api:GetContainerItemID(bagID, slot)
    local item = self:GetContainerItemInfo(bagID, slot)
    return item and item.itemID
end

dofile("src/bags/recent-items.lua")

local itemA = "|cff1eff00|Hitem:100:0:0:0:0:0:0:0|h[Item A]|h|r"
local itemB = "|cff0070dd|Hitem:100:0:0:0:0:1:0:0|h[Item B]|h|r"

SetSlot(0, 1, itemA, 5)
bags:InitializeRecentItemTracking()
AssertEqual(bags:IsRecentItem(0, 1), false, "initial inventory is only a baseline")

SetSlot(0, 1, itemA, 7)
bags:ReconcileRecentItems(false)
AssertEqual(bags:IsRecentItem(0, 1), true, "stack increase is recent")

SetSlot(0, 1, nil)
SetSlot(0, 2, itemA, 7)
bags:ReconcileRecentItems(false)
AssertEqual(bags:IsRecentItem(0, 1), false, "old moved slot is cleared")
AssertEqual(bags:IsRecentItem(0, 2), true, "recent identity follows a move")

SetSlot(0, 3, itemB, 1)
bags:ReconcileRecentItems(false)
AssertEqual(bags:IsRecentItem(0, 3), true, "links sharing an item ID use the same recent aggregate")

AssertEqual(bags:AcknowledgeRecentItem(0, 3), true, "smaller changed stack can be acknowledged")
AssertEqual(bags:IsRecentItem(0, 3), false, "acknowledged stack is no longer recent")
AssertEqual(bags:IsRecentItem(0, 2), true, "remaining same-ID quantity stays highlighted")
AssertEqual(bags:AcknowledgeRecentItem(0, 2), true, "remaining aggregate can be acknowledged")
AssertEqual(bags:IsRecentItem(0, 2), false, "hover dismisses the remaining highlight")

SetSlot(0, 4, "|cffffffff|Hitem:200:0:0:0:0:0:0:0|h[Bank Item]|h|r", 1)
bags:ReconcileRecentItems(true)
AssertEqual(bags:IsRecentItem(0, 4), false, "suppressed bank changes are not recent")

SetSlot(0, 4, nil)
SetSlot(1, 1, "|cffffffff|Hitem:300:0:0:0:0:0:0:0|h[Locked Item]|h|r", 1, true)
local previousSnapshot = bags.recentItemSnapshot
AssertEqual(bags:ReconcileRecentItems(false), false, "locked snapshots are deferred")
AssertEqual(bags.recentItemSnapshot, previousSnapshot, "deferred snapshots preserve the baseline")

ResetScenario()
SetSlot(0, 1, nil, 1, false, 400)
bags:InitializeRecentItemTracking()
AssertEqual(bags:IsRecentItem(0, 1), false, "item-ID-only inventory is a silent baseline")
SetSlot(0, 1, "|cffffffff|Hitem:400:0:0:0:0:0:0:0|h[Cached Item]|h|r", 1)
bags:ReconcileRecentItems(false)
AssertEqual(bags:IsRecentItem(0, 1), false, "caching an item hyperlink is not an acquisition")

local validSnapshot = bags.recentItemSnapshot
slotCounts[0] = 0
AssertEqual(bags:ReconcileRecentItems(false), false, "zero-slot backpack snapshots are deferred")
AssertEqual(bags.recentItemSnapshot, validSnapshot, "zero-slot snapshots preserve the baseline")
slotCounts[0] = nil

inventory[0][1] = {
    itemID = 400,
    iconFileID = 1,
    isLocked = false,
}
AssertEqual(bags:ReconcileRecentItems(false), false, "missing stack counts are deferred")
AssertEqual(bags.recentItemSnapshot, validSnapshot, "incomplete item snapshots preserve the baseline")

SetSlot(0, 1, "|cffffffff|Hitem:400:0:0:0:0:0:0:0|h[Cached Item]|h|r", 2)
bags:ReconcileRecentItems(false)
AssertEqual(bags:IsRecentItem(0, 1), true, "a real quantity increase remains an acquisition")

print("bags recent item runtime tests passed")
