-- Script: Sistema de Generador de Ítems (Lado del Servidor)
-- Propósito: Genera dinámicamente objetos de juego (ej. recursos, enemigos) en ubicaciones predefinidas.
-- Ubicación recomendada: ServerScriptService (Para una generación sincronizada en todos los clientes).

-- --- INSTRUCCIONES DE CONFIGURACIÓN Y USO PARA EL USUARIO ---
-- Esta sección proporciona los pasos esenciales para el correcto funcionamiento del sistema.

-- 1.  PREPARACIÓN DE MODELOS DE ÍTEMS:
--     a.  Coloca todos los modelos de ítems que deseas generar (Partes, Modelos, etc.) en 'ServerStorage'.
--     b.  Asegúrate de que cada modelo tenga una propiedad 'Name' única y descriptiva (ej. "MineralDeCobre", "ModeloDeArbol", "ModeloDeGoblin").
--     c.  Verifica que la propiedad 'Archivable' esté habilitada para todos los modelos y sus hijos.
--     d.  Para instancias de 'Model', configura una 'PrimaryPart' (ej. 'HumanoidRootPart' para personajes) para un posicionamiento preciso.

-- 2.  PREPARACIÓN DE PUNTOS DE APARICIÓN:
--     a.  En 'Workspace', crea un nuevo objeto 'Folder' (Carpeta).
--     b.  **Nombra esta carpeta idénticamente a la variable 'SPAWN_POINTS_FOLDER_NAME' definida a continuación.** (Por defecto: "SpawnLocations").
--     c.  Dentro de esta carpeta, crea múltiples instancias de 'Part'. Estas servirán como las coordenadas exactas de aparición.
--     d.  Posiciona cada 'Part' en la ubicación deseada para la aparición.
--     e.  Configura las siguientes propiedades para cada 'Part' de punto de aparición:
--         -   'Transparency' = 1 (Invisible durante la ejecución).
--         -   'CanCollide' = false (No colisionable).
--         -   'Anchored' = true (Estático en posición).

-- 3.  DESPLIEGUE Y CONFIGURACIÓN DEL SCRIPT:
--     a.  Este script debe ser un 'Script' estándar (no un 'LocalScript').
--     b.  Coloca este script dentro de 'ServerScriptService' en la ventana 'Explorer'.
--     c.  Ajusta las variables dentro de la sección '--- CONFIGURACIÓN DEL GENERADOR ---' para que coincidan con los requisitos del juego.

-- Al iniciar el juego, el sistema comenzará a generar ítems según la configuración.
-- Los ítems generados serán hijos de una carpeta creada dinámicamente dentro de 'Workspace' (nombrada por 'SPAWNED_ITEMS_FOLDER_NAME').
-- --- FIN DE INSTRUCCIONES PARA EL USUARIO ---

local ServerStorage = game:GetService("ServerStorage") -- Referencia al servicio ServerStorage.
local Workspace = game:GetService("Workspace")         -- Referencia al servicio Workspace.

-- --- CONFIGURACIÓN DEL GENERADOR ---

-- (string) El nombre de la 'Folder' en 'Workspace' que contiene todas las instancias 'Part' de puntos de aparición.
-- Debe coincidir precisamente con el nombre de la carpeta en 'Workspace'.
local SPAWN_POINTS_FOLDER_NAME = "SpawnLocations"

-- (table) Define el grupo de ítems generables y sus probabilidades relativas.
-- Formato: {{"NombreDelModeloEnServerStorage", PesoDeProbabilidadRelativa}, ...}
-- Ejemplo: {{"MineralDeOro", 3}, {"MineralDeHierro", 2}, {"EnemigoSlime", 1}}
local SPAWNABLE_ITEMS = {
    {"MineralOre", 3},  -- Modelo llamado "MineralOre" en ServerStorage
    {"SmallTree", 2},   -- Modelo llamado "SmallTree" en ServerStorage
    {"GoblinEnemy", 1}  -- Modelo llamado "GoblinEnemy" en ServerStorage
}

