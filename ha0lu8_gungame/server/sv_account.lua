Account = {}

local cache = {}

local function dbg(...)
    if Config.Debug then print("[gungame:account]", ...) end
end

function Account.ComputeLevel(totalXp)
    local lvl = math.floor((totalXp or 0) / Config.Level.xpPerLevel) + 1
    if lvl > Config.Level.maxLevel then lvl = Config.Level.maxLevel end
    return lvl
end

function Account.LevelProgress(totalXp)
    local per = Config.Level.xpPerLevel
    local intoLevel = (totalXp or 0) % per
    return intoLevel, per
end

function Account.Get(citizenid)
    if not citizenid then return nil end
    if cache[citizenid] then return cache[citizenid] end

    local row = MySQL.single.await(
        "SELECT * FROM gungame_accounts WHERE citizenid = ?", { citizenid })
    if row then
        cache[citizenid] = row
    end
    return row
end

function Account.GetByAccountId(accountId)
    return MySQL.single.await(
        "SELECT * FROM gungame_accounts WHERE account_id = ?", { accountId })
end

function Account.IsAccountIdTaken(accountId)
    local row = MySQL.scalar.await(
        "SELECT 1 FROM gungame_accounts WHERE account_id = ? LIMIT 1", { accountId })
    return row ~= nil
end

function Account.GetProfile(citizenid)
    local a = Account.Get(citizenid)
    if not a then return nil end
    local intoLevel, need = Account.LevelProgress(a.total_xp)
    return {
        accountId   = a.account_id,
        name        = a.name,
        icon        = a.icon,
        level       = a.level,
        totalXp     = a.total_xp,
        levelXp     = intoLevel,
        levelNeed   = need,
        totalKills  = a.total_kills,
        totalWins   = a.total_wins,
        totalLosses = a.total_losses,
    }
end

function Account.UpdateProfile(citizenid, name, icon)
    local a = Account.Get(citizenid)
    if not a then return false, "no_player" end

    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #name < Config.Account.nameMinLen or #name > Config.Account.nameMaxLen then
        return false, "invalid_name"
    end

    icon = (icon and icon ~= "") and icon or nil

    MySQL.update.await(
        "UPDATE gungame_accounts SET name = ?, icon = ? WHERE citizenid = ?",
        { name, icon, citizenid })

    a.name = name
    a.icon = icon
    dbg("profile updated", citizenid, name)
    return true, nil
end

