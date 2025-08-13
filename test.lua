-- \\ VARIABLES
local rs = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local virtualInputManager = game:GetService("VirtualInputManager")
local player = players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- \\ FUNCTIONS
function EquipArtifact(artifact)
    local args = {
        artifact,
        "CurrentSecondArtefact"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("EquipArtefact"):FireServer(unpack(args))
end

function RollPassive(petId, passiveName, slot)
    local args = {
        petId,
        passiveName,
        true,
        slot -- 1 or 2 depending on passive slot
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("RollPassive"):FireServer(unpack(args))
end

local CONFIG = {
    LOOP_WAIT = 0.1, 
    TP_COOLDOWN = 0.5, 
    MAX_RETRY = 3 
}

local state = {
    eggSelected = nil,
    artiSelected = nil,
    PetSelected = nil,
    autoNoTP = false,
    autoWithTP = false,
    passives = nil,
    passiveone = false,
    passivetwo = false,
    autoCurrent = false,
    autopassive = false,
    lastTeleport = 0,
    isProcessing = false,
    selectedPassives = {}
}

-- \\ SAFE WAIT FUNCTION
local function safeWait(duration)
    local startTime = tick()
    while tick() - startTime < duration and runService.Heartbeat:Wait() do end
end

-- \\ TABLE OF WORLDS
local function getWorldList()
    local worldList = {}
    local worldsFolder = workspace:FindFirstChild("Worlds")
    
    if worldsFolder then
        for _, world in ipairs(worldsFolder:GetChildren()) do
            if world:IsA("Model") or world:IsA("Folder") then
                table.insert(worldList, world.Name)
            end
        end
    end
    
    table.sort(worldList, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    
    return worldList
end

-- \\ SAFE TELEPORT FUNCTION
local function safeTeleport(targetCFrame)
    local currentTime = tick()
    if currentTime - state.lastTeleport < CONFIG.TP_COOLDOWN then
        return false
    end
    
    state.lastTeleport = currentTime
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    if distance < 10 then
        return true 
    end
    
    hrp.CFrame = targetCFrame
    return true
end

-- \\ MAIN FUNCTION
local function attemptEggOpen(eggName, withTP)
    if state.isProcessing then return end
    state.isProcessing = true
    
    local success = false
    local retries = 0
    
    while retries < CONFIG.MAX_RETRY and not success do
        pcall(function()
            if withTP then
                local eggObject = workspace.Worlds:FindFirstChild(state.eggSelected .. "Egg")
                if eggObject and safeTeleport(eggObject:GetPivot()) then
                    safeWait(0.3) 
                end
            end
            
            local remote = rs:FindFirstChild("Remote")
            if remote then
                local attemptMultiOpen = remote:FindFirstChild("AttemptMultiOpen")
                if attemptMultiOpen then
                    attemptMultiOpen:FireServer(eggName)
                    success = true
                end
            end
        end)
        
        retries = retries + 1
        if not success then
            safeWait(0.1)
        end
    end
    
    state.isProcessing = false
    return success
end

-- \\ CHECK IF PET HAS DESIRED PASSIVE
local function checkPetHasPassive(petData, desiredPassives, slot)
    if not petData or not petData.Passives then
        return false
    end
    
    local currentPassive = nil
    if type(petData.Passives) == "table" then
        currentPassive = petData.Passives[slot]
    end
    
    if currentPassive then
        for _, desiredPassive in ipairs(desiredPassives) do
            if currentPassive == desiredPassive then
                return true, desiredPassive
            end
        end
    end
    
    return false, nil
end

-- \\ GET UPDATED PET DATA
local function getUpdatedPetData(petId)
    local updatedPetData = nil
    pcall(function()
        local PetData = require(ReplicatedStorage.ModuleScripts.LocalDairebStore)
            .GetStoreProxy("GameData")
            :GetData("Pets")
        
        for petName, petInfo in pairs(PetData) do
            if type(petInfo) == "table" and petInfo.PetId == petId then
                updatedPetData = petInfo
                break
            end
        end
    end)
    return updatedPetData
end

-- \\ AUTO PASSIVE FUNCTION
local function attemptPassiveRoll()
    if not state.PetSelected or not state.selectedPassives or #state.selectedPassives == 0 then
        return false, "No pet or passives selected"
    end
    
    -- Get updated pet data to check current passives
    local updatedPetData = getUpdatedPetData(state.PetSelected.PetId)
    if not updatedPetData then
        return false, "Failed to get pet data"
    end
    
    local success = false
    local statusMessage = ""
    local rollsNeeded = false
    
    pcall(function()
        -- Check slot 1
        if state.passiveone then
            local hasDesiredPassive1, foundPassive1 = checkPetHasPassive(updatedPetData, state.selectedPassives, 1)
            if hasDesiredPassive1 then
                statusMessage = statusMessage .. "Slot 1: Has " .. foundPassive1 .. " ✓ "
            else
                rollsNeeded = true
                for _, passiveName in ipairs(state.selectedPassives) do
                    RollPassive(state.PetSelected.PetId, passiveName, 1)
                    safeWait(0.2)
                end
                statusMessage = statusMessage .. "Slot 1: Rolling... "
            end
        end
        
        -- Check slot 2
        if state.passivetwo then
            local hasDesiredPassive2, foundPassive2 = checkPetHasPassive(updatedPetData, state.selectedPassives, 2)
            if hasDesiredPassive2 then
                statusMessage = statusMessage .. "Slot 2: Has " .. foundPassive2 .. " ✓"
            else
                rollsNeeded = true
                for _, passiveName in ipairs(state.selectedPassives) do
                    RollPassive(state.PetSelected.PetId, passiveName, 2)
                    safeWait(0.2)
                end
                statusMessage = statusMessage .. "Slot 2: Rolling..."
            end
        end
        
        success = true
    end)
    
    -- If both slots have desired passives, stop auto rolling
    if not rollsNeeded and (state.passiveone or state.passivetwo) then
        state.autopassive = false
        Options.autopassto:SetValue(false)
        statusMessage = statusMessage .. " - AUTO STOPPED (Complete!)"
    end
    
    return success, statusMessage
end

-- \\ TOGGLE BUTTON
local function ToogleButtonV()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DraggableControlButton"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    
    local button = Instance.new("TextButton")
    button.Name = "ControlButton"
    button.Parent = screenGui
    button.Size = UDim2.new(0, 60, 0, 60)
    button.Position = UDim2.new(0, 100, 0, 100)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Text = "•"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Active = true
    button.Draggable = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button
    
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Parent = button
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, 2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = button.ZIndex - 1
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    local originalSize = button.Size
    local hoverSize = UDim2.new(0, 65, 0, 65)
    
    local hoverTween = tweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = hoverSize, BackgroundColor3 = Color3.fromRGB(55, 55, 55)}
    )
    
    local unhoverTween = tweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize, BackgroundColor3 = Color3.fromRGB(45, 45, 45)}
    )
    
    button.MouseEnter:Connect(function()
        hoverTween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        unhoverTween:Play()
    end)
    
    local clickTween = tweenService:Create(
        button,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(35, 35, 35)}
    )
    
    local unclickTween = tweenService:Create(
        button,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = originalSize, BackgroundColor3 = Color3.fromRGB(45, 45, 45)}
    )
    
    button.MouseButton1Click:Connect(function()
        clickTween:Play()
        
        pcall(function()
            virtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            task.wait(0.05)
            virtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end)
        
        button.Text = "✓"
        task.wait(0.1)
        button.Text = "•"
        
        unclickTween:Play()
    end)
    
    button.ZIndex = 999
    shadow.ZIndex = 998
    
    return screenGui
