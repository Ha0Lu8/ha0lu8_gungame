local QBCore = nil

local function dbg(...)
    if Config.Debug then print("[gungame:cl]", ...) end
end

CreateThread(function()
    while not QBCore do
        QBCore = Framework.GetCore()
        Wait(100)
    end
end)

local function registerApp()
    if GetResourceState(Config.PhoneResource) ~= "started" then return false end
    local ok = pcall(function()
        exports[Config.PhoneResource]:AddCustomApp({
            identifier  = Config.App.identifier,
            name        = Config.App.name,
            description = Config.App.description,
            developer   = Config.App.developer,
            defaultApp  = Config.App.defaultApp,
            price       = Config.App.price,
            icon        = Config.App.icon,
            ui          = Config.App.ui,
        })
    end)
    if ok then dbg("app registered") end
    return ok
end

CreateThread(function()
    while not registerApp() do
        Wait(2000)
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Wait(1000)
    registerApp()
end)

RegisterNetEvent("gungame:toUI", function(event, data)
    SendToUI(event, data)
end)

RegisterNetEvent("gungame:radio:apply", function(channel)
    local res = (Config.Radio and Config.Radio.resource) or "pma-voice"
    channel = tonumber(channel) or 0
    pcall(function()
        if channel ~= 0 then
            exports[res]:setVoiceProperty("radioEnabled", true)
        end
        exports[res]:setRadioChannel(channel)
    end)
    if Config.Debug then print("[gungame:cl] radio set to channel", channel) end
end)

RegisterNetEvent("gungame:phoneNotify", function(data)
    pcall(function()
        exports[Config.PhoneResource]:SendNotification({
            app     = Config.App.identifier,
            title   = data.title or Config.App.name,
            content = data.content or "",
        })
    end)
end)

function SendToUI(event, data)
    pcall(function()
        exports[Config.PhoneResource]:SendCustomAppMessage(Config.App.identifier, {
            event = event,
            data = data,
        })
    end)
end

local function relayCallback(name, data, cb)
    QBCore.Functions.TriggerCallback(name, function(result)
        cb(result)
    end, data)
end

RegisterNUICallback("gungame:getInit", function(data, cb)
    relayCallback("gungame:getInit", data, cb)
end)
RegisterNUICallback("gungame:register", function(data, cb)
    relayCallback("gungame:register", data, cb)
end)
RegisterNUICallback("gungame:getRankings", function(data, cb)
    relayCallback("gungame:getRankings", data, cb)
end)
RegisterNUICallback("gungame:updateProfile", function(data, cb)
    relayCallback("gungame:updateProfile", data, cb)
end)
RegisterNUICallback("gungame:createListing", function(data, cb)
    relayCallback("gungame:createListing", data, cb)
end)
RegisterNUICallback("gungame:joinListing", function(data, cb)
    relayCallback("gungame:joinListing", data, cb)
end)
RegisterNUICallback("gungame:friendRequest", function(data, cb)
    relayCallback("gungame:friendRequest", data, cb)
end)
RegisterNUICallback("gungame:partyInvite", function(data, cb)
    relayCallback("gungame:partyInvite", data, cb)
end)

local typingUntil = 0
local typingLoopRunning = false

local function isInMatch()
    return GG_IsInMatch ~= nil and GG_IsInMatch()
end

RegisterNUICallback("gungame:setTyping", function(data, cb)
    local on = data and data.typing and true or false
    if on and not isInMatch() then
        typingUntil = GetGameTimer() + 1500
        if not typingLoopRunning then
            typingLoopRunning = true
            CreateThread(function()
                while GetGameTimer() < typingUntil and not isInMatch() do
                    DisableControlAction(0, 30, true)
                    DisableControlAction(0, 31, true)
                    DisableControlAction(0, 32, true)
                    DisableControlAction(0, 33, true)
                    DisableControlAction(0, 34, true)
                    DisableControlAction(0, 35, true)
                    DisableControlAction(0, 21, true)
                    DisableControlAction(0, 22, true)
                    Wait(0)
                end
                typingLoopRunning = false
            end)
        end
    else
        typingUntil = 0
    end
    if cb then cb({ ok = true }) end
end)

local function relayEvent(name, payload)
    TriggerServerEvent(name, payload)
end

RegisterNUICallback("gungame:leaveListing", function(_, cb)
    TriggerServerEvent("gungame:leaveListing"); cb({ ok = true })
end)
RegisterNUICallback("gungame:cancelListing", function(_, cb)
    TriggerServerEvent("gungame:cancelListing"); cb({ ok = true })
end)
RegisterNUICallback("gungame:forfeit", function(_, cb)
    TriggerServerEvent("gungame:forfeit"); cb({ ok = true })
end)
RegisterNUICallback("gungame:acceptFriend", function(data, cb)
    TriggerServerEvent("gungame:acceptFriend", data.fromCid); cb({ ok = true })
end)
RegisterNUICallback("gungame:declineFriend", function(data, cb)
    TriggerServerEvent("gungame:declineFriend", data.fromCid); cb({ ok = true })
end)
RegisterNUICallback("gungame:removeFriend", function(data, cb)
    TriggerServerEvent("gungame:removeFriend", data.friendCid); cb({ ok = true })
end)
RegisterNUICallback("gungame:acceptParty", function(data, cb)
    TriggerServerEvent("gungame:acceptParty", data.partyId); cb({ ok = true })
end)
RegisterNUICallback("gungame:declineParty", function(data, cb)
    TriggerServerEvent("gungame:declineParty", data.partyId); cb({ ok = true })
end)
RegisterNUICallback("gungame:leaveParty", function(_, cb)
    TriggerServerEvent("gungame:leaveParty"); cb({ ok = true })
end)
RegisterNUICallback("gungame:kickParty", function(data, cb)
    TriggerServerEvent("gungame:kickParty", data.targetCid); cb({ ok = true })
end)
RegisterNUICallback("gungame:syncParty", function(_, cb)
    TriggerServerEvent("gungame:syncParty"); cb({ ok = true })
end)