-- (number) El intervalo en segundos entre cada intento de generación de un ítem.
local SPAWN_INTERVAL = 5

-- (integer) El número máximo de ítems generados activos simultáneamente en el Workspace.
-- La generación se pausará si se alcanza este límite hasta que los ítems existentes sean eliminados.
local MAX_SPAWNED_ITEMS = 10

-- (string) El nombre de la 'Folder' que se creará en 'Workspace' para contener todos los ítems generados.
-- Facilita la organización y el seguimiento de las instancias generadas activas.
local SPAWNED_ITEMS_FOLDER_NAME = "SpawnedItems"

-- --- FIN DE CONFIGURACIÓN DEL GENERADOR ---

-- Adquiere una referencia a la carpeta de puntos de aparición; usa :WaitForChild() para asegurar su disponibilidad.
local spawnPointsFolder = Workspace:WaitForChild(SPAWN_POINTS_FOLDER_NAME)
-- Instancia y asigna como padre la carpeta para contener los ítems generados.
local spawnedItemsFolder = Instance.new("Folder")
spawnedItemsFolder.Name = SPAWNED_ITEMS_FOLDER_NAME
spawnedItemsFolder.Parent = Workspace

-- Recupera todos los hijos (puntos de aparición) de la carpeta designada.
local spawnPoints = spawnPointsFolder:GetChildren()
-- Detiene la ejecución del script si no se detectan puntos de aparición, emitiendo una advertencia.
if #spawnPoints == 0 then
    warn("Advertencia del Generador: No se encontraron instancias 'Part' de puntos de aparición dentro de la carpeta '" .. SPAWN_POINTS_FOLDER_NAME .. "'. El sistema de generación no se activará.")
    return -- Termina la ejecución del script.
end

-- Calcula la suma de probabilidades acumuladas para la selección aleatoria ponderada de ítems.
local totalProbability = 0
for _, itemData in ipairs(SPAWNABLE_ITEMS) do
    totalProbability += itemData[2]
end

-- Función: selectItemToSpawn()
-- Propósito: Selecciona un ítem de 'SPAWNABLE_ITEMS' basándose en los pesos de probabilidad relativa definidos.
-- Retorna: La instancia 'Model' o 'BasePart' a clonar desde 'ServerStorage'.
local function selectItemToSpawn()
    local randomNumber = math.random(1, totalProbability) -- Genera un número aleatorio dentro del rango de probabilidad total.
    local cumulativeProbability = 0 -- Acumulador para la comparación de probabilidad.
    for _, itemData in ipairs(SPAWNABLE_ITEMS) do
        cumulativeProbability += itemData[2]
        if randomNumber <= cumulativeProbability then
            -- Retorna el modelo correspondiente encontrado en ServerStorage.
            return ServerStorage:FindFirstChild(itemData[1])
        end
    end
    return nil -- No debería alcanzarse con una configuración correcta; indica un fallo en la búsqueda.
end