end

-- \\ GET WORLD LIST
local WorldList = getWorldList()
if #WorldList == 0 then
    warn("No worlds found")
end

-- \\ LOAD FLUENT GUI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Auto Open Egg | AFS",
    SubTitle = "By Someone In The World",
    TabWidth = 180,
    Size = UDim2.fromOffset(450, 350),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
    Arti = Window:AddTab({ Title = "Artifacts", Icon = "" }),
    Pass = Window:AddTab({ Title = "Passives", Icon = "" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "" }),
}

local Options = Fluent.Options

-- \\ MAIN GUI SETUP
do
    local onoffbutton = ToogleButtonV()
    
    local statusLabel = Tabs.Main:AddParagraph({
        Title = "Status",
        Content = "Ready"
    })

    local EggsDropdown = Tabs.Main:AddDropdown("EggsDropdown", {
        Title = "Select World",
        Values = WorldList,
        Multi = false,
        Default = "",
    })

    EggsDropdown:OnChanged(function(Value)
        state.eggSelected = Value
    end)

    local autoEggNoTP = Tabs.Main:AddToggle("autoEggNoTP", {
        Title = "Auto Open Egg",
        Default = false
    })
    autoEggNoTP:OnChanged(function(Value)
        state.autoNoTP = Value
        if Value then
            state.autoCurrent = false
            Options.autoEggCurrent:SetValue(false)
        end
    end)
    
    local autoEggCurrent = Tabs.Main:AddToggle("autoEggCurrent", {
        Title = "Auto Open Egg | Current World",
        Default = false
    })
    autoEggCurrent:OnChanged(function(Value)
        state.autoCurrent = Value
        if Value then
            state.autoNoTP = false
            Options.autoEggNoTP:SetValue(false)
        end
    end)

    local speedSlider = Tabs.Settings:AddSlider("Speed", {
        Title = "Loop Wait (seconds)",
        Description = "Adjust loop speed",
        Default = 0.1,
        Min = 0.05,
        Max = 2,
        Rounding = 2
    })
    speedSlider:OnChanged(function(Value)
        CONFIG.LOOP_WAIT = Value
    end)

    -- \\ MAIN LOOP FOR SELECTED WORLD
    local connectionMain = runService.Heartbeat:Connect(function()
        if state.eggSelected and state.eggSelected ~= "" and state.autoNoTP and game:GetService("Players").LocalPlayer.World.Value == state.eggSelected then
            if not state.isProcessing then
                local eggName = state.eggSelected .. "Egg"
                local success = attemptEggOpen(eggName, false)
                
                statusLabel:SetDesc(success and 
                    ("Opening: " .. eggName) or 
                    ("Failed: " .. eggName)
                )
            end
        end
        safeWait(CONFIG.LOOP_WAIT)
    end)

    -- \\ LOOP FOR CURRENT WORLD
    local connectionCurrent = runService.Heartbeat:Connect(function()
        if state.autoCurrent then
            if not state.isProcessing then
                local eggName = game:GetService("Players").LocalPlayer.World.Value .. "Egg"
                local success = attemptEggOpen(eggName, false)
                
                statusLabel:SetDesc(success and 
                    ("Opening: " .. eggName) or 
                    ("Failed: " .. eggName)
                )
            end
        end
        
        safeWait(CONFIG.LOOP_WAIT)
    end)

    -- \\ AUTO PASSIVE LOOP
    local connectionPassive = runService.Heartbeat:Connect(function()
        if state.autopassive then
            local success, message = attemptPassiveRoll()
            if success then
                statusLabel:SetDesc(message or "Rolling passives...")
            else
                statusLabel:SetDesc(message or "Passive roll failed")
            end
        end
        safeWait(CONFIG.LOOP_WAIT * 10) -- Slower for passive rolls (1 second default)
    end)

    -- \\ TELEPORT TO EGG BUTTON
    Tabs.Main:AddButton({
        Title = "TP To Egg",
        Description = "Teleport to selected egg",
        Callback = function()
            if state.eggSelected and state.eggSelected ~= "" then
                local eggName = state.eggSelected .. "Egg"
                local eggObject = workspace.Worlds:FindFirstChild(eggName)
                
                if eggObject then
                    hrp.CFrame = eggObject:GetPivot()
                    statusLabel:SetDesc("Teleported to: " .. eggName)
                else
                    local worldObject = workspace.Worlds:FindFirstChild(state.eggSelected)
                    if worldObject then
                        local eggInWorld = worldObject:FindFirstChild("Egg") or worldObject:FindFirstChild(eggName)
                        if eggInWorld then
                            hrp.CFrame = eggInWorld:GetPivot()
                            statusLabel:SetDesc("Teleported to: " .. eggName)
                        else
                            warn("Egg not found in world: " .. state.eggSelected)
                            statusLabel:SetDesc("Egg not found in world!")
                        end
                    else
                        warn("Egg not found: " .. eggName)
                        statusLabel:SetDesc("Egg not found!")
                    end
                end
            else
                statusLabel:SetDesc("No egg selected!")
            end
        end
    })

    -- \\ STOP ALL BUTTON
    Tabs.Main:AddButton({
        Title = "Stop All",
        Description = "Stop all automation",
        Callback = function()
            state.autoNoTP = false
            state.autoWithTP = false
            state.autoCurrent = false
            state.autopassive = false
            Options.autoEggNoTP:SetValue(false)
            Options.autoEggCurrent:SetValue(false)
            Options.autopassto:SetValue(false)
            statusLabel:SetDesc("Emergency stopped")
        end
    })

    -- \\ CLEANUP ON PLAYER LEAVING
    players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            if connectionMain then connectionMain:Disconnect() end
            if connectionCurrent then connectionCurrent:Disconnect() end
            if connectionPassive then connectionPassive:Disconnect() end
            if onoffbutton then onoffbutton:Destroy() end
        end
    end)

    -- \\ UPDATE CHARACTER REFERENCE
    player.CharacterAdded:Connect(function(newChar)
        char = newChar
        hrp = char:WaitForChild("HumanoidRootPart")
    end)
