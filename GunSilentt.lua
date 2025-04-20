-- Проверяем, загружен ли уже Visuals, чтобы избежать дублирования
local WatermarkModule = _G.WatermarkModule
if not WatermarkModule then
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/AndreyAboba/mainLogic/refs/heads/main/Visuals.lua"))()
    end)
    if success and result and type(result) == "table" then
        WatermarkModule = result
        _G.WatermarkModule = WatermarkModule -- Сохраняем в глобальной области
    else
        warn("Failed to load Visuals.lua:", result)
        WatermarkModule = { Settings = { gradientColor1 = Color3.fromRGB(255, 255, 255), gradientColor2 = Color3.fromRGB(255, 255, 255) } }
    end
end

local GunSilent = {
    Settings = {
        Enabled = { Value = false, Default = false },
        RangePlus = { Value = 50, Default = 50 },
        Rage = { Value = false, Default = false },
        HitPart = { Value = "Head", Default = "Head" },
        PredictBullet = { Value = 2500, Default = 2500 },
        YCorrection = { Value = 0.01, Default = 0.01 },
        FakeDistance = { Value = 3, Default = 3 },
        WallSupport = { Value = true, Default = true },
        UseFOV = { Value = true, Default = true },
        FOV = { Value = 120, Default = 120 },
        ShowCircle = { Value = true, Default = true },
        SortMethod = { Value = "Mouse&Distance", Default = "Mouse&Distance" },
        TargetVisual = { Value = true, Default = true },
        HitboxVisual = { Value = true, Default = true },
        PredictVisual = { Value = true, Default = true },
        ShowDirection = { Value = true, Default = true },
        HitChance = { Value = 100, Default = 100 },
        GradientCircle = { Value = false, Default = false },
        GradientSpeed = { Value = 2, Default = 2 },
        AdvancedEnabled = { Value = false, Default = false },
        AdvancedVehicleFactor = { Value = 0.9, Default = 0.9 },
        AdvancedPedestrianFactor = { Value = 0.55, Default = 0.55 },
        AdvancedTeleportThreshold = { Value = 600, Default = 600 },
        AdvancedMaxSpeed = { Value = 500, Default = 500 },
        AdvancedVehicleYCorrection = { Value = 0, Default = 0 },
        AdvancedPredictionAggressiveness = { Value = 1.2, Default = 1.2 },
        AdvancedSmoothingFactor = { Value = 0.1, Default = 0.1 },
        AdvancedSmallDistanceSpeedFactorMultiplier = { Value = 1.7, Default = 1.7 },
        AdvancedSlowVehiclePredictionFactor = { Value = 1.95, Default = 1.95 },
        AdvancedFastVehiclePredictionLimit = { Value = 2.2, Default = 2.2 },
        VisualUpdateFrequency = { Value = 0.05, Default = 0.05 },
        AdvancedPositionHistorySize = { Value = 20, Default = 20 },
        LatencyCompensation = { Value = 0.2, Default = 0.2 },
        ShowTrajectoryBeam = { Value = true, Default = true },
        ShowFullTrajectory = { Value = true, Default = true }
    },
    FixedPredictionValues = {
        VehicleFactor = 0.9,
        PedestrianFactor = 0.55,
        PredictionAggressiveness = 1.2,
        SmallDistanceSpeedFactorMultiplier = 1.7,
        SlowVehiclePredictionFactor = 1.95,
        FastVehiclePredictionLimit = 2.2,
        PositionHistorySize = 20,
        SmoothingFactor = 0.1,
        TeleportThreshold = 600,
        MaxSpeed = 500,
        PredictBullet = 600
    },
    State = {
        LastEventId = 0,
        LastLogTime = 0,
        LastTool = nil,
        TargetVisualPart = nil,
        HitboxVisualPart = nil,
        PredictVisualPart = nil,
        DirectionVisualPart = nil,
        RealDirectionVisualPart = nil,
        FovCircle = nil,
        V_U_4 = nil,
        Connection = nil,
        OldFireServer = nil,
        GradientTime = 0,
        PositionHistory = {},
        LastPredictionTime = 0,
        PredictionInterval = 0.1,
        LastPing = 0.15,
        SmoothedVelocity = {},
        LastDirection = {},
        LastRealDirection = {},
        LastVisualUpdateTime = nil,
        IsTeleporting = false,
        LastTargetPosition = {},
        TrajectoryBeam = nil,
        FullTrajectoryParts = nil
    },
    Watermark = WatermarkModule -- Присваиваем Watermark здесь
}

local Players = game:GetService("Players")

local function isGunTool(tool)
    if not tool then return false end
    local items = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
    if not items then return false end
    local gunFolder = items:FindFirstChild("gun")
    if not gunFolder then return false end
    for _, gun in pairs(gunFolder:GetChildren()) do
        if tool.Name == gun.Name then return true end
    end
    return false
