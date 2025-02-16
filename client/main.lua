local Markers          = {}  -- Tabla donde guardamos todos los markers
local ActiveMarkers    = {}  -- Control de hilos activos
local ActivePeds       = {}  -- Peds creados
local markerStopFlags = {}  -- Flags para detener hilos
-----------------------------------------
--           HELPER FUNCTIONS          --
-----------------------------------------

local function SpawnPed(marker)
    if not marker.pedModel then return end
    if ActivePeds[marker.id] then return end

    local modelHash = GetHashKey(marker.pedModel)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end

    local ped = CreatePed(4, modelHash, marker.coords.x, marker.coords.y, marker.coords.z - 1.0, marker.pedHeading or 0.0, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    ActivePeds[marker.id] = ped
end

local function DeletePedIfExists(marker)
    if ActivePeds[marker.id] then
        DeleteEntity(ActivePeds[marker.id])
        ActivePeds[marker.id] = nil
    end
end

local function DrawMarkerNative(marker)
    DrawMarker(marker.markerType or Config.DefaultMarkerType,
        marker.coords.x, marker.coords.y, marker.coords.z - 1.0,
        0.0,0.0,0.0,
        0.0,0.0,0.0,
        marker.scale.x, marker.scale.y, marker.scale.z,
        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
        false,false,2,true,nil,nil,false
    )
end

-----------------------------------------
--         MARKER THREAD (1x)          --
-----------------------------------------
-- Cada marker corre su propia corrutina.
-- Se detiene cuando "running" es false
-----------------------------------------

local function markerThread(marker)
    local showingHelp = false
    local markerId    = marker.id

    while true do
        -- si se marcó que lo borremos, salimos
        if markerStopFlags[markerId] then
            DeletePedIfExists(marker)
            ActiveMarkers[markerId] = nil
            markerStopFlags[markerId] = nil
            return
        end

        local sleep = 500
        local ped   = PlayerPedId()
        local dist  = #(GetEntityCoords(ped) - marker.coords)

        if dist < Config.DrawDistance then
            sleep = 0 -- dibujar a 0 ms para suavidad

            -- Spawn / Delete Ped
            if Config.showPeds then
                if dist < Config.PedSpawnDistance then
                    if not ActivePeds[markerId] then
                        -- spawnea ped
                        local modelHash = GetHashKey(marker.pedModel or "")
                        if marker.pedModel and modelHash ~= 0 then
                            RequestModel(modelHash)
                            while not HasModelLoaded(modelHash) do
                                Wait(10)
                            end
                            local pedEnt = CreatePed(
                                4, 
                                modelHash, 
                                marker.coords.x, marker.coords.y, marker.coords.z - 1.0, 
                                marker.pedHeading or 0.0, 
                                false, true
                            )
                            SetEntityInvincible(pedEnt, true)
                            SetBlockingOfNonTemporaryEvents(pedEnt, true)
                            FreezeEntityPosition(pedEnt, true)
    
                            ActivePeds[markerId] = pedEnt
                        end
                    end
                else
                    DeletePedIfExists(marker)
                end
            end

            -- Dibujar Marker
            if not Config.showPeds or not ActivePeds[markerId] then
                DrawMarkerNative(marker)
            end

            -- Interacción
            if dist < Config.InteractDistance then
                if not showingHelp then
                    showingHelp = true
                    if Config.TextUIResource then
                        exports[Config.TextUIResource]:Open(
                            marker.interactText or "Pulsa [E] para interactuar", 
                            Config.TextUIColor, 
                            Config.TextUIAlign
                        )
                    end
                end
                if IsControlJustReleased(0, Config.InteractKey) then
                    -- Llamar callback
                    if marker.onPress then
                        marker.onPress(marker)
                    else
                        print("[MarkerLibrary] Interact con marker ID:", markerId)
                    end
                end
            else
                if showingHelp then
                    showingHelp = false
                    if Config.TextUIResource then
                        exports[Config.TextUIResource]:Close()
                    end
                end
            end
        else
            -- Fuera de draw distance => cierra textUI si estaba
            if showingHelp then
                showingHelp = false
                if Config.TextUIResource then
                    exports[Config.TextUIResource]:Close()
                end
            end
            -- Borramos ped si existe
            DeletePedIfExists(marker)
        end

        Wait(sleep)
    end
end

-----------------------------------------
--       FUNCIONES DE LA LIBRERÍA      --
-----------------------------------------

-- 1) Añadir un marker
--    Param: data => { 
--       id = number / string único,
--       coords = vector3(),
--       markerType = (opcional),
--       color = {r,g,b,a},
--       scale = {x,y,z},
--       pedModel = "a_m_m_...", (opcional)
--       pedHeading = 0.0,
--       interactText = "algo",
--       onPress = function(marker) 
--         -- callback al pulsar E 
--       end
--    }
function AddMarker(data)
    if not data.id then
        print("^1[nb_markers] ERROR: AddMarker() => data.id faltante^7")
        return
    end

    if Markers[data.id] then
        print("^3[nb_markers] WARNING: El marker con ID "..tostring(data.id).." ya existe. Se reemplazará.^7")
        RemoveMarker(data.id) 
    end

    -- Ajustes por defecto
    data.markerType = data.markerType or Config.DefaultMarkerType
    data.scale      = data.scale      or Config.DefaultMarkerScale
    data.color      = data.color      or Config.DefaultMarkerColor
    data.coords     = data.coords     or vector3(0,0,0)

    Markers[data.id] = data
    print("^2[nb_markers] Marker añadido: "..tostring(data.id).."^7")

    -- Lanzar hilo
    Citizen.CreateThread(function()
        ActiveMarkers[data.id] = true
        markerThread(data)
    end)
end

-- 2) Eliminar un marker
function RemoveMarker(markerId)
    local marker = Markers[markerId]
    if marker then
        Markers[markerId] = nil
        -- si está corriendo su hilo, se autodestruirá al ver coords vacías 
        -- o dist grande, pero forzamos borrado:
        DeletePedIfExists(marker)
    end
end

-- 3) Actualizar un marker
function UpdateMarker(markerId, newData)
    local marker = Markers[markerId]
    if not marker then return end

    for k, v in pairs(newData) do
        marker[k] = v
    end
end

-----------------------------------------
--  EXPORTAR LAS FUNCIONES (client)    --
-----------------------------------------

exports('AddMarker', AddMarker)
exports('RemoveMarker', RemoveMarker)
exports('UpdateMarker', UpdateMarker)
