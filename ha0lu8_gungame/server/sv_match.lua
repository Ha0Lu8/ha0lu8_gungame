Match = {}

local listings = {}
local matches = {}
local playerListing = {}
local playerMatch = {}
local swapActive = {}
local nextListingId = 1
local nextBucket = Config.BucketStart

local function dbg(...)
    if Config.Debug then print("[gungame:match]", ...) end
end

local function setInMatchState(src, on)
    if not src then return end
    pcall(function()
        Player(src).state:set("gungameMatch", on and true or nil, true)
    end)
end

local function setLoadoutState(src, on)
    if not src then return end
    pcall(function()
        Player(src).state:set("gungameLoadout", on and true or nil, true)
    end)
end

CreateThread(function()
    if not (Config.InventorySwap and Config.InventorySwap.enabled) then return end
    local res = Config.InventorySwap.resource
    while GetResourceState(res) ~= "started" do Wait(1000) end
    local ok = pcall(function()
        exports[res]:registerHook("swapItems", function(payload)
            if payload.toType ~= "drop" then return end
            local src = payload.source
            if src and Player(src).state.gungameLoadout then
                return false
            end
        end, { print = false })
    end)
    if ok then dbg("drop-guard hook registered") end
end)

local SWAP_KVP = "gungame_swapActive"

local function saveSwapKvp()
    local ok, encoded = pcall(json.encode, swapActive)
    if ok then SetResourceKvp(SWAP_KVP, encoded) end
end

local function setSwapped(cid, active)
    if active then swapActive[cid] = true else swapActive[cid] = nil end
    saveSwapKvp()
end

local function loadSwapKvp()
    local raw = GetResourceKvpString(SWAP_KVP)
    if not raw then return end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == "table" then
        for cid in pairs(t) do swapActive[cid] = true end
    end
end

local returnPos = {}
local RETURNPOS_KVP = "gungame_returnPos"

local function saveReturnPosKvp()
    local ok, encoded = pcall(json.encode, returnPos)
    if ok then SetResourceKvp(RETURNPOS_KVP, encoded) end
end

local function setReturnPos(cid, pos)
    returnPos[cid] = pos
    saveReturnPosKvp()
end

local function clearReturnPos(cid)
    if returnPos[cid] == nil then return end
    returnPos[cid] = nil
    saveReturnPosKvp()
end

local function loadReturnPosKvp()
    local raw = GetResourceKvpString(RETURNPOS_KVP)
    if not raw then return end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == "table" then
        for cid, pos in pairs(t) do returnPos[cid] = pos end
    end
end

local function teleportBack(cid, src)
    local pos = returnPos[cid]
    if not pos or not src then return end
    TriggerClientEvent("gungame:returnToPos", src, pos)
    clearReturnPos(cid)
    dbg("teleported back to pre-match pos", cid)
end

RegisterNetEvent("gungame:requestReturn", function()
    local src = source
    local cid = Framework.GetCitizenId(src)
    if not cid then return end
    if playerMatch[cid] then return end
    teleportBack(cid, src)
end)

local function teamRadioChannel(match, team)
    if not (Config.Radio and Config.Radio.enabled) then return nil end
    if Config.Radio.teamOnly and match.ffa then return nil end
    if match.ffa then return nil end
    return (Config.Radio.channelBase or 900000) + match.id * 2 + (team == 1 and 0 or 1)
end

local function restorePlayerInventory(cid, src)
    if not swapActive[cid] then return true end
    if not src then return false end

    local status = Framework.RestoreInventory(src, cid)
    if status == "done" or status == "no_stash" then
        setSwapped(cid, nil)
        setLoadoutState(src, false)
        dbg("inventory restored", cid, status)
        return true
    end
    dbg("inventory restore pending (will retry)", cid)
    return false
end

local function scheduleRestoreRetry(cid, src)
    CreateThread(function()
        for _ = 1, 10 do
            if not swapActive[cid] then return end
            local s = (Framework.GetSourceByCitizenId(cid)) or src
            if s and restorePlayerInventory(cid, s) then return end
            Wait(1000)
        end
    end)
end

local function modeInfo(mode) return Config.Modes[mode] end

local function teamSizesOf(l, m)
    m = m or modeInfo(l.mode)
    if m.custom then
        return l.team1Size or 1, l.team2Size or 1
    end
    return m.teamSize, m.teamSize
end

local function requiredCounts(listing)
    local m = modeInfo(listing.mode)
    if m.ffa then
        return { ffa = listing.ffaSize }
    end
    local s1, s2 = teamSizesOf(listing, m)
    return { [1] = s1, [2] = s2 }
end

local function isPlayerBusy(cid)
    return playerListing[cid] ~= nil or playerMatch[cid] ~= nil
end

