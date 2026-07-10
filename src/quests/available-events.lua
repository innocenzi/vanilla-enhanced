local Quests = _G.VanillaEnhanced:GetModule("quests")

local EVENT_SORT_RANGES = {
    [-21] = {{18, 10, 31, 10}},
    [-41] = {{1, 11, 2, 11}},
    [-364] = "darkmoon",
    [-366] = {
        {5, 2, 19, 2},
        {23, 1, 10, 2},
        {30, 1, 18, 2},
        {20, 1, 10, 2},
        {3, 2, 23, 2},
        {28, 1, 17, 2},
        {16, 2, 9, 3},
        {24, 1, 14, 2},
    },
    [-369] = {{21, 6, 5, 7}},
    [-370] = {{20, 9, 5, 10}},
    [-374] = {{28, 3, 28, 3}},
    [-375] = {{25, 11, 1, 12}},
    [-376] = {{11, 2, 15, 2}},
    [-378] = {{27, 4, 4, 5}},
    [-402] = {{2, 10, 8, 10}},
    [-404] = {{15, 12, 2, 1}},
}

local GENERIC_EVENT_SORTS = {
    [-22] = true,
    [-284] = true,
    [-1000] = true,
}

local INACTIVE_EVENT_SORTS = {
    [-365] = true,
    [-368] = true,
}

function Quests:GetAvailableQuestCalendarDate()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local ok, calendarDate = pcall(C_DateAndTime.GetCurrentCalendarTime)
        if ok and calendarDate then
            return calendarDate.monthDay, calendarDate.month, calendarDate.year
        end
    end

    local currentDate = date and date("*t")
    if currentDate then
        return currentDate.day, currentDate.month, currentDate.year
    end

    return nil, nil, nil
end

function Quests:GetAvailableQuestCalendarDaySignature()
    local day, month, year = self:GetAvailableQuestCalendarDate()
    if not day or not month or not year then return nil end
    return tostring(year) .. "-" .. tostring(month) .. "-" .. tostring(day)
end

local function IsWithinDateRange(day, month, startDay, startMonth, endDay, endMonth)
    if not day or not month then
        return nil
    end

    if startMonth <= endMonth then
        if month < startMonth or month > endMonth then
            return false
        end
        if month == startMonth and day < startDay then
            return false
        end
        if month == endMonth and day > endDay then
            return false
        end
        return true
    end

    if month > startMonth or month < endMonth then
        return true
    end
    if month == startMonth and day >= startDay then
        return true
    end
    if month == endMonth and day <= endDay then
        return true
    end
    return false
end

local function IsDarkmoonFaireActive(day, month, year)
    if not day or not month or not year or not time or not date then
        return false
    end

    local firstDayTime = time({ year = year, month = month, day = 1, hour = 12 })
    local firstWeekday = tonumber(date("%w", firstDayTime)) + 1
    local startDayByFirstWeekday = {
        [1] = 9,
        [2] = 8,
        [3] = 7,
        [4] = 6,
        [5] = 5,
        [6] = 4,
        [7] = 10,
    }
    local startDay = startDayByFirstWeekday[firstWeekday]
    return day >= startDay and day <= startDay + 6
end

local function IsAnyKnownEventActive(day, month, year)
    for _, ranges in pairs(EVENT_SORT_RANGES) do
        if ranges == "darkmoon" then
            if IsDarkmoonFaireActive(day, month, year) then
                return true
            end
        else
            for _, range in ipairs(ranges) do
                if IsWithinDateRange(day, month, range[1], range[2], range[3], range[4]) then
                    return true
                end
            end
        end
    end

    return false
end

local function IsEventSortActive(sortKey, day, month, year)
    if INACTIVE_EVENT_SORTS[sortKey] then
        return false
    end

    local ranges = EVENT_SORT_RANGES[sortKey]
    if ranges == "darkmoon" then
        return IsDarkmoonFaireActive(day, month, year)
    end
    if ranges then
        for _, range in ipairs(ranges) do
            if IsWithinDateRange(day, month, range[1], range[2], range[3], range[4]) then
                return true
            end
        end
        return false
    end

    if GENERIC_EVENT_SORTS[sortKey] then
        return IsAnyKnownEventActive(day, month, year)
    end

    return true
end

function Quests:GetAvailableQuestEventState(dbQuest, context)
    if not dbQuest or not dbQuest.z then return true end
    if not EVENT_SORT_RANGES[dbQuest.z] and not GENERIC_EVENT_SORTS[dbQuest.z]
        and not INACTIVE_EVENT_SORTS[dbQuest.z] then
        return true
    end
    if INACTIVE_EVENT_SORTS[dbQuest.z] then return false, "event-inactive" end
    local day = context and context.calendarDay
    local month = context and context.calendarMonth
    local year = context and context.calendarYear
    if not day or not month or not year then
        day, month, year = self:GetAvailableQuestCalendarDate()
    end
    if not day or not month or not year then return nil, "event-unknown" end
    local active = IsEventSortActive(dbQuest.z, day, month, year)
    return active, active and nil or "event-inactive"
end

function Quests:HasActiveAvailableQuestEventWindow(dbQuest)
    local state = self:GetAvailableQuestEventState(dbQuest)
    return state ~= false
end
