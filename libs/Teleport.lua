--[[
    Teleport Library - Các chức năng dịch chuyển nhanh trong Roblox
    Hỗ trợ: ToPosition, ToPlayer, ToPlace, GetPlayers, NearestPlayer, GetPlayerByName,
            ToPlayerByName, GetPlayersInRange, ClickTeleport, Keybind

    Cách sử dụng:
        local Teleport = require(https://raw.githubusercontent.com/WiniFyCode/Roblox/refs/heads/main/libs/Teleport.lua)

        -- Dịch chuyển đến vị trí cụ thể
        Teleport.ToPosition(Vector3.new(100, 50, 200))

        -- Dịch chuyển đến người chơi (theo tên hoặc UserId)
        Teleport.ToPlayer("PlayerName")
        Teleport.ToPlayer(12345678)  -- Player.UserId

        -- Dịch chuyển đến PlaceId khác
        Teleport.ToPlace(12345678)

        -- Tìm player gần nhất
        local player, distance = Teleport.GetNearestPlayer()

        -- Tìm player theo tên (partial match)
        local target = Teleport.GetPlayerByName("VIP")
        Teleport.ToPlayer(target)

        -- Lấy danh sách người chơi trong bán kính
        local nearby = Teleport.GetPlayersInRange(20)

        -- Click Teleport - click đất để dịch chuyển
        Teleport.SetClickTeleport(true, Enum.KeyCode.Q)  -- Bật với phím Q
        Teleport.SetClickTeleport(false)                 -- Tắt

        -- Click Teleport không cần phím (luôn bật khi click)
        Teleport.SetClickTeleport(true)
        Teleport.SetClickTeleport(false)
--]]

local Teleport = {}

-- Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- State variables cho Click Teleport
local clickTeleportEnabled = false
local clickKeybind = nil -- nil = luôn bật, Enum.KeyCode.X = bật với phím X
local clickConn = nil
local clickInputConn = nil

-- GetCharacter - Lấy nhân vật local player
local function getLocalCharacter()
    return LocalPlayer.Character or workspace:FindFirstChild(LocalPlayer.Name)
end

local function getRootPart(character)
    if character then
        return character:FindFirstChild("HumanoidRootPart") or
            character:FindFirstChild("Torso") or
            character:FindFirstChild("UpperTorso")
    end
    return nil
end

-- ToPosition - Dịch chuyển đến vị trí 3D
-- @param position: Vector3 - vị trí đến
-- @param offsetY: (optional) offset Y để tránh rơi xuống
function Teleport.ToPosition(position, offsetY)
    if not position or typeof(position) ~= "Vector3" then
        warn("Vị trí không hợp lệ")
        return false
    end

    local character = getLocalCharacter()
    if not character then return false end

    local rootPart = getRootPart(character)
    if not rootPart then return false end

    rootPart.CFrame = CFrame.new(position.X, position.Y + (offsetY or 5), position.Z)
    return true
end

-- ToPlayer - Dịch chuyển đến vị trí của người chơi
-- @param player: string(playerName) hoặc number(userId)
function Teleport.ToPlayer(player)
    if not player then return false end

    local targetPlayer = nil

    -- Tìm player theo tên hoặc ID
    if typeof(player) == "string" then
        targetPlayer = Players:FindFirstChild(player) or Players:WaitForChild(player, 1)
    elseif typeof(player) == "number" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == player then
                targetPlayer = p
                break
            end
        end
    elseif player:IsA("Player") then
        targetPlayer = player
    end

    if not targetPlayer then
        warn("Không tìm thấy player:", player)
        return false
    end

    -- Lấy vị trí của player đích
    local targetChar = targetPlayer.Character or workspace:FindFirstChild(targetPlayer.Name)
    if not targetChar then
        warn("Player chưa có character")
        return false
    end

    local targetRoot = getRootPart(targetChar)
    if not targetRoot then return false end

    -- Dịch chuyển đến gần player đích
    local targetPos = targetRoot.Position
    local character = getLocalCharacter()
    if not character then return false end

    local rootPart = getRootPart(character)
    if not rootPart then return false end

    -- Dịch chuyển lên trên player đích 3 stud
    rootPart.CFrame = CFrame.new(targetPos) * CFrame.new(0, 3, 0)
    return true
end

-- ToPlace - Dịch chuyển đến PlaceId khác
-- @param placeId: number - ID của game muốn chuyển đến
function Teleport.ToPlace(placeId)
    if not placeId then
        warn("PlaceId không hợp lệ")
        return false
    end

    local success = pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)

    return success
