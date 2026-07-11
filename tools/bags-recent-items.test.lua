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

local function SetSlot(bagID, slot, link, count, locked)
    inventory[bagID] = inventory[bagID] or {}
    inventory[bagID][slot] = link and {
        hyperlink = link,
        itemID = tonumber(string.match(link, "item:(%d+)")),
        iconFileID = 1,
        stackCount = count or 1,
        isLocked = locked == true,
    } or nil
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
    return 4
end
function bags.Api:GetContainerItemInfo(bagID, slot)
    return inventory[bagID] and inventory[bagID][slot]
end
function bags.Api:GetContainerItemLink(bagID, slot)
    local item = self:GetContainerItemInfo(bagID, slot)
    return item and item.hyperlink
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
AssertEqual(bags:IsRecentItem(0, 3), true, "different full links remain distinct")

AssertEqual(bags:AcknowledgeRecentItem(0, 2), true, "hover acknowledgment succeeds")
AssertEqual(bags:IsRecentItem(0, 2), false, "acknowledged stack is no longer recent")
AssertEqual(bags:IsRecentItem(0, 3), true, "acknowledging one fingerprint preserves others")
AssertEqual(bags:IsRecentItem(0, 3), true, "unacknowledged stacks remain recent")
AssertEqual(bags:AcknowledgeRecentItem(0, 3), true, "remaining stack can be acknowledged")
AssertEqual(bags:IsRecentItem(0, 3), false, "hover is the dismissal mechanism")

SetSlot(0, 4, "|cffffffff|Hitem:200:0:0:0:0:0:0:0|h[Bank Item]|h|r", 1)
bags:ReconcileRecentItems(true)
AssertEqual(bags:IsRecentItem(0, 4), false, "suppressed bank changes are not recent")

SetSlot(0, 4, nil)
SetSlot(1, 1, "|cffffffff|Hitem:300:0:0:0:0:0:0:0|h[Locked Item]|h|r", 1, true)
local previousSnapshot = bags.recentItemSnapshot
AssertEqual(bags:ReconcileRecentItems(false), false, "locked snapshots are deferred")
AssertEqual(bags.recentItemSnapshot, previousSnapshot, "deferred snapshots preserve the baseline")

print("bags recent item runtime tests passed")
