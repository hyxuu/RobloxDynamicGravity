--!strict
-- Este script se encarga de generar un laberinto de plataformas con gravedad dinámica.
-- Cuando un jugador pisa una plataforma, su gravedad se ajusta a la dirección de esa plataforma.

-- Servicios de Roblox
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- RemoteEvent para la comunicación entre el cliente y el servidor (para generar un nuevo laberinto)
local GeneratePuzzleEvent = Instance.new("RemoteEvent")
GeneratePuzzleEvent.Name = "GeneratePuzzleEvent"
GeneratePuzzleEvent.Parent = ReplicatedStorage

-- Configuración del laberinto y la gravedad
local PLATFORM_COUNT = 30 -- Número de plataformas a generar
local PLATFORM_SIZE_MIN = Vector3.new(5, 1, 5) -- Tamaño mínimo de la plataforma (X, Y, Z)
local PLATFORM_SIZE_MAX = Vector3.new(15, 1, 15) -- Tamaño máximo de la plataforma
local SPAWN_AREA_RADIUS = 150 -- Radio del área de generación de plataformas
local PLATFORM_HEIGHT_RANGE = 40 -- Rango de altura para las plataformas
local GRAVITY_MAGNITUDE = 196.2 -- Magnitud de la fuerza de gravedad (Roblox default is 196.2 studs/s^2)

-- Direcciones de gravedad posibles (Vector3.new(x, y, z) donde 1 o -1 indica la dirección)
local GRAVITY_DIRECTIONS = {
    Vector3.new(0, -1, 0), -- Abajo (gravedad normal)
    Vector3.new(0, 1, 0),  -- Arriba
    Vector3.new(1, 0, 0),  -- Derecha (eje X positivo)
    Vector3.new(-1, 0, 0), -- Izquierda (eje X negativo)
    Vector3.new(0, 0, 1),  -- Adelante (eje Z positivo)
    Vector3.new(0, 0, -1)  -- Atrás (eje Z negativo)
}

-- Colores asociados a cada dirección de gravedad para una mejor visualización
local GRAVITY_COLORS = {
    [GRAVITY_DIRECTIONS[1]] = BrickColor.new("Forest Green"),     -- Abajo
    [GRAVITY_DIRECTIONS[2]] = BrickColor.new("Bright yellow"),    -- Arriba
    [GRAVITY_DIRECTIONS[3]] = BrickColor.new("Bright orange"),    -- Derecha
    [GRAVITY_DIRECTIONS[4]] = BrickColor.new("Institutional white"), -- Izquierda
    [GRAVITY_DIRECTIONS[5]] = BrickColor.new("Dark stone grey"),  -- Adelante
    [GRAVITY_DIRECTIONS[6]] = BrickColor.new("Dark blue")         -- Atrás
}

-- Carpeta para contener las plataformas generadas dinámicamente
local platformsFolder = Instance.new("Folder")
platformsFolder.Name = "DynamicPlatforms"
platformsFolder.Parent = workspace

-- Tabla para rastrear las fuerzas de gravedad personalizadas de cada jugador
local playerGravityForces: { [number]: VectorForce } = {}

-- Función para limpiar todas las plataformas existentes
local function clearPlatforms()
    for _, platform in ipairs(platformsFolder:GetChildren()) do
        if platform:IsA("BasePart") then
            platform:Destroy()
        end
    end
end

-- Función para crear una nueva plataforma
local function createPlatform(position: Vector3, size: Vector3, gravityDir: Vector3): Part
    local platform = Instance.new("Part")
    platform.Size = size
    platform.CFrame = CFrame.new(position)
    platform.Anchored = true -- Las plataformas no se mueven
    platform.CanCollide = true -- Los jugadores pueden pisarlas
    platform.Parent = platformsFolder
    platform.Name = "GravityPlatform"
    platform.Transparency = 0.1 -- Ligeramente transparente para un mejor efecto visual

    -- Almacena la dirección de la gravedad como un atributo para que el cliente pueda leerla (opcional)
    platform:SetAttribute("GravityDirection", gravityDir)

    -- Asigna el color de la plataforma según la dirección de la gravedad
    platform.BrickColor = GRAVITY_COLORS[gravityDir] or BrickColor.new("Really black") -- Fallback color

    -- Añade una SurfaceGui para mostrar la dirección de la gravedad en la parte superior de la plataforma
    local surface = Instance.new("SurfaceGui")
    surface.Face = Enum.NormalId.Top -- Muestra en la cara superior
    surface.Parent = platform

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextScaled = true -- Escala el texto para que quepa
    textLabel.TextColor3 = Color3.new(1, 1, 1) -- Texto blanco (contraste)
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextStrokeTransparency = 0 -- Borde del texto para mayor visibilidad
    textLabel.Text = string.upper(tostring(gravityDir)) -- Muestra la dirección como texto (ej. "0, -1, 0")
    textLabel.Parent = surface

    return platform
end

