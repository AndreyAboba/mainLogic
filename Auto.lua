-- Модуль Auto: AutoInteract
local Auto = {
    AutoInteract = {
        Settings = {
            Enabled = { Value = false, Default = false },
            TargetObject = { Value = "AirDrop", Default = "AirDrop" },
            MaxDistance = { Value = 10, Default = 10 },
            MinusHoldTime = { Value = 10, Default = 10 },
            MinDistanceBetweenObjects = { Value = 5, Default = 5 },
            ActivationDelay = { Value = 1.0, Default = 1.0 },
            EnableDebugLogs = { Value = true, Default = true }
        },
        State = {
            ProcessedObjects = {},
            LastDistance = {},
            ActiveObjects = {},
            BinCache = {},
            LastBinCacheUpdate = 0,
            BinCacheUpdateInterval = 10,
            LastUpdateTime = 0,
            UpdateInterval = 0.1,
            OriginalHoldTimes = {},
            CurrentAirDrop = nil
        }
    }
}

function Auto.Init(UI, Core, notify)
    local AutoInteract = Auto.AutoInteract

    -- Функция отладочного лога
    local function debugLog(...)
        if AutoInteract.Settings.EnableDebugLogs.Value then
            print(...)
        end
    end

    -- Проверка, жив ли игрок
    local function isPlayerInGame()
        local character = Core.PlayerData.LocalPlayer.Character
        if not character then
            debugLog("Character not found!")
            return false
        end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            debugLog("Humanoid not found!")
            return false
        end
        if humanoid.Health <= 0 then
            debugLog("Player is dead!")
            return false
        end
        if humanoid.WalkSpeed == 0 and humanoid.JumpPower == 0 then
            debugLog("Player might be in menu!")
            return false
        end
        return true
    end

    -- Проверка, является ли объект целевым
    local function isTargetObject(objectName)
        local targetObjects = { "Dumpster", "Bin", "AirDrop" }
        for _, target in pairs(targetObjects) do
            if objectName == target then
                return true
            end
        end
        return false
    end

    -- Получение расстояния до объекта
    local function getDistanceToObject(obj, objectType)
        if not obj.Parent then
            return math.huge
        end

        local character = Core.PlayerData.LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return math.huge
        end
        local humanoidRootPart = character.HumanoidRootPart

        local objPosition
        local success, err = pcall(function()
            if objectType == "AirDrop" then
                local boxInteriorBottom = obj:FindFirstChild("Model") and obj.Model:FindFirstChild("BoxInteriorBottom")
                objPosition = boxInteriorBottom and boxInteriorBottom.Position or obj:GetPivot().Position
            elseif objectType == "Bin" then
                local mesh = obj:FindFirstChild("Meshes/bin_Cube")
                objPosition = mesh and mesh.Position or obj:GetPivot().Position
            elseif objectType == "Dumpster" then
                local trash = obj:FindFirstChild("Trash")
                objPosition = trash and trash.Position or obj:GetPivot().Position
            else
                objPosition = obj:GetPivot().Position
            end
        end)
        if not success then
            debugLog("Error getting object position:", err)
            return math.huge
        end
        return (humanoidRootPart.Position - objPosition).Magnitude
    end

    -- Проверка расстояния между объектами
    local function getDistanceBetweenObjects(obj1, obj2)
        local pos1, pos2
        local success1 = pcall(function() pos1 = obj1:GetPivot().Position end)
        local success2 = pcall(function() pos2 = obj2:GetPivot().Position end)
        if not success1 or not success2 then return math.huge end
        return (pos1 - pos2).Magnitude
    end

    -- Обновление кэша Bin
    local function updateBinCache()
        if tick() - AutoInteract.State.LastBinCacheUpdate < AutoInteract.State.BinCacheUpdateInterval then return end
        debugLog("Updating Bin cache...")
        AutoInteract.State.BinCache = {}
        for _, obj in pairs(Core.Services.Workspace:GetDescendants()) do
            if obj.Name == "Bin" and isTargetObject(obj.Name) then
                local mesh = obj:FindFirstChild("Meshes/bin_Cube")
                if mesh and mesh:FindFirstChild("ProximityPrompt") then
                    table.insert(AutoInteract.State.BinCache, obj)
                end
            end
        end
        AutoInteract.State.LastBinCacheUpdate = tick()
        debugLog("Found Bins:", #AutoInteract.State.BinCache)
    end

    -- Активация ProximityPrompt
    local function forceTriggerPrompt(prompt, targetObject, objectType)
        debugLog("forceTriggerPrompt called for", targetObject.Name, "type:", objectType)
        if not targetObject.Parent then
            debugLog("Object", targetObject.Name, "no longer exists!")
            AutoInteract.State.ProcessedObjects[targetObject] = nil
            AutoInteract.State.LastDistance[targetObject] = nil
            AutoInteract.State.OriginalHoldTimes[targetObject] = nil
            return false
        end

        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            debugLog("ProximityPrompt found and active")
            for activeObj, _ in pairs(AutoInteract.State.ActiveObjects) do
                local distance = getDistanceBetweenObjects(targetObject, activeObj)
                if distance < AutoInteract.Settings.MinDistanceBetweenObjects.Value then
                    debugLog("Object", targetObject.Name, "too close to", activeObj.Name, "- waiting...")
                    task.wait(AutoInteract.Settings.ActivationDelay.Value)
                    break
                end
            end

            AutoInteract.State.ActiveObjects[targetObject] = true

            local character = Core.PlayerData.LocalPlayer.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then
                debugLog("Character or HumanoidRootPart not found")
                AutoInteract.State.ActiveObjects[targetObject] = nil
                return false
            end
            local humanoidRootPart = character.HumanoidRootPart

            local objectPosition
            local success, err = pcall(function()
                if objectType == "AirDrop" then
                    local boxInteriorBottom = targetObject:FindFirstChild("Model") and targetObject.Model:FindFirstChild("BoxInteriorBottom")
                    objectPosition = boxInteriorBottom and boxInteriorBottom.Position or targetObject:GetPivot().Position
                else
                    objectPosition = targetObject:GetPivot().Position
                end
            end)
            if not success then
                debugLog("GetPivot error:", err)
                AutoInteract.State.ActiveObjects[targetObject] = nil
                return false
            end

            local distance = (humanoidRootPart.Position - objectPosition).Magnitude
            debugLog("Distance to object:", distance)

            if distance <= AutoInteract.Settings.MaxDistance.Value then
                debugLog("In range:", targetObject.Name)
                if prompt.Enabled then
                    prompt.RequiresLineOfSight = false
                    local originalDistance = prompt.MaxActivationDistance
                    prompt.MaxActivationDistance = distance + 5

                    if not AutoInteract.State.OriginalHoldTimes[targetObject] then
                        AutoInteract.State.OriginalHoldTimes[targetObject] = prompt.HoldDuration
                        debugLog("Saved original HoldDuration for", targetObject.Name, ":", AutoInteract.State.OriginalHoldTimes[targetObject])
                    end
                    local originalHoldTime = AutoInteract.State.OriginalHoldTimes[targetObject]
                    if originalHoldTime == 0 then
                        debugLog("HoldDuration is 0 for", targetObject.Name, "- using default 1")
                        originalHoldTime = 1
                        AutoInteract.State.OriginalHoldTimes[targetObject] = 1
                    end

                    local reductionPercentage = AutoInteract.Settings.MinusHoldTime.Value
                    local reductionFactor = 1 - (reductionPercentage / 100)
                    local newHoldTime = math.max(0, originalHoldTime * reductionFactor)
                    debugLog("Original HoldDuration:", originalHoldTime, "MinusHoldTime:", reductionPercentage .. "%", "Reduction Factor:", reductionFactor, "New HoldDuration:", newHoldTime)

                    prompt.HoldDuration = newHoldTime

                    local triggered = false
                    local connection
                    connection = prompt.Triggered:Connect(function()
                        triggered = true
                        connection:Disconnect()
                    end)

                    debugLog("Holding Prompt for", newHoldTime, "seconds")
                    local startTime = tick()
                    prompt:InputHoldBegin()

                    local elapsed = 0
                    while elapsed < newHoldTime do
                        local waitTime = math.min(0.0167, newHoldTime - elapsed)
                        task.wait(waitTime)
                        elapsed = tick() - startTime
                        distance = getDistanceToObject(targetObject, objectType)
                        if distance > AutoInteract.Settings.MaxDistance.Value then
                            debugLog("Player moved away from", targetObject.Name, "during activation - aborting!")
                            prompt:InputHoldEnd()
                            prompt.MaxActivationDistance = originalDistance
                            prompt.HoldDuration = originalHoldTime
                            AutoInteract.State.ActiveObjects[targetObject] = nil
                            AutoInteract.State.ProcessedObjects[targetObject] = nil
                            return false
                        end
                    end
                    task.wait(0.4)
                    debugLog("Hold time elapsed:", tick() - startTime, "seconds")
                    prompt:InputHoldEnd()
                    task.wait(0.4)
                    if triggered then
                        debugLog("Activated Prompt for:", targetObject.Name)
                        AutoInteract.State.ProcessedObjects[targetObject] = true
                    else
                        debugLog("Failed to activate Prompt for:", targetObject.Name)
                    end

                    prompt.MaxActivationDistance = originalDistance
                    prompt.HoldDuration = originalHoldTime
                    debugLog("Restored HoldDuration:", prompt.HoldDuration)
                else
                    debugLog("Prompt disabled in:", targetObject.Name)
                end
            else
                debugLog("Too far from:", targetObject.Name, "Distance:", distance)
            end
        else
            debugLog("ProximityPrompt not found, invalid, or disabled in:", targetObject.Name)
        end

        AutoInteract.State.ActiveObjects[targetObject] = nil
        return triggered
    end

    -- Основной цикл AutoInteract
    AutoInteract.Start = function()
        if not AutoInteract.Settings.Enabled.Value then return end

        Core.Services.RunService.Heartbeat:Connect(function()
            if not AutoInteract.Settings.Enabled.Value then return end

            local currentTime = tick()
            if currentTime - AutoInteract.State.LastUpdateTime < AutoInteract.State.UpdateInterval then return end
            AutoInteract.State.LastUpdateTime = currentTime

            if not isPlayerInGame() then
                debugLog("Player not in game, waiting...")
                return
            end

            -- Обработка Dumpster
            if AutoInteract.Settings.TargetObject.Value == "Dumpster" then
                local props = Core.Services.Workspace:FindFirstChild("Map") and Core.Services.Workspace.Map:FindFirstChild("Props")
                if props then
                    for _, targetObject in pairs(props:GetChildren()) do
                        if isTargetObject(targetObject.Name) then
                            local distance = getDistanceToObject(targetObject, "Dumpster")
                            local wasOutside = AutoInteract.State.LastDistance[targetObject] and AutoInteract.State.LastDistance[targetObject] > AutoInteract.Settings.MaxDistance.Value
                            if distance > AutoInteract.Settings.MaxDistance.Value and AutoInteract.State.ProcessedObjects[targetObject] then
                                debugLog("Player left range of", targetObject.Name, "- resetting status")
                                AutoInteract.State.ProcessedObjects[targetObject] = nil
                            end
                            AutoInteract.State.LastDistance[targetObject] = distance

                            if distance <= AutoInteract.Settings.MaxDistance.Value then
                                local trash = targetObject:FindFirstChild("Trash")
                                if trash then
                                    local attachment = trash:FindFirstChild("Attachment")
                                    if attachment then
                                        local prompt = attachment:FindFirstChild("ProximityPrompt")
                                        if prompt then
                                            forceTriggerPrompt(prompt, targetObject, "Dumpster")
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    debugLog("workspace.Map.Props not found!")
                end
            end

            -- Обработка Bin
            if AutoInteract.Settings.TargetObject.Value == "Bin" then
                updateBinCache()
                for _, targetObject in pairs(AutoInteract.State.BinCache) do
                    if not targetObject.Parent then
                        AutoInteract.State.LastDistance[targetObject] = nil
                        AutoInteract.State.ProcessedObjects[targetObject] = nil
                        continue
                    end
                    local distance = getDistanceToObject(targetObject, "Bin")
                    local wasOutside = AutoInteract.State.LastDistance[targetObject] and AutoInteract.State.LastDistance[targetObject] > AutoInteract.Settings.MaxDistance.Value
                    if distance > AutoInteract.Settings.MaxDistance.Value and AutoInteract.State.ProcessedObjects[targetObject] then
                        debugLog("Player left range of", targetObject.Name, "- resetting status")
                        AutoInteract.State.ProcessedObjects[targetObject] = nil
                    end
                    AutoInteract.State.LastDistance[targetObject] = distance

                    if distance <= AutoInteract.Settings.MaxDistance.Value then
                        local mesh = targetObject:FindFirstChild("Meshes/bin_Cube")
                        if mesh then
                            local prompt = mesh:FindFirstChild("ProximityPrompt")
                            if prompt then
                                forceTriggerPrompt(prompt, targetObject, "Bin")
                            end
                        end
                    end
                end
            end

            -- Обработка AirDrop
            if AutoInteract.Settings.TargetObject.Value == "AirDrop" then
                local airDropRoot = Core.Services.Workspace:FindFirstChild("AirDropModel")
                if airDropRoot then
                    local weaponCrate = airDropRoot:FindFirstChild("Weapon Crate")
                    if weaponCrate then
                        local targetObject = weaponCrate
                        if isTargetObject("AirDrop") then
                            local distance = getDistanceToObject(targetObject, "AirDrop")
                            local wasOutside = AutoInteract.State.LastDistance[targetObject] and AutoInteract.State.LastDistance[targetObject] > AutoInteract.Settings.MaxDistance.Value
                            if distance > AutoInteract.Settings.MaxDistance.Value and AutoInteract.State.ProcessedObjects[targetObject] then
                                debugLog("Player left AirDrop range - resetting status")
                                AutoInteract.State.ProcessedObjects[targetObject] = nil
                            end
                            AutoInteract.State.LastDistance[targetObject] = distance

                            if distance <= AutoInteract.Settings.MaxDistance.Value then
                                local model = targetObject:FindFirstChild("Model")
                                if model then
                                    local boxInteriorBottom = model:FindFirstChild("BoxInteriorBottom")
                                    if boxInteriorBottom then
                                        local prompt = boxInteriorBottom:FindFirstChild("ProximityPrompt")
                                        if prompt then
                                            forceTriggerPrompt(prompt, targetObject, "AirDrop")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Периодическая очистка ProcessedObjects
            if currentTime % 60 == 0 then
                for obj, _ in pairs(AutoInteract.State.ProcessedObjects) do
                    if obj.Name ~= "Weapon Crate" then
                        AutoInteract.State.ProcessedObjects[obj] = nil
                        AutoInteract.State.LastDistance[obj] = nil
                    end
                end
                debugLog("Cleared ProcessedObjects list (except AirDrop)")
            end
        end)
    end

    -- Отслеживание AirDrop
    Core.Services.Workspace.ChildAdded:Connect(function(child)
        if child.Name == "AirDropModel" then
            debugLog("New AirDropModel detected!")
            for obj, _ in pairs(AutoInteract.State.ProcessedObjects) do
                if obj.Name == "Weapon Crate" then
                    AutoInteract.State.ProcessedObjects[obj] = nil
                    AutoInteract.State.LastDistance[obj] = nil
                    AutoInteract.State.OriginalHoldTimes[obj] = nil
                end
            end
            AutoInteract.State.CurrentAirDrop = child
        end
    end)

    Core.Services.Workspace.ChildRemoved:Connect(function(child)
        if child == AutoInteract.State.CurrentAirDrop then
            debugLog("AirDropModel removed!")
            for obj, _ in pairs(AutoInteract.State.ProcessedObjects) do
                if obj.Name == "Weapon Crate" then
                    AutoInteract.State.ProcessedObjects[obj] = nil
                    AutoInteract.State.LastDistance[obj] = nil
                    AutoInteract.State.OriginalHoldTimes[obj] = nil
                end
            end
            AutoInteract.State.CurrentAirDrop = nil
        end
    end)

    -- Настройка UI
    if UI.Sections.AutoInteract then
        UI.Sections.AutoInteract:Header({ Name = "AutoInteract Settings" })
        UI.Sections.AutoInteract:Toggle({
            Name = "Enabled",
            Default = AutoInteract.Settings.Enabled.Default,
            Callback = function(value)
                AutoInteract.Settings.Enabled.Value = value
                if value then
                    AutoInteract.Start()
                    notify("AutoInteract", "Enabled", true)
                else
                    notify("AutoInteract", "Disabled", true)
                end
            end
        })
        UI.Sections.AutoInteract:Dropdown({
            Name = "Target Object",
            Options = {"Bin", "Dumpster", "AirDrop"},
            Default = AutoInteract.Settings.TargetObject.Default,
            Callback = function(value)
                AutoInteract.Settings.TargetObject.Value = value
                notify("AutoInteract", "Target Object set to: " .. value, true)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Max Distance",
            Minimum = 5,
            Maximum = 50,
            Default = AutoInteract.Settings.MaxDistance.Default,
            Precision = 1,
            Callback = function(value)
                AutoInteract.Settings.MaxDistance.Value = value
                notify("AutoInteract", "Max Distance set to: " .. value, false)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Minus Hold Time",
            Minimum = 0,
            Maximum = 100,
            Default = AutoInteract.Settings.MinusHoldTime.Default,
            Precision = 0,
            Suffix = "%",
            Callback = function(value)
                AutoInteract.Settings.MinusHoldTime.Value = value
                notify("AutoInteract", "Minus Hold Time set to: " .. value .. "%", false)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Min Distance Between Objects",
            Minimum = 1,
            Maximum = 20,
            Default = AutoInteract.Settings.MinDistanceBetweenObjects.Default,
            Precision = 1,
            Callback = function(value)
                AutoInteract.Settings.MinDistanceBetweenObjects.Value = value
                notify("AutoInteract", "Min Distance Between Objects set to: " .. value, false)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Activation Delay",
            Minimum = 0.1,
            Maximum = 5,
            Default = AutoInteract.Settings.ActivationDelay.Default,
            Precision = 1,
            Callback = function(value)
                AutoInteract.Settings.ActivationDelay.Value = value
                notify("AutoInteract", "Activation Delay set to: " .. value, false)
            end
        })
        UI.Sections.AutoInteract:Toggle({
            Name = "Enable Debug Logs",
            Default = AutoInteract.Settings.EnableDebugLogs.Default,
            Callback = function(value)
                AutoInteract.Settings.EnableDebugLogs.Value = value
                notify("AutoInteract", "Debug Logs " .. (value and "Enabled" or "Disabled"), false)
            }
        })
    end
end

return Auto