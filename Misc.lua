local Misc = {}

function Misc.Init(UI, Core, notify)
    if not Core.Services.FriendsList then
        Core.Services.FriendsList = {}
    end

    if not (UI.Window and UI.Tabs.Misc and UI.Sections.FriendList) then
        warn("Failed to initialize Friend List: UI components missing")
        return
    end

    -- Кэш
    local Cache = {
        PlayerList = {},
        LastUpdate = 0,
        UpdateInterval = 1,
        LastFriendUpdate = 0,
        FriendUpdateThreshold = 0.5
    }

    local currentSelection = Core.Services.FriendsList
    local friendDropdown

    local function getPlayerList()
        if tick() - Cache.LastUpdate < Cache.UpdateInterval then
            return Cache.PlayerList
        end

        local players = {}
        -- Попытка через GetPlayers
        for _, player in ipairs(Core.Services.Players:GetPlayers()) do
            if player ~= Core.PlayerData.LocalPlayer then
                players[player.Name] = true
            end
        end

        -- Если GetPlayers не сработал, ищем через Workspace (для Deadline)
        if not next(players) then
            for _, descendant in ipairs(Core.Services.Workspace:GetDescendants()) do
                if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
                    local player = Core.Services.Players:GetPlayerFromCharacter(descendant)
                    if player and player ~= Core.PlayerData.LocalPlayer then
                        players[player.Name] = true
                    elseif descendant.Name ~= Core.PlayerData.LocalPlayer.Name then
                        players[descendant.Name] = true
                    end
                end
            end
        end

        Cache.PlayerList = players
        Cache.LastUpdate = tick()

        -- Собираем имена для лога
        local playerNames = {}
        local playerCount = 0
        for name in pairs(players) do
            table.insert(playerNames, name)
            playerCount = playerCount + 1
        end
        print("getPlayerList: ", table.concat(playerNames, ", "), " (", playerCount, " players)")
        return players
    end

    local function updateFriendsList(selected)
        if tick() - Cache.LastFriendUpdate < Cache.FriendUpdateThreshold then
            return
        end
        Cache.LastFriendUpdate = tick()

        local selectedPlayers = {}
        if type(selected) == "table" and #selected > 0 then
            for _, value in ipairs(selected) do
                if type(value) == "string" then
                    selectedPlayers[value] = true
                end
            end
        elseif type(selected) == "string" then
            selectedPlayers[selected] = true
        end

        local newFriendsList = {}
        for playerName in pairs(selectedPlayers) do
            table.insert(newFriendsList, playerName)
        end

        -- Синхронизируем с текущим выбором в Dropdown
        local currentDropdownSelection = friendDropdown:GetSelection() or {}
        for _, playerName in ipairs(currentDropdownSelection) do
            if not selectedPlayers[playerName] then
                table.insert(newFriendsList, playerName)
            end
        end

        if #newFriendsList == #Core.Services.FriendsList and table.concat(newFriendsList, ",") == table.concat(Core.Services.FriendsList, ",") then
            return
        end

        Core.Services.FriendsList = newFriendsList
        currentSelection = newFriendsList

        print("updateFriendsList: ", #Core.Services.FriendsList, "friends selected (", table.concat(Core.Services.FriendsList, ", "), ")")
        notify("Friend List", "Updated friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
    end

    local function updateFriendDropdownOptions()
        if not friendDropdown then return end

        local playerList = getPlayerList()
        local newOptions = {}
        for playerName in pairs(playerList) do
            table.insert(newOptions, playerName)
        end
        table.sort(newOptions)

        local currentOptions = friendDropdown:GetOptions() or {}
        local optionsChanged = #newOptions ~= #currentOptions
        if not optionsChanged then
            for i, opt in ipairs(newOptions) do
                if opt ~= currentOptions[i] then
                    optionsChanged = true
                    break
                end
            end
        end

        if optionsChanged then
            friendDropdown:ClearOptions()
            friendDropdown:InsertOptions(newOptions)
            print("updateFriendDropdownOptions: Inserted ", #newOptions, "options (", table.concat(newOptions, ", "), ")")
        end

        local newSelection = {}
        for _, playerName in ipairs(currentSelection) do
            if playerList[playerName] then
                table.insert(newSelection, playerName)
            end
        end

        Core.Services.FriendsList = newSelection
        currentSelection = newSelection
        friendDropdown:UpdateSelection(newSelection)
        print("updateFriendDropdownOptions: Selected ", #newSelection, "friends (", table.concat(newSelection, ", "), ")")
    end

    UI.Sections.FriendList:Header({ Name = "Friend List" })

    -- Отложенная инициализация Dropdown
    task.delay(2, function()
        local initialOptions = {}
        for playerName in pairs(getPlayerList()) do
            table.insert(initialOptions, playerName)
        end
        table.sort(initialOptions)

        if not friendDropdown then
            friendDropdown = UI.Sections.FriendList:Dropdown({
                Name = "Select Friend",
                Options = initialOptions,
                Multi = true,
                Default = Core.Services.FriendsList,
                Callback = updateFriendsList
            })
            print("friendDropdown initialized with ", #initialOptions, "options")
        else
            friendDropdown:ClearOptions()
            friendDropdown:InsertOptions(initialOptions)
            friendDropdown:UpdateSelection(Core.Services.FriendsList)
            print("friendDropdown updated with ", #initialOptions, "options")
        end
        updateFriendDropdownOptions()
    end)

    UI.Sections.FriendList:Button({
        Name = "Refresh Player List",
        Callback = function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
            notify("Friend List", "Player list refreshed")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Clear Friends List",
        Callback = function()
            Core.Services.FriendsList = {}
            currentSelection = {}
            friendDropdown:UpdateSelection({})
            notify("Friend List", "Friends list cleared")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Show Friends List",
        Callback = function()
            notify("Friend List", "Current friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
        end
    })

    local function onPlayerAdded()
        task.defer(function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
        end)
    end

    local function onPlayerRemoving(player)
        if table.find(Core.Services.FriendsList, player.Name) then
            table.remove(Core.Services.FriendsList, table.find(Core.Services.FriendsList, player.Name))
            table.remove(currentSelection, table.find(currentSelection, player.Name))
            notify("Friend List", player.Name .. " has left and was removed from friends")
        end
        task.defer(function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
        end)
    end

    Core.Services.Players.PlayerAdded:Connect(onPlayerAdded)
    Core.Services.Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Misc
