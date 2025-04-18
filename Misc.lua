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
        UpdateInterval = 1
    }

    local currentSelection = Core.Services.FriendsList
    local friendDropdown

    local function getPlayerList()
        if tick() - Cache.LastUpdate < Cache.UpdateInterval then
            return Cache.PlayerList
        end

        local players = {}
        for _, player in ipairs(Core.Services.Players:GetPlayers()) do
            if player ~= Core.PlayerData.LocalPlayer then
                players[player.Name] = true
            end
        end

        Cache.PlayerList = players
        Cache.LastUpdate = tick()
        return players
    end

    local function updateFriendsList(selected)
        local selectedPlayers = {}
        if type(selected) == "table" then
            for _, value in ipairs(selected) do
                if type(value) == "string" then
                    selectedPlayers[value] = true
                end
            end
        elseif type(selected) == "string" then
            selectedPlayers[selected] = true
        end

        Core.Services.FriendsList = {}
        for playerName in pairs(selectedPlayers) do
            table.insert(Core.Services.FriendsList, playerName)
        end
        currentSelection = Core.Services.FriendsList

        notify("Friend List", "Updated friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
    end

    local function updateFriendDropdownOptions()
        if not friendDropdown then return end

        local playerList = getPlayerList()
        local newOptions = {}
        for playerName in pairs(playerList) do
            table.insert(newOptions, playerName)
        end

        -- Проверяем, изменился ли список
        local currentOptions = friendDropdown:GetOptions()
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
        end

        -- Обновляем выбор
        local newSelection = {}
        for _, playerName in ipairs(currentSelection) do
            if playerList[playerName] then
                table.insert(newSelection, playerName)
            end
        end
        Core.Services.FriendsList = newSelection
        currentSelection = newSelection

        friendDropdown:UpdateSelection(newSelection)
    end

    UI.Sections.FriendList:Header({ Name = "Friend List" })

    friendDropdown = UI.Sections.FriendList:Dropdown({
        Name = "Select Friend",
        Options = {},
        Multi = true,
        Default = Core.Services.FriendsList,
        Callback = updateFriendsList
    })

    UI.Sections.FriendList:Button({
        Name = "Refresh Player List",
        Callback = function()
            Cache.LastUpdate = 0 -- Сброс кэша для немедленного обновления
            updateFriendDropdownOptions()
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

    -- Обновление списка при входе/выходе игроков
    local function onPlayerAdded()
        task.defer(updateFriendDropdownOptions)
    end

    local function onPlayerRemoving(player)
        if table.find(Core.Services.FriendsList, player.Name) then
            table.remove(Core.Services.FriendsList, table.find(Core.Services.FriendsList, player.Name))
            table.remove(currentSelection, table.find(currentSelection, player.Name))
            notify("Friend List", player.Name .. " has left and was removed from friends")
        end
        task.defer(updateFriendDropdownOptions)
    end

    Core.Services.Players.PlayerAdded:Connect(onPlayerAdded)
    Core.Services.Players.PlayerRemoving:Connect(onPlayerRemoving)

    -- Инициализация выпадающего списка
    updateFriendDropdownOptions()
end

return Misc