end

-- \\ ARTIFACTS TAB
local arti = {"Drops", "Luck", "Time", "Dungeon", "Dreams"}

local ArtiDropdown = Tabs.Arti:AddDropdown("ArtiDropdown", {
    Title = "Choose An Artifact To Equip | Slot 2",
    Values = arti,
    Multi = false,
    Default = "",
})

ArtiDropdown:OnChanged(function(Value)
    state.artiSelected = Value
end)

Tabs.Arti:AddButton({
    Title = "Equip",
    Description = "Equip selected artifact",
    Callback = function()
        if state.artiSelected then
            EquipArtifact(state.artiSelected)
        else
            warn("No artifact selected!")
        end
    end
})

-- \\ PASSIVES TAB
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Get pet data safely
local petstable = {}
local petDisplayNames = {}

pcall(function()
    local PickPassives = require(ReplicatedStorage.ModuleScripts.PickPassive)
    local PetData = require(ReplicatedStorage.ModuleScripts.LocalDairebStore)
        .GetStoreProxy("GameData")
        :GetData("Pets")

    for petName, petInfo in pairs(PetData) do
        if type(petInfo) == "table" and petInfo.PetId then
            local passives = petInfo.Passives
            
            local hasPassives = false
            if type(passives) == "table" then
                for _, v in ipairs(passives) do
                    if v ~= "" then
                        hasPassives = true
                        break
                    end
                end
            elseif passives ~= nil and passives ~= "" then
                hasPassives = true
            end

            local petEntry = {
                PetId = petInfo.PetId,
                Name = petName,
                Level = petInfo.Level or 1,
                Passives = hasPassives and passives or nil
            }
            
            table.insert(petstable, petEntry)
            table.insert(petDisplayNames, petName .. " (ID: " .. petInfo.PetId .. ")")
        end
    end
end)