-- Función: spawnItem()
-- Propósito: Maneja la clonación, el posicionamiento y la configuración inicial de un nuevo ítem generado.
local function spawnItem()
    -- Verifica si se ha alcanzado el número máximo de ítems generados activos.
    if #spawnedItemsFolder:GetChildren() >= MAX_SPAWNED_ITEMS then
        -- Opcional: print("Info del Generador: Límite máximo de ítems generados alcanzado. Esperando la eliminación de ítems.")
        return -- Aborta el intento de generación si se cumple el límite.
    end

    local itemTemplate = selectItemToSpawn() -- Selecciona el modelo del ítem a generar.
    if not itemTemplate then
        warn("Advertencia del Generador: No se pudo recuperar una plantilla de ítem válida de 'ServerStorage'. Verifique la configuración de 'SPAWNABLE_ITEMS'.")
        return -- Aborta si no se encuentra la plantilla.
    end

    local randomSpawnPoint = spawnPoints[math.random(1, #spawnPoints)] -- Selecciona un punto de aparición aleatorio.
    local clonedItem = itemTemplate:Clone() -- Crea un clon de la plantilla del ítem.
    clonedItem.Parent = spawnedItemsFolder -- Asigna el ítem clonado a la carpeta designada en Workspace.

    -- Posiciona el ítem clonado según su tipo de instancia.
    if clonedItem:IsA("BasePart") then
        -- Para instancias 'BasePart' individuales, establece directamente la 'Position'.
        clonedItem.Position = randomSpawnPoint.Position
        if clonedItem.Anchored then
            clonedItem.Anchored = false -- Asegura la interacción física si es necesario.
        end
    elseif clonedItem:IsA("Model") and clonedItem.PrimaryPart then
        -- Para instancias 'Model' (ej. personajes), usa 'SetPrimaryPartCFrame' para una ubicación precisa del modelo.
        clonedItem:SetPrimaryPartCFrame(randomSpawnPoint.CFrame)
        -- Asegura que todas las partes dentro del modelo no estén ancladas.
        for _, part in ipairs(clonedItem:GetChildren()) do
            if part:IsA("BasePart") then
                part.Anchored = false
            end
        end
    else
        -- Registra una advertencia y destruye el ítem si su tipo no es manejado o carece de una 'PrimaryPart'.
        warn("Advertencia del Generador: El ítem clonado '" .. clonedItem.Name .. "' no es una BasePart ni un Modelo con PrimaryPart definida. Destruyendo la instancia para prevenir errores.")
        clonedItem:Destroy()
        return
    end

    -- Si el ítem contiene un 'Humanoid' (típico para NPCs enemigos), reinicia su salud para su activación.
    local humanoid = clonedItem:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Health = humanoid.MaxHealth -- Asegura salud completa al aparecer.
        -- Los scripts de IA adicionales para el comportamiento del enemigo residirían típicamente dentro del propio modelo clonado.
    end

    print("Registro del Generador: Generado '" .. clonedItem.Name .. "' en el punto de aparición '" .. randomSpawnPoint.Name .. "'.")

    -- --- LÓGICA DE INTERACCIÓN / DESTRUCCIÓN DE ÍTEMS (EJEMPLO) ---
    -- Este es un ejemplo básico para una 'BasePart' coleccionable que se destruye al ser tocada por un jugador.
    -- Para entidades enemigas, la lógica de desaparición/muerte suele residir en un script local al modelo del enemigo.
    if clonedItem:IsA("BasePart") and not humanoid then -- Aplica a partes simples, excluyendo partes de humanoides.
        clonedItem.Touched:Connect(function(hit)
            local player = game.Players:GetPlayerFromCharacter(hit.Parent)
            if player then
                -- Implementar lógica de concesión de recursos aquí (ej. player.leaderstats.Recurso.Value += 1).
                print("Registro del Generador: El jugador '" .. player.Name .. "' recolectó el ítem '" .. clonedItem.Name .. "'.")
                clonedItem:Destroy() -- Elimina el ítem del Workspace.
            end
        end)
    end
end

-- Bucle principal del Generador: Intenta generar ítems continuamente a intervalos definidos.
while true do
    spawnItem() -- Inicia un intento de generación de ítem.
    task.wait(SPAWN_INTERVAL) -- Pausa la ejecución por el intervalo especificado.
end

print("Sistema de Generador Activado: Máx. ítems concurrentes: " .. MAX_SPAWNED_ITEMS .. ". Intentos de generación cada " .. SPAWN_INTERVAL .. " segundos.")

-- --- FIN DEL SCRIPT ---
-- Notas importantes: Este script es un ejemplo básico de generación de ítems y puede requerir ajustes adicionales según las necesidades específicas del juego.
-- Asegúrate de probar exhaustivamente en un entorno de desarrollo antes de implementarlo en producción.
-- Considera agregar más lógica de interacción, como recompensas, eliminación de ítems, o eventos especiales al recoger ítems.
-- También es recomendable implementar un sistema de limpieza para eliminar ítems generados que ya no son necesarios, para evitar la acumulación en el Workspace.
-- Sin mas que decir, espero que este script sea de utilidad en tu proyecto y te ayude a crear una experiencia de juego más dinámica y atractiva.
