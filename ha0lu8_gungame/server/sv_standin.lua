local standIns = {}
local sentTo   = {}

local SYNC_DISTANCE_SQ = 150.0 * 150.0

local function despawnForAll(ownerSrc)
    local targets = sentTo[ownerSrc]
    if targets then
        for target in pairs(targets) do
            TriggerClientEvent("gungame:standIn:despawn", target, ownerSrc)
        end
    end
    sentTo[ownerSrc] = nil
end

local function removeStandIn(ownerSrc)
    standIns[ownerSrc] = nil
    despawnForAll(ownerSrc)
end

RegisterNetEvent("gungame:standIn:create", function(coords, heading, model, appearance)
    if not (Config.StandIn and Config.StandIn.enabled) then return end
    local src = source
    if not coords then return end
    removeStandIn(src)
    local tagId, tagName
    local ok, cid = pcall(Framework.GetCitizenId, src)
    if ok and cid and Account and Account.GetProfile then
        local p = Account.GetProfile(cid)
        if p then tagId = p.accountId end
    end
    local okn, cn = pcall(Framework.GetCharName, src)
    if okn and cn then tagName = cn end
    standIns[src] = {
        coords     = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
        heading    = heading or 0.0,
        model      = Config.StandIn.model or model,
        appearance = appearance,
        anim       = Config.StandIn.anim,
        alpha      = Config.StandIn.alpha,
        tagId      = tagId,
        tagName    = tagName,
    }
    sentTo[src] = {}
end)

RegisterNetEvent("gungame:standIn:remove", function()
    removeStandIn(source)
end)

AddEventHandler("gungame:standIn:serverRemove", function(src)
    removeStandIn(src)
end)

AddEventHandler("playerDropped", function()
    local src = source
    removeStandIn(src)
    for _, targets in pairs(sentTo) do
        targets[src] = nil
    end
end)

CreateThread(function()
    while true do
        for owner, data in pairs(standIns) do
            local oc = data.coords
            sentTo[owner] = sentTo[owner] or {}
            for _, pidStr in ipairs(GetPlayers()) do
                local p = tonumber(pidStr)
                local shouldSee = false
                if p ~= owner and GetPlayerRoutingBucket(p) == 0 then
                    local ped = GetPlayerPed(p)
                    if ped and ped ~= 0 then
                        local pc = GetEntityCoords(ped)
                        local dx, dy, dz = pc.x - oc.x, pc.y - oc.y, pc.z - oc.z
                        if (dx * dx + dy * dy + dz * dz) <= SYNC_DISTANCE_SQ then
                            shouldSee = true
                        end
                    end
                end

                local has = sentTo[owner][p]
                if shouldSee and not has then
                    TriggerClientEvent("gungame:standIn:spawn", p, owner, data)
                    sentTo[owner][p] = true
                elseif has and not shouldSee then
                    TriggerClientEvent("gungame:standIn:despawn", p, owner)
                    sentTo[owner][p] = nil
                end
            end
        end
        Wait(2000)
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for owner in pairs(standIns) do despawnForAll(owner) end
    standIns = {}
end)