local petsdropdown = Tabs.Pass:AddDropdown("petsdropdown", {
    Title = "Select Pet",
    Values = petDisplayNames,
    Multi = false,
    Default = "",
})

petsdropdown:OnChanged(function(Value)
    -- Find the corresponding pet data
    for i, displayName in ipairs(petDisplayNames) do
        if displayName == Value then
            state.PetSelected = petstable[i]
            break
        end
    end
end)

-- Get passive list safely
local passiveff = {}
local passiveNames = {}

pcall(function()
    local PickPassives = require(ReplicatedStorage.ModuleScripts.PickPassive)
    
    for key, value in pairs(PickPassives) do
        local keyStr = tostring(key)
        if not string.find(keyStr, "Requiem") then
            table.insert(passiveff, {
                Key = keyStr,
                Value = value
            })
            table.insert(passiveNames, keyStr)
        end
    end
end)

local passdrop = Tabs.Pass:AddDropdown("passdrop", {
    Title = "Select Passives",
    Values = passiveNames,
    Multi = true,
    Default = {},
})

passdrop:OnChanged(function(Value)
    state.selectedPassives = Value
end)

local pssone = Tabs.Pass:AddToggle("pssone", {
    Title = "Passive Slot 1",
    Default = false
})
pssone:OnChanged(function(Value)
    state.passiveone = Value
end)

local psstwo = Tabs.Pass:AddToggle("psstwo", {
    Title = "Passive Slot 2",
    Default = false
})
psstwo:OnChanged(function(Value)
    state.passivetwo = Value
end)

local autopassto = Tabs.Pass:AddToggle("autopassto", {
    Title = "Auto Passive",
    Default = false
})
autopassto:OnChanged(function(Value)
    state.autopassive = Value
end)

-- Manual passive roll button
Tabs.Pass:AddButton({
    Title = "Roll Passives Once",
    Description = "Manually roll selected passives",
    Callback = function()
        if state.PetSelected and state.selectedPassives and #state.selectedPassives > 0 then
            local success, message = attemptPassiveRoll()
            if success then
                print("Passive Roll Result: " .. (message or "Completed"))
            end
        else
            warn("No pet or passives selected!")
        end
    end
})

-- Check current passives button
Tabs.Pass:AddButton({
    Title = "Check Current Passives",
    Description = "View pet's current passives",
    Callback = function()
        if state.PetSelected then
            local updatedData = getUpdatedPetData(state.PetSelected.PetId)
            if updatedData and updatedData.Passives then
                local passiveInfo = "Pet Passives:\n"
                if type(updatedData.Passives) == "table" then
                    passiveInfo = passiveInfo .. "Slot 1: " .. (updatedData.Passives[1] or "Empty") .. "\n"
                    passiveInfo = passiveInfo .. "Slot 2: " .. (updatedData.Passives[2] or "Empty")
                else
                    passiveInfo = passiveInfo .. "Single Passive: " .. tostring(updatedData.Passives)
                end
                print(passiveInfo)
                
                Fluent:Notify({
                    Title = "Current Passives",
                    Content = passiveInfo,
                    Duration = 5
                })
            else
                warn("No passives found for this pet!")
            end
        else
            warn("No pet selected!")
        end
    end
})

-- \\ ANTI AFK
local vu = game:GetService("VirtualUser")
local plr = game.Players.LocalPlayer
plr.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

Fluent:Notify({
    Title = "Script Loaded Successfully!",
    Content = "All features ready to use.",
    Duration = 3
})