local current = nil
local saved = nil
local isDead = false
local isSpectating = false
local reportedDeath = false
local hudState = nil
local hudCountdown = 0
local preCountdown = 0
local deathGraceUntil = 0
local zone = nil
local zoneWarnShown = false
local zoneBlip = nil

local KnownWeapons = {
    "weapon_pistol","weapon_pistol_mk2","weapon_combatpistol","weapon_appistol",
    "weapon_pistol50","weapon_snspistol","weapon_snspistol_mk2","weapon_heavypistol",
    "weapon_vintagepistol","weapon_marksmanpistol","weapon_revolver","weapon_revolver_mk2",
    "weapon_doubleaction","weapon_ceramicpistol","weapon_navyrevolver","weapon_gadgetpistol",
    "weapon_microsmg","weapon_smg","weapon_smg_mk2","weapon_assaultsmg","weapon_combatpdw",
    "weapon_machinepistol","weapon_minismg","weapon_combatmg","weapon_combatmg_mk2",
    "weapon_gusenberg","weapon_pumpshotgun","weapon_pumpshotgun_mk2","weapon_sawnoffshotgun",
    "weapon_assaultshotgun","weapon_bullpupshotgun","weapon_musket","weapon_heavyshotgun",
    "weapon_dbshotgun","weapon_autoshotgun","weapon_combatshotgun","weapon_assaultrifle",
    "weapon_assaultrifle_mk2","weapon_carbinerifle","weapon_carbinerifle_mk2","weapon_advancedrifle",
    "weapon_specialcarbine","weapon_specialcarbine_mk2","weapon_bullpuprifle","weapon_bullpuprifle_mk2",
    "weapon_compactrifle","weapon_militaryrifle","weapon_sniperrifle","weapon_heavysniper",
    "weapon_heavysniper_mk2","weapon_marksmanrifle","weapon_marksmanrifle_mk2","weapon_knife",
    "weapon_bat","weapon_crowbar","weapon_hammer","weapon_machete","weapon_flashlight",
    "weapon_stungun","weapon_grenade","weapon_smokegrenade","weapon_molotov",
}

local function dbg(...)
    if Config.Debug then print("[gungame:match:cl]", ...) end
end

local function playSound(def)
    if not (Config.Sounds and Config.Sounds.enabled) then return end
    if not def or not def.name or not def.set then return end
    dbg("playSound", def.name, def.set)
    pcall(function()
        PlaySoundFrontend(-1, def.name, def.set, true)
    end)
end

local invLockUntil = 0
local invLockRunning = false

local function lockInventory(seconds)
    if not (Config.InventorySwap and Config.InventorySwap.enabled) then return end
    local res = Config.InventorySwap.resource
    seconds = seconds or (Config.InventorySwap.lockSeconds or 3)
    invLockUntil = math.max(invLockUntil, GetGameTimer() + seconds * 1000)
    if invLockRunning then return end
    invLockRunning = true
    CreateThread(function()
        while GetGameTimer() < invLockUntil do
            LocalPlayer.state:set("invBusy", true, true)
            if res then pcall(function() exports[res]:closeInventory() end) end
            Wait(200)
        end
        LocalPlayer.state:set("invBusy", false, true)
        invLockRunning = false
    end)
end