end

local function getGunRange(tool)
    local baseRange = tool and tool:GetAttribute("Range") or 50
    return baseRange + GunSilent.Settings.RangePlus.Value
end

local function getEquippedGunTool()
    local character = GunSilent.Core.Services.Workspace:FindFirstChild(GunSilent.Core.PlayerData.LocalPlayer.Name)
    if not character then return nil end
    for _, child in pairs(character:GetChildren()) do
        if child.ClassName == "Tool" and isGunTool(child) then
            return child
        end
    end
    return nil
end

local function updateFovCircle(deltaTime)
    if not GunSilent.Settings.ShowCircle.Value then
        if GunSilent.State.FovCircle then
            GunSilent.State.FovCircle:Remove()
            GunSilent.State.FovCircle = nil
        end
        return
    end

    local camera = GunSilent.Core.PlayerData.Camera
    if not camera then return end

    if not GunSilent.State.FovCircle then
        GunSilent.State.FovCircle = Drawing.new("Circle")
        GunSilent.State.FovCircle.Thickness = 2
        GunSilent.State.FovCircle.NumSides = 100
        GunSilent.State.FovCircle.Color = Color3.fromRGB(255, 255, 255)
        GunSilent.State.FovCircle.Visible = true
        GunSilent.State.FovCircle.Filled = false
    end

    deltaTime = type(deltaTime) == "number" and deltaTime or 0
    GunSilent.State.GradientTime = GunSilent.State.GradientTime or 0

    GunSilent.State.FovCircle.Radius = math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
    local mousePos = GunSilent.Core.Services.UserInputService:GetMouseLocation()
    GunSilent.State.FovCircle.Position = Vector2.new(mousePos.X, mousePos.Y)

    if GunSilent.Settings.GradientCircle.Value then
        GunSilent.State.GradientTime = GunSilent.State.GradientTime + deltaTime
        local speed = GunSilent.Settings.GradientSpeed.Value
        local t = (math.sin(GunSilent.State.GradientTime / speed * 2 * math.pi) + 1) / 2

        -- Берем цвета из GradientColors (ESP.Settings в Visuals.lua)
        local color1, color2
        if GunSilent.Watermark and GunSilent.Watermark.ESP and GunSilent.Watermark.ESP.Settings and GunSilent.Watermark.ESP.Settings.GradientColor1 and GunSilent.Watermark.ESP.Settings.GradientColor2 then
            color1 = GunSilent.Watermark.ESP.Settings.GradientColor1.Value
            color2 = GunSilent.Watermark.ESP.Settings.GradientColor2.Value
        else
            -- Если что-то недоступно, используем цвета по умолчанию
            color1 = Color3.fromRGB(0, 0, 255)
            color2 = Color3.fromRGB(147, 112, 219)
        end

        local interpolatedColor = color1:Lerp(color2, t)
        GunSilent.State.FovCircle.Color = interpolatedColor

        -- Отладочный вывод для проверки
        print("FOV Circle Color Updated:", interpolatedColor, "GradientCircle:", GunSilent.Settings.GradientCircle.Value)
    else
        GunSilent.State.FovCircle.Color = Color3.fromRGB(255, 255, 255)
    end
end

-- Остальные функции остаются без изменений, обновляем только Init