function Account.Register(citizenid, name, accountId, icon)
    if not citizenid then return false, "no_player" end
    if Account.Get(citizenid) then return false, "already_registered" end

    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    accountId = (accountId or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if #name < Config.Account.nameMinLen or #name > Config.Account.nameMaxLen then
        return false, "invalid_name"
    end
    if #accountId < Config.Account.idMinLen or #accountId > Config.Account.idMaxLen then
        return false, "invalid_id"
    end
    if not accountId:match(Config.Account.idPattern) then
        return false, "invalid_id_chars"
    end
    if Account.IsAccountIdTaken(accountId) then
        return false, "id_taken"
    end

    MySQL.insert.await(
        "INSERT INTO gungame_accounts (citizenid, account_id, name, icon, level, total_xp) VALUES (?, ?, ?, ?, 1, 0)",
        { citizenid, accountId, name, icon })
    MySQL.insert.await(
        "INSERT INTO gungame_weekly (citizenid, xp, wins, kills) VALUES (?, 0, 0, 0)",
        { citizenid })

    cache[citizenid] = nil
    Account.Get(citizenid)
    dbg("registered", citizenid, accountId)
    return true, nil
end

function Account.ApplyResult(citizenid, result)
    local a = Account.Get(citizenid)
    if not a then return end

    local kills = result.kills or 0
    local xp = kills * Config.XP.perKill
    local winInc, lossInc = 0, 0

    if result.outcome == "win" then
        xp = xp + Config.XP.perWin
        winInc = 1
    elseif result.outcome == "loss" then
        xp = xp + Config.XP.perLoss
        lossInc = 1
    elseif result.outcome == "draw" then
        xp = xp + Config.XP.perDraw
    end

    local newTotalXp = a.total_xp + xp
    local newLevel = Account.ComputeLevel(newTotalXp)

    MySQL.update.await([[
        UPDATE gungame_accounts
        SET total_xp = ?, level = ?, total_kills = total_kills + ?,
            total_wins = total_wins + ?, total_losses = total_losses + ?
        WHERE citizenid = ?
    ]], { newTotalXp, newLevel, kills, winInc, lossInc, citizenid })

    MySQL.update.await([[
        UPDATE gungame_weekly
        SET xp = xp + ?, wins = wins + ?, kills = kills + ?
        WHERE citizenid = ?
    ]], { xp, winInc, kills, citizenid })

    a.total_xp = newTotalXp
    a.level = newLevel
    a.total_kills = a.total_kills + kills
    a.total_wins = a.total_wins + winInc
    a.total_losses = a.total_losses + lossInc

    dbg("applied result", citizenid, "xp+"..xp, "lvl", newLevel)
    return { xpGained = xp, level = newLevel, leveledUp = newLevel > Account.ComputeLevel(a.total_xp - xp) }
end

function Account.GetRankings()
    local limit = Config.Ranking.topCount
    local function top(orderCol)
        return MySQL.query.await(([[
            SELECT a.account_id AS accountId, a.name AS name, a.icon AS icon,
                   a.level AS level, w.xp AS xp, w.wins AS wins, w.kills AS kills
            FROM gungame_weekly w
            JOIN gungame_accounts a ON a.citizenid = w.citizenid
            WHERE w.%s > 0
            ORDER BY w.%s DESC
            LIMIT ?
        ]]):format(orderCol, orderCol), { limit }) or {}
    end
    return {
        xp    = top("xp"),
        wins  = top("wins"),
        kills = top("kills"),
    }
end

local function getLastReset()
    local v = MySQL.scalar.await(
        "SELECT value FROM gungame_meta WHERE `key` = 'last_weekly_reset'")
    return v and tonumber(v) or 0
end

local function setLastReset(ts)
    MySQL.query.await([[
        INSERT INTO gungame_meta (`key`, value) VALUES ('last_weekly_reset', ?)
        ON DUPLICATE KEY UPDATE value = ?
    ]], { tostring(ts), tostring(ts) })
end

local function lastScheduledResetTime(now)
    local cfg = Config.Ranking.reset
    local t = os.date("*t", now)
    local cfgWday = cfg.weekday
    local curWday = (t.wday == 1) and 7 or (t.wday - 1)

    local todayReset = os.time({
        year = t.year, month = t.month, day = t.day,
        hour = cfg.hour, min = cfg.minute, sec = 0
    })

    local daysSinceTarget = (curWday - cfgWday) % 7
    local scheduled = todayReset - daysSinceTarget * 86400
    if scheduled > now then
        scheduled = scheduled - 7 * 86400
    end
    return scheduled
end

local function performReset()
    MySQL.update.await("UPDATE gungame_weekly SET xp = 0, wins = 0, kills = 0")
    setLastReset(os.time())
    dbg("weekly stats reset")
    print("[gungame] 週間ランキングをリセットしました")
end

local function startResetScheduler()
    CreateThread(function()
        Wait(2000)
        local scheduled = lastScheduledResetTime(os.time())
        if getLastReset() < scheduled then
            performReset()
        end
        while true do
            Wait(60 * 1000)
            local now = os.time()
            local sched = lastScheduledResetTime(now)
            if getLastReset() < sched then
                performReset()
            end
        end
    end)
end

function Account.ClearCache(citizenid)
    if citizenid then cache[citizenid] = nil end
end

CreateThread(function()
    Wait(1000)
    startResetScheduler()
end)
