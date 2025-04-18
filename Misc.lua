local Misc = {}

function Misc.Init(UI, Core, notify)
    if not Core.Services.FriendsList then
        Core.Services.FriendsList = {}
    end

    if not (UI.Window and UI.Tabs.Misc and UI.Sections.FriendList) then
        warn("Failed to initialize Friend List: UI components missing")
        return
    end

    local function getPlayerList()
        local players = {}
        -- Попытка через GetPlayers
        for _, player in pairs(Core.Services.Players:GetPlayers()) do
            if player ~= Core.PlayerData.LocalPlayer then
                table.insert(players, player.Name)
            end
        end
        print("getPlayerList (GetPlayers): ", table.concat(players, ", "), " (", #players, " players)")

        -- Если GetPlayers не сработал, ищем через Workspace (для Deadline)
        if #players == 0 then
            for _, descendant in ipairs(Core.Services.Workspace:GetDescendants()) do
                if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
                    local player = Core.Services.Players:GetPlayerFromCharacter(descendant)
                    if player and player ~= Core.PlayerData.LocalPlayer then
                        table.insert(players, player.Name)
                    elseif descendant.Name ~= Core.PlayerData.LocalPlayer.Name then
                        -- Проверяем, есть ли атрибут или тег, указывающий на игрока
                        if descendant:GetAttribute("IsPlayer") or game:GetService("CollectionService"):HasTag(descendant, "Player") then
                            table.insert(players, descendant.Name)
                        end
                    end
                end
            end
            print("getPlayerList (Workspace): ", table.concat(players, ", "), " (", #players, " players)")
        end

        return players
    end

    local currentSelection = Core.Services.FriendsList
    local friendDropdown

    local function updateFriendsList(selected)
        local selectedPlayers = {}
        if type(selected) == "table" then
            for key, value in pairs(selected) do
                if type(value) == "string" then
                    table.insert(selectedPlayers, value)
                elseif type(key) == "string" and value == true then
                    table.insert(selectedPlayers, key)
                elseif type(key) == "string" then
                    table.insert(selectedPlayers, key)
                end
            end
        elseif type(selected) == "string" then
            selectedPlayers = {selected}
        end

        Core.Services.FriendsList = selectedPlayers
        currentSelection = selectedPlayers

        print("updateFriendsList: ", #Core.Services.FriendsList, "friends selected (", table.concat(Core.Services.FriendsList, ", "), ")")
        notify("Friend List", "Updated friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
    end

    local function updateFriendDropdownOptions()
        if not friendDropdown then return end

        local previousSelection = {}
        for _, playerName in pairs(currentSelection) do
            previousSelection[playerName] = true
        end

        local newOptions = getPlayerList()
        local newSelection = {}
        for _, playerName in pairs(newOptions) do
            if previousSelection[playerName] then
                table.insert(newSelection, playerName)
            end
        end
        Core.Services.FriendsList = newSelection
        currentSelection = newSelection

        friendDropdown:ClearOptions()
        friendDropdown:InsertOptions(newOptions)
        friendDropdown:UpdateSelection(newSelection)
        print("updateFriendDropdownOptions: Inserted ", #newOptions, "options, Selected ", #newSelection, "friends")
    end

    UI.Sections.FriendList:Header({ Name = "Friend List" })

    friendDropdown = UI.Sections.FriendList:Dropdown({
        Name = "Select Friend",
        Options = getPlayerList(),
        Multi = true,
        Default = Core.Services.FriendsList,
        Callback = updateFriendsList
    })

    UI.Sections.FriendList:Button({
        Name = "Refresh Player List",
        Callback = function()
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
            updateFriendDropdownOptions()
            notify("Friend List", "Friends list cleared")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Show Friends List",
        Callback = function()
            notify("Friend List", "Current friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
        end
    })

    Core.Services.Players.PlayerAdded:Connect(function()
        updateFriendDropdownOptions()
    end)

    Core.Services.Players.PlayerRemoving:Connect(function(player)
        if table.find(Core.Services.FriendsList, player.Name) then
            table.remove(Core.Services.FriendsList, table.find(Core.Services.FriendsList, player.Name))
            table.remove(currentSelection, table.find(currentSelection, player.Name))
            notify("Friend List", player.Name .. " has left and was removed from friends")
        end
        updateFriendDropdownOptions()
    end)
end

return Misc