local function saveState()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local swap = current and current.inventorySwap
    local weapons = {}
    if not swap then
        for _, name in ipairs(KnownWeapons) do
            local hash = GetHashKey(name)
            if HasPedGotWeapon(ped, hash, false) then
                weapons[#weapons + 1] = { hash = hash, ammo = GetAmmoInPedWeapon(ped, hash) }
            end
        end
    end
    saved = {
        coords  = coords,
        heading = GetEntityHeading(ped),
        health  = GetEntityHealth(ped),
        armor   = GetPedArmour(ped),
        maxHealth = GetEntityMaxHealth(ped),
        weapons = weapons,
        swap    = swap,
    }
end

local function restoreState()
    if not saved then return end
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(saved.coords.x, saved.coords.y, saved.coords.z, saved.heading, true, false)
        Wait(200)
        ped = PlayerPedId()
    end

    SetEntityCoordsNoOffset(ped, saved.coords.x, saved.coords.y, saved.coords.z, false, false, false)
    SetEntityHeading(ped, saved.heading)

    if not saved.swap then
        RemoveAllPedWeapons(ped, true)
        for _, w in ipairs(saved.weapons) do
            GiveWeaponToPed(ped, w.hash, w.ammo or 0, false, false)
        end
        SetCurrentPedWeapon(ped, GetHashKey("weapon_unarmed"), true)
    end

    SetEntityMaxHealth(ped, saved.maxHealth)
    SetEntityHealth(ped, saved.health)
    SetPedArmour(ped, saved.armor)

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    saved = nil
end

local function applyLoadout()
    if not current or not current.weapon then return end
    local ped = PlayerPedId()
    if current.inventorySwap then
        SetEntityMaxHealth(ped, current.startHealth)
        SetEntityHealth(ped, current.startHealth)
        SetPedArmour(ped, current.startArmor)
        return
    end
    local hash = GetHashKey(current.weapon)
    RemoveAllPedWeapons(ped, true)
    SetEntityMaxHealth(ped, current.startHealth)
    SetEntityHealth(ped, current.startHealth)
    SetPedArmour(ped, current.startArmor)
    GiveWeaponToPed(ped, hash, current.ammo or 0, false, true)
    SetPedAmmo(ped, hash, current.ammo or 0)
    SetCurrentPedWeapon(ped, hash, true)
end

local function equipArenaWeapon()
    if not current or not current.weaponSlot then return end
    local res = Config.InventorySwap and Config.InventorySwap.resource
    if not res then return end
    local hash = GetHashKey(current.weapon)
    CreateThread(function()
        RequestWeaponAsset(hash, 31, 0)
        local t = 0
        while not HasWeaponAssetLoaded(hash) and t < 75 do Wait(20); t = t + 1 end
        if not HasWeaponAssetLoaded(hash) then
            return
        end
        for _ = 1, 15 do
            if not current then return end
            local ped = PlayerPedId()
            if GetSelectedPedWeapon(ped) == hash then
                local loaded = current.loadedAmmo or 250
                SetAmmoInClip(ped, hash, loaded)
                return
            end
            pcall(function() exports[res]:useSlot(current.weaponSlot) end)
            Wait(300)
        end
    end)
end

local function ensureLoadout()
    if current and current.inventorySwap then
        equipArenaWeapon()
        return
    end
    CreateThread(function()
        if not current or not current.weapon then return end
        local hash = GetHashKey(current.weapon)
        for _ = 1, 10 do
            local ped = PlayerPedId()
            if not current then return end
            if not HasPedGotWeapon(ped, hash, false) then
                applyLoadout()
            else
                SetCurrentPedWeapon(ped, hash, true)
                return
            end
            Wait(200)
        end
    end)
end

local function teleport(spawn)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w)
end

local function createStandIn()
    if not (Config.StandIn and Config.StandIn.enabled) then return end
    if not saved then return end
    local ped = PlayerPedId()
    local mdl = GetEntityModel(ped)
    local appearance = nil
    if GG_CapturePlayerAppearance then
        local ok, res = pcall(GG_CapturePlayerAppearance, ped)
        if ok then appearance = res end
    end
    TriggerServerEvent("gungame:standIn:create",
        { x = saved.coords.x, y = saved.coords.y, z = saved.coords.z },
        saved.heading or 0.0, mdl, appearance)
end

local function removeStandIn()
    if not (Config.StandIn and Config.StandIn.enabled) then return end
    TriggerServerEvent("gungame:standIn:remove")
end

local function protectReturn()
    local secs = (Config.StandIn and Config.StandIn.returnProtect) or 0
    if secs <= 0 then return end
    CreateThread(function()
        local endt = GetGameTimer() + secs * 1000
        while GetGameTimer() < endt do
            local ped = PlayerPedId()
            SetEntityInvincible(ped, true)
            SetPedCanRagdoll(ped, false)
            Wait(200)
        end
        if not current then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, false)
            SetPedCanRagdoll(ped, true)
        end
    end)
end

local function enterSpectate()
    isSpectating = true
    local ped = PlayerPedId()
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
end

local function exitSpectate()
    isSpectating = false
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
end

