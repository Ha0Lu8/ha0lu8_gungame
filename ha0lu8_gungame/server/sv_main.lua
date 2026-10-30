local sourceToCid = {}

local function dbg(...)
    if Config.Debug then print("[gungame:main]", ...) end
end

function SendApp(source, event, data)
    if not source then return end
    TriggerClientEvent("gungame:toUI", source, event, data)
end

function BroadcastApp(event, data)
    for _, src in ipairs(Framework.GetPlayers()) do
        local cid = sourceToCid[src] or Framework.GetCitizenId(src)
        if cid and Account.Get(cid) then
            SendApp(src, event, data)
        end
    end
end

local function buildInit(source, cid)
    local profile = Account.GetProfile(cid)
    if not profile then
        return { registered = false }
    end
    return {
        registered = true,
        profile    = profile,
        status     = Match.GetPlayerStatus(cid),
        match      = Match.GetPlayerMatchView(cid),
        listings   = Match.GetListings(),
        friends    = Social.GetFriends(cid),
        requests   = Social.GetFriendRequests(cid),
        rankings   = Account.GetRankings(),
        config     = {
            modes        = Config.Modes,
            modeOrder    = Config.ModeOrder,
            winConditions = Config.WinConditions,
            ffa          = Config.FFA,
            custom       = Config.Custom,
            arenas       = (function()
                local t = {}
                for i, a in ipairs(Config.Arenas) do
                    t[#t + 1] = { index = i, name = a.name }
                end
                return t
            end)(),
            betting      = { enabled = Config.Betting.enabled, min = Config.Betting.min, max = Config.Betting.max },
            weapons      = Config.Weapons,
            account      = Config.Account,
            partyMaxSize = Config.Social.partyMaxSize,
            uiSounds     = not (Config.Sounds and Config.Sounds.uiEnabled == false),
        },
    }
end

CreateThread(function()
    local QBCore = Framework.GetCore()
    while not QBCore do Wait(100); QBCore = Framework.GetCore() end

    QBCore.Functions.CreateCallback("gungame:getInit", function(source, cb)
        local cid = Framework.GetCitizenId(source)
        sourceToCid[source] = cid
        cb(buildInit(source, cid))
    end)

    QBCore.Functions.CreateCallback("gungame:register", function(source, cb, data)
        local cid = Framework.GetCitizenId(source)
        if not cid then cb({ ok = false, err = "no_player" }); return end
        local ok, err = Account.Register(cid, data.name, data.accountId, data.icon)
        if ok then
            sourceToCid[source] = cid
            cb({ ok = true, init = buildInit(source, cid) })
        else
            cb({ ok = false, err = err })
        end
    end)

    QBCore.Functions.CreateCallback("gungame:getRankings", function(source, cb)
        cb(Account.GetRankings())
    end)

    QBCore.Functions.CreateCallback("gungame:updateProfile", function(source, cb, data)
        local cid = Framework.GetCitizenId(source)
        if not cid then cb({ ok = false, err = "no_player" }); return end
        local ok, err = Account.UpdateProfile(cid, data.name, data.icon)
        if ok then
            Social.RefreshParty(cid)
            cb({ ok = true, profile = Account.GetProfile(cid) })
        else
            cb({ ok = false, err = err })
        end
    end)

    QBCore.Functions.CreateCallback("gungame:createListing", function(source, cb, data)
        local cid = Framework.GetCitizenId(source)
        local ok, err, id = Match.CreateListing(cid, data)
        cb({ ok = ok, err = err, id = id })
    end)

    QBCore.Functions.CreateCallback("gungame:joinListing", function(source, cb, data)
        local cid = Framework.GetCitizenId(source)
        local ok, err = Match.JoinListing(cid, data.id, data.side)
        cb({ ok = ok, err = err })
    end)

    QBCore.Functions.CreateCallback("gungame:friendRequest", function(source, cb, data)
        local cid = Framework.GetCitizenId(source)
        local ok, err = Social.SendFriendRequest(cid, data.accountId)
        cb({ ok = ok, err = err })
    end)

    QBCore.Functions.CreateCallback("gungame:partyInvite", function(source, cb, data)
        local cid = Framework.GetCitizenId(source)
        local ok, err = Social.InviteToParty(cid, data.accountId)
        cb({ ok = ok, err = err })
    end)
end)

RegisterNetEvent("gungame:leaveListing", function()
    local cid = Framework.GetCitizenId(source)
    if cid then Match.LeaveListing(cid) end
end)

RegisterNetEvent("gungame:cancelListing", function()
    local cid = Framework.GetCitizenId(source)
    if cid then Match.LeaveListing(cid) end
end)

RegisterNetEvent("gungame:forfeit", function()
    local cid = Framework.GetCitizenId(source)
    if cid then Match.Forfeit(cid) end
end)

RegisterNetEvent("gungame:reportDeath", function(killerServerId)
    local victimCid = Framework.GetCitizenId(source)
    if not victimCid then return end
    local killerCid = nil
    if killerServerId and killerServerId ~= 0 and killerServerId ~= source then
        killerCid = Framework.GetCitizenId(killerServerId)
    end
    Match.OnDeath(victimCid, killerCid)
end)

RegisterNetEvent("gungame:acceptFriend", function(fromCid)
    local cid = Framework.GetCitizenId(source)
    if cid then Social.AcceptFriendRequest(cid, fromCid) end
end)
RegisterNetEvent("gungame:declineFriend", function(fromCid)
    local cid = Framework.GetCitizenId(source)
    if cid then Social.DeclineFriendRequest(cid, fromCid) end
end)
RegisterNetEvent("gungame:removeFriend", function(friendCid)
    local cid = Framework.GetCitizenId(source)
    if cid then Social.RemoveFriend(cid, friendCid) end
end)

RegisterNetEvent("gungame:acceptParty", function(partyId)
    local cid = Framework.GetCitizenId(source)
    if cid then
        local ok = Social.AcceptPartyInvite(cid, partyId)
    end
end)
RegisterNetEvent("gungame:declineParty", function(partyId)
    local cid = Framework.GetCitizenId(source)
    if cid then Social.DeclinePartyInvite(cid, partyId) end
end)
RegisterNetEvent("gungame:leaveParty", function()
    local cid = Framework.GetCitizenId(source)
    if cid then Social.LeaveParty(cid) end
end)
RegisterNetEvent("gungame:kickParty", function(targetCid)
    local cid = Framework.GetCitizenId(source)
    if cid then Social.KickFromParty(cid, targetCid) end
end)
RegisterNetEvent("gungame:syncParty", function()
    local cid = Framework.GetCitizenId(source)
    if cid then Social.SyncParty(source, cid) end
end)

AddEventHandler("QBCore:Server:OnPlayerLoaded", function(Player)
    local src = Player.PlayerData.source
    local cid = Player.PlayerData.citizenid
    sourceToCid[src] = cid
    Match.RestoreOnLoad(src, cid)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local cid = sourceToCid[src]
    if cid then
        Match.OnPlayerDrop(cid)
        Social.OnPlayerDrop(cid)
        Account.ClearCache(cid)
        sourceToCid[src] = nil
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, src in ipairs(Framework.GetPlayers()) do
        SetPlayerRoutingBucket(src, 0)
    end
end)