-- Función para generar un nuevo laberinto de plataformas
local function generateNewPuzzle()
    clearPlatforms() -- Limpia las plataformas anteriores
    print("Generando nuevo laberinto...")

    local lastPosition = Vector3.new(0, 5, 0) -- Posición inicial para la primera plataforma

    for i = 1, PLATFORM_COUNT do
        -- Genera un tamaño aleatorio para la plataforma
        local randomSize = Vector3.new(
            math.random(PLATFORM_SIZE_MIN.X, PLATFORM_SIZE_MAX.X),
            PLATFORM_SIZE_MIN.Y, -- La altura de la plataforma es constante
            math.random(PLATFORM_SIZE_MIN.Z, PLATFORM_SIZE_MAX.Z)
        )
        -- Elige una dirección de gravedad aleatoria
        local randomGravityDir = GRAVITY_DIRECTIONS[math.random(1, #GRAVITY_DIRECTIONS)]

        -- Calcula la posición de la siguiente plataforma
        -- Intenta mantener las plataformas dentro de un radio y altura razonables
        local xOffset = math.random(-SPAWN_AREA_RADIUS / 2, SPAWN_AREA_RADIUS / 2)
        local zOffset = math.random(-SPAWN_AREA_RADIUS / 2, SPAWN_AREA_RADIUS / 2)
        local yOffset = math.random(-PLATFORM_HEIGHT_RANGE / 2, PLATFORM_HEIGHT_RANGE / 2)

        local newPosition = lastPosition + Vector3.new(xOffset, yOffset, zOffset)

        -- Asegura que las plataformas no estén demasiado lejos del centro inicial
        newPosition = Vector3.new(
            math.clamp(newPosition.X, -SPAWN_AREA_RADIUS, SPAWN_AREA_RADIUS),
            math.clamp(newPosition.Y, 5, PLATFORM_HEIGHT_RANGE + 5), -- Mantiene las plataformas a una altura jugable
            math.clamp(newPosition.Z, -SPAWN_AREA_RADIUS, SPAWN_AREA_RADIUS)
        )

        local platform = createPlatform(newPosition, randomSize, randomGravityDir)
        lastPosition = newPosition -- La próxima plataforma se generará cerca de esta
    end

    print("Laberinto generado con " .. PLATFORM_COUNT .. " plataformas.")
end

-- Función para aplicar una fuerza de gravedad personalizada a un jugador
local function applyCustomGravity(player: Player, gravityVector: Vector3)
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    -- Elimina cualquier VectorForce existente para este jugador
    if playerGravityForces[player.UserId] then
        playerGravityForces[player.UserId]:Destroy()
        playerGravityForces[player.UserId] = nil
    end

    -- Crea una nueva VectorForce para simular la gravedad personalizada
    local force = Instance.new("VectorForce")
    force.Name = "CustomGravityForce"
    -- Busca o crea un Attachment en HumanoidRootPart para aplicar la fuerza
    force.Attachment0 = humanoidRootPart:FindFirstChild("RootRigAttachment") or Instance.new("Attachment", humanoidRootPart)
    force.Force = gravityVector * GRAVITY_MAGNITUDE -- La fuerza se aplica en la dirección de la gravedad
    force.RelativeTo = Enum.ActuatorRelativeTo.World -- La fuerza es relativa al mundo
    force.Parent = humanoidRootPart
    playerGravityForces[player.UserId] = force

end

-- Función para restaurar la gravedad predeterminada de Roblox para un jugador
local function restoreDefaultGravity(player: Player)
    if playerGravityForces[player.UserId] then
        playerGravityForces[player.UserId]:Destroy()
        playerGravityForces[player.UserId] = nil
    end
end

-- Conecta el evento Touched a las plataformas recién añadidas
platformsFolder.ChildAdded:Connect(function(platform: Instance)
    if platform:IsA("BasePart") then
        platform.Touched:Connect(function(hit: BasePart)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player then
                local gravityDir = platform:GetAttribute("GravityDirection")
                if gravityDir and typeof(gravityDir) == "Vector3" then -- Asegura que el atributo sea un Vector3
                    applyCustomGravity(player, gravityDir)
                    print(player.Name .. " tocó una plataforma. Gravedad cambiada a: " .. tostring(gravityDir))
                end
            end
        end)
    end
end)

-- Maneja la aparición de personajes (respawn) y el cambio de estado del Humanoid
Players.PlayerAdded:Connect(function(player: Player)
    player.CharacterAdded:Connect(function(character: Model)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Restaura la gravedad predeterminada cuando el jugador cae o salta (para evitar bugs de flotación)
            humanoid.StateChanged:Connect(function(oldState: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
                if newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Landed then
                    restoreDefaultGravity(player)
                end
            end)
        end
        restoreDefaultGravity(player)
    end)
end)

-- Maneja la salida del jugador del juego para limpiar las fuerzas
Players.PlayerRemoving:Connect(function(player: Player)
    restoreDefaultGravity(player)
end)

-- Conecta el RemoteEvent para la generación de laberintos
GeneratePuzzleEvent.OnServerEvent:Connect(function(playerWhoFired: Player)
    -- Puedes añadir aquí una verificación de administrador si solo quieres que ciertos jugadores generen laberintos
    print(playerWhoFired.Name .. " solicitó un nuevo laberinto.")
    generateNewPuzzle()
end)

-- Genera el laberinto inicial cuando el servidor comienza
generateNewPuzzle()

print("Script de Servidor de Plataformas de Gravedad Dinámica cargado.")

