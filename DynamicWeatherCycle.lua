--!strict
-- Script de Servidor: Ciclo Dinámico de Día y Noche con Efectos Climáticos
-- Este script gestiona el paso del tiempo y los cambios climáticos en el juego.

-- Servicios de Roblox
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Configuración del ciclo de tiempo
local DAY_DURATION_MINUTES = 20 -- Duración de un ciclo completo de día/noche en minutos reales
local DAY_CYCLE_SPEED = 1 / (DAY_DURATION_MINUTES * 60) -- Velocidad de avance del tiempo (segundos por segundo real)

-- Configuración de los efectos climáticos
local WEATHER_CHANGE_INTERVAL_MIN = 5 -- Intervalo mínimo para cambio de clima (minutos)
local WEATHER_CHANGE_INTERVAL_MAX = 15 -- Intervalo máximo para cambio de clima (minutos)

-- Definición de estados climáticos y sus propiedades de iluminación
local WeatherStates = {
    Soleado = { -- Nombre actualizado
        OutdoorAmbient = Color3.fromRGB(128, 128, 128),
        FogEnd = 100000,
        FogStart = 0,
        FogColor = Color3.fromRGB(128, 128, 128),
        Brightness = 2,
        RainParticles = false,
    },
    Lluvioso = { -- Nombre actualizado
        OutdoorAmbient = Color3.fromRGB(80, 80, 90),
        FogEnd = 500,
        FogStart = 50,
        FogColor = Color3.fromRGB(60, 70, 80),
        Brightness = 1,
        RainParticles = true,
    },
    Neblina = { -- Nombre actualizado
        OutdoorAmbient = Color3.fromRGB(100, 100, 100),
        FogEnd = 200,
        FogStart = 0,
        FogColor = Color3.fromRGB(150, 150, 150),
        Brightness = 1.5,
        RainParticles = false,
    },
}

-- Propiedades de tween para transiciones suaves
local TWEEN_INFO = TweenInfo.new(
    5, -- Duración de la transición en segundos
    Enum.EasingStyle.Quad, -- Estilo de easing
    Enum.EasingDirection.Out, -- Dirección de easing
    0, -- Repeticiones
    false, -- Invertir
    0 -- Retraso
)

-- Variable para el estado climático actual
local currentWeatherState = "Soleado" -- Actualizado al nuevo nombre por defecto
local nextWeatherChangeTime = 0

-- Referencia a los emisores de partículas de lluvia (si se crean)
local rainParticleEmitter: ParticleEmitter? = nil

-- Función para crear o destruir el efecto de partículas de lluvia
local function setRainParticles(enabled: boolean)
    if enabled then
        if not rainParticleEmitter then
            -- Crea un Attachment en el centro del Workspace para emitir partículas de lluvia
            local attachment = Instance.new("Attachment")
            attachment.Parent = workspace.CurrentCamera -- O un punto fijo en el cielo
            attachment.Position = Vector3.new(0, 100, 0) -- Posición alta para simular lluvia

            rainParticleEmitter = Instance.new("ParticleEmitter")
            rainParticleEmitter.Parent = attachment
            rainParticleEmitter.Texture = "rbxassetid://625488057" -- ID de textura de gota de lluvia (ejemplo)
            rainParticleEmitter.Size = NumberSequence.new(0.5, 1)
            rainParticleEmitter.Transparency = NumberSequence.new(0.5, 1)
            rainParticleEmitter.Lifetime = 2
            rainParticleEmitter.Speed = NumberRange.new(50, 70)
            rainParticleEmitter.SpreadAngle = Vector2.new(180, 180)
            rainParticleEmitter.EmissionDirection = Enum.ParticleEmissionDirection.Bottom
            rainParticleEmitter.Rate = 500 -- Cantidad de partículas por segundo
            rainParticleEmitter.Enabled = true
            rainParticleEmitter.LightInfluence = 0 -- Para que la lluvia sea visible incluso de noche
            rainParticleEmitter.Drag = 0.1
            rainParticleEmitter.Acceleration = Vector3.new(0, -100, 0) -- Gravedad para las gotas
        end
        rainParticleEmitter.Enabled = true
    else
        if rainParticleEmitter then
            rainParticleEmitter.Enabled = false
        end
    end
end

-- Función para aplicar un estado climático
local function applyWeatherState(stateName: string)
    local state = WeatherStates[stateName]
    if not state then return end

    print("Cambiando clima a: " .. stateName) -- Mensaje actualizado
    currentWeatherState = stateName

    -- Crea un tween para las propiedades de Lighting
    local tweenProperties = {
        OutdoorAmbient = state.OutdoorAmbient,
        FogEnd = state.FogEnd,
        FogStart = state.FogStart,
        FogColor = state.FogColor,
        Brightness = state.Brightness,
    }

    local tween = TweenService:Create(Lighting, TWEEN_INFO, tweenProperties)
    tween:Play()

    -- Maneja las partículas de lluvia
    setRainParticles(state.RainParticles)

    -- Calcula el próximo tiempo de cambio de clima
    nextWeatherChangeTime = os.time() + math.random(WEATHER_CHANGE_INTERVAL_MIN * 60, WEATHER_CHANGE_INTERVAL_MAX * 60)
end

-- Bucle principal del ciclo de tiempo y clima
local lastTick = os.clock()
while true do
    local currentTick = os.clock()
    local deltaTime = currentTick - lastTick
    lastTick = currentTick

    -- Actualiza la hora del día
    -- Lighting.TimeOfDay es un string en formato "HH:MM:SS"
    local currentHour = Lighting:GetMinutesAfterMidnight() / 60
    local newMinutesAfterMidnight = Lighting:GetMinutesAfterMidnight() + (deltaTime * 60 * DAY_CYCLE_SPEED)
    
    -- Asegura que el tiempo se mantenga dentro de 24 horas
    if newMinutesAfterMidnight >= 1440 then -- 1440 minutos en un día (24 * 60)
        newMinutesAfterMidnight = newMinutesAfterMidnight - 1440
    end
    Lighting:SetMinutesAfterMidnight(newMinutesAfterMidnight)

    -- Verifica si es hora de cambiar el clima
    if os.time() >= nextWeatherChangeTime then
        local weatherStatesNames = {}
        for name, _ in pairs(WeatherStates) do
            table.insert(weatherStatesNames, name)
        end

        local newWeatherStateName = weatherStatesNames[math.random(1, #weatherStatesNames)]
        -- Asegura que el nuevo clima sea diferente al actual para evitar cambios redundantes
        while newWeatherStateName == currentWeatherState do
            newWeatherStateName = weatherStatesNames[math.random(1, #weatherStatesNames)]
        end
        applyWeatherState(newWeatherStateName)
    end

    -- Espera al siguiente frame (aproximadamente 1/60 de segundo)
    RunService.Stepped:Wait()
end

print("Script de Ciclo Climático Dinámico cargado.") -- Mensaje actualizado
