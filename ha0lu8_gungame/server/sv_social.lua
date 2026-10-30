Social = {}

local function dbg(...)
    if Config.Debug then print("[gungame:social]", ...) end
end


function Social.GetFriends(citizenid)
    local rows = MySQL.query.await([[
        SELECT a.citizenid AS citizenid, a.account_id AS accountId, a.name AS name,
               a.icon AS icon, a.level AS level
        FROM gungame_friends f
        JOIN gungame_accounts a ON a.citizenid = f.friend_citizenid
        WHERE f.citizenid = ?
        ORDER BY a.name ASC
    ]], { citizenid }) or {}

    for _, r in ipairs(rows) do
        r.online = Framework.GetSourceByCitizenId(r.citizenid) ~= nil
        r.inParty = Social.GetPartyId(r.citizenid) ~= nil
    end
    return rows
end

function Social.GetFriendRequests(citizenid)
    return MySQL.query.await([[
        SELECT a.citizenid AS citizenid, a.account_id AS accountId, a.name AS name, a.icon AS icon
        FROM gungame_friend_requests r
        JOIN gungame_accounts a ON a.citizenid = r.from_cid
        WHERE r.to_cid = ?
        ORDER BY r.created_at ASC
    ]], { citizenid }) or {}
end

function Social.SendFriendRequest(fromCid, toAccountId)
    local target = Account.GetByAccountId(toAccountId)
    if not target then return false, "user_not_found" end
    local toCid = target.citizenid
    if toCid == fromCid then return false, "cannot_add_self" end

    local exists = MySQL.scalar.await(
        "SELECT 1 FROM gungame_friends WHERE citizenid = ? AND friend_citizenid = ?",
        { fromCid, toCid })
    if exists then return false, "already_friends" end

    local cnt = MySQL.scalar.await(
        "SELECT COUNT(*) FROM gungame_friends WHERE citizenid = ?", { fromCid }) or 0
    if cnt >= Config.Social.maxFriends then return false, "friend_limit" end

    local reverse = MySQL.scalar.await(
        "SELECT 1 FROM gungame_friend_requests WHERE from_cid = ? AND to_cid = ?",
        { toCid, fromCid })
    if reverse then
        Social.AcceptFriendRequest(fromCid, toCid)
        return true, nil
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO gungame_friend_requests (from_cid, to_cid) VALUES (?, ?)
    ]], { fromCid, toCid })

    local toSrc = Framework.GetSourceByCitizenId(toCid)
    if toSrc then
        SendApp(toSrc, "friends:requests", Social.GetFriendRequests(toCid))
        SendApp(toSrc, "notify", { type = "friend_request", message = "新しいフレンド申請があります" })
    end
    return true, nil
end

function Social.AcceptFriendRequest(cid, fromCid)
    local req = MySQL.scalar.await(
        "SELECT 1 FROM gungame_friend_requests WHERE from_cid = ? AND to_cid = ?",
        { fromCid, cid })
    if not req then return false, "no_request" end

    MySQL.query.await(
        "DELETE FROM gungame_friend_requests WHERE from_cid = ? AND to_cid = ?",
        { fromCid, cid })
    MySQL.query.await([[
        INSERT IGNORE INTO gungame_friends (citizenid, friend_citizenid) VALUES (?, ?), (?, ?)
    ]], { cid, fromCid, fromCid, cid })

    local function refresh(c)
        local s = Framework.GetSourceByCitizenId(c)
        if s then
            SendApp(s, "friends:list", Social.GetFriends(c))
            SendApp(s, "friends:requests", Social.GetFriendRequests(c))
        end
    end
    refresh(cid)
    refresh(fromCid)
    return true, nil
end

function Social.DeclineFriendRequest(cid, fromCid)
    MySQL.query.await(
        "DELETE FROM gungame_friend_requests WHERE from_cid = ? AND to_cid = ?",
        { fromCid, cid })
    return true
end

function Social.RemoveFriend(cid, friendCid)
    MySQL.query.await([[
        DELETE FROM gungame_friends
        WHERE (citizenid = ? AND friend_citizenid = ?)
           OR (citizenid = ? AND friend_citizenid = ?)
    ]], { cid, friendCid, friendCid, cid })
    local function refresh(c)
        local s = Framework.GetSourceByCitizenId(c)
        if s then SendApp(s, "friends:list", Social.GetFriends(c)) end
    end
    refresh(cid)
    refresh(friendCid)
    return true
end

local parties = {}
local playerParty = {}
local nextPartyId = 1

function Social.GetPartyId(citizenid)
    return playerParty[citizenid]
end

function Social.GetParty(citizenid)
    local pid = playerParty[citizenid]
    if not pid then return nil end
    return parties[pid]
end

function Social.GetPartyMembers(citizenid)
    local p = Social.GetParty(citizenid)
    if not p then return { citizenid } end
    return p.members
end