local function Init(UI, Core, notify)
    GunSilent.Core = Core
    GunSilent.notify = notify

    -- Инициализируем Watermark только один раз
    if GunSilent.Watermark and GunSilent.Watermark.Init and not _G.WatermarkInitialized then
        GunSilent.Watermark.Init(UI, Core, notify)
        _G.WatermarkInitialized = true -- Устанавливаем флаг, чтобы избежать повторной инициализации
    end

    if UI.Tabs.Combat then
        UI.Sections.GunSilent = UI.Tabs.Combat:Section({ Side = "Right", Name = "GunSilent" })
        if UI.Sections.GunSilent then
            UI.Sections.GunSilent:Header({ Name = "GunSilent" })
            UI.Sections.GunSilent:Toggle({
                Name = "Enabled",
                Default = GunSilent.Settings.Enabled.Default,
                Callback = function(value)
                    GunSilent.Settings.Enabled.Value = value
                    initializeGunSilent()
                    notify("GunSilent", "GunSilent " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Range Plus",
                Minimum = 0,
                Maximum = 200,
                Default = GunSilent.Settings.RangePlus.Default,
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.RangePlus.Value = value
                    notify("GunSilent", "Range Plus set to: " .. value, false)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Rage",
                Default = GunSilent.Settings.Rage.Default,
                Callback = function(value)
                    GunSilent.Settings.Rage.Value = value
                    initializeGunSilent()
                    notify("GunSilent", "Rage " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Dropdown({
                Name = "Hit Part",
                Default = GunSilent.Settings.HitPart.Default,
                Options = {"Head", "UpperTorso", "HumanoidRootPart", "Random"},
                Callback = function(value)
                    GunSilent.Settings.HitPart.Value = value
                    notify("GunSilent", "Hit Part set to: " .. value, true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Fake Distance",
                Default = GunSilent.Settings.FakeDistance.Default,
                Minimum = 0,
                Maximum = 15,
                DisplayMethod = "Value",
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.FakeDistance.Value = value
                    notify("GunSilent", "Fake Distance set to: " .. value)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Wall Support",
                Default = GunSilent.Settings.WallSupport.Default,
                Callback = function(value)
                    GunSilent.Settings.WallSupport.Value = value
                    notify("GunSilent", "Wall Support " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Use FOV",
                Default = GunSilent.Settings.UseFOV.Default,
                Callback = function(value)
                    GunSilent.Settings.UseFOV.Value = value
                    notify("GunSilent", "Use FOV " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "FOV",
                Default = GunSilent.Settings.FOV.Default,
                Minimum = 0,
                Maximum = 120,
                DisplayMethod = "Value",
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.FOV.Value = value
                    notify("GunSilent", "FOV set to: " .. value)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Show Circle",
                Default = GunSilent.Settings.ShowCircle.Default,
                Callback = function(value)
                    GunSilent.Settings.ShowCircle.Value = value
                    notify("GunSilent", "Show Circle " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Gradient Circle",
                Default = GunSilent.Settings.GradientCircle.Default,
                Callback = function(value)
                    GunSilent.Settings.GradientCircle.Value = value
                    notify("GunSilent", "Gradient Circle " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Gradient Speed",
                Default = GunSilent.Settings.GradientSpeed.Default,
                Minimum = 0.1,
                Maximum = 3.5,
                DisplayMethod = "Value",
                Precision = 1,
                Callback = function(value)
                    GunSilent.Settings.GradientSpeed.Value = value
                    notify("GunSilent", "Gradient Speed set to: " .. value)
                end
            })
            UI.Sections.GunSilent:Dropdown({
                Name = "Sort Method",
                Default = GunSilent.Settings.SortMethod.Default,
                Options = {"Mouse", "Distance", "Mouse&Distance"},
                Callback = function(value)
                    GunSilent.Settings.SortMethod.Value = value
                    notify("GunSilent", "Sort Method set to: " .. value, true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Target Visual",
                Default = GunSilent.Settings.TargetVisual.Default,
                Callback = function(value)
                    GunSilent.Settings.TargetVisual.Value = value
                    notify("GunSilent", "Target Visual " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Hitbox Visual",
                Default = GunSilent.Settings.HitboxVisual.Default,
                Callback = function(value)
                    GunSilent.Settings.HitboxVisual.Value = value
                    notify("GunSilent", "Hitbox Visual " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Predict Visual",
                Default = GunSilent.Settings.PredictVisual.Default,
                Callback = function(value)
                    GunSilent.Settings.PredictVisual.Value = value
                    notify("GunSilent", "Predict Visual " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Show Direction",
                Default = GunSilent.Settings.ShowDirection.Default,
                Callback = function(value)
                    GunSilent.Settings.ShowDirection.Value = value
                    notify("GunSilent", "Show Direction " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Show Trajectory",
                Default = GunSilent.Settings.ShowTrajectoryBeam.Default,
                Callback = function(value)
                    GunSilent.Settings.ShowTrajectoryBeam = value
                    notify("GunSilent", "Trajectory Beam " .. (value and "enabled" or "disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Show Full Trajectory",
                Default = GunSilent.Settings.ShowFullTrajectory.Default,
                Callback = function(value)
                    GunSilent.Settings.ShowFullTrajectory = value
                    notify("GunSilent", "Full Trajectory " .. (value and "enabled" or "disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Hit Chance",
                Default = GunSilent.Settings.HitChance.Default,
                Minimum = 0,
                Maximum = 100,
                DisplayMethod = "Percent",
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.HitChance.Value = value
                    notify("GunSilent", "Hit Chance set to: " .. value .. "%")
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Latency Compensation",
                Minimum = 0.0,
                Maximum = 0.5,
                Default = GunSilent.Settings.LatencyCompensation.Default,
                Precision = 3,
                Callback = function(value)
                    GunSilent.Settings.LatencyCompensation.Value = value
                    notify("GunSilent", "Latency Compensation set to: " .. value .. "s", false)
                end
            })
            UI.Sections.GunSilent:Header({ Name = "Prediction Settings" })
            UI.Sections.GunSilent:Toggle({
                Name = "Advanced Prediction",
                Default = GunSilent.Settings.AdvancedEnabled.Default,
                Callback = function(value)
                    GunSilent.Settings.AdvancedEnabled.Value = value
                    if value then
                        notify("GunSilent", "Advanced Prediction Enabled", true)
                    else
                        notify("GunSilent", "Advanced Prediction Disabled - Using default prediction values", true)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Vehicle Factor",
                Minimum = 0.1,
                Maximum = 2.0,
                Default = GunSilent.Settings.AdvancedVehicleFactor.Default,
                Precision = 2,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedVehicleFactor.Value = value
                        notify("GunSilent", "Vehicle Prediction Factor set to: " .. value, false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Player Factor",
                Minimum = 0.1,
                Maximum = 2.0,
                Default = GunSilent.Settings.AdvancedPedestrianFactor.Default,
                Precision = 2,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedPedestrianFactor.Value = value
                        notify("GunSilent", "Pedestrian Prediction Factor set to: " .. value, false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Agressivness",
                Minimum = 0.4,
                Maximum = 2.1,
                Default = GunSilent.Settings.AdvancedPredictionAggressiveness.Default,
                Precision = 2,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedPredictionAggressiveness.Value = value
                        notify("GunSilent", "Prediction Aggressiveness set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Prediction Aggressiveness.", false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "LowDistanceMulti",
                Minimum = 0.4,
                Maximum = 2.1,
                Default = GunSilent.Settings.AdvancedSmallDistanceSpeedFactorMultiplier.Default,
                Precision = 2,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedSmallDistanceSpeedFactorMultiplier.Value = value
                        notify("GunSilent", "Small Distance Speed Multiplier set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Small Distance Speed Multiplier.", false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "SlowVehicleMulti",
                Minimum = 0.5,
                Maximum = 3.0,
                Default = GunSilent.Settings.AdvancedSlowVehiclePredictionFactor.Default,
                Precision = 2,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedSlowVehiclePredictionFactor.Value = value
                        notify("GunSilent", "Slow Vehicle Prediction Factor set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Slow Vehicle Prediction Factor.", false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "FastPredictionLimit",
                Minimum = 1.0,
                Maximum = 5.0,
                Default = GunSilent.Settings.AdvancedFastVehiclePredictionLimit.Default,
                Precision = 1,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedFastVehiclePredictionLimit.Value = value
                        notify("GunSilent", "Fast Vehicle Prediction Limit set to: " .. value, false)
                    else
                        notify(" consequence of the settings", "Enable Advanced Prediction to change Fast Vehicle Prediction Limit.", false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Position History",
                Minimum = 2,
                Maximum = 20,
                Default = GunSilent.Settings.AdvancedPositionHistorySize.Default,
                Precision = 0,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedPositionHistorySize.Value = value
                        notify("GunSilent", "Position History Size set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Position History Size.", true)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Smoothing Factor",
                Minimum = 0.1,
                Maximum = 0.9,
                Default = GunSilent.Settings.AdvancedSmoothingFactor.Default,
                Precision = 1,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedSmoothingFactor.Value = value
                        notify("GunSilent", "Smoothing Factor set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Smoothing Factor.", false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Vehicle Y Correction",
                Minimum = 0,
                Maximum = 5,
                Default = GunSilent.Settings.AdvancedVehicleYCorrection.Default,
                Precision = 2,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedVehicleYCorrection.Value = value
                        notify("GunSilent", "Vehicle Y Correction set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Vehicle Y Correction.", true)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Visual Update Frequency",
                Minimum = 0.01,
                Maximum = 0.2,
                Default = GunSilent.Settings.VisualUpdateFrequency.Default,
                Precision = 2,
                Callback = function(value)
                    GunSilent.Settings.VisualUpdateFrequency.Value = value
                    notify("GunSilent", "Visual Update Frequency set to: " .. value .. " seconds", false)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Teleport Speed",
                Minimum = 300,
                Maximum = 1000,
                Default = GunSilent.Settings.AdvancedTeleportThreshold.Default,
                Precision = 0,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedTeleportThreshold.Value = value
                        notify("GunSilent", "Teleport Threshold set to: " .. value, false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "TP Limit",
                Minimum = 100,
                Maximum = 500,
                Default = GunSilent.Settings.AdvancedMaxSpeed.Default,
                Precision = 0,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.AdvancedMaxSpeed.Value = value
                        notify("GunSilent", "Max Speed Limit set to: " .. value, false)
                    end
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Bullet Speed",
                Minimum = 500,
                Maximum = 5000,
                Default = GunSilent.Settings.PredictBullet.Default,
                Precision = 0,
                Callback = function(value)
                    if GunSilent.Settings.AdvancedEnabled.Value then
                        GunSilent.Settings.PredictBullet.Value = value
                        notify("GunSilent", "Bullet Speed set to: " .. value, false)
                    else
                        notify("GunSilent", "Enable Advanced Prediction to change Bullet Speed.", false)
                    end
                end
            })
        end
    end

    initializeGunSilent()
end

return { Init = Init }
