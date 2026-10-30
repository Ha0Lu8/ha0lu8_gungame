local ILLENIUM_RESOURCE = 'illenium-appearance'

function GG_IsIlleniumReady()
    return GetResourceState(ILLENIUM_RESOURCE) == 'started'
end

local function GG_FormattedHeadBlend(ped)
    local _, shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(ped)
    return {
        shapeFirst  = shapeFirst or 0,
        shapeSecond = shapeSecond or 0,
        shapeThird  = shapeThird or 0,
        skinFirst   = skinFirst or 0,
        skinSecond  = skinSecond or 0,
        skinThird   = skinThird or 0,
        shapeMix    = shapeMix or 0.0,
        skinMix     = skinMix or 0.0,
        thirdMix    = thirdMix or 0.0,
    }
end

function GG_CaptureAppearance(ped)
    local appearance = {}

    appearance.headBlend = GG_FormattedHeadBlend(ped)

    appearance.components = {}
    for i = 0, 11 do
        appearance.components[i] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture  = GetPedTextureVariation(ped, i),
        }
    end

    appearance.props = {}
    for i = 0, 7 do
        appearance.props[i] = {
            drawable = GetPedPropIndex(ped, i),
            texture  = GetPedPropTextureIndex(ped, i),
        }
    end

    appearance.headOverlays = {}
    for i = 0, 12 do
        local _, overlayValue, colourType, firstColour, secondColour, overlayOpacity = GetPedHeadOverlayData(ped, i)
        appearance.headOverlays[i] = {
            value        = overlayValue,
            colourType   = colourType,
            firstColour  = firstColour,
            secondColour = secondColour,
            opacity      = overlayOpacity,
        }
    end

    appearance.faceFeatures = {}
    for i = 0, 19 do
        appearance.faceFeatures[i] = GetPedFaceFeature(ped, i)
    end

    appearance.hairColor          = GetPedHairColor(ped)
    appearance.hairHighlightColor = GetPedHairHighlightColor(ped)
    appearance.eyeColor           = GetPedEyeColor(ped)

    return appearance
end

function GG_CapturePlayerAppearance(ped)
    if GG_IsIlleniumReady() then
        local appearance = exports[ILLENIUM_RESOURCE]:getPedAppearance(ped)
        if appearance then
            appearance._format = 'illenium'
            return appearance
        end
    end

    local appearance = GG_CaptureAppearance(ped)
    if appearance then
        appearance._format = 'native'
    end
    return appearance
end

local function GetByKey(tbl, key)
    if not tbl then return nil end
    return tbl[key] or tbl[tostring(key)]
end

local function GG_ApplyAppearanceNative(ped, appearance)
    if not appearance or not DoesEntityExist(ped) then return end

    if appearance.headBlend then
        local hb = appearance.headBlend
        SetPedHeadBlendData(ped,
            hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
            hb.skinFirst or 0, hb.skinSecond or 0, hb.skinThird or 0,
            hb.shapeMix or 0.0, hb.skinMix or 0.0, hb.thirdMix or 0.0,
            false
        )
    end

    if appearance.components then
        for i = 0, 11 do
            local comp = GetByKey(appearance.components, i)
            if comp then
                SetPedComponentVariation(ped, i, comp.drawable or 0, comp.texture or 0, 0)
            end
        end
    end

    if appearance.props then
        for i = 0, 7 do
            local prop = GetByKey(appearance.props, i)
            if prop then
                if prop.drawable == -1 then
                    ClearPedProp(ped, i)
                else
                    SetPedPropIndex(ped, i, prop.drawable or 0, prop.texture or 0, true)
                end
            end
        end
    end

    if appearance.headOverlays then
        for i = 0, 12 do
            local overlay = GetByKey(appearance.headOverlays, i)
            if overlay then
                SetPedHeadOverlay(ped, i, overlay.value or 0, overlay.opacity or 1.0)
                if overlay.colourType and overlay.firstColour then
                    SetPedHeadOverlayColor(ped, i, overlay.colourType, overlay.firstColour, overlay.secondColour or 0)
                end
            end
        end
    end

    if appearance.faceFeatures then
        for i = 0, 19 do
            local val = GetByKey(appearance.faceFeatures, i)
            if val then
                SetPedFaceFeature(ped, i, val)
            end
        end
    end

    if appearance.hairColor then
        SetPedHairColor(ped, appearance.hairColor, appearance.hairHighlightColor or 0)
    end
    if appearance.eyeColor then
        SetPedEyeColor(ped, appearance.eyeColor)
    end
end

local function GG_ApplyAppearanceIllenium(ped, appearance)
    if not GG_IsIlleniumReady() then
        print('[ha0lu8_gungame] illenium 形式の外見データですが illenium-appearance が起動していません')
        return
    end

    local ill = exports[ILLENIUM_RESOURCE]

    if appearance.components then ill:setPedComponents(ped, appearance.components) end
    if appearance.props then ill:setPedProps(ped, appearance.props) end

    if appearance.headBlend then ill:setPedHeadBlend(ped, appearance.headBlend) end
    if appearance.faceFeatures then ill:setPedFaceFeatures(ped, appearance.faceFeatures) end
    if appearance.headOverlays then ill:setPedHeadOverlays(ped, appearance.headOverlays) end
    if appearance.eyeColor then ill:setPedEyeColor(ped, appearance.eyeColor) end

    if appearance.hair then
        SetPedComponentVariation(ped, 2, appearance.hair.style or 0, appearance.hair.texture or 0, 0)
        SetPedHairColor(ped, appearance.hair.color or 0, appearance.hair.highlight or 0)
    end
end

local function GG_DetectAppearanceFormat(appearance)
    if appearance._format then
        return appearance._format
    end

    if appearance.hair ~= nil then
        return 'illenium'
    end

    local comps = appearance.components
    if type(comps) == 'table' then
        local first = comps[1] or comps['1']
        if type(first) == 'table' and first.component_id ~= nil then
            return 'illenium'
        end
    end

    return 'native'
end

function GG_ApplyAppearance(ped, appearance)
    if not appearance or not DoesEntityExist(ped) then return end

    if GG_DetectAppearanceFormat(appearance) == 'illenium' then
        GG_ApplyAppearanceIllenium(ped, appearance)
    else
        GG_ApplyAppearanceNative(ped, appearance)
    end
end
