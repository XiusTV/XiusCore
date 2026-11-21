local addonName, ns = ...

--[[
    Flight Map Upgrade (XiusCore built-in module)
    Upgrades the Flight Master map (TaxiFrame on WoW Forever / Classic and
    FlightMapFrame on Retail) with:
      - High-detail continent & zone map textures (auto-detecting OpenMap,
        Leatrix Maps, and Mapster texture packs with clean fallback to
        Blizzard's C_Map.GetMapArtLayers / GetMapArtLayerTextures)
      - Optional Unexplored Area Reveal
      - Smooth cursor-centered mouse-wheel zoom (1.0x - 2.5x+) and
        click-drag panning inside a clipped ScrollFrame viewport, with
        inversely scaled, 100% aligned & clickable TaxiButton1..N pins
        and clipped TaxiRouteMap route lines
      - Bottom-edge zone name, level range, and cursor coordinate readout
      - Lazy frame creation on first TAXIMAP_OPENED and clean reset on close
]]

local FM = {}
FM.VERSION = "1.0.0"

local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local select = select
local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local abs = math.abs
local format = string.format
local find = string.find
local lower = string.lower
local wipe = wipe or function(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local UnitLevel = UnitLevel
local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc
local C_Map = C_Map
local C_MapExplorationInfo = C_MapExplorationInfo
local C_TaxiMap = C_TaxiMap
local C_AddOns = C_AddOns

-- Classic / WoW Forever continent map IDs with OpenMap enhanced MapArt tiles.
local OPENMAP_ART_MAPS = {
    [947]  = true, -- Azeroth
    [1414] = true, -- Kalimdor
    [1415] = true, -- Eastern Kingdoms
}

-- Fallback zone level ranges (uiMapID -> { minLevel, maxLevel }) for clients
-- where C_Map.GetMapLevels does not return Classic/Forever zone ranges.
local CLASSIC_ZONE_LEVELS = {
    -- Kalimdor
    [1411] = { 1, 10 },  -- Durotar
    [1412] = { 1, 10 },  -- Mulgore
    [1413] = { 10, 25 }, -- The Barrens
    [1438] = { 1, 10 },  -- Teldrassil
    [1439] = { 10, 20 }, -- Darkshore
    [1440] = { 18, 30 }, -- Ashenvale
    [1441] = { 25, 35 }, -- Thousand Needles
    [1442] = { 15, 27 }, -- Stonetalon Mountains
    [1443] = { 30, 40 }, -- Desolace
    [1444] = { 40, 50 }, -- Feralas
    [1445] = { 35, 45 }, -- Dustwallow Marsh
    [1446] = { 40, 50 }, -- Tanaris
    [1447] = { 45, 55 }, -- Azshara
    [1448] = { 48, 55 }, -- Felwood
    [1449] = { 48, 55 }, -- Un'Goro Crater
    [1450] = { 55, 60 }, -- Moonglade
    [1451] = { 55, 60 }, -- Silithus
    [1452] = { 53, 60 }, -- Winterspring
    -- Eastern Kingdoms
    [1416] = { 30, 40 }, -- Alterac Mountains
    [1417] = { 30, 40 }, -- Arathi Highlands
    [1418] = { 35, 45 }, -- Badlands
    [1419] = { 45, 55 }, -- Blasted Lands
    [1420] = { 1, 10 },  -- Tirisfal Glades
    [1421] = { 10, 20 }, -- Silverpine Forest
    [1422] = { 51, 58 }, -- Western Plaguelands
    [1423] = { 53, 60 }, -- Eastern Plaguelands
    [1424] = { 20, 30 }, -- Hillsbrad Foothills
    [1425] = { 45, 50 }, -- The Hinterlands
    [1426] = { 1, 10 },  -- Dun Morogh
    [1427] = { 43, 50 }, -- Searing Gorge
    [1428] = { 50, 58 }, -- Burning Steppes
    [1429] = { 1, 10 },  -- Elwynn Forest
    [1430] = { 55, 60 }, -- Deadwind Pass
    [1431] = { 18, 30 }, -- Duskwood
    [1432] = { 10, 20 }, -- Loch Modan
    [1433] = { 15, 25 }, -- Redridge Mountains
    [1434] = { 30, 45 }, -- Stranglethorn Vale
    [1435] = { 35, 45 }, -- Swamp of Sorrows
    [1436] = { 10, 20 }, -- Westfall
    [1437] = { 20, 30 }, -- Wetlands
}

local DEFAULTS = {
    enabled           = true,
    highResArt        = true,
    preferOpenMapPack = true,
    revealUnexplored  = true,
    enableZoomPan     = true,
    maxZoom           = 2.5,
    showFooterInfo    = true,
}

local ZOOM_MIN          = 1.0
local ZOOM_STEP         = 0.28
local ZOOM_LERP_SPEED   = 14.0
local PIN_SCALE_MIN     = 0.48
local FOOTER_INTERVAL   = 0.05

--------------------------------------------------------------------------------
-- Helpers & SavedVariables
--------------------------------------------------------------------------------

local function IsSecret(value)
    if value == nil then
        return false
    end
    if XiusUI and XiusUI.Hidden then
        return XiusUI:Hidden(value)
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then
            return true
        end
    end
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        if ok and not allowed then
            return true
        end
    end
    return false
end

local function SafeNumber(value, fallback)
    if IsSecret(value) then
        return fallback
    end
    local n = tonumber(value)
    if not n then
        return fallback
    end
    return n
end

local function SafeString(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function Clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok and not IsSecret(loaded) then
            return loaded and true or false
        end
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok and not IsSecret(loaded) then
            return loaded and true or false
        end
    end
    return false
end

local function CoreDB()
    if XiusUI and XiusUI.CoreDB then
        return XiusUI:CoreDB()
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    return XiusCoreDB
end

function FM:GetDB()
    local core = CoreDB()
    if type(core.flightMap) ~= "table" then
        core.flightMap = {}
    end
    local db = core.flightMap
    for key, defaultVal in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = defaultVal
        end
    end
    db.maxZoom = Clamp(SafeNumber(db.maxZoom, DEFAULTS.maxZoom), 1.5, 3.0)
    return db
end

function FM:ResetDefaults()
    local core = CoreDB()
    core.flightMap = {}
    local db = self:GetDB()
    for key, defaultVal in pairs(DEFAULTS) do
        db[key] = defaultVal
    end
    self:Apply()
end

--------------------------------------------------------------------------------
-- Texture Pack Detection
--------------------------------------------------------------------------------

local packCacheChecked = false
local hasOpenMap       = false
local hasLeatrixMaps   = false
local hasMapster       = false

local function DetectMapPacks()
    if packCacheChecked then
        return
    end
    packCacheChecked = true
    hasOpenMap     = AddonLoaded("OpenMap") or (_G.OpenMapAPI ~= nil)
    hasLeatrixMaps = AddonLoaded("Leatrix_Maps") or (_G.LeaMapsDB ~= nil)
    hasMapster     = AddonLoaded("Mapster") or (_G.Mapster ~= nil)
end

function FM:GetDetectedPackLabel()
    DetectMapPacks()
    if hasOpenMap then
        return "OpenMap (enhanced tiles)"
    elseif hasLeatrixMaps then
        return "Leatrix Maps + Blizzard high-res tiles"
    elseif hasMapster then
        return "Mapster + Blizzard high-res tiles"
    end
    return "Blizzard high-res continent tiles"
end

--------------------------------------------------------------------------------
-- Zone Info & Difficulty Coloring
--------------------------------------------------------------------------------

local function GetZoneLevels(zoneMapID)
    if not zoneMapID then
        return nil, nil
    end
    if C_Map and C_Map.GetMapLevels then
        local ok, minLvl, maxLvl = pcall(C_Map.GetMapLevels, zoneMapID)
        if ok then
            minLvl = SafeNumber(minLvl)
            maxLvl = SafeNumber(maxLvl)
            if minLvl and maxLvl and (minLvl > 0 or maxLvl > 0) then
                return minLvl, maxLvl
            end
        end
    end
    local fallback = CLASSIC_ZONE_LEVELS[zoneMapID]
    if fallback then
        return fallback[1], fallback[2]
    end
    return nil, nil
end

local function GetLevelColorHex(minLvl, maxLvl)
    if not minLvl or not maxLvl or maxLvl <= 0 then
        return "ffd100"
    end
    local playerLvl = SafeNumber(UnitLevel and UnitLevel("player"), 60) or 60
    if playerLvl < minLvl - 4 then
        return "ff4040" -- red
    elseif playerLvl < minLvl then
        return "ff8040" -- orange
    elseif playerLvl <= maxLvl then
        return "ffff00" -- yellow
    elseif playerLvl <= maxLvl + 8 then
        return "40bf40" -- green
    end
    return "9d9d9d" -- gray
end

--------------------------------------------------------------------------------
-- Continent Map ID Resolution & Coordinate Calibration
--------------------------------------------------------------------------------

local function FindContinentMapID()
    -- 1. Walk up from player's current map via C_Map
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        mapID = ok and SafeNumber(mapID) or nil
        local guard = 0
        while mapID and guard < 10 do
            guard = guard + 1
            local okInfo, info = pcall(C_Map.GetMapInfo, mapID)
            if not okInfo or type(info) ~= "table" then
                break
            end
            local mapType = SafeNumber(info.mapType)
            -- Enum.UIMapType.Continent == 2
            if mapType == 2 then
                return mapID
            end
            local parentID = SafeNumber(info.parentMapID)
            if not parentID or parentID == 0 or parentID == mapID then
                break
            end
            mapID = parentID
        end
    end

    -- 2. Fallback: inspect TaxiMap texture path (TAXIMAP0 = EK, TAXIMAP1 = Kalimdor)
    local taxiMap = _G.TaxiMap
    if taxiMap and taxiMap.GetTexture then
        local ok, tex = pcall(taxiMap.GetTexture, taxiMap)
        tex = ok and SafeString(tex) or nil
        if tex then
            local lowerTex = lower(tex)
            if find(lowerTex, "taximap1", 1, true) or find(lowerTex, "kalimdor", 1, true) then
                return 1414
            elseif find(lowerTex, "taximap0", 1, true) or find(lowerTex, "azeroth", 1, true) or find(lowerTex, "eastern", 1, true) then
                return 1415
            end
        end
    end

    return nil
end

-- Reusable scratch tables for zero-allocation least-squares calibration
local taxiNodeByName = {}
local calMX, calMY   = {}, {}
local calTX, calTY   = {}, {}

-- Solves tx = ax * mx + bx and ty_top = ay * my + by from matched flight nodes
-- so WorldMap/OpenMap continent tiles align pixel-perfectly under TaxiButton1..N.
local function CalibrateTaxiToContinent(continentMapID)
    if not (continentMapID and NumTaxiNodes and TaxiNodeName and TaxiNodePosition) then
        return 1, 0, 1, 0, false
    end
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then
        return 1, 0, 1, 0, false
    end

    local ok, mapNodes = pcall(C_TaxiMap.GetTaxiNodesForMap, continentMapID)
    if not ok or type(mapNodes) ~= "table" or #mapNodes < 2 then
        return 1, 0, 1, 0, false
    end

    wipe(taxiNodeByName)
    local numNodes = SafeNumber(NumTaxiNodes(), 0) or 0
    for i = 1, numNodes do
        local name = SafeString(TaxiNodeName(i))
        if name then
            local tx, ty = TaxiNodePosition(i)
            tx = SafeNumber(tx)
            ty = SafeNumber(ty)
            if tx and ty then
                taxiNodeByName[lower(name)] = i
            end
        end
    end

    local count = 0
    for i = 1, #mapNodes do
        local info = mapNodes[i]
        if type(info) == "table" and info.name and info.position and info.position.GetXY then
            local key = lower(info.name)
            local taxiIdx = taxiNodeByName[key]
            if taxiIdx then
                local tx, ty = TaxiNodePosition(taxiIdx)
                local mx, my = info.position:GetXY()
                tx, ty = SafeNumber(tx), SafeNumber(ty)
                mx, my = SafeNumber(mx), SafeNumber(my)
                if tx and ty and mx and my then
                    count = count + 1
                    calMX[count] = mx
                    calMY[count] = my
                    calTX[count] = tx
                    calTY[count] = 1 - ty -- convert bottom-to-top to top-to-bottom
                end
            end
        end
    end

    if count < 2 then
        return 1, 0, 1, 0, false
    end

    local sumMX, sumMY, sumTX, sumTY = 0, 0, 0, 0
    for i = 1, count do
        sumMX = sumMX + calMX[i]
        sumMY = sumMY + calMY[i]
        sumTX = sumTX + calTX[i]
        sumTY = sumTY + calTY[i]
    end
    local meanMX = sumMX / count
    local meanMY = sumMY / count
    local meanTX = sumTX / count
    local meanTY = sumTY / count

    local numX, denX, numY, denY = 0, 0, 0, 0
    for i = 1, count do
        local dmx = calMX[i] - meanMX
        local dmy = calMY[i] - meanMY
        numX = numX + dmx * (calTX[i] - meanTX)
        denX = denX + dmx * dmx
        numY = numY + dmy * (calTY[i] - meanTY)
        denY = denY + dmy * dmy
    end

    if denX < 1e-6 or denY < 1e-6 then
        return 1, 0, 1, 0, false
    end

    local ax = numX / denX
    local ay = numY / denY
    -- Sanity check: reject degenerate fits
    if ax < 0.35 or ax > 3.0 or ay < 0.35 or ay > 3.0 then
        return 1, 0, 1, 0, false
    end
    local bx = meanTX - ax * meanMX
    local by = meanTY - ay * meanMY
    return ax, bx, ay, by, true
end

--------------------------------------------------------------------------------
-- Classic / WoW Forever TaxiFrame State
--------------------------------------------------------------------------------

local taxiState = {
    initialized   = false,
    active        = false,
    hookedRoutes  = false,
    continentID   = nil,
    -- Calibration: tx = ax * mx + bx, ty_top = ay * my + by
    ax            = 1,
    bx            = 0,
    ay            = 1,
    by            = 0,
    calibrated    = false,
    -- Viewport geometry
    baseW         = 580,
    baseH         = 580,
    -- Zoom & pan state
    zoom          = 1.0,
    targetZoom    = 1.0,
    panX          = 0,
    panY          = 0,
    targetPanX    = 0,
    targetPanY    = 0,
    zoomFocusU    = 0.5,
    zoomFocusV    = 0.5,
    zoomCursorX   = 0,
    zoomCursorY   = 0,
    animating     = false,
    dragging      = false,
    dragStartCX   = 0,
    dragStartCY   = 0,
    dragStartPanX = 0,
    dragStartPanY = 0,
    footerElapsed = 0,
    -- Original Blizzard anchors saved for clean disable/restore
    origMapParent    = nil,
    origMapPoints    = {},
    origRouteParent  = nil,
    origRoutePoints  = {},
    -- Created lazily on first TAXIMAP_OPENED
    viewport      = nil,
    scrollChild   = nil,
    canvas        = nil,
    artFrame      = nil,
    artHolder     = nil,
    backdropTex   = nil,
    routeFrame    = nil,
    pinFrame      = nil,
    resetBtn      = nil,
    footerBar     = nil,
    footerZone    = nil,
    footerCoords  = nil,
    -- Reusable pools (zero per-open allocations)
    artTiles      = {},
    exploreTiles  = {},
    pinOrigPos    = {}, -- [buttonIndex] = { x, y } in TaxiMap coords
    zoneRectCache = {}, -- [continentMapID] = { [zoneMapID] = { l, r, t, b } }
}

local function SavePoints(region, dest)
    wipe(dest)
    if not (region and region.GetNumPoints) then
        return
    end
    local n = region:GetNumPoints() or 0
    for i = 1, n do
        local p, rel, rp, x, y = region:GetPoint(i)
        dest[i] = { p, rel, rp, x, y }
    end
end

local function RestorePoints(region, src)
    if not (region and src and #src > 0) then
        return
    end
    region:ClearAllPoints()
    for i = 1, #src do
        local pt = src[i]
        region:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
    end
end

--------------------------------------------------------------------------------
-- High-Detail Map Art & Exploration Overlay Compositing
--------------------------------------------------------------------------------

local function HidePooledTextures(pool)
    for i = 1, #pool do
        pool[i]:Hide()
    end
end

local function AcquireTexture(pool, index, parent, drawLayer, subLevel)
    local tex = pool[index]
    if not tex then
        tex = parent:CreateTexture(nil, drawLayer or "ARTWORK", nil, subLevel or 0)
        pool[index] = tex
    end
    return tex
end

local function CompositeExplorationOverlays(continentMapID, artW, artH, revealUnexplored)
    HidePooledTextures(taxiState.exploreTiles)
    if revealUnexplored or not continentMapID then
        return
    end
    if not (C_Map and C_Map.GetMapChildrenInfo and C_Map.GetMapRectOnMap and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures) then
        return
    end

    local okChildren, children = pcall(C_Map.GetMapChildrenInfo, continentMapID, 3, true) -- Enum.UIMapType.Zone == 3
    if not okChildren or type(children) ~= "table" then
        return
    end

    local tileIdx = 0
    for i = 1, #children do
        local child = children[i]
        local zID = child and SafeNumber(child.mapID)
        if zID then
            local okRect, l, r, t, b = pcall(C_Map.GetMapRectOnMap, zID, continentMapID)
            l, r, t, b = SafeNumber(l), SafeNumber(r), SafeNumber(t), SafeNumber(b)
            if okRect and l and r and t and b and r > l and b > t then
                local okLayers, zLayers = pcall(C_Map.GetMapArtLayers, zID)
                local zLayer = okLayers and type(zLayers) == "table" and zLayers[1]
                local zLayerW = zLayer and SafeNumber(zLayer.layerWidth)
                local zLayerH = zLayer and SafeNumber(zLayer.layerHeight)
                if zLayerW and zLayerH and zLayerW > 0 and zLayerH > 0 then
                    local okExp, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, zID)
                    if okExp and type(explored) == "table" then
                        local zLeft = l * artW
                        local zTop  = t * artH
                        local zW    = (r - l) * artW
                        local zH    = (b - t) * artH
                        local scaleX = zW / zLayerW
                        local scaleY = zH / zLayerH
                        for j = 1, #explored do
                            local info = explored[j]
                            if type(info) == "table" and info.fileDataIDs and info.textureWidth and info.textureHeight then
                                local cols = ceil(info.textureWidth / 256)
                                local rows = ceil(info.textureHeight / 256)
                                local fileIdx = 0
                                for row = 0, rows - 1 do
                                    local h = min(256, info.textureHeight - row * 256)
                                    for col = 0, cols - 1 do
                                        local w = min(256, info.textureWidth - col * 256)
                                        fileIdx = fileIdx + 1
                                        local fileID = info.fileDataIDs[fileIdx]
                                        if fileID then
                                            tileIdx = tileIdx + 1
                                            local tex = AcquireTexture(taxiState.exploreTiles, tileIdx, taxiState.artHolder, "ARTWORK", 2)
                                            tex:SetTexture(fileID)
                                            tex:SetVertexColor(1, 1, 1, 1)
                                            tex:ClearAllPoints()
                                            tex:SetPoint(
                                                "TOPLEFT",
                                                taxiState.artHolder,
                                                "TOPLEFT",
                                                zLeft + (info.offsetX + col * 256) * scaleX,
                                                -(zTop + (info.offsetY + row * 256) * scaleY)
                                            )
                                            tex:SetSize(w * scaleX, h * scaleY)
                                            tex:SetTexCoord(0, w / 256, 0, h / 256)
                                            tex:Show()
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function CompositeContinentArt(continentMapID)
    local db = FM:GetDB()
    local taxiMap = _G.TaxiMap
    if not (taxiState.artHolder and taxiMap) then
        return false
    end

    HidePooledTextures(taxiState.artTiles)
    HidePooledTextures(taxiState.exploreTiles)

    if not (db.enabled and db.highResArt and continentMapID) then
        taxiState.artFrame:Hide()
        taxiMap:SetAlpha(1)
        return false
    end

    if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then
        taxiState.artFrame:Hide()
        taxiMap:SetAlpha(1)
        return false
    end

    local okLayers, layers = pcall(C_Map.GetMapArtLayers, continentMapID)
    if not okLayers or type(layers) ~= "table" or #layers == 0 then
        taxiState.artFrame:Hide()
        taxiMap:SetAlpha(1)
        return false
    end

    -- Choose highest-detail layer
    local bestIdx = 1
    local bestArea = 0
    for i = 1, #layers do
        local lyr = layers[i]
        local area = (SafeNumber(lyr.layerWidth, 0) or 0) * (SafeNumber(lyr.layerHeight, 0) or 0)
        if area > bestArea then
            bestArea = area
            bestIdx = i
        end
    end

    local layer = layers[bestIdx]
    local layerW = SafeNumber(layer.layerWidth)
    local layerH = SafeNumber(layer.layerHeight)
    local tileW  = SafeNumber(layer.tileWidth, 256) or 256
    local tileH  = SafeNumber(layer.tileHeight, 256) or 256
    if not layerW or not layerH or layerW <= 0 or layerH <= 0 then
        taxiState.artFrame:Hide()
        taxiMap:SetAlpha(1)
        return false
    end

    local okTex, textures = pcall(C_Map.GetMapArtLayerTextures, continentMapID, bestIdx)
    if not okTex or type(textures) ~= "table" or #textures == 0 then
        taxiState.artFrame:Hide()
        taxiMap:SetAlpha(1)
        return false
    end

    DetectMapPacks()
    local useOpenMapArt = db.preferOpenMapPack and hasOpenMap and OPENMAP_ART_MAPS[continentMapID] and bestIdx == 1

    local baseW = taxiState.baseW
    local baseH = taxiState.baseH
    local artW  = taxiState.ax * baseW
    local artH  = taxiState.ay * baseH
    local artX  = taxiState.bx * baseW
    local artY  = taxiState.by * baseH

    taxiState.artHolder:ClearAllPoints()
    taxiState.artHolder:SetPoint("TOPLEFT", taxiState.artFrame, "TOPLEFT", artX, -artY)
    taxiState.artHolder:SetSize(artW, artH)

    local cols = ceil(layerW / tileW)
    local rows = ceil(layerH / tileH)
    local sx = artW / layerW
    local sy = artH / layerH

    -- Slight dim on base art when Unexplored Area Reveal is OFF so explored
    -- overlays stand out clearly; full brightness when reveal is ON.
    local tintR, tintG, tintB = 1, 1, 1
    if not db.revealUnexplored then
        tintR, tintG, tintB = 0.62, 0.59, 0.54
    end

    local idx = 0
    for row = 0, rows - 1 do
        local h = min(tileH, layerH - row * tileH)
        for col = 0, cols - 1 do
            local w = min(tileW, layerW - col * tileW)
            idx = idx + 1
            local texSource = textures[idx]
            if useOpenMapArt and cols == 4 and rows == 3 then
                texSource = "Interface\\AddOns\\OpenMap\\Media\\Textures\\Forever\\MapArt\\" .. continentMapID .. "_" .. idx
            end
            if texSource then
                local tex = AcquireTexture(taxiState.artTiles, idx, taxiState.artHolder, "ARTWORK", 0)
                tex:SetTexture(texSource)
                tex:SetVertexColor(tintR, tintG, tintB, 1)
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", taxiState.artHolder, "TOPLEFT", col * tileW * sx, -(row * tileH * sy))
                tex:SetSize(w * sx, h * sy)
                tex:SetTexCoord(0, w / tileW, 0, h / tileH)
                tex:Show()
            end
        end
    end

    CompositeExplorationOverlays(continentMapID, artW, artH, db.revealUnexplored)

    taxiState.artFrame:Show()
    -- Hide Blizzard's low-res parchment via alpha so all Blizzard anchors remain intact.
    taxiMap:SetAlpha(0)
    return true
end

--------------------------------------------------------------------------------
-- Flight Pin & Route Line Alignment / Inverse Scaling
--------------------------------------------------------------------------------

local function ReparentRouteLines()
    local taxiFrame = _G.TaxiFrame
    local taxiRouteMap = _G.TaxiRouteMap
    if not (taxiFrame and taxiState.routeFrame) then
        return
    end
    local numRegions = taxiFrame:GetNumRegions() or 0
    for i = 1, numRegions do
        local region = select(i, taxiFrame:GetRegions())
        if region and region ~= _G.TaxiMap and region ~= taxiRouteMap and region.GetObjectType and region:GetObjectType() == "Texture" then
            local okTex, texPath = pcall(region.GetTexture, region)
            local pathStr = okTex and SafeString(texPath) or nil
            local isRoute = false
            if pathStr and find(lower(pathStr), "taxi%-line") then
                isRoute = true
            elseif region.GetNumPoints and (region:GetNumPoints() or 0) > 0 then
                local _, relTo = region:GetPoint(1)
                if relTo == taxiRouteMap or relTo == _G.TaxiMap then
                    isRoute = true
                end
            end
            if isRoute then
                region:SetParent(taxiState.routeFrame)
            end
        end
    end
end

local function SyncTaxiPins(zoom)
    local taxiMap = _G.TaxiMap
    if not (taxiMap and taxiState.pinFrame and NumTaxiNodes) then
        return
    end
    local db = FM:GetDB()
    local numNodes = SafeNumber(NumTaxiNodes(), 0) or 0
    local pinScale = 1.0
    if db.enabled and db.enableZoomPan and zoom > 1.001 then
        pinScale = Clamp(1.0 / zoom, PIN_SCALE_MIN, 1.0)
    end

    local mapW = taxiState.baseW
    local mapH = taxiState.baseH

    for i = 1, numNodes do
        local btn = _G["TaxiButton" .. i]
        if btn then
            if db.enabled then
                if btn:GetParent() ~= taxiState.pinFrame then
                    btn:SetParent(taxiState.pinFrame)
                end
            else
                if _G.TaxiFrame and btn:GetParent() ~= _G.TaxiFrame then
                    btn:SetParent(_G.TaxiFrame)
                end
            end

            -- Cache exact Blizzard TaxiMap pixel coordinates
            local pos = taxiState.pinOrigPos[i]
            if not pos then
                local tx, ty = TaxiNodePosition(i)
                tx = SafeNumber(tx)
                ty = SafeNumber(ty)
                if tx and ty then
                    pos = { tx * mapW, ty * mapH }
                    taxiState.pinOrigPos[i] = pos
                end
            end

            if pos then
                btn:SetScale(pinScale)
                -- Compensate anchor offset for button's own scale so its CENTER
                -- stays pixel-locked to (pos[1], pos[2]) on TaxiMap at any zoom.
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", taxiMap, "BOTTOMLEFT", pos[1] / pinScale, pos[2] / pinScale)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Zoom & Pan Engine (Zero-Idle-CPU, Clipped ScrollFrame)
--------------------------------------------------------------------------------

local function UpdateResetButtonVisibility()
    if not taxiState.resetBtn then
        return
    end
    local db = FM:GetDB()
    if db.enabled and db.enableZoomPan and taxiState.zoom > 1.02 then
        taxiState.resetBtn:Show()
    else
        taxiState.resetBtn:Hide()
    end
end

local function ApplyZoomAndPan(zoom, panX, panY)
    if not (taxiState.viewport and taxiState.scrollChild and taxiState.canvas) then
        return
    end
    local db = FM:GetDB()
    local maxZ = db.enableZoomPan and db.maxZoom or ZOOM_MIN
    zoom = Clamp(zoom, ZOOM_MIN, maxZ)

    local maxPanX = max(0, taxiState.baseW * (zoom - 1))
    local maxPanY = max(0, taxiState.baseH * (zoom - 1))
    panX = Clamp(panX, 0, maxPanX)
    panY = Clamp(panY, 0, maxPanY)

    taxiState.zoom = zoom
    taxiState.panX = panX
    taxiState.panY = panY

    taxiState.scrollChild:SetSize(taxiState.baseW * zoom, taxiState.baseH * zoom)
    taxiState.canvas:SetScale(zoom)
    taxiState.viewport:SetHorizontalScroll(panX)
    taxiState.viewport:SetVerticalScroll(panY)

    SyncTaxiPins(zoom)
    UpdateResetButtonVisibility()
end

local function StopViewportMotion()
    taxiState.animating = false
    taxiState.dragging = false
    if taxiState.viewport then
        taxiState.viewport:SetScript("OnUpdate", nil)
    end
end

local function ViewportOnUpdate(_, elapsed)
    if taxiState.dragging then
        local scale = taxiState.viewport:GetEffectiveScale()
        if not scale or scale <= 0 then
            scale = 1
        end
        local cx, cy = GetCursorPosition()
        cx = cx / scale
        cy = cy / scale
        local dx = cx - taxiState.dragStartCX
        local dy = cy - taxiState.dragStartCY
        local newPanX = taxiState.dragStartPanX - dx
        local newPanY = taxiState.dragStartPanY + dy
        taxiState.targetPanX = newPanX
        taxiState.targetPanY = newPanY
        ApplyZoomAndPan(taxiState.zoom, newPanX, newPanY)
        return
    end

    if taxiState.animating then
        local t = min(1, elapsed * ZOOM_LERP_SPEED)
        local nextZoom = taxiState.zoom + (taxiState.targetZoom - taxiState.zoom) * t
        local nextPanX, nextPanY
        if abs(taxiState.targetZoom - nextZoom) < 0.002 then
            nextZoom = taxiState.targetZoom
            if nextZoom <= ZOOM_MIN + 0.001 then
                nextZoom = ZOOM_MIN
                nextPanX = 0
                nextPanY = 0
            else
                nextPanX = taxiState.zoomFocusU * nextZoom - taxiState.zoomCursorX
                nextPanY = taxiState.zoomFocusV * nextZoom - taxiState.zoomCursorY
            end
            ApplyZoomAndPan(nextZoom, nextPanX, nextPanY)
            StopViewportMotion()
        else
            if taxiState.targetZoom <= ZOOM_MIN + 0.001 then
                nextPanX = taxiState.panX + (0 - taxiState.panX) * t
                nextPanY = taxiState.panY + (0 - taxiState.panY) * t
            else
                nextPanX = taxiState.zoomFocusU * nextZoom - taxiState.zoomCursorX
                nextPanY = taxiState.zoomFocusV * nextZoom - taxiState.zoomCursorY
            end
            ApplyZoomAndPan(nextZoom, nextPanX, nextPanY)
        end
        return
    end

    StopViewportMotion()
end

local function ResetZoomSmooth(immediate)
    if immediate then
        StopViewportMotion()
        taxiState.targetZoom = ZOOM_MIN
        taxiState.targetPanX = 0
        taxiState.targetPanY = 0
        ApplyZoomAndPan(ZOOM_MIN, 0, 0)
        return
    end
    taxiState.dragging = false
    taxiState.targetZoom = ZOOM_MIN
    taxiState.targetPanX = 0
    taxiState.targetPanY = 0
    taxiState.animating = true
    if taxiState.viewport then
        taxiState.viewport:SetScript("OnUpdate", ViewportOnUpdate)
    end
end

local function OnViewportMouseWheel(self, delta)
    local db = FM:GetDB()
    if not (db.enabled and db.enableZoomPan) then
        return
    end
    local scale = self:GetEffectiveScale()
    if not scale or scale <= 0 then
        scale = 1
    end
    local cx, cy = GetCursorPosition()
    cx = cx / scale
    cy = cy / scale

    local left = self:GetLeft() or 0
    local top  = self:GetTop() or 0
    local localX = Clamp(cx - left, 0, taxiState.baseW)
    local localY = Clamp(top - cy, 0, taxiState.baseH)

    -- Anchor zoom toward the exact canvas coordinate under the cursor
    local curZoom = taxiState.zoom
    taxiState.zoomFocusU  = (taxiState.panX + localX) / curZoom
    taxiState.zoomFocusV  = (taxiState.panY + localY) / curZoom
    taxiState.zoomCursorX = localX
    taxiState.zoomCursorY = localY

    local desired = Clamp(taxiState.targetZoom + delta * ZOOM_STEP, ZOOM_MIN, db.maxZoom)
    if abs(desired - taxiState.targetZoom) < 0.001 and abs(desired - curZoom) < 0.001 then
        return
    end
    taxiState.targetZoom = desired
    taxiState.animating = true
    self:SetScript("OnUpdate", ViewportOnUpdate)
end

local function OnViewportMouseDown(self, button)
    local db = FM:GetDB()
    if not (db.enabled and db.enableZoomPan) then
        return
    end
    if button == "RightButton" then
        if taxiState.zoom > ZOOM_MIN + 0.01 or taxiState.targetZoom > ZOOM_MIN + 0.01 then
            ResetZoomSmooth(false)
        end
        return
    end
    if button == "LeftButton" and taxiState.zoom > ZOOM_MIN + 0.01 then
        local scale = self:GetEffectiveScale()
        if not scale or scale <= 0 then
            scale = 1
        end
        local cx, cy = GetCursorPosition()
        taxiState.dragging = true
        taxiState.animating = false
        taxiState.dragStartCX = cx / scale
        taxiState.dragStartCY = cy / scale
        taxiState.dragStartPanX = taxiState.panX
        taxiState.dragStartPanY = taxiState.panY
        self:SetScript("OnUpdate", ViewportOnUpdate)
    end
end

local function OnViewportMouseUp(_, button)
    if button == "LeftButton" and taxiState.dragging then
        taxiState.dragging = false
        if not taxiState.animating and taxiState.viewport then
            taxiState.viewport:SetScript("OnUpdate", nil)
        end
    end
end

--------------------------------------------------------------------------------
-- Footer Bar: Zone Name, Level Range & Cursor Coordinates
--------------------------------------------------------------------------------

local function UpdateFooterReadout(_, elapsed)
    taxiState.footerElapsed = taxiState.footerElapsed + elapsed
    if taxiState.footerElapsed < FOOTER_INTERVAL then
        return
    end
    taxiState.footerElapsed = 0

    local vp = taxiState.viewport
    if not (vp and vp:IsShown() and taxiState.footerBar and taxiState.footerBar:IsShown()) then
        return
    end

    local continentID = taxiState.continentID
    if not vp:IsMouseOver() then
        local zoomSuffix = taxiState.zoom > 1.02 and format("  |cffd4a85a%.1fx|r", taxiState.zoom) or ""
        taxiState.footerZone:SetText("")
        taxiState.footerCoords:SetText(zoomSuffix)
        return
    end

    local scale = vp:GetEffectiveScale()
    if not scale or scale <= 0 then
        scale = 1
    end
    local cx, cy = GetCursorPosition()
    local left = vp:GetLeft()
    local top  = vp:GetTop()
    if not (left and top) then
        return
    end

    local localX = (cx / scale) - left
    local localY = top - (cy / scale)
    local tx = (taxiState.panX + localX) / (taxiState.baseW * taxiState.zoom)
    local ty = (taxiState.panY + localY) / (taxiState.baseH * taxiState.zoom)

    local mx = (tx - taxiState.bx) / taxiState.ax
    local my = (ty - taxiState.by) / taxiState.ay

    local zoneText = ""
    local coordX, coordY = mx, my

    if continentID and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 and C_Map and C_Map.GetMapInfoAtPosition then
        local okInfo, info = pcall(C_Map.GetMapInfoAtPosition, continentID, mx, my)
        if okInfo and type(info) == "table" and info.name then
            local zoneID = SafeNumber(info.mapID)
            local minLvl, maxLvl = GetZoneLevels(zoneID)
            if minLvl and maxLvl and maxLvl > 0 then
                local hex = GetLevelColorHex(minLvl, maxLvl)
                zoneText = format("|cffffffff%s|r |cff%s(%d-%d)|r", info.name, hex, minLvl, maxLvl)
            else
                zoneText = format("|cffffffff%s|r", info.name)
            end

            -- Convert continent (mx, my) into zone-local (0..100) coordinates if available
            if zoneID and zoneID ~= continentID and C_Map.GetMapRectOnMap then
                local okR, l, r, t, b = pcall(C_Map.GetMapRectOnMap, zoneID, continentID)
                l, r, t, b = SafeNumber(l), SafeNumber(r), SafeNumber(t), SafeNumber(b)
                if okR and l and r and t and b and r > l and b > t then
                    coordX = (mx - l) / (r - l)
                    coordY = (my - t) / (b - t)
                end
            end
        end
    end

    local coordText = ""
    if coordX >= 0 and coordX <= 1 and coordY >= 0 and coordY <= 1 then
        coordText = format("|cffc8ccd4%.1f, %.1f|r", coordX * 100, coordY * 100)
    end
    if taxiState.zoom > 1.02 then
        coordText = coordText .. format("  |cffd4a85a%.1fx|r", taxiState.zoom)
    end

    taxiState.footerZone:SetText(zoneText)
    taxiState.footerCoords:SetText(coordText)
end

--------------------------------------------------------------------------------
-- Lazy Construction for Classic / WoW Forever TaxiFrame
--------------------------------------------------------------------------------

local function EnsureTaxiFrameBuilt()
    if taxiState.initialized then
        return true
    end
    local taxiFrame = _G.TaxiFrame
    local taxiMap = _G.TaxiMap
    if not (taxiFrame and taxiMap) then
        return false
    end

    taxiState.initialized = true

    local w = SafeNumber(taxiMap:GetWidth(), 580) or 580
    local h = SafeNumber(taxiMap:GetHeight(), 580) or 580
    taxiState.baseW = w
    taxiState.baseH = h

    -- Save Blizzard's original hierarchy & anchors so we can cleanly restore if disabled
    taxiState.origMapParent = taxiMap:GetParent()
    SavePoints(taxiMap, taxiState.origMapPoints)
    local taxiRouteMap = _G.TaxiRouteMap
    if taxiRouteMap then
        taxiState.origRouteParent = taxiRouteMap:GetParent()
        SavePoints(taxiRouteMap, taxiState.origRoutePoints)
    end

    -- Clipped ScrollFrame viewport matching TaxiMap's exact screen rect
    local viewport = CreateFrame("ScrollFrame", "XiusFlightMapViewport", taxiFrame)
    viewport:SetClipsChildren(true)
    viewport:SetSize(w, h)
    RestorePoints(viewport, taxiState.origMapPoints)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    viewport:SetFrameLevel(taxiFrame:GetFrameLevel() + 1)
    viewport:SetScript("OnMouseWheel", OnViewportMouseWheel)
    viewport:SetScript("OnMouseDown", OnViewportMouseDown)
    viewport:SetScript("OnMouseUp", OnViewportMouseUp)
    taxiState.viewport = viewport

    -- Unscaled scroll child so ScrollFrame scroll ranges stay exact across all clients
    local scrollChild = CreateFrame("Frame", "XiusFlightMapScrollChild", viewport)
    scrollChild:SetSize(w, h)
    viewport:SetScrollChild(scrollChild)
    taxiState.scrollChild = scrollChild

    -- Zoomable canvas inside scrollChild
    local canvas = CreateFrame("Frame", "XiusFlightMapCanvas", scrollChild)
    canvas:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    canvas:SetSize(w, h)
    taxiState.canvas = canvas

    -- High-res art layer
    local artFrame = CreateFrame("Frame", nil, canvas)
    artFrame:SetAllPoints(canvas)
    artFrame:SetFrameLevel(canvas:GetFrameLevel() + 1)
    taxiState.artFrame = artFrame

    local backdropTex = artFrame:CreateTexture(nil, "BACKGROUND")
    backdropTex:SetAllPoints(artFrame)
    backdropTex:SetColorTexture(0.08, 0.11, 0.15, 1)
    taxiState.backdropTex = backdropTex

    local artHolder = CreateFrame("Frame", nil, artFrame)
    artHolder:SetAllPoints(artFrame)
    taxiState.artHolder = artHolder

    -- Route line layer (above map art, below flight pins)
    local routeFrame = CreateFrame("Frame", nil, canvas)
    routeFrame:SetAllPoints(canvas)
    routeFrame:SetFrameLevel(canvas:GetFrameLevel() + 2)
    taxiState.routeFrame = routeFrame

    -- Flight pin layer (always on top & clickable)
    local pinFrame = CreateFrame("Frame", nil, canvas)
    pinFrame:SetAllPoints(canvas)
    pinFrame:SetFrameLevel(canvas:GetFrameLevel() + 5)
    taxiState.pinFrame = pinFrame

    -- Compact Reset Zoom button (top-right inside viewport, visible only when zoomed)
    local resetBtn = CreateFrame("Button", "XiusFlightMapResetZoom", viewport)
    resetBtn:SetSize(56, 22)
    resetBtn:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", -8, -8)
    resetBtn:SetFrameLevel(viewport:GetFrameLevel() + 15)
    local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
    resetBg:SetAllPoints(resetBtn)
    resetBg:SetColorTexture(0.06, 0.07, 0.10, 0.85)
    local resetBorder = resetBtn:CreateTexture(nil, "BORDER")
    resetBorder:SetPoint("TOPLEFT", -1, 1)
    resetBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    resetBorder:SetColorTexture(0.83, 0.66, 0.35, 0.65)
    local resetLabel = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetLabel:SetPoint("CENTER")
    resetLabel:SetText("1.0x")
    resetBtn:SetScript("OnClick", function()
        ResetZoomSmooth(false)
    end)
    resetBtn:SetScript("OnEnter", function(self)
        resetBg:SetColorTexture(0.14, 0.16, 0.22, 0.95)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Reset Zoom (1.0x)", 1, 0.82, 0)
            GameTooltip:AddLine("Or right-click anywhere on the map.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)
    resetBtn:SetScript("OnLeave", function()
        resetBg:SetColorTexture(0.06, 0.07, 0.10, 0.85)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    resetBtn:Hide()
    taxiState.resetBtn = resetBtn

    -- Bottom-edge footer readout (Zone + Level Range on left, Cursor Coords + Zoom on right)
    local footerBar = CreateFrame("Frame", "XiusFlightMapFooter", viewport)
    footerBar:SetHeight(22)
    footerBar:SetPoint("BOTTOMLEFT", viewport, "BOTTOMLEFT", 0, 0)
    footerBar:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", 0, 0)
    footerBar:SetFrameLevel(viewport:GetFrameLevel() + 14)

    local footerBg = footerBar:CreateTexture(nil, "BACKGROUND")
    footerBg:SetAllPoints(footerBar)
    footerBg:SetColorTexture(0.05, 0.06, 0.09, 0.78)

    local footerZone = footerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerZone:SetPoint("LEFT", footerBar, "LEFT", 8, 0)
    footerZone:SetJustifyH("LEFT")
    taxiState.footerZone = footerZone

    local footerCoords = footerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerCoords:SetPoint("RIGHT", footerBar, "RIGHT", -8, 0)
    footerCoords:SetJustifyH("RIGHT")
    taxiState.footerCoords = footerCoords
    taxiState.footerBar = footerBar

    -- Hook TaxiNodeOnButtonEnter so dynamically created Blizzard route lines
    -- are reparented into routeFrame (clipped & layered above our high-res art).
    if not taxiState.hookedRoutes then
        taxiState.hookedRoutes = true
        if type(_G.TaxiNodeOnButtonEnter) == "function" then
            hooksecurefunc("TaxiNodeOnButtonEnter", function()
                if taxiState.active then
                    ReparentRouteLines()
                end
            end)
        end
        taxiFrame:HookScript("OnHide", function()
            FM:OnTaxiClosed()
        end)
    end

    return true
end

local function AttachTaxiMapToCanvas(attach)
    local taxiMap = _G.TaxiMap
    local taxiRouteMap = _G.TaxiRouteMap
    if not (taxiMap and taxiState.initialized) then
        return
    end
    if attach then
        taxiState.viewport:Show()
        taxiMap:SetParent(taxiState.canvas)
        taxiMap:ClearAllPoints()
        taxiMap:SetPoint("TOPLEFT", taxiState.canvas, "TOPLEFT", 0, 0)
        taxiMap:SetSize(taxiState.baseW, taxiState.baseH)
        if taxiRouteMap then
            taxiRouteMap:SetParent(taxiState.routeFrame)
            taxiRouteMap:ClearAllPoints()
            taxiRouteMap:SetAllPoints(taxiMap)
        end
    else
        taxiState.viewport:Hide()
        taxiMap:SetParent(taxiState.origMapParent or _G.TaxiFrame)
        RestorePoints(taxiMap, taxiState.origMapPoints)
        taxiMap:SetSize(taxiState.baseW, taxiState.baseH)
        taxiMap:SetAlpha(1)
        if taxiRouteMap then
            taxiRouteMap:SetParent(taxiState.origRouteParent or _G.TaxiFrame)
            RestorePoints(taxiRouteMap, taxiState.origRoutePoints)
        end
    end
end

--------------------------------------------------------------------------------
-- Retail FlightMapFrame Integration
--------------------------------------------------------------------------------

local retailState = {
    hooked       = false,
    footerBar    = nil,
    footerZone   = nil,
    footerCoords = nil,
    elapsed      = 0,
}

local function ApplyRetailExplorationReveal(frame)
    local db = FM:GetDB()
    if not (frame and frame.dataProviders) then
        return
    end
    for provider in pairs(frame.dataProviders) do
        if type(provider) == "table" and provider.RefreshAllData and provider.pin then
            -- FogOfWar / Exploration pin overlay
            if provider.pin.SetAlpha then
                if db.enabled and db.revealUnexplored then
                    provider.pin:SetAlpha(0)
                else
                    provider.pin:SetAlpha(1)
                end
            end
        end
    end
end

local function RetailFooterOnUpdate(_, elapsed)
    retailState.elapsed = retailState.elapsed + elapsed
    if retailState.elapsed < FOOTER_INTERVAL then
        return
    end
    retailState.elapsed = 0

    local fmf = _G.FlightMapFrame
    if not (fmf and fmf:IsShown() and fmf.ScrollContainer and retailState.footerBar and retailState.footerBar:IsShown()) then
        return
    end

    if not fmf.ScrollContainer:IsMouseOver() then
        retailState.footerZone:SetText("")
        retailState.footerCoords:SetText("")
        return
    end

    local mapID = fmf.GetMapID and SafeNumber(fmf:GetMapID()) or nil
    local mx, my
    if fmf.GetNormalizedCursorPosition then
        local ok, x, y = pcall(fmf.GetNormalizedCursorPosition, fmf)
        if ok then
            mx, my = SafeNumber(x), SafeNumber(y)
        end
    end
    if not (mapID and mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1) then
        retailState.footerZone:SetText("")
        retailState.footerCoords:SetText("")
        return
    end

    local zoneText = ""
    local coordX, coordY = mx, my
    if C_Map and C_Map.GetMapInfoAtPosition then
        local okInfo, info = pcall(C_Map.GetMapInfoAtPosition, mapID, mx, my)
        if okInfo and type(info) == "table" and info.name then
            local zoneID = SafeNumber(info.mapID)
            local minLvl, maxLvl = GetZoneLevels(zoneID)
            if minLvl and maxLvl and maxLvl > 0 then
                local hex = GetLevelColorHex(minLvl, maxLvl)
                zoneText = format("|cffffffff%s|r |cff%s(%d-%d)|r", info.name, hex, minLvl, maxLvl)
            else
                zoneText = format("|cffffffff%s|r", info.name)
            end
            if zoneID and zoneID ~= mapID and C_Map.GetMapRectOnMap then
                local okR, l, r, t, b = pcall(C_Map.GetMapRectOnMap, zoneID, mapID)
                l, r, t, b = SafeNumber(l), SafeNumber(r), SafeNumber(t), SafeNumber(b)
                if okR and l and r and t and b and r > l and b > t then
                    coordX = (mx - l) / (r - l)
                    coordY = (my - t) / (b - t)
                end
            end
        end
    end

    retailState.footerZone:SetText(zoneText)
    retailState.footerCoords:SetText(format("|cffc8ccd4%.1f, %.1f|r", coordX * 100, coordY * 100))
end

local function EnsureRetailFlightMapHooked()
    local fmf = _G.FlightMapFrame
    if not fmf or retailState.hooked then
        return fmf ~= nil
    end
    retailState.hooked = true

    local host = fmf.BorderFrame or fmf
    local bar = CreateFrame("Frame", "XiusRetailFlightMapFooter", host)
    bar:SetHeight(22)
    bar:SetPoint("BOTTOMLEFT", fmf.ScrollContainer or fmf, "BOTTOMLEFT", 4, 4)
    bar:SetPoint("BOTTOMRIGHT", fmf.ScrollContainer or fmf, "BOTTOMRIGHT", -4, 4)
    bar:SetFrameStrata("HIGH")

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0.05, 0.06, 0.09, 0.78)

    local zText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zText:SetPoint("LEFT", bar, "LEFT", 8, 0)
    zText:SetJustifyH("LEFT")
    retailState.footerZone = zText

    local cText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cText:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    cText:SetJustifyH("RIGHT")
    retailState.footerCoords = cText
    retailState.footerBar = bar

    fmf:HookScript("OnShow", function(self)
        local db = FM:GetDB()
        ApplyRetailExplorationReveal(self)
        if db.enabled and db.showFooterInfo then
            retailState.elapsed = 0
            bar:Show()
            bar:SetScript("OnUpdate", RetailFooterOnUpdate)
        else
            bar:Hide()
            bar:SetScript("OnUpdate", nil)
        end
    end)

    fmf:HookScript("OnHide", function()
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
    end)

    if fmf.OnMapChanged then
        hooksecurefunc(fmf, "OnMapChanged", function(self)
            ApplyRetailExplorationReveal(self)
        end)
    end

    return true
end

--------------------------------------------------------------------------------
-- Lifecycle: TAXIMAP_OPENED / TAXIMAP_CLOSED / Apply
--------------------------------------------------------------------------------

function FM:OnTaxiOpened()
    -- Retail FlightMapFrame path
    if _G.FlightMapFrame and _G.FlightMapFrame:IsShown() then
        EnsureRetailFlightMapHooked()
        return
    end

    -- Classic / WoW Forever TaxiFrame path
    if not _G.TaxiFrame or not _G.TaxiMap then
        return
    end

    local db = self:GetDB()
    if not db.enabled then
        if taxiState.initialized then
            AttachTaxiMapToCanvas(false)
            SyncTaxiPins(ZOOM_MIN)
        end
        return
    end

    if not EnsureTaxiFrameBuilt() then
        return
    end

    taxiState.active = true
    wipe(taxiState.pinOrigPos)

    AttachTaxiMapToCanvas(true)

    local continentID = FindContinentMapID()
    taxiState.continentID = continentID
    local ax, bx, ay, by, calibrated = CalibrateTaxiToContinent(continentID)
    taxiState.ax = ax
    taxiState.bx = bx
    taxiState.ay = ay
    taxiState.by = by
    taxiState.calibrated = calibrated

    CompositeContinentArt(continentID)
    ReparentRouteLines()
    ResetZoomSmooth(true)

    if db.showFooterInfo then
        taxiState.footerElapsed = 0
        taxiState.footerBar:Show()
        taxiState.footerBar:SetScript("OnUpdate", UpdateFooterReadout)
    else
        taxiState.footerBar:SetScript("OnUpdate", nil)
        taxiState.footerBar:Hide()
    end
end

function FM:OnTaxiClosed()
    taxiState.active = false
    if not taxiState.initialized then
        return
    end
    StopViewportMotion()
    ResetZoomSmooth(true)
    if taxiState.footerBar then
        taxiState.footerBar:SetScript("OnUpdate", nil)
        taxiState.footerZone:SetText("")
        taxiState.footerCoords:SetText("")
    end
    wipe(taxiState.pinOrigPos)
end

function FM:Apply()
    local db = self:GetDB()

    -- Live update if Retail FlightMapFrame is open
    if _G.FlightMapFrame and _G.FlightMapFrame:IsShown() then
        EnsureRetailFlightMapHooked()
        ApplyRetailExplorationReveal(_G.FlightMapFrame)
        if retailState.footerBar then
            if db.enabled and db.showFooterInfo then
                retailState.footerBar:Show()
                retailState.footerBar:SetScript("OnUpdate", RetailFooterOnUpdate)
            else
                retailState.footerBar:SetScript("OnUpdate", nil)
                retailState.footerBar:Hide()
            end
        end
    end

    -- Live update if Classic / WoW Forever TaxiFrame is open
    if _G.TaxiFrame and _G.TaxiFrame:IsShown() then
        if db.enabled then
            if not taxiState.active then
                self:OnTaxiOpened()
            else
                CompositeContinentArt(taxiState.continentID)
                if not db.enableZoomPan then
                    ResetZoomSmooth(true)
                else
                    ApplyZoomAndPan(min(taxiState.zoom, db.maxZoom), taxiState.panX, taxiState.panY)
                end
                if db.showFooterInfo then
                    taxiState.footerBar:Show()
                    taxiState.footerBar:SetScript("OnUpdate", UpdateFooterReadout)
                else
                    taxiState.footerBar:SetScript("OnUpdate", nil)
                    taxiState.footerBar:Hide()
                end
            end
        elseif taxiState.initialized then
            taxiState.active = false
            StopViewportMotion()
            ResetZoomSmooth(true)
            AttachTaxiMapToCanvas(false)
            SyncTaxiPins(ZOOM_MIN)
            if taxiState.footerBar then
                taxiState.footerBar:SetScript("OnUpdate", nil)
                taxiState.footerBar:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Event Registration & Module Registration
--------------------------------------------------------------------------------

if XiusUI and XiusUI.RegisterEvent then
    XiusUI:RegisterEvent("TAXIMAP_OPENED", function()
        -- Defer one frame so Blizzard's TaxiFrame_OnEvent finishes placing
        -- TaxiButton1..N before we calibrate and sync pins.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if (_G.TaxiFrame and _G.TaxiFrame:IsShown()) or (_G.FlightMapFrame and _G.FlightMapFrame:IsShown()) then
                    FM:OnTaxiOpened()
                end
            end)
        else
            FM:OnTaxiOpened()
        end
    end)

    XiusUI:RegisterEvent("TAXIMAP_CLOSED", function()
        FM:OnTaxiClosed()
    end)

    XiusUI:RegisterEvent("ADDON_LOADED", function(_, name)
        if name == "Blizzard_FlightMap" then
            EnsureRetailFlightMapHooked()
        elseif name == "OpenMap" or name == "Leatrix_Maps" or name == "Mapster" then
            packCacheChecked = false
        end
    end)
end

if XiusUI and XiusUI.RegisterModule then
    XiusUI:RegisterModule("FlightMap", FM)
end