local function getKillerServerId()
    local ped = PlayerPedId()
    local killer = GetPedSourceOfDeath(ped)
    if killer and killer ~= 0 and DoesEntityExist(killer) and IsPedAPlayer(killer) then
        local plyIdx = NetworkGetPlayerIndexFromPed(killer)
        if plyIdx ~= -1 then
            return GetPlayerServerId(plyIdx)
        end
    end
    return 0
end

local function hud(payload)
    SendNUIMessage(payload)
end

exports("IsInMatch", function()
    return current ~= nil
end)

function GG_IsInMatch()
    return current ~= nil
end

local function matchInfoForHud()
    if not current then return {} end
    local ffa = current.ffa
    local mode = ffa and "" or (current.mode or "")
    local winLabel
    if current.winType == "rounds" then
        winLabel = "ラウンド制（" .. (current.winValue or 0) .. "本先取）"
    else
        winLabel = (current.winValue or 0) .. "キル先取"
    end
    return { mode = mode, winLabel = winLabel, team = current.team, ffa = ffa }
end

local function deathWatcher()
    CreateThread(function()
        while current do
            if not isSpectating and not isDead and GetGameTimer() >= deathGraceUntil then
                local ped = PlayerPedId()
                if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
                    if not reportedDeath then
                        reportedDeath = true
                        isDead = true
                        local killer = getKillerServerId()
                        TriggerServerEvent("gungame:reportDeath", killer)
                    end
                end
            end
            Wait(200)
        end
    end)
end

RegisterNetEvent("gungame:match:preCountdown", function(data)
    local delay = tonumber(data and data.delay) or 0
    if delay <= 0 then return end
    preCountdown = delay

    CreateThread(function()
        while preCountdown > 0 do
            hud({ action = "preCountdown", value = preCountdown })
            if preCountdown <= 3 then
                playSound(Config.Sounds and Config.Sounds.countdownBeep)
                lockInventory()
            end
            Wait(1000)
            preCountdown = preCountdown - 1
        end
        hud({ action = "preCountdown", value = 0 })
    end)
end)

RegisterNetEvent("gungame:match:lockInv", function(seconds)
    lockInventory(tonumber(seconds))
end)

RegisterNetEvent("gungame:match:start", function(data)
    preCountdown = 0
    hud({ action = "clear" })
    current = data
    isDead = false
    isSpectating = false
    reportedDeath = false
    if Config.Zone and Config.Zone.enabled and data.zoneCenter and data.zoneRadius then
        zone = { center = data.zoneCenter, radius = data.zoneRadius + 0.0 }
    else
        zone = nil
    end

    lockInventory()

    saveState()
    createStandIn()

    local ped = PlayerPedId()
    teleport(data.spawn)
    applyLoadout()
    ensureLoadout()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)

    SendToUI("match:enter", {
        mode = data.mode,
        weapon = data.weapon,
        team = data.team,
        ffa = data.ffa,
        winType = data.winType,
        winValue = data.winValue,
        countdown = data.countdown,
    })
    deathWatcher()

    if data.staminaDrain == false then
        CreateThread(function()
            while current and current.staminaDrain == false do
                Wait(0)
                RestorePlayerStamina(PlayerId(), 1.0)
            end
        end)
    end

    CreateThread(function()
        hudCountdown = data.countdown or 0
        while hudCountdown > 0 do
            hud({ action = "countdown", value = hudCountdown, info = matchInfoForHud() })
            if hudCountdown <= 3 then
                playSound(Config.Sounds and Config.Sounds.countdownBeep)
            end
            Wait(1000)
            hudCountdown = hudCountdown - 1
        end
        hud({ action = "countdown", value = 0 })
    end)
end)

RegisterNetEvent("gungame:match:arenaLoadout", function(data)
    if not current or not data then return end
    current.weaponSlot = data.weaponSlot
    if data.weapon then current.weapon = data.weapon end
    if data.ammo then current.ammo = data.ammo end
    ensureLoadout()
end)

RegisterNetEvent("gungame:match:go", function()
    local ped = PlayerPedId()
    hudCountdown = 0
    hud({ action = "countdown", value = 0 })
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    playSound(Config.Sounds and Config.Sounds.countdownGo)
    ensureLoadout()
    SendToUI("match:go", {})
end)

RegisterNetEvent("gungame:match:state", function(data)
    hudState = data
    hud({ action = "state", data = data })
    SendToUI("match:state", data)
end)