local function buildPartyView(p, viewerCid)
    if not p then return nil end
    local members = {}
    for _, cid in ipairs(p.members) do
        local prof = Account.GetProfile(cid)
        if prof then
            members[#members + 1] = {
                citizenid = cid,
                accountId = prof.accountId,
                name      = prof.name,
                icon      = prof.icon,
                level     = prof.level,
                isLeader  = (cid == p.leader),
                online    = Framework.GetSourceByCitizenId(cid) ~= nil,
            }
        end
    end
    return {
        id = p.id,
        leader = p.leader,
        size = #p.members,
        max = Config.Social.partyMaxSize,
        members = members,
        isLeader = (viewerCid == p.leader),
    }
end

local function pushPartyUpdate(p)
    if not p then return end
    for _, cid in ipairs(p.members) do
        local s = Framework.GetSourceByCitizenId(cid)
        if s then SendApp(s, "party:update", buildPartyView(p, cid)) end
    end
end

function Social.SyncParty(source, citizenid)
    SendApp(source, "party:update", buildPartyView(Social.GetParty(citizenid), citizenid))
end

function Social.RefreshParty(citizenid)
    local p = Social.GetParty(citizenid)
    if p then pushPartyUpdate(p) end
end

function Social.InviteToParty(leaderCid, targetAccountId)
    local target = Account.GetByAccountId(targetAccountId)
    if not target then return false, "user_not_found" end
    local targetCid = target.citizenid
    if targetCid == leaderCid then return false, "cannot_invite_self" end

    local targetSrc = Framework.GetSourceByCitizenId(targetCid)
    if not targetSrc then return false, "target_offline" end

    if playerParty[targetCid] then return false, "target_in_party" end

    local pid = playerParty[leaderCid]
    local p
    if pid then
        p = parties[pid]
        if p.leader ~= leaderCid then return false, "not_leader" end
    else
        pid = nextPartyId
        nextPartyId = nextPartyId + 1
        p = { id = pid, leader = leaderCid, members = { leaderCid }, invites = {} }
        parties[pid] = p
        playerParty[leaderCid] = pid
    end

    if #p.members >= Config.Social.partyMaxSize then
        return false, "party_full"
    end

    p.invites[targetCid] = os.time() + Config.Social.inviteTimeout

    local leaderProf = Account.GetProfile(leaderCid)
    SendApp(targetSrc, "party:invite", {
        partyId = pid,
        from = leaderProf and leaderProf.name or "?",
        fromAccountId = leaderProf and leaderProf.accountId or "?",
    })
    pushPartyUpdate(p)
    return true, nil
end

function Social.AcceptPartyInvite(citizenid, partyId)
    local p = parties[partyId]
    if not p then return false, "party_gone" end
    if playerParty[citizenid] then return false, "already_in_party" end

    local exp = p.invites[citizenid]
    if not exp or exp < os.time() then
        p.invites[citizenid] = nil
        return false, "invite_expired"
    end
    if #p.members >= Config.Social.partyMaxSize then
        return false, "party_full"
    end

    p.invites[citizenid] = nil
    p.members[#p.members + 1] = citizenid
    playerParty[citizenid] = partyId
    pushPartyUpdate(p)
    return true, nil
end

function Social.DeclinePartyInvite(citizenid, partyId)
    local p = parties[partyId]
    if p then p.invites[citizenid] = nil end
    return true
end

local function disband(p)
    if not p then return end
    for _, cid in ipairs(p.members) do
        playerParty[cid] = nil
        local s = Framework.GetSourceByCitizenId(cid)
        if s then SendApp(s, "party:update", nil) end
    end
    parties[p.id] = nil
end

function Social.LeaveParty(citizenid)
    local pid = playerParty[citizenid]
    if not pid then return false end
    local p = parties[pid]
    if not p then playerParty[citizenid] = nil; return false end

    if p.leader == citizenid then
        disband(p)
        return true
    end

    for i, cid in ipairs(p.members) do
        if cid == citizenid then
            table.remove(p.members, i)
            break
        end
    end
    playerParty[citizenid] = nil
    local s = Framework.GetSourceByCitizenId(citizenid)
    if s then SendApp(s, "party:update", nil) end

    if #p.members <= 1 then
        disband(p)
    else
        pushPartyUpdate(p)
    end
    return true
end

function Social.KickFromParty(leaderCid, targetCid)
    local pid = playerParty[leaderCid]
    if not pid then return false, "not_in_party" end
    local p = parties[pid]
    if p.leader ~= leaderCid then return false, "not_leader" end
    if targetCid == leaderCid then return false, "cannot_kick_self" end

    for i, cid in ipairs(p.members) do
        if cid == targetCid then
            table.remove(p.members, i)
            playerParty[targetCid] = nil
            local s = Framework.GetSourceByCitizenId(targetCid)
            if s then SendApp(s, "party:update", nil) end
            break
        end
    end
    if #p.members <= 1 then disband(p) else pushPartyUpdate(p) end
    return true, nil
end

function Social.DisbandParty(leaderCid)
    local pid = playerParty[leaderCid]
    if not pid then return false end
    local p = parties[pid]
    if p.leader ~= leaderCid then return false end
    disband(p)
    return true
end

function Social.OnPlayerDrop(citizenid)
    if not citizenid then return end
    Social.LeaveParty(citizenid)
end