local function buildListingView(l)
    local m = modeInfo(l.mode)
    local function names(cids)
        local t = {}
        for _, cid in ipairs(cids) do
            local p = Account.GetProfile(cid)
            t[#t + 1] = { accountId = p and p.accountId or "?", name = p and p.name or "?", level = p and p.level or 1 }
        end
        return t
    end
    local view = {
        id        = l.id,
        host      = (Account.GetProfile(l.host) or {}).name,
        hostId    = (Account.GetProfile(l.host) or {}).accountId,
        mode      = l.mode,
        modeLabel = m.label,
        weapon    = l.weapon,
        weaponLabel = Config.WeaponLabels[l.weapon] or l.weapon,
        winType   = l.winType,
        winValue  = l.winValue,
        bet       = l.bet,
        armor     = l.armor and true or false,
        staminaDrain = l.staminaDrain ~= false,
        custom    = m.custom and true or false,
        mapName   = l.arenaIndex and (Config.Arenas[l.arenaIndex] or {}).name or nil,
        mapRandom = (l.arenaIndex == nil),
    }
    if m.ffa then
        view.ffa = true
        view.ffaSize = l.ffaSize
        view.players = names(l.ffaPlayers)
        view.count = #l.ffaPlayers
    else
        view.ffa = false
        local s1, s2 = teamSizesOf(l, m)
        view.team1Size = s1
        view.team2Size = s2
        view.teamSize  = s1
        view.team1 = names(l.teams[1])
        view.team2 = names(l.teams[2])
    end
    return view
end

local function listingsView()
    local out = {}
    for _, l in pairs(listings) do
        if l.status == "open" then out[#out + 1] = buildListingView(l) end
    end
    return out
end

local function broadcastListings()
    BroadcastApp("match:listings", listingsView())
end

local function isWanted(cid)
    if GetResourceState("gkr-wanted") ~= "started" then return false end
    local src = Framework.GetSourceByCitizenId(cid)
    if not src then return false end
    local ok, lvl = pcall(function() return exports["gkr-wanted"]:GetWantedLevel(src) end)
    return ok and type(lvl) == "number" and lvl > 0
end

function Match.CreateListing(hostCid, data)
    if isPlayerBusy(hostCid) then return false, "already_busy" end
    if isWanted(hostCid) then return false, "wanted" end

    local m = modeInfo(data.mode)
    if not m then return false, "invalid_mode" end

    local party = Social.GetPartyMembers(hostCid)
    local partySize = #party
    for _, mcid in ipairs(party) do
        if isWanted(mcid) then return false, "wanted" end
    end
    local p = Social.GetParty(hostCid)
    if p and p.leader ~= hostCid then return false, "not_leader" end

    local team1Size, team2Size
    if m.custom then
        local cc = Config.Custom
        team1Size = math.floor(tonumber(data.team1Size or 0))
        team2Size = math.floor(tonumber(data.team2Size or 0))
        if team1Size < cc.minPerTeam or team1Size > cc.maxPerTeam
           or team2Size < cc.minPerTeam or team2Size > cc.maxPerTeam then
            return false, "invalid_custom_size"
        end
    end

    if m.ffa then
        if partySize > 1 then return false, "party_no_ffa" end
    elseif m.custom then
        if partySize > team1Size then return false, "party_too_big" end
    else
        if partySize > m.teamSize then return false, "party_too_big" end
    end

    local arenaIndex = nil
    if data.arenaIndex ~= nil and data.arenaIndex ~= "" then
        local ai = math.floor(tonumber(data.arenaIndex) or 0)
        if Config.Arenas[ai] then arenaIndex = ai end
    end

    local winType, winValue = data.winType, tonumber(data.winValue or 0)
    if winType == "rounds" then
        local c = Config.WinConditions.rounds
        if winValue < c.min or winValue > c.max then return false, "invalid_winvalue" end
    elseif winType == "kills" then
        local c = Config.WinConditions.kills
        if winValue < c.min or winValue > c.max then return false, "invalid_winvalue" end
    else
        return false, "invalid_wintype"
    end
    if m.ffa and winType ~= "kills" then return false, "ffa_needs_kills" end

    local bet = 0
    if Config.Betting.enabled then
        bet = math.floor(tonumber(data.bet or 0))
        if bet < Config.Betting.min or bet > Config.Betting.max then
            return false, "invalid_bet"
        end
    end

    local ffaSize = nil
    if m.ffa then
        ffaSize = math.floor(tonumber(data.ffaSize or 0))
        if ffaSize < Config.FFA.minPlayers or ffaSize > Config.FFA.maxPlayers then
            return false, "invalid_ffa_size"
        end
    end

    local id = nextListingId
    nextListingId = nextListingId + 1

    local l = {
        id = id, host = hostCid, mode = data.mode, weapon = data.weapon,
        winType = winType, winValue = winValue, bet = bet, status = "open",
        ffaSize = ffaSize,
        team1Size = team1Size, team2Size = team2Size,
        arenaIndex = arenaIndex,
        armor = data.armor and true or false,
        staminaDrain = data.staminaDrain ~= false,
        teams = { [1] = {}, [2] = {} },
        ffaPlayers = {},
    }

    if m.ffa then
        l.ffaPlayers[1] = hostCid
        playerListing[hostCid] = id
    else
        for _, cid in ipairs(party) do
            l.teams[1][#l.teams[1] + 1] = cid
            playerListing[cid] = id
        end
    end

    listings[id] = l
    dbg("listing created", id, data.mode)
    broadcastListings()
    Match.TryStart(id)
    return true, nil, id
end

function Match.JoinListing(cid, listingId, side)
    local l = listings[listingId]
    if not l or l.status ~= "open" then return false, "listing_gone" end
    if isPlayerBusy(cid) then return false, "already_busy" end
    if isWanted(cid) then return false, "wanted" end

    local m = modeInfo(l.mode)
    local req = requiredCounts(l)

    if m.ffa then
        if #l.ffaPlayers >= req.ffa then return false, "full" end
        l.ffaPlayers[#l.ffaPlayers + 1] = cid
    else
        side = tonumber(side)
        if side ~= 1 and side ~= 2 then return false, "invalid_side" end
        if #l.teams[side] >= req[side] then return false, "side_full" end
        l.teams[side][#l.teams[side] + 1] = cid
    end
    playerListing[cid] = listingId
    broadcastListings()
    Match.TryStart(listingId)
    return true, nil
end

function Match.LeaveListing(cid)
    local id = playerListing[cid]
    if not id then return false end
    local l = listings[id]
    if not l then playerListing[cid] = nil; return false end

    local m = modeInfo(l.mode)
    local function removeFrom(arr)
        for i, c in ipairs(arr) do
            if c == cid then table.remove(arr, i); return true end
        end
        return false
    end

    if cid == l.host then
        Match.CancelListing(id)
        return true
    end

    if m.ffa then removeFrom(l.ffaPlayers)
    else removeFrom(l.teams[1]); removeFrom(l.teams[2]) end
    playerListing[cid] = nil
    broadcastListings()
    return true
end

function Match.CancelListing(id)
    local l = listings[id]
    if not l then return end
    local function clear(arr)
        for _, cid in ipairs(arr) do
            playerListing[cid] = nil
            local s = Framework.GetSourceByCitizenId(cid)
            if s then SendApp(s, "match:cancelled", { id = id }) end
        end
    end
    clear(l.teams[1]); clear(l.teams[2]); clear(l.ffaPlayers)
    listings[id] = nil
    broadcastListings()
end

function Match.TryStart(id)
    local l = listings[id]
    if not l or l.status ~= "open" then return end
    local m = modeInfo(l.mode)
    local req = requiredCounts(l)

    local ready
    if m.ffa then
        ready = (#l.ffaPlayers == req.ffa)
    else
        ready = (#l.teams[1] == req[1]) and (#l.teams[2] == req[2])
    end

    if Config.DebugSolo and not ready then
        local total = m.ffa and #l.ffaPlayers or (#l.teams[1] + #l.teams[2])
        if total >= 1 then
            dbg("DebugSolo: forcing start with", total, "player(s)")
            ready = true
        end
    end

    if not ready then return end

    Match.Start(l)
end

local function allParticipants(l, m)
    local list = {}
    if m.ffa then
        for _, cid in ipairs(l.ffaPlayers) do list[#list + 1] = cid end
    else
        for _, cid in ipairs(l.teams[1]) do list[#list + 1] = cid end
        for _, cid in ipairs(l.teams[2]) do list[#list + 1] = cid end
    end
    return list
end

function Match.Start(l)
    local m = modeInfo(l.mode)
    local participants = allParticipants(l, m)

    local sources = {}
    for _, cid in ipairs(participants) do
        local s = Framework.GetSourceByCitizenId(cid)
        if not s then
            Match.CancelListing(l.id)
            return
        end
        sources[cid] = s
    end

    local pot = 0
    if Config.Betting.enabled and l.bet > 0 then
        local charged = {}
        local ok = true
        for _, cid in ipairs(participants) do
            local s = sources[cid]
            if Framework.GetMoney(s, Config.Betting.account) >= l.bet
               and Framework.RemoveMoney(s, Config.Betting.account, l.bet, "gungame-bet") then
                charged[#charged + 1] = s
                pot = pot + l.bet
            else
                ok = false
                break
            end
        end
        if not ok then
            for _, s in ipairs(charged) do
                Framework.AddMoney(s, Config.Betting.account, l.bet, "gungame-bet-refund")
            end
            for _, cid in ipairs(participants) do
                local s = sources[cid]
                SendApp(s, "match:aborted", { reason = "bet" })
            end
            Match.CancelListing(l.id)
            return
        end
    end

    nextBucket = nextBucket + 1
    local bucket = nextBucket
    if Config.DisableArenaPopulation ~= false then
        SetRoutingBucketPopulationEnabled(bucket, false)
    end
    local arena = (l.arenaIndex and Config.Arenas[l.arenaIndex])
        or Config.Arenas[math.random(1, #Config.Arenas)]

    local s1, s2 = teamSizesOf(l, m)
    local match = {
        id = l.id, bucket = bucket, arena = arena, mode = l.mode, weapon = l.weapon,
        winType = l.winType, winValue = l.winValue, bet = l.bet, pot = pot,
        armor = l.armor and true or false,
        staminaDrain = l.staminaDrain ~= false,
        ffa = m.ffa, teamSize = m.teamSize, team1Size = s1, team2Size = s2,
        status = "countdown",
        players = {}, round = 1,
        teamKills = { [1] = 0, [2] = 0 },
        teamRoundWins = { [1] = 0, [2] = 0 },
        roundsPlayed = 0,
    }

    local function addPlayer(cid, team, spawn)
        match.players[cid] = {
            source = sources[cid], team = team, kills = 0, deaths = 0,
            alive = true, spawn = spawn,
        }
        playerMatch[cid] = match.id
        playerListing[cid] = nil
    end

    if m.ffa then
        local spawns = arena.ffaSpawns
        local order = {}
        for i = 1, #spawns do order[i] = i end
        for i = #order, 2, -1 do
            local j = math.random(i)
            order[i], order[j] = order[j], order[i]
        end
        for i, cid in ipairs(l.ffaPlayers) do
            local idx = order[((i - 1) % #order) + 1]
            addPlayer(cid, 0, spawns[idx])
        end
    else
        for t = 1, 2 do
            local spawns = arena.teams[t]
            for i, cid in ipairs(l.teams[t]) do
                addPlayer(cid, t, spawns[((i - 1) % #spawns) + 1])
            end
        end
    end

    matches[match.id] = match
    listings[l.id] = nil
    broadcastListings()

    local delay = Config.MatchStartDelay or 0
    match.status = "forming"
    for cid, pl in pairs(match.players) do
        TriggerClientEvent("gungame:phoneNotify", pl.source, {
            title = Config.Notify.matchFound or "マッチが成立しました！",
            content = delay > 0
                and (("%d秒後に試合会場へ移動します"):format(delay))
                or "まもなく試合会場へ移動します",
        })
        SendApp(pl.source, "match:found", { delay = delay, mode = match.mode, weapon = match.weapon })
        if delay > 0 then
            TriggerClientEvent("gungame:match:preCountdown", pl.source, { delay = delay })
        end
    end
    dbg("match formed", match.id, "begins in", delay, "s")

    CreateThread(function()
        if delay > 0 then Wait(delay * 1000) end
        if not matches[match.id] then return end
        Match.Begin(match)
    end)
end

function Match.Begin(match)
    if not matches[match.id] then return end
    match.status = "countdown"

    local invSwap = Framework.InvSwapReady()
    local ammoItem = Config.WeaponAmmoItem[match.weapon]

    local zoneCenter, zoneRadius
    if Config.Zone and Config.Zone.enabled and match.arena and match.arena.center then
        zoneCenter = match.arena.center
        zoneRadius = match.arena.radius or Config.Zone.defaultRadius
    end

    for cid, pl in pairs(match.players) do
        local ped = GetPlayerPed(pl.source)
        if ped and ped ~= 0 then
            local pc = GetEntityCoords(ped)
            local ph = GetEntityHeading(ped) + 0.0
            setReturnPos(cid, { x = pc.x + 0.0, y = pc.y + 0.0, z = pc.z + 0.0, h = ph })
            Framework.FreezeSavePosition(pl.source, pc.x, pc.y, pc.z, ph)
        end

        if invSwap then
            if Framework.ConfiscateInventory(pl.source) then
                setSwapped(cid, true)
                setLoadoutState(pl.source, true)
            end
        end

        SetPlayerRoutingBucket(pl.source, match.bucket)
        setInMatchState(pl.source, true)

        TriggerClientEvent("gungame:match:start", pl.source, {
            matchId = match.id,
            mode = match.mode,
            weapon = match.weapon,
            ammo = Config.WeaponAmmo,
            loadedAmmo = Config.WeaponLoadedAmmo,
            spawn = pl.spawn,
            team = pl.team,
            ffa = match.ffa,
            winType = match.winType,
            winValue = match.winValue,
            startHealth = Config.Combat.startHealth,
            startArmor = (match.armor and Config.Combat.startArmor or 0),
            staminaDrain = match.staminaDrain ~= false,
            countdown = Config.Combat.countdown,
            respawnDelay = Config.RespawnDelay,
            inventorySwap = invSwap,
            weaponSlot = nil,
            zoneCenter = zoneCenter and { x = zoneCenter.x, y = zoneCenter.y, z = zoneCenter.z } or nil,
            zoneRadius = zoneRadius,
        })

        local ch = teamRadioChannel(match, pl.team)
        if ch and Framework.RadioReady() then
            pl.prevRadio = Framework.GetPlayerRadio(pl.source)
            Framework.SetPlayerRadio(pl.source, ch)
            dbg("radio connected", cid, "team", pl.team, "channel", ch)
        end

        if invSwap then
            local sCid, sSrc, mid = cid, pl.source, match.id
            local closeDelay = Config.InventorySwap.phoneCloseDelay or 0
            local giveDelay = (closeDelay > 0) and closeDelay or 0.8
            CreateThread(function()
                Wait(math.floor(giveDelay * 1000))
                if not (matches[mid] and swapActive[sCid]) then return end
                local wslot = Framework.GiveArenaWeapon(sSrc, match.weapon, ammoItem, Config.WeaponAmmo)
                Framework.GiveArenaExtras(sSrc)
                Framework.GiveArenaAttachments(sSrc, match.weapon)
                TriggerClientEvent("gungame:match:arenaLoadout", sSrc, {
                    weapon = match.weapon,
                    ammo = Config.WeaponAmmo,
                    weaponSlot = wslot,
                })
                dbg("arena loadout given for", sCid, "weaponSlot", wslot)
            end)
        end
    end

    dbg("match started", match.id, "bucket", match.bucket)
    Match.PushState(match)

    CreateThread(function()
        Wait(Config.Combat.countdown * 1000)
        if not matches[match.id] then return end
        match.status = "running"
        match.roundStart = os.time()
        match.matchStart = os.time()
        for _, pl in pairs(match.players) do
            TriggerClientEvent("gungame:match:go", pl.source)
        end
        Match.StartTimer(match)
    end)
end

function Match.PushState(match)
    local scores
    if match.ffa then
        scores = {}
        for cid, pl in pairs(match.players) do
            local prof = Account.GetProfile(cid)
            scores[#scores + 1] = { name = prof and prof.name or "?", kills = pl.kills, alive = pl.alive }
        end
        table.sort(scores, function(a, b) return a.kills > b.kills end)
    end
    for _, pl in pairs(match.players) do
        TriggerClientEvent("gungame:match:state", pl.source, {
            winType = match.winType,
            winValue = match.winValue,
            round = match.round,
            teamKills = { t1 = match.teamKills[1], t2 = match.teamKills[2] },
            teamRoundWins = { t1 = match.teamRoundWins[1], t2 = match.teamRoundWins[2] },
            ffa = match.ffa,
            scores = scores,
        })
    end
end

function Match.StartTimer(match)
    CreateThread(function()
        while matches[match.id] and match.status == "running" do
            local limit
            if match.winType == "rounds" then
                limit = Config.TimeLimit.perRound
            elseif match.ffa then
                limit = Config.TimeLimit.ffa
            else
                limit = Config.TimeLimit.killRace
            end

            if limit and limit > 0 then
                local elapsed = os.time() - (match.winType == "rounds" and match.roundStart or match.matchStart)
                if elapsed >= limit then
                    Match.OnTimeout(match)
                    return
                end
            end
            Wait(1000)
        end
    end)
end

function Match.OnDeath(victimCid, killerCid)
    local mid = playerMatch[victimCid]
    if not mid then return end
    local match = matches[mid]
    if not match or match.status ~= "running" then return end

    local victim = match.players[victimCid]
    if not victim then return end
    victim.deaths = victim.deaths + 1
    victim.alive = false

    if killerCid and killerCid ~= victimCid then
        local killer = match.players[killerCid]
        if killer then
            local sameTeam = (not match.ffa) and (killer.team == victim.team)
            if not sameTeam then
                killer.kills = killer.kills + 1
                if not match.ffa then
                    match.teamKills[killer.team] = match.teamKills[killer.team] + 1
                end
                if match.winType == "kills" and killer.alive then
                    local hc = Config.Combat and Config.Combat.killHeal
                    if hc and ((hc.health or 0) > 0 or (hc.armor or 0) > 0) then
                        TriggerClientEvent("gungame:match:heal", killer.source, {
                            health = hc.health or 0,
                            armor  = hc.armor or 0,
                        })
                    end
                end
            end
        end
    end

    Match.PushState(match)

    if match.winType == "kills" then
        Match.CheckKillRace(match)
        if matches[mid] then
            Match.ScheduleRespawn(match, victimCid)
        end
    else
        TriggerClientEvent("gungame:match:spectate", victim.source)
        Match.CheckRoundElimination(match)
    end
end

function Match.ScheduleRespawn(match, cid)
    CreateThread(function()
        Wait(Config.RespawnDelay * 1000)
        if not matches[match.id] or match.status ~= "running" then return end
        local pl = match.players[cid]
        if not pl then return end
        pl.alive = true
        Framework.Revive(pl.source)
        Wait(250)
        if not matches[match.id] then return end
        local spawn = pl.spawn
        if match.ffa and match.arena and match.arena.ffaSpawns and #match.arena.ffaSpawns > 0 then
            spawn = match.arena.ffaSpawns[math.random(#match.arena.ffaSpawns)]
        end
        TriggerClientEvent("gungame:match:respawn", pl.source, { spawn = spawn })
    end)
end

function Match.CheckKillRace(match)
    if match.ffa then
        for cid, pl in pairs(match.players) do
            if pl.kills >= match.winValue then
                Match.Finish(match, { ffaWinner = cid })
                return
            end
        end
    else
        for t = 1, 2 do
            if match.teamKills[t] >= match.winValue then
                Match.Finish(match, { winningTeam = t })
                return
            end
        end
    end
end

local function aliveCount(match, team)
    local n = 0
    for _, pl in pairs(match.players) do
        if pl.team == team and pl.alive then n = n + 1 end
    end
    return n
end

local function tieBreakByKills(match)
    if match.teamKills[1] > match.teamKills[2] then return 1
    elseif match.teamKills[2] > match.teamKills[1] then return 2
    else return nil end
end

function Match.CheckRoundElimination(match)
    local a1, a2 = aliveCount(match, 1), aliveCount(match, 2)
    if a1 > 0 and a2 > 0 then return end

    local roundWinner
    if a1 > 0 and a2 == 0 then roundWinner = 1
    elseif a2 > 0 and a1 == 0 then roundWinner = 2
    else roundWinner = tieBreakByKills(match) end

    Match.ResolveRound(match, roundWinner)
end

function Match.ResolveRound(match, roundWinner)
    match.roundsPlayed = match.roundsPlayed + 1
    if roundWinner then
        match.teamRoundWins[roundWinner] = match.teamRoundWins[roundWinner] + 1
    end

    for t = 1, 2 do
        if match.teamRoundWins[t] >= match.winValue then
            Match.Finish(match, { winningTeam = t })
            return
        end
    end

    local cap = match.winValue * 6 + 10
    if match.roundsPlayed >= cap then
        if match.teamRoundWins[1] ~= match.teamRoundWins[2] then
            Match.Finish(match, { winningTeam = match.teamRoundWins[1] > match.teamRoundWins[2] and 1 or 2 })
        elseif match.teamKills[1] ~= match.teamKills[2] then
            Match.Finish(match, { winningTeam = match.teamKills[1] > match.teamKills[2] and 1 or 2 })
        else
            Match.Finish(match, { draw = true })
        end
        return
    end

    match.round = match.round + 1
    Match.PushState(match)
    for _, pl in pairs(match.players) do
        if not pl.alive then Framework.Revive(pl.source) end
        pl.alive = true
    end
    match.roundStart = os.time()
    local mid = match.id
    local roundNum = match.round
    local rc = (Config.Combat and Config.Combat.roundCountdown) or 0
    CreateThread(function()
        Wait(300)
        local m = matches[mid]
        if not m or m.status ~= "running" then return end
        for _, pl in pairs(m.players) do
            TriggerClientEvent("gungame:match:roundReset", pl.source, {
                round = roundNum, spawn = pl.spawn, countdown = rc,
            })
        end
        if rc > 0 then Wait(rc * 1000) end
        local m2 = matches[mid]
        if not m2 or m2.status ~= "running" then return end
        m2.roundStart = os.time()
        for _, pl in pairs(m2.players) do
            TriggerClientEvent("gungame:match:roundGo", pl.source)
        end
    end)
end

function Match.OnTimeout(match)
    if match.winType == "rounds" then
        local a1, a2 = aliveCount(match, 1), aliveCount(match, 2)
        local rw
        if a1 ~= a2 then rw = a1 > a2 and 1 or 2
        elseif match.teamKills[1] ~= match.teamKills[2] then
            rw = match.teamKills[1] > match.teamKills[2] and 1 or 2
        else rw = nil end
        Match.ResolveRound(match, rw)
        if matches[match.id] and match.status == "running" then
            Match.StartTimer(match)
        end
    else
        if match.ffa then
            local best, bestCid, tie = -1, nil, false
            for cid, pl in pairs(match.players) do
                if pl.kills > best then best = pl.kills; bestCid = cid; tie = false
                elseif pl.kills == best then tie = true end
            end
            if tie or not bestCid then Match.Finish(match, { draw = true })
            else Match.Finish(match, { ffaWinner = bestCid }) end
        else
            if match.teamKills[1] ~= match.teamKills[2] then
                Match.Finish(match, { winningTeam = match.teamKills[1] > match.teamKills[2] and 1 or 2 })
            else
                Match.Finish(match, { draw = true })
            end
        end
    end
end

function Match.Finish(match, result)
    if match.status == "finished" then return end
    match.status = "finished"

    local winners = {}
    if result.winningTeam then
        for cid, pl in pairs(match.players) do
            if pl.team == result.winningTeam then winners[cid] = true end
        end
    elseif result.ffaWinner then
        winners[result.ffaWinner] = true
    end

    if Config.Betting.enabled and match.pot > 0 then
        if result.draw then
            for cid, pl in pairs(match.players) do
                Framework.AddMoney(pl.source, Config.Betting.account, match.bet, "gungame-bet-refund")
            end
        else
            local winnerList = {}
            for cid in pairs(winners) do winnerList[#winnerList + 1] = cid end
            local share = math.floor(match.pot / math.max(1, #winnerList))
            local remainder = match.pot - share * #winnerList
            for i, cid in ipairs(winnerList) do
                local pl = match.players[cid]
                local amt = share + (i == 1 and remainder or 0)
                Framework.AddMoney(pl.source, Config.Betting.account, amt, "gungame-payout")
            end
        end
    end

    for cid, pl in pairs(match.players) do
        local outcome
        if result.draw then outcome = "draw"
        elseif winners[cid] then outcome = "win"
        else outcome = "loss" end

        local applied = Account.ApplyResult(cid, { kills = pl.kills, outcome = outcome })

        if not pl.alive then Framework.Revive(pl.source) end

        TriggerClientEvent("gungame:match:end", pl.source, {
            outcome = outcome,
            kills = pl.kills,
            deaths = pl.deaths,
            xpGained = applied and applied.xpGained or 0,
            level = applied and applied.level or nil,
            leveledUp = applied and applied.leveledUp or false,
            pot = (not result.draw and winners[cid]) and match.pot or 0,
        })

        if not match.ffa and Framework.RadioReady() then
            Framework.SetPlayerRadio(pl.source, pl.prevRadio or 0)
        end

        TriggerEvent("gungame:standIn:serverRemove", pl.source)

        SetPlayerRoutingBucket(pl.source, 0)
        setInMatchState(pl.source, false)
        playerMatch[cid] = nil
        clearReturnPos(cid)
        do
            local usrc = pl.source
            SetTimeout(((Config.ResultDisplay and Config.ResultDisplay.duration or 5) + 3) * 1000, function()
                Framework.UnfreezeSavePosition(usrc)
            end)
        end
        local rcid, rsrc, rweapon = cid, pl.source, match.weapon
        SetTimeout(300, function()
            if not restorePlayerInventory(rcid, rsrc) then
                scheduleRestoreRetry(rcid, rsrc)
            end
            if Config.Debug then
                SetTimeout(800, function()
                    local item = string.upper(rweapon or "")
                    local wcnt = 0
                    pcall(function() wcnt = exports[Config.InventorySwap.resource]:Search(rsrc, "count", item) or 0 end)
                    print(("^3[gungame] post-restore check: %s server-side arena weapon %s count=%d^0"):format(tostring(rcid), item, wcnt))
                end)
            end
        end)
    end

    matches[match.id] = nil
    dbg("match finished", match.id, result.winningTeam or result.ffaWinner or "draw")
end

function Match.OnPlayerDrop(cid)
    if playerListing[cid] then
        Match.LeaveListing(cid)
    end

    local mid = playerMatch[cid]
    if not mid then return end
    local match = matches[mid]
    if not match then playerMatch[cid] = nil; return end

    local pl = match.players[cid]
    if not pl then return end

    if match.ffa then
        match.players[cid] = nil
        playerMatch[cid] = nil
        local remaining = {}
        for c in pairs(match.players) do remaining[#remaining + 1] = c end
        if #remaining == 1 then
            Match.Finish(match, { ffaWinner = remaining[1] })
        elseif #remaining == 0 then
            match.status = "finished"
            matches[mid] = nil
        else
            Match.PushState(match)
        end
    else
        local losingTeam = pl.team
        match.players[cid] = nil
        playerMatch[cid] = nil
        local winTeam = losingTeam == 1 and 2 or 1
        Match.Finish(match, { winningTeam = winTeam })
    end
end

function Match.Forfeit(cid)
    if playerListing[cid] then
        Match.LeaveListing(cid)
        return
    end

    local mid = playerMatch[cid]
    if not mid then return end
    local match = matches[mid]
    if not match then playerMatch[cid] = nil; return end
    local pl = match.players[cid]
    if not pl then return end

    if pl.forfeiting then return end
    pl.forfeiting = true

    local lockSecs = (Config.InventorySwap and Config.InventorySwap.lockSeconds) or 3
    TriggerClientEvent("gungame:match:lockInv", pl.source, lockSecs)

    Match.DoForfeit(cid)
end

function Match.DoForfeit(cid)
    local mid = playerMatch[cid]
    if not mid then return end
    local match = matches[mid]
    if not match then playerMatch[cid] = nil; return end
    local pl = match.players[cid]
    if not pl then return end

    if match.ffa then
        local applied = Account.ApplyResult(cid, { kills = pl.kills, outcome = "loss" })
        TriggerClientEvent("gungame:match:end", pl.source, {
            outcome = "loss", kills = pl.kills, deaths = pl.deaths,
            xpGained = applied and applied.xpGained or 0,
            level = applied and applied.level or nil,
            leveledUp = applied and applied.leveledUp or false,
            pot = 0,
        })
        TriggerEvent("gungame:standIn:serverRemove", pl.source)

        SetPlayerRoutingBucket(pl.source, 0)
        setInMatchState(pl.source, false)
        match.players[cid] = nil
        playerMatch[cid] = nil
        clearReturnPos(cid)
        do
            local usrc = pl.source
            SetTimeout(((Config.ResultDisplay and Config.ResultDisplay.duration or 5) + 3) * 1000, function()
                Framework.UnfreezeSavePosition(usrc)
            end)
        end
        local rcid, rsrc = cid, pl.source
        SetTimeout(300, function()
            if not restorePlayerInventory(rcid, rsrc) then
                scheduleRestoreRetry(rcid, rsrc)
            end
        end)

        local remaining = {}
        for c in pairs(match.players) do remaining[#remaining + 1] = c end
        if #remaining == 1 then
            Match.Finish(match, { ffaWinner = remaining[1] })
        elseif #remaining == 0 then
            match.status = "finished"
            matches[mid] = nil
        else
            Match.PushState(match)
        end
    else
        local winTeam = pl.team == 1 and 2 or 1
        Match.Finish(match, { winningTeam = winTeam })
    end
end

function Match.RestoreOnLoad(src, cid)
    if not swapActive[cid] then return end
    CreateThread(function()
        for attempt = 1, 12 do
            Wait(2000)
            if not swapActive[cid] then return end
            local s = Framework.GetSourceByCitizenId(cid) or src
            if s then
                SetPlayerRoutingBucket(s, 0)
                if restorePlayerInventory(cid, s) then
                    dbg("RestoreOnLoad done", cid, "attempt", attempt)
                    return
                end
            end
        end
        dbg("RestoreOnLoad gave up (still pending)", cid)
    end)
end

CreateThread(function()
    while true do
        Wait(3000)
        for cid in pairs(swapActive) do
            if not playerMatch[cid] then
                local s = Framework.GetSourceByCitizenId(cid)
                if s then
                    SetPlayerRoutingBucket(s, 0)
                    if restorePlayerInventory(cid, s) then
                        dbg("sweep restored inventory", cid)
                    end
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, match in pairs(matches) do
        for _, pl in pairs(match.players) do
            setInMatchState(pl.source, false)
            if not match.ffa and Framework.RadioReady() then
                Framework.SetPlayerRadio(pl.source, pl.prevRadio or 0)
            end
        end
    end
    for cid in pairs(swapActive) do
        local s = Framework.GetSourceByCitizenId(cid)
        if s then restorePlayerInventory(cid, s) end
    end
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    loadSwapKvp()
    loadReturnPosKvp()
    for _, pidStr in ipairs(GetPlayers()) do
        setInMatchState(tonumber(pidStr), false)
    end
    CreateThread(function()
        Wait(3000)
        for attempt = 1, 12 do
            local remaining = 0
            for cid in pairs(swapActive) do
                local s = Framework.GetSourceByCitizenId(cid)
                if s then
                    SetPlayerRoutingBucket(s, 0)
                    Framework.UnfreezeSavePosition(s)
                    if not restorePlayerInventory(cid, s) then
                        remaining = remaining + 1
                    end
                end
            end
            if remaining == 0 then break end
            Wait(2000)
        end
        dbg("recovered swapped inventories on start")
    end)
end)

function Match.GetListings()
    return listingsView()
end

function Match.IsInMatch(cid)
    return playerMatch[cid] ~= nil
end

exports("IsPlayerInMatch", function(source)
    local cid = Framework.GetCitizenId(source)
    if not cid then return false end
    return playerMatch[cid] ~= nil
end)

function Match.GetPlayerStatus(cid)
    if playerMatch[cid] then return "in_match" end
    if playerListing[cid] then return "in_listing" end
    return "idle"
end

function Match.GetPlayerMatchView(cid)
    local mid = playerMatch[cid]
    if not mid then return nil end
    local match = matches[mid]
    if not match then return nil end
    local pl = match.players[cid]
    if not pl then return nil end

    local phase = (match.status == "running") and "running" or "countdown"

    local info = {
        mode     = match.mode,
        weapon   = match.weapon,
        team     = pl.team,
        ffa      = match.ffa,
        winType  = match.winType,
        winValue = match.winValue,
        countdown = Config.Combat.countdown,
    }

    local scores
    if match.ffa then
        scores = {}
        for c, p in pairs(match.players) do
            local prof = Account.GetProfile(c)
            scores[#scores + 1] = { name = prof and prof.name or "?", kills = p.kills, alive = p.alive }
        end
        table.sort(scores, function(a, b) return a.kills > b.kills end)
    end

    local st = {
        winType       = match.winType,
        winValue      = match.winValue,
        round         = match.round,
        teamKills     = { t1 = match.teamKills[1], t2 = match.teamKills[2] },
        teamRoundWins = { t1 = match.teamRoundWins[1], t2 = match.teamRoundWins[2] },
        ffa           = match.ffa,
        scores        = scores,
    }

    local spectating = (match.winType == "rounds") and (pl.alive == false) or false

    return { phase = phase, info = info, state = st, spectating = spectating }
end
