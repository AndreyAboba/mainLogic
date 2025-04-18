local Visuals = {}

function Visuals.Init(UI, Core, notify)
    -- Menu Button
    local MenuButton = {
        Settings = {
            Enabled = { Value = false, Default = false },
            Icon = "rbxassetid://18821914323"
        },
        State = {
            Dragging = false,
            DragStart = nil,
            StartPos = nil
        }
    }

    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "MenuToggleButtonGui"
    buttonGui.Parent = Core.Services.CoreGuiService
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false
    print("ScreenGui created:", buttonGui)

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, 50, 0, 50)
    buttonFrame.Position = UDim2.new(0, 100, 0, 100)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = MenuButton.Settings.Enabled.Value
    buttonFrame.Parent = buttonGui
    print("Button created at position:", buttonFrame.Position, "Visible:", buttonFrame.Visible)

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.5, 0)
    buttonCorner.Parent = buttonFrame

    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, 30, 0, 30)
    buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = MenuButton.Settings.Icon
    buttonIcon.Parent = buttonFrame

    local function emulateRightControl()
        local success, error = pcall(function()
            if game:GetService("VirtualInputManager") then
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
                wait()
                vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
            else
                warn("VirtualInputManager not available, cannot emulate RightControl")
            end
        end)
        if not success then
            warn("Failed to emulate RightControl: " .. tostring(error))
        end
    end

    local touchStartTime = 0
    local touchThreshold = 0.2
    local draggingButton = false
    local dragStartPos = nil
    local buttonStartPos = nil

    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            touchStartTime = tick()
            local mousePos
            if input.UserInputType == Enum.UserInputType.Touch then
                mousePos = input.Position
            else
                mousePos = Core.Services.UserInputService:GetMouseLocation()
            end
            if mousePos then
                draggingButton = true
                dragStartPos = mousePos
                buttonStartPos = buttonFrame.Position
            end
        end
    end)

    Core.Services.UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and draggingButton then
            local mousePos
            if input.UserInputType == Enum.UserInputType.Touch then
                mousePos = input.Position
            else
                mousePos = Core.Services.UserInputService:GetMouseLocation()
            end
            if not mousePos then return end
            local delta = mousePos - dragStartPos
            buttonFrame.Position = UDim2.new(0, buttonStartPos.X.Offset + delta.X, 0, buttonStartPos.Y.Offset + delta.Y)
        end
    end)

    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingButton = false
            local touchDuration = tick() - touchStartTime
            if touchDuration < touchThreshold then
                emulateRightControl()
            end
        end
    end)

    -- Watermark
    local WaterMark = {
        Settings = {
            Enabled = true,
            gradientSpeed = 2,
            segmentCount = 12,
            showFPS = true,
            showTime = true,
            gradientColor1 = Color3.fromRGB(0, 0, 255),
            gradientColor2 = Color3.fromRGB(147, 112, 219)
        },
        Elements = {},
        State = {
            Dragging = false,
            DragStart = nil,
            StartPos = nil,
            GradientTime = 0,
            FrameCount = 0,
            LastUpdateTime = 0,
            UpdateInterval = 0.5,
            AccumulatedTime = 0
        }
    }

    local function initWaterMarkElements()
        local elements = WaterMark.Elements
        local savedPosition = elements.Container and elements.Container.Position or UDim2.new(0, 350, 0, 10)
        if elements.Gui then
            elements.Gui:Destroy()
        end
        elements = {}
        WaterMark.Elements = elements

        local gui = Instance.new("ScreenGui")
        gui.Name = "WaterMarkGui"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Parent = Core.Services.CoreGuiService
        elements.Gui = gui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 0, 0, 30)
        container.Position = savedPosition
        container.BackgroundTransparency = 1
        container.Parent = gui
        elements.Container = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 5)
        layout.Parent = container

        local logoBackground = Instance.new("Frame")
        logoBackground.Size = UDim2.new(0, 24, 0, 24)
        logoBackground.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        logoBackground.BackgroundTransparency = 0.3
        logoBackground.BorderSizePixel = 0
        logoBackground.Parent = container
        elements.LogoBackground = logoBackground

        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 5)
        logoCorner.Parent = logoBackground

        local logoFrame = Instance.new("Frame")
        logoFrame.Size = UDim2.new(0, 20, 0, 20)
        logoFrame.Position = UDim2.new(0, 2, 0, 2)
        logoFrame.BackgroundTransparency = 1
        logoFrame.Parent = logoBackground
        elements.LogoFrame = logoFrame

        elements.LogoSegments = {}
        local segmentCount = math.max(1, WaterMark.Settings.segmentCount)
        for i = 1, segmentCount do
            local segment = Instance.new("ImageLabel")
            segment.Size = UDim2.new(1, 0, 1, 0)
            segment.BackgroundTransparency = 1
            segment.Image = "rbxassetid://7151778302"
            segment.ImageTransparency = 0.4
            segment.Rotation = (i - 1) * (360 / segmentCount)
            segment.Parent = logoFrame

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = segment

            local gradient = Instance.new("UIGradient")
            gradient.Name = "UIGradient"
            gradient.Color = ColorSequence.new(WaterMark.Settings.gradientColor1, WaterMark.Settings.gradientColor2)
            gradient.Rotation = (i - 1) * (360 / segmentCount)
            gradient.Parent = segment

            table.insert(elements.LogoSegments, segment)
        end

        local playerNameFrame = Instance.new("Frame")
        playerNameFrame.Size = UDim2.new(0, 0, 0, 20)
        playerNameFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        playerNameFrame.BackgroundTransparency = 0.3
        playerNameFrame.BorderSizePixel = 0
        playerNameFrame.Parent = container
        elements.PlayerNameFrame = playerNameFrame

        local playerNameCorner = Instance.new("UICorner")
        playerNameCorner.CornerRadius = UDim.new(0, 5)
        playerNameCorner.Parent = playerNameFrame

        local playerNameLabel = Instance.new("TextLabel")
        playerNameLabel.Size = UDim2.new(0, 0, 1, 0)
        playerNameLabel.BackgroundTransparency = 1
        playerNameLabel.Text = Core.PlayerData.LocalPlayer.Name
        playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerNameLabel.TextSize = 14
        playerNameLabel.Font = Enum.Font.GothamBold
        playerNameLabel.TextXAlignment = Enum.TextXAlignment.Center
        playerNameLabel.Parent = playerNameFrame
        elements.PlayerNameLabel = playerNameLabel

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = playerNameFrame

        if WaterMark.Settings.showFPS then
            local fpsFrame = Instance.new("Frame")
            fpsFrame.Size = UDim2.new(0, 0, 0, 20)
            fpsFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
            fpsFrame.BackgroundTransparency = 0.3
            fpsFrame.BorderSizePixel = 0
            fpsFrame.Parent = container
            elements.FPSFrame = fpsFrame

            local fpsCorner = Instance.new("UICorner")
            fpsCorner.CornerRadius = UDim.new(0, 5)
            fpsCorner.Parent = fpsFrame

            local fpsContainer = Instance.new("Frame")
            fpsContainer.Size = UDim2.new(0, 0, 0, 20)
            fpsContainer.BackgroundTransparency = 1
            fpsContainer.Parent = fpsFrame
            elements.FPSContainer = fpsContainer

            local fpsLayout = Instance.new("UIListLayout")
            fpsLayout.FillDirection = Enum.FillDirection.Horizontal
            fpsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            fpsLayout.Padding = UDim.new(0, 4)
            fpsLayout.Parent = fpsContainer

            local fpsIcon = Instance.new("ImageLabel")
            fpsIcon.Size = UDim2.new(0, 14, 0, 14)
            fpsIcon.BackgroundTransparency = 1
            fpsIcon.Image = "rbxassetid://8587689304"
            fpsIcon.ImageTransparency = 0.3
            fpsIcon.Parent = fpsContainer
            elements.FPSIcon = fpsIcon

            local fpsLabel = Instance.new("TextLabel")
            fpsLabel.BackgroundTransparency = 1
            fpsLabel.Text = "999 FPS"
            fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            fpsLabel.TextSize = 14
            fpsLabel.Font = Enum.Font.Gotham
            fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
            fpsLabel.Parent = fpsContainer
            elements.FPSLabel = fpsLabel

            local maxWidth = fpsLabel.TextBounds.X
            fpsLabel.Size = UDim2.new(0, maxWidth, 0, 20)
            fpsLabel.Text = "0 FPS"

            local fpsPadding = Instance.new("UIPadding")
            fpsPadding.PaddingLeft = UDim.new(0, 5)
            fpsPadding.PaddingRight = UDim.new(0, 5)
            fpsPadding.Parent = fpsFrame
        end

        if WaterMark.Settings.showTime then
            local timeFrame = Instance.new("Frame")
            timeFrame.Size = UDim2.new(0, 0, 0, 20)
            timeFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
            timeFrame.BackgroundTransparency = 0.3
            timeFrame.BorderSizePixel = 0
            timeFrame.Parent = container
            elements.TimeFrame = timeFrame

            local timeCorner = Instance.new("UICorner")
            timeCorner.CornerRadius = UDim.new(0, 5)
            timeCorner.Parent = timeFrame

            local timeContainer = Instance.new("Frame")
            timeContainer.Size = UDim2.new(0, 0, 0, 20)
            timeContainer.BackgroundTransparency = 1
            timeContainer.Parent = timeFrame
            elements.TimeContainer = timeContainer

            local timeLayout = Instance.new("UIListLayout")
            timeLayout.FillDirection = Enum.FillDirection.Horizontal
            timeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            timeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            timeLayout.Padding = UDim.new(0, 4)
            timeLayout.Parent = timeContainer

            local timeIcon = Instance.new("ImageLabel")
            timeIcon.Size = UDim2.new(0, 14, 0, 14)
            timeIcon.BackgroundTransparency = 1
            timeIcon.Image = "rbxassetid://4034150594"
            timeIcon.ImageTransparency = 0.3
            timeIcon.Parent = timeContainer
            elements.TimeIcon = timeIcon

            local timeLabel = Instance.new("TextLabel")
            timeLabel.Size = UDim2.new(0, 0, 0, 20)
            timeLabel.BackgroundTransparency = 1
            timeLabel.Text = "00:00:00"
            timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            timeLabel.TextSize = 14
            timeLabel.Font = Enum.Font.Gotham
            timeLabel.TextXAlignment = Enum.TextXAlignment.Left
            timeLabel.Parent = timeContainer
            elements.TimeLabel = timeLabel

            local timePadding = Instance.new("UIPadding")
            timePadding.PaddingLeft = UDim.new(0, 5)
            timePadding.PaddingRight = UDim.new(0, 5)
            timePadding.Parent = timeFrame
        end

        local function updateSizes()
            playerNameLabel.Size = UDim2.new(0, playerNameLabel.TextBounds.X, 1, 0)
            playerNameFrame.Size = UDim2.new(0, playerNameLabel.TextBounds.X + 10, 0, 20)

            if WaterMark.Settings.showFPS and elements.FPSLabel then
                elements.FPSContainer.Size = UDim2.new(0, elements.FPSIcon.Size.X.Offset + elements.FPSLabel.Size.X.Offset + 4, 0, 20)
                elements.FPSFrame.Size = UDim2.new(0, elements.FPSContainer.Size.X.Offset + 10, 0, 20)
            end

            if WaterMark.Settings.showTime and elements.TimeLabel then
                elements.TimeLabel.Size = UDim2.new(0, elements.TimeLabel.TextBounds.X, 0, 20)
                elements.TimeContainer.Size = UDim2.new(0, elements.TimeIcon.Size.X.Offset + elements.TimeLabel.TextBounds.X + 4, 0, 20)
                elements.TimeFrame.Size = UDim2.new(0, elements.TimeContainer.Size.X.Offset + 10, 0, 20)
            end

            local totalWidth = 0
            local visibleChildren = 0
            for _, child in pairs(container:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    totalWidth = totalWidth + child.Size.X.Offset
                    visibleChildren = visibleChildren + 1
                end
            end
            totalWidth = totalWidth + (layout.Padding.Offset * math.max(0, visibleChildren - 1))
            container.Size = UDim2.new(0, totalWidth, 0, 30)
        end

        updateSizes()
        playerNameLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateSizes)
        if elements.TimeLabel then
            elements.TimeLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateSizes)
        end
    end

    local function updateGradientCircle(deltaTime)
        if not WaterMark.Settings.Enabled then return end
        if not WaterMark.Elements.LogoSegments then return end
        WaterMark.State.GradientTime = WaterMark.State.GradientTime + deltaTime
        local t = (math.sin(WaterMark.State.GradientTime / WaterMark.Settings.gradientSpeed * 2 * math.pi) + 1) / 2
        local color1 = WaterMark.Settings.gradientColor1
        local color2 = WaterMark.Settings.gradientColor2
        for i, segment in ipairs(WaterMark.Elements.LogoSegments) do
            if segment and segment:FindFirstChild("UIGradient") then
                segment:FindFirstChild("UIGradient").Color = ColorSequence.new(color1:Lerp(color2, t), color2:Lerp(color1, t))
            else
                warn("Invalid segment or missing UIGradient at index " .. i)
            end
        end
    end

    local function setWaterMarkVisibility(visible)
        WaterMark.Settings.Enabled = visible
        if WaterMark.Elements.Gui then
            WaterMark.Elements.Gui.Enabled = visible
        else
            warn("Cannot set Watermark visibility: Gui is nil")
        end
    end

    Core.Services.UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = Core.Services.UserInputService:GetMouseLocation()
            local container = WaterMark.Elements.Container
            if container and mousePos.X >= container.Position.X.Offset and mousePos.X <= container.Position.X.Offset + container.Size.X.Offset and
               mousePos.Y >= container.Position.Y.Offset and mousePos.Y <= container.Position.Y.Offset + container.Size.Y.Offset then
                WaterMark.State.Dragging = true
                WaterMark.State.DragStart = mousePos
                WaterMark.State.StartPos = container.Position
            end
        end
    end)

    Core.Services.UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if WaterMark.State.Dragging then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local delta = mousePos - WaterMark.State.DragStart
                WaterMark.Elements.Container.Position = UDim2.new(0, WaterMark.State.StartPos.X.Offset + delta.X, 0, WaterMark.State.StartPos.Y.Offset + delta.Y)
            end
        end
    end)

    Core.Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            WaterMark.State.Dragging = false
        end
    end)

    initWaterMarkElements()

    Core.Services.RunService.RenderStepped:Connect(function(deltaTime)
        if WaterMark.Settings.Enabled then
            updateGradientCircle(deltaTime)
            if WaterMark.Settings.showFPS and WaterMark.Elements.FPSLabel then
                WaterMark.State.FrameCount = WaterMark.State.FrameCount + 1
                WaterMark.State.AccumulatedTime = WaterMark.State.AccumulatedTime + deltaTime
                if WaterMark.State.AccumulatedTime >= WaterMark.State.UpdateInterval then
                    local fps = math.floor(WaterMark.State.FrameCount / WaterMark.State.AccumulatedTime)
                    WaterMark.Elements.FPSLabel.Text = tostring(fps) .. " FPS"
                    WaterMark.State.FrameCount = 0
                    WaterMark.State.AccumulatedTime = 0
                end
            end
            if WaterMark.Settings.showTime and WaterMark.Elements.TimeLabel then
                local currentTime = os.date("*t")
                WaterMark.Elements.TimeLabel.Text = string.format("%02d:%02d:%02d", currentTime.hour, currentTime.min, currentTime.sec)
            end
        end
    end)

    -- UI Integration
    if UI.Tabs.Visuals then
        if UI.Sections.MenuButton then
            UI.Sections.MenuButton:Header({ Name = "Menu Button Settings" })
            UI.Sections.MenuButton:Toggle({
                Name = "Enabled",
                Default = MenuButton.Settings.Enabled.Default,
                Callback = function(value)
                    MenuButton.Settings.Enabled.Value = value
                    buttonFrame.Visible = value
                    print("Button visibility set to:", value)
                end
            })
        end

        if UI.Sections.Watermark then
            UI.Sections.Watermark:Header({ Name = "Watermark Settings" })
            UI.Sections.Watermark:Toggle({
                Name = "Enabled",
                Default = WaterMark.Settings.Enabled,
                Callback = function(value)
                    WaterMark.Settings.Enabled = value
                    setWaterMarkVisibility(value)
                    notify("Watermark", "Watermark " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.Watermark:Slider({
                Name = "Gradient Speed",
                Minimum = 0.1,
                Maximum = 3.5,
                Default = WaterMark.Settings.gradientSpeed,
                Precision = 1,
                Callback = function(value)
                    WaterMark.Settings.gradientSpeed = value
                    notify("Watermark", "Gradient Speed set to: " .. value)
                end
            })
            UI.Sections.Watermark:Slider({
                Name = "Segment Count",
                Minimum = 8,
                Maximum = 16,
                Default = 12,
                Precision = 0,
                Callback = function(value)
                    WaterMark.Settings.segmentCount = value
                    initWaterMarkElements()
                    notify("Watermark", "Segment Count set to: " .. value)
                end
            })
            UI.Sections.Watermark:Toggle({
                Name = "Show FPS",
                Default = true,
                Callback = function(value)
                    WaterMark.Settings.showFPS = value
                    initWaterMarkElements()
                    notify("Watermark", "Show FPS " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.Watermark:Toggle({
                Name = "Show Time",
                Default = true,
                Callback = function(value)
                    WaterMark.Settings.showTime = value
                    initWaterMarkElements()
                    notify("Watermark", "Show Time " .. (value and "Enabled" or "Disabled"), true)
                end
            })
        end

        if UI.Sections.GradientColors then
            UI.Sections.GradientColors:Header({ Name = "Gradient Colors" })
            UI.Sections.GradientColors:Colorpicker({
                Name = "Gradient Color 1",
                Default = Color3.fromRGB(0, 0, 255),
                Callback = function(value)
                    WaterMark.Settings.gradientColor1 = value
                    initWaterMarkElements()
                    notify("Syllinse", "Gradient Color 1 set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            })
            UI.Sections.GradientColors:Colorpicker({
                Name = "Gradient Color 2",
                Default = Color3.fromRGB(147, 112, 219),
                Callback = function(value)
                    WaterMark.Settings.gradientColor2 = value
                    initWaterMarkElements()
                    notify("Syllinse", "Gradient Color 2 set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            })
        end
    else
        warn("Failed to create Visuals tab")
    end
end

return Visuals