RegisterNetEvent("gungame:match:spectate", function()
    isDead = true
    hud({ action = "spectate", on = true })
    SendToUI("match:spectate", {})
end)

RegisterNetEvent("gungame:match:heal", function(data)
    if not current or not data then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    if data.health and data.health > 0 then
        local maxH = GetEntityMaxHealth(ped)
        local newH = math.min(GetEntityHealth(ped) + data.health, maxH)
        SetEntityHealth(ped, newH)
    end
    if data.armor and data.armor > 0 and current.startArmor and current.startArmor > 0 then
        local newA = math.min(GetPedArmour(ped) + data.armor, current.startArmor)
        SetPedArmour(ped, newA)
    end
end)

RegisterNetEvent("gungame:match:respawn", function(data)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, true, false)
        Wait(100)
    end
    isDead = false
    reportedDeath = false
    deathGraceUntil = GetGameTimer() + 2000
    teleport(data.spawn)
    applyLoadout()
    ensureLoadout()
    hud({ action = "spectate", on = false })
    SendToUI("match:respawn", {})
end)

RegisterNetEvent("gungame:match:roundReset", function(data)
    exitSpectate()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, true, false)
        Wait(100)
    end
    isDead = false
    reportedDeath = false
    deathGraceUntil = GetGameTimer() + 2000
    teleport(data.spawn)
    applyLoadout()
    ensureLoadout()
    hud({ action = "spectate", on = false })

    ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    local rc = tonumber(data.countdown) or 0
    if rc > 0 then
        CreateThread(function()
            local n = rc
            while n > 0 and current do
                hud({ action = "countdown", value = n, info = matchInfoForHud() })
                if n <= 3 then
                    playSound(Config.Sounds and Config.Sounds.countdownBeep)
                end
                Wait(1000)
                n = n - 1
            end
            hud({ action = "countdown", value = 0 })
        end)
    end

    SendToUI("match:roundReset", { round = data.round })
end)

RegisterNetEvent("gungame:match:roundGo", function()
    local ped = PlayerPedId()
    hud({ action = "countdown", value = 0 })
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    playSound(Config.Sounds and Config.Sounds.countdownGo)
    ensureLoadout()
end)

local function finalizeAndRestore(payload)
    hud({ action = "clear" })
    lockInventory()
    exitSpectate()
    removeStandIn()
    restoreState()
    protectReturn()
    hudState = nil
    hudCountdown = 0
    isDead = false
    isSpectating = false
    reportedDeath = false
    SendToUI("match:end", payload or {})
end

local function endMatch(payload)
    payload = payload or {}
    zone = nil

    if payload.cancelled or payload.aborted then
        current = nil
        finalizeAndRestore(payload)
        return
    end

    local outcome = payload.outcome or "draw"
    local dur = (Config.ResultDisplay and Config.ResultDisplay.duration) or 5

    if outcome == "win" then
        playSound(Config.Sounds and Config.Sounds.matchWin)
    elseif outcome == "loss" then
        playSound(Config.Sounds and Config.Sounds.matchLose)
    else
        playSound(Config.Sounds and Config.Sounds.matchDraw)
    end

    hud({
        action    = "result",
        outcome   = outcome,
        kills     = payload.kills,
        deaths    = payload.deaths,
        xpGained  = payload.xpGained,
        level     = payload.level,
        leveledUp = payload.leveledUp,
        pot       = payload.pot,
        duration  = dur,
    })
    SendToUI("match:end", payload)

    exitSpectate()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        Wait(50)
        ped = PlayerPedId()
    end
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    current = nil
    hudState = nil
    hudCountdown = 0
    isDead = false
    isSpectating = false
    reportedDeath = false

    local lockSecs = (Config.InventorySwap and Config.InventorySwap.lockSeconds) or 3
    local firstWait = math.max(0, dur - lockSecs)
    local secondWait = dur - firstWait
    CreateThread(function()
        if firstWait > 0 then Wait(firstWait * 1000) end
        lockInventory(lockSecs * 2)
        if secondWait > 0 then Wait(secondWait * 1000) end
        hud({ action = "clear" })
        local p = PlayerPedId()
        SetEntityInvincible(p, false)
        removeStandIn()
        restoreState()
        protectReturn()
    end)
end

