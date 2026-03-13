-- ============================================================
-- D3M0N-HUB: PIZZA BOY V2 (CLOUD VERSION)
-- ============================================================
local samp_ev = require 'lib.samp.events'
local imgui   = require 'mimgui'

-- Estado del Script
local renderWindow  = imgui.new.bool(false)
local autoMode      = imgui.new.bool(false)
local cpActive      = false
local lastVehicle   = nil
local is_tp_running = false
local deliveryCount = 0
local pulseTimer    = 0.0
local cpCoords      = {x = 0.0, y = 0.0, z = 0.0}

-- Paleta de Colores
local C = {
    bg_dark    = imgui.ImVec4(0.06, 0.06, 0.08, 0.97),
    bg_panel   = imgui.ImVec4(0.10, 0.10, 0.13, 1.00),
    accent     = imgui.ImVec4(1.00, 0.45, 0.10, 1.00),
    accent_dim = imgui.ImVec4(1.00, 0.45, 0.10, 0.25),
    accent_brd = imgui.ImVec4(1.00, 0.45, 0.10, 0.55),
    green      = imgui.ImVec4(0.22, 0.90, 0.44, 1.00),
    yellow     = imgui.ImVec4(1.00, 0.85, 0.20, 1.00),
    border     = imgui.ImVec4(0.25, 0.25, 0.30, 1.00),
    text_bright= imgui.ImVec4(0.96, 0.96, 0.96, 1.00),
    text_mid   = imgui.ImVec4(0.65, 0.65, 0.70, 1.00),
    text_dim   = imgui.ImVec4(0.38, 0.38, 0.43, 1.00),
}

local function ic(v4) return imgui.ColorConvertFloat4ToU32(v4) end
local function lerp(a, b, t) return a + (b - a) * t end

-- Inicialización de Estilo (mimgui)
imgui.OnInitialize(function()
    local style = imgui.GetStyle()
    style.WindowPadding    = imgui.ImVec2(0, 0)
    style.WindowRounding   = 8.0
    style.WindowBorderSize = 1.0
    style.FramePadding     = imgui.ImVec2(10, 6)
    style.FrameRounding    = 5.0
    style.Colors[imgui.Col.WindowBg] = C.bg_dark
    style.Colors[imgui.Col.Border]   = C.border
    style.Colors[imgui.Col.CheckMark]= C.green
    style.Colors[imgui.Col.Text]     = C.text_bright
end)

-- Interfaz Gráfica (OnFrame)
imgui.OnFrame(function() return renderWindow[0] end,
    function()
        pulseTimer = pulseTimer + 0.04
        local sw, sh = getScreenResolution()
        local WW, WH = 270, 255
        imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(WW, WH), imgui.Cond.Always)

        imgui.Begin("##PizzaHUD", renderWindow, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)
        local dl  = imgui.GetWindowDrawList()
        local wp  = imgui.GetWindowPos()
        local wMx = imgui.ImVec2(wp.x + WW, wp.y + WH)
        
        dl:AddRect(wp, wMx, ic(C.accent_brd), 8, 15, 1.5)
        
        -- Header y Contenido (Simplificado para el ejemplo, mantén tu lógica de dibujo aquí)
        imgui.SetCursorPos(imgui.ImVec2(15, 15))
        imgui.TextColored(C.accent, "D3M0N-HUB | PIZZA BOY")
        imgui.Separator()
        
        imgui.Text("Entregas: " .. deliveryCount)
        imgui.Checkbox("AUTO-BUCLE", autoMode)

        if imgui.Button("JACK MOTO", imgui.ImVec2(-1, 25)) then
            if lastVehicle and doesVehicleExist(lastVehicle) then
                warpCharIntoCar(PLAYER_PED, lastVehicle)
            end
        end

        if imgui.Button("Ir a Pizzeria", imgui.ImVec2(-1, 25)) then
            teleportToPizzeria()
        end

        imgui.End()
    end
)

-- Funciones de Lógica
function teleportToPizzeria()
    local px, py, pz = 2105.3750, -1806.3750, 13.5000
    lua_thread.create(function()
        requestCollision(px, py)
        loadScene(px, py, pz)
        wait(500)
        if isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            setCarCoordinates(veh, px, py, pz)
        else
            setCharCoordinates(PLAYER_PED, px, py, pz)
        end
    end)
end

function freezeCarVariable(veh, state)
    if veh and doesVehicleExist(veh) and not isCarDead(veh) then
        pcall(freezeCarPosition, veh, state)
    end
end

function executePizzaSequence()
    if not cpCoords or not cpCoords.x then return end
    lua_thread.create(function()
        if not lastVehicle or not doesVehicleExist(lastVehicle) or isCarDead(lastVehicle) then 
            is_tp_running = false
            return 
        end
        is_tp_running = true
        local cx, cy, cz = cpCoords.x, cpCoords.y, cpCoords.z
        local vX, vY, vZ = cx + 3.5, cy + 3.5, cz + 1.0

        if not isCharInAnyCar(PLAYER_PED) then pcall(warpCharIntoCar, PLAYER_PED, lastVehicle) end
        freezeCarVariable(lastVehicle, true)
        requestCollision(vX, vY)
        loadScene(vX, vY, vZ)
        wait(400)

        if doesVehicleExist(lastVehicle) then pcall(setCarCoordinates, lastVehicle, vX, vY, vZ) end
        wait(400)
        pcall(warpCharFromCarToCoord, PLAYER_PED, vX + 0.5, vY + 0.5, vZ)
        wait(500)
        setCharCoordinates(PLAYER_PED, cx, cy, cz)
        
        wait(1400) -- Tiempo de cobro

        if doesVehicleExist(lastVehicle) and not isCarDead(lastVehicle) then
            local mx, my, mz = getCarCoordinates(lastVehicle)
            setCharCoordinates(PLAYER_PED, mx, my, mz)
            wait(300)
            pcall(warpCharIntoCar, PLAYER_PED, lastVehicle)
            freezeCarVariable(lastVehicle, false)
            deliveryCount = deliveryCount + 1
        end
        is_tp_running = false
    end)
end

-- ============================================================
-- REGISTRO DE COMANDOS Y BUCLE (SIN FUNCTION MAIN)
-- ============================================================

-- Registro de comando inmediato
sampRegisterChatCommand("pizza", function()
    renderWindow[0] = not renderWindow[0]
end)

-- Hilo principal para el bucle
lua_thread.create(function()
    while true do
        wait(0)
        -- Detección de vehículo
        if isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            if getCarModel(veh) == 448 then lastVehicle = veh end
        end

        -- Lógica Auto-Bucle
        if autoMode[0] and cpActive and not is_tp_running then
            if lastVehicle and doesVehicleExist(lastVehicle) then
                executePizzaSequence()
            else
                is_tp_running = false
            end
        end
    end
end)

-- Hooks de Eventos (SAMP.Events)
function samp_ev.onSetCheckpoint(pos, rad)
    cpActive = true
    cpCoords = {x = pos.x, y = pos.y, z = pos.z}
end

function samp_ev.onDisableCheckpoint() cpActive = false end

function samp_ev.onSetRaceCheckpoint(t, pos, n, r)
    cpActive = true
    cpCoords = {x = pos.x, y = pos.y, z = pos.z}
end

function samp_ev.onDisableRaceCheckpoint() cpActive = false end

sampAddChatMessage("{8800FF}[D3M0N-HUB]: {FFFFFF}Módulo PizzaBoy V2 cargado desde la nube.", -1)
