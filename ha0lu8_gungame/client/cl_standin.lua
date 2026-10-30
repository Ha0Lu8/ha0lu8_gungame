local localPeds   = {}
local propByOwner = {}
local tagByOwner  = {}

local function despawn(ownerSrc)
    local prop = propByOwner[ownerSrc]
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteObject(prop)
    end
    propByOwner[ownerSrc] = nil
    tagByOwner[ownerSrc] = nil
    local ped = localPeds[ownerSrc]
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    localPeds[ownerSrc] = nil
end

local function loadModel(hash)
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 100 do
        Wait(10)
        tries = tries + 1
    end
    return HasModelLoaded(hash)
end

local function applyAnimAndProp(ownerSrc, ped, anim, alpha)
    if not anim then return end
    if anim.dict and anim.name then
        if not HasAnimDictLoaded(anim.dict) then
            RequestAnimDict(anim.dict)
            local t = 0
            while not HasAnimDictLoaded(anim.dict) and t < 100 do Wait(10); t = t + 1 end
        end
        TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, -1, anim.flag or 1, 0.0, false, false, false)
    end
    if anim.prop and not (propByOwner[ownerSrc] and DoesEntityExist(propByOwner[ownerSrc])) then
        local phash = (type(anim.prop) == "number") and anim.prop or joaat(anim.prop)
        if loadModel(phash) then
            local pc = GetEntityCoords(ped)
            local obj = CreateObject(phash, pc.x, pc.y, pc.z, false, false, false)
            SetModelAsNoLongerNeeded(phash)
            if anim.propTexture then pcall(function() SetObjectTextureVariant(obj, anim.propTexture) end) end
            local bone = GetPedBoneIndex(ped, anim.bone or 28422)
            local pp = anim.placement or {}
            AttachEntityToEntity(obj, ped, bone,
                pp.x or 0.0, pp.y or 0.0, pp.z or 0.0,
                pp.rx or 0.0, pp.ry or 0.0, pp.rz or 0.0,
                true, true, false, true, 1, true)
            SetEntityAlpha(obj, alpha or 150, false)
            propByOwner[ownerSrc] = obj
        end
    end
end

RegisterNetEvent("gungame:standIn:spawn", function(ownerSrc, data)
    if not data or not data.coords then return end
    despawn(ownerSrc)

    local c = data.coords
    local modelHash = (type(data.model) == "number") and data.model or joaat(data.model or "mp_m_freemode_01")
    if not loadModel(modelHash) then return end

    local ped = CreatePed(0, modelHash, c.x + 0.0, c.y + 0.0, c.z + 0.0, data.heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(modelHash)
    if not ped or ped == 0 then return end
    localPeds[ownerSrc] = ped
    tagByOwner[ownerSrc] = { id = data.tagId, name = data.tagName }

    if data.appearance and GG_ApplyAppearance then
        GG_ApplyAppearance(ped, data.appearance)
    end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityHeading(ped, data.heading or 0.0)

    SetEntityVisible(ped, false, false)
    RequestCollisionAtCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    local tries = 0
    while not HasCollisionLoadedAroundEntity(ped) and tries < 50 do
        Wait(10); tries = tries + 1
    end
    if not DoesEntityExist(ped) or localPeds[ownerSrc] ~= ped then return end
    local off = data.zOffset or (Config.StandIn and Config.StandIn.zOffset) or 0.0
    local h = GetEntityHeightAboveGround(ped)
    if h and h > 0.3 and h < 10.0 then
        local cur = GetEntityCoords(ped)
        SetEntityCoordsNoOffset(ped, cur.x, cur.y, cur.z - h + off, false, false, false)
    end

    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, data.alpha or 150, false)

    applyAnimAndProp(ownerSrc, ped, data.anim, data.alpha)
end)

RegisterNetEvent("gungame:standIn:despawn", function(ownerSrc)
    despawn(ownerSrc)
end)

local gkrTags  = {}
local gkrNames = {}

RegisterNetEvent("gkrhud:client:updateCustomTag", function(serverId, tagData)
    gkrTags[serverId] = tagData or nil
end)
RegisterNetEvent("gkrhud:client:syncAllCustomTags", function(allData)
    if type(allData) ~= "table" then return end
    for sid, data in pairs(allData) do gkrTags[tonumber(sid) or sid] = data end
end)
RegisterNetEvent("gkrhud:client:updateNameplate", function(serverId, charName)
    gkrNames[serverId] = charName
end)
RegisterNetEvent("gkrhud:client:syncAllNameplates", function(allData)
    if type(allData) ~= "table" then return end
    for sid, name in pairs(allData) do gkrNames[tonumber(sid) or sid] = name end
end)

CreateThread(function()
    if GetResourceState("GKRHUD") ~= "started" then return end
    Wait(3000)
    TriggerServerEvent("gkrhud:server:requestAllNameplates")
    TriggerServerEvent("gkrhud:server:requestAllCustomTags")
end)

local function resolveTagDisplay(ownerSrc, fallbackName, defColor)
    local t = gkrTags[ownerSrc]
    if t then
        if t.visible == false then
            return { hidden = true }
        end
        if t.text and t.text ~= "" then
            return { name = t.text, r = t.r or 255, g = t.g or 255, b = t.b or 255 }
        end
    end
    local nm = gkrNames[ownerSrc] or fallbackName or "?"
    return { name = nm, r = defColor.r, g = defColor.g, b = defColor.b }
end

local function drawTextScreen(sx, sy, text, size, r, g, b)
    SetTextScale(0.0, size)
    SetTextFont(0)
    SetTextColour(r, g, b, 220)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    local cfg = Config.StandIn and Config.StandIn.nameTag
    if not (cfg and cfg.enabled) then return end
    local dist    = cfg.drawDistance or 40.0
    local distSq  = dist * dist
    local size    = cfg.textSize or 0.40
    local height  = cfg.height or 1.1
    local lineGap = cfg.lineGap or 0.022
    local c1 = cfg.line1Color or { r = 255, g = 210, b = 60 }
    local c2 = cfg.line2Color or { r = 255, g = 255, b = 255 }
    while true do
        if next(localPeds) == nil then
            Wait(500)
        else
            local myCoords = GetEntityCoords(PlayerPedId())
            for owner, ped in pairs(localPeds) do
                if ped and DoesEntityExist(ped) then
                    local pc = GetEntityCoords(ped)
                    local dx, dy, dz = pc.x - myCoords.x, pc.y - myCoords.y, pc.z - myCoords.z
                    if (dx * dx + dy * dy + dz * dz) <= distSq then
                        local on, sx, sy = World3dToScreen2d(pc.x, pc.y, pc.z + height)
                        if on then
                            local tag = tagByOwner[owner] or {}
                            local disp = resolveTagDisplay(owner, tag.name, c2)
                            local hasL1 = cfg.line1 and cfg.line1 ~= ""
                            if disp.hidden then
                                if hasL1 then
                                    drawTextScreen(sx, sy, cfg.line1, size, c1.r, c1.g, c1.b)
                                end
                            else
                                local nameLine = ("[%s] %s"):format(tag.id or "?", disp.name)
                                if hasL1 then
                                    drawTextScreen(sx, sy, cfg.line1, size, c1.r, c1.g, c1.b)
                                    drawTextScreen(sx, sy + lineGap, nameLine, size, disp.r, disp.g, disp.b)
                                else
                                    drawTextScreen(sx, sy, nameLine, size, disp.r, disp.g, disp.b)
                                end
                            end
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for owner in pairs(localPeds) do despawn(owner) end
end)