RegisterNetEvent("gungame:match:end", function(data)
    endMatch(data)
end)

RegisterNetEvent("gungame:match:cancelled", function(data)
    preCountdown = 0
    if current then endMatch({ cancelled = true }) end
    SendToUI("match:cancelled", data)
end)

RegisterNetEvent("gungame:match:aborted", function(data)
    preCountdown = 0
    if current then endMatch({ aborted = true }) end
    SendToUI("match:aborted", data)
end)

local function requestReturn()
    CreateThread(function()
        for _ = 1, 4 do
            TriggerServerEvent("gungame:requestReturn")
            Wait(1500)
        end
    end)
end

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    requestReturn()
end)

CreateThread(function()
    Wait(1500)
    if LocalPlayer.state.isLoggedIn then
        requestReturn()
    end
end)

RegisterNetEvent("gungame:returnToPos", function(pos)
    if not pos then return end
    CreateThread(function()
        local tries = 0
        while (PlayerPedId() == 0 or not DoesEntityExist(PlayerPedId()) or IsEntityDead(PlayerPedId())) and tries < 100 do
            Wait(100); tries = tries + 1
        end
        do
            local cur = GetEntityCoords(PlayerPedId())
            local dx, dy, dz = cur.x - pos.x, cur.y - pos.y, cur.z - pos.z
            if (dx * dx + dy * dy + dz * dz) <= (75.0 * 75.0) then return end
        end
        Wait(1200)
        DoScreenFadeOut(300)
        local t = 0
        while not IsScreenFadedOut() and t < 30 do Wait(50); t = t + 1 end
        for _ = 1, 5 do
            local ped = PlayerPedId()
            if ped ~= 0 then
                SetEntityCoordsNoOffset(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false)
                SetEntityHeading(ped, (pos.h or 0.0) + 0.0)
            end
            Wait(200)
        end
        DoScreenFadeIn(500)
    end)
end)

local function createZoneBlip()
    if zoneBlip then RemoveBlip(zoneBlip); zoneBlip = nil end
    if not zone or not zone.center then return end
    local c = zone.center
    zoneBlip = AddBlipForRadius(c.x, c.y, c.z, zone.radius + 0.0)
    SetBlipColour(zoneBlip, 1)
    SetBlipAlpha(zoneBlip, 128)
    SetBlipHighDetail(zoneBlip, true)
end

local function removeZoneBlip()
    if zoneBlip then RemoveBlip(zoneBlip); zoneBlip = nil end
end

local function drawZoneBoundary(pc)
    if not zone or not zone.center then return end
    local c = zone.center
    local rad = zone.radius
    local col = (Config.Zone and Config.Zone.color) or { r = 255, g = 60, b = 60, a = 90 }
    local floorA = (Config.Zone and Config.Zone.floorAlpha) or 35

    if floorA > 0 then
        local h = (Config.Zone and Config.Zone.height) or 2.0
        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            rad * 2.0, rad * 2.0, h, col.r, col.g, col.b, floorA, false, false, 2, false, nil, nil, false)
    end
end

CreateThread(function()
    local lastTick = 0
    while true do
        if current and zone and zone.center then
            if not zoneBlip then createZoneBlip() end
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            drawZoneBoundary(pc)
            if not isDead then
                local dx, dy = pc.x - zone.center.x, pc.y - zone.center.y
                local outside = (dx * dx + dy * dy) > (zone.radius * zone.radius)
                if outside then
                    if not zoneWarnShown then zoneWarnShown = true; hud({ action = "zone", on = true }) end
                    local now = GetGameTimer()
                    local tick = (Config.Zone and Config.Zone.tickMs) or 1000
                    if now - lastTick > tick then
                        lastTick = now
                        ApplyDamageToPed(ped, (Config.Zone and Config.Zone.damage) or 5, false)
                    end
                elseif zoneWarnShown then
                    zoneWarnShown = false; hud({ action = "zone", on = false })
                end
            end
            Wait(0)
        else
            if zoneBlip then removeZoneBlip() end
            if zoneWarnShown then zoneWarnShown = false; hud({ action = "zone", on = false }) end
            Wait(500)
        end
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    hud({ action = "clear" })
    removeZoneBlip()
    if current then
        exitSpectate()
        restoreState()
    end
end)
