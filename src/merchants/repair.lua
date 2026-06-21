local VanillaEnhanced = _G.VanillaEnhanced
local Merchants = VanillaEnhanced:GetModule("merchants")

local function T(key, vars)
    return VanillaEnhanced:T(key, vars)
end

local function FormatMoney(value)
    if type(GetCoinTextureString) == "function" then
        return GetCoinTextureString(value or 0)
    end
    if type(GetMoneyString) == "function" then
        return GetMoneyString(value or 0, true)
    end
    return tostring(value or 0)
end

function Merchants:AutoRepair()
    if self:GetSettings().autoRepair ~= true then
        return true
    end
    if type(GetRepairAllCost) ~= "function" or type(RepairAllItems) ~= "function" then
        return false
    end

    local cost = GetRepairAllCost()
    if not cost or cost <= 0 then
        return false
    end
    if type(GetMoney) == "function" and GetMoney() < cost then
        self:PrintMessage(T("merchants.autoRepair.notEnoughMoney", {
            money = FormatMoney(cost),
        }))
        return true
    end

    local ok = pcall(RepairAllItems)
    if not ok then
        return false
    end

    self:PrintMessage(T("merchants.autoRepair.repaired", {
        money = FormatMoney(cost),
    }))
    return true
end