end

-- GetPlayers - Lấy danh sách tất cả người chơi trừ mình
-- @return table - danh sách player objects
function Teleport.GetPlayers()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player)
        end
    end
    return players
end

-- GetNearestPlayer - Tìm người chơi gần nhất
-- @return Player hoặc nil nếu không có ai
function Teleport.GetNearestPlayer()
    local character = getLocalCharacter()
    if not character then return nil end

    local rootPart = getRootPart(character)
    if not rootPart then return nil end

    local nearestPlayer = nil
    local nearestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetChar = player.Character or workspace:FindFirstChild(player.Name)
            if targetChar then
                local targetRoot = getRootPart(targetChar)
                if targetRoot then
                    local distance = (targetRoot.Position - rootPart.Position).magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    end

    return nearestPlayer, nearestDistance
end

-- ToNearest - Dịch chuyển đến người chơi gần nhất
function Teleport.ToNearest()
    local player, distance = Teleport.GetNearestPlayer()
    if player then
        return Teleport.ToPlayer(player)
    end
    return false
end

-- GetPlayerByName - Tìm player theo tên (partial match)
-- @param name: string - tên hoặc một phần tên
-- @return Player hoặc nil
function Teleport.GetPlayerByName(name)
    if not name then return nil end

    name = string.lower(name)

    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.Name):find(name) or
            (player.DisplayName and string.lower(player.DisplayName):find(name)) then
            return player
        end
    end

    return nil
end

-- ToPositionByName - Dịch chuyển đến vị trí một người chơi bằng tên
-- @param name: string - tên hoặc một phần tên của player
function Teleport.ToPlayerByName(name)
    local player = Teleport.GetPlayerByName(name)
    if player then
        return Teleport.ToPlayer(player)
    end
    return false
end

-- GetPlayersInRange - Lấy danh sách người chơi trong phạm vi
-- @param range: number - phạm vi tính bằng stud
-- @return table - danh sách {player, distance}
function Teleport.GetPlayersInRange(range)
    range = range or 50
    local character = getLocalCharacter()
    if not character then return {} end

    local rootPart = getRootPart(character)
    if not rootPart then return {} end

    local inRange = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetChar = player.Character or workspace:FindFirstChild(player.Name)
            if targetChar then
                local targetRoot = getRootPart(targetChar)
                if targetRoot then
                    local distance = (targetRoot.Position - rootPart.Position).magnitude
                    if distance <= range then
                        table.insert(inRange, {
                            Player = player,
                            Distance = distance
                        })
                    end
                end
            end
        end
    end

    return inRange
end

-- SetClickTeleport - Bật/tắt click to teleport
-- @param enable: boolean
-- @param keybind: Enum.KeyCode (tùy chọn) - phím để kích hoạt click teleport
--    Nếu để trống: luôn hoạt động khi click
function Teleport.SetClickTeleport(enable, keybind)
    clickTeleportEnabled = enable
    clickKeybind = keybind

    -- Ngắt kết nối cũ
    if clickConn then
        clickConn:Disconnect()
        clickConn = nil
    end
    if clickInputConn then
        clickInputConn:Disconnect()
        clickInputConn = nil
    end

    if not enable then return end

    -- Kết nối mouse click
    local mouse = LocalPlayer:GetMouse()

    clickConn = mouse.Button1Down:Connect(function()
        if not clickTeleportEnabled then return end

        -- Nếu có keybind, kiểm tra đang giữ phím không
        if clickKeybind and not UserInputService:IsKeyDown(clickKeybind) then
            return
        end

        local targetPos = mouse.Hit
        if targetPos then
            Teleport.ToPosition(targetPos.p)
        end
    end)

    -- Nếu có keybind, setup input listener
    if clickKeybind then
        clickInputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == clickKeybind then
                -- Key đang được giữ - click sẽ teleport
            end
        end)
    end
end

function Teleport.IsClickTeleportEnabled()
    return clickTeleportEnabled
end

return Teleport
