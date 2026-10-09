--[[
    Misc Library - Các chức năng phụ trợ cho Roblox
    Hỗ trợ: SpeedHack, JumpPower, Fly, Noclip, InfJump, NoClipCam, CamDistance,
            TimeManager, SpeedMultiplier, NoFog, InstantPrompts, AntiAFK, FPSUnlocker, NameTags,
            Freecam, Spectator

    Cách sử dụng:
        local Misc = require(https://raw.githubusercontent.com/WiniFyCode/Roblox/refs/heads/main/libs/Misc.lua)

        -- Speed hack
        Misc:SetSpeed(true, 50)  -- Tốc độ 50 (mặc định 16)
        Misc:SetSpeed(false)

        -- Speed Multiplier
        Misc:SetSpeedMultiplier(true, 3)
        Misc:SetSpeedMultiplier(false)

        -- Jump power
        Misc:SetJumpPower(true, 100)
        Misc:SetJumpPower(false)

        -- Jump Power Multiplier
        Misc:SetJumpPowerMultiplier(true, 5)
        Misc:SetJumpPowerMultiplier(false)

        -- Fly
        Misc:SetFly(true, 50)
        Misc:SetFly(false)

        -- Noclip
        Misc:SetNoclip(true)
        Misc:SetNoclip(false)

        -- NoClip Camera
        Misc:SetNoClipCam(true)
        Misc:SetNoClipCam(false)

        -- Camera Distance
        Misc:SetCamDistance(true, 50)
        Misc:SetCamDistance(false)

        -- Infinite Jump
        Misc:SetInfJump(true)
        Misc:SetInfJump(false)

        -- Time Manager
        Misc:SetTimeManager(true, 12)
        Misc:SetTimeManager(false)

        -- No Fog
        Misc:SetNoFog(true)
        Misc:SetNoFog(false)

        -- Instant Proximity Prompts
        Misc:SetInstantPrompts(true)
        Misc:SetInstantPrompts(false)

        -- Anti AFK
        Misc:SetAntiAFK(true)
        Misc:SetAntiAFK(false)

        -- FPS Unlocker
        Misc:SetFPSUnlocker(true)
        Misc:SetFPSUnlocker(false)

        -- Name Tags
        Misc:SetNameTags(true, "[VIP] ", Color3.fromRGB(255, 215, 0))
        Misc:SetNameTags(false)

        -- Freecam (camera tự do, chuột phải để nhập vào player/model)
        Misc:SetFreecam(true, 50)   -- Bật freecam, tốc độ 50
        Misc:SetFreecam(false)       -- Tắt freecam

        -- Spectator (theo dõi camera player khác)
        Misc:SetSpectator(true, targetPlayer)  -- Spectate player
        Misc:SpectateNext()                    -- Chuyển sang player tiếp theo
        Misc:SpectatePrev()                    -- Chuyển sang player trước đó
        Misc:SetSpectator(false)               -- Tắt spectate
--]]

local Misc = {}
Misc.__index = Misc

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer

-- State variables
local speedEnabled = false
local speedValue = 50
local speedMultiplierEnabled = false
local speedMultiplierValue = 1.0

local jumpPowerEnabled = false
local jumpPowerValue = 100
local jumpPowerMultiplierEnabled = false
local jumpPowerMultiplierValue = 1.0

local flyEnabled = false
local flySpeed = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyRenderConn = nil
local flyCharConn = nil

local noclipEnabled = false
local noclipConn = nil

local noClipCamEnabled = false
local noClipCamConn = nil
local camDistanceConn = nil
local camDistanceEnabled = false
local camDistanceValue = 0.5

-- Trạng thái Quản lý thời gian (Time Manager)
local timeManagerEnabled = false
local timeManagerHour = 12
local originalClockTime = nil
local lightingConn = nil
local lightingChangeConn = nil
local isApplyingTime = false

-- Trạng thái Xóa sương mù (No Fog)
local noFogEnabled = false
local fogConn = nil
local fogDescendantConn = nil
local originalLightingFog = nil
local originalAtmospheres = {}
local originalDoFs = {}

-- Trạng thái Sáng toàn cảnh (Fullbright)
local fullbrightEnabled = false
local fullbrightConn = nil
local fullbrightLight = nil
local originalLightingSettings = nil

local instantPromptsEnabled = false

local antiAFKEnabled = false
local antiAFKConn = nil
local antiAFKTick = 0

local fpsUnlockerEnabled = false
local fpsUnlockerConn = nil

local nameTagsEnabled = false
local nameTagsPrefix = ""
local nameTagsColor = Color3.new(1, 1, 1)

local infJumpEnabled = false
local infJumpConn = nil

-- Freecam state
local freecamEnabled = false
local freecamSpeed = 50
local freecamConn = nil
local freecamRightClickConn = nil
local freecamYaw = 0
local freecamPitch = 0
local freecamPosition = nil  -- Vector3 vị trí camera tự do
local freecamPossessed = nil -- Model đang được possess (chuột phải)
local freecamOriginalCameraType = nil
local freecamOriginalCameraSubject = nil
local freecamOriginalAnchored = false

-- Spectator state
local spectatorEnabled = false
local spectatorTarget = nil -- Player đang spectate
local spectatorConn = nil   -- Kết nối CharacterAdded
local spectatorOriginalCameraType = nil
local spectatorOriginalCameraSubject = nil

-- Lấy nhân vật local
local function getCharacter()
    return LocalPlayer.Character or workspace:FindFirstChild(LocalPlayer.Name)
end

local function getHumanoid()
    local char = getCharacter()
    if char then
        return char:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function normalizeCall(first, ...)
    if first == Misc then
        return ...
    end
    return first, ...
end

-- SpeedHack - Tăng tốc độ di chuyển
function Misc.SetSpeed(enable, speed)
    enable, speed = normalizeCall(enable, speed)
    speedEnabled = enable
    if enable then
        speedValue = speed or 50
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = speedValue
        end
        -- Theo dõi nhân vật thay đổi
        local function onCharacterAdded()
            local hum = getHumanoid()
            if hum then
                hum.WalkSpeed = speedValue
            end
        end
        LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    else
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = 16 -- Giá trị mặc định
        end
    end
end

function Misc.IsSpeedEnabled()
    return speedEnabled
end

-- Speed Multiplier - Nhân hệ số WalkSpeed (mặc định 16)
function Misc.SetSpeedMultiplier(enable, multiplier)
    enable, multiplier = normalizeCall(enable, multiplier)
    speedMultiplierEnabled = enable
    if enable then
        speedMultiplierValue = multiplier or 3
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = 16 * speedMultiplierValue
        end
        local function onCharacterAdded()
            local hum = getHumanoid()
            if hum then
                hum.WalkSpeed = 16 * speedMultiplierValue
            end
        end
        LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    else
        local humanoid = getHumanoid()
        if humanoid and not speedEnabled then
            humanoid.WalkSpeed = 16
        elseif humanoid and speedEnabled then
            humanoid.WalkSpeed = speedValue
        end
    end
end

function Misc.IsSpeedMultiplierEnabled()
    return speedMultiplierEnabled
end

-- JumpPower - Tăng sức nhảy
function Misc.SetJumpPower(enable, power)
    enable, power = normalizeCall(enable, power)
    jumpPowerEnabled = enable
    if enable then
        jumpPowerValue = power or 100
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.JumpPower = jumpPowerValue
        end
        local function onCharacterAdded()
            local hum = getHumanoid()
            if hum then
                hum.JumpPower = jumpPowerValue
            end
        end
        LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    else
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.JumpPower = 50 -- Giá trị mặc định
        end
    end
end

function Misc.IsJumpPowerEnabled()
    return jumpPowerEnabled
end

-- Jump Power Multiplier - Nhân hệ số JumpPower (mặc định 50)
function Misc.SetJumpPowerMultiplier(enable, multiplier)
    enable, multiplier = normalizeCall(enable, multiplier)
    jumpPowerMultiplierEnabled = enable
    if enable then
        jumpPowerMultiplierValue = multiplier or 5
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.JumpPower = 50 * jumpPowerMultiplierValue
        end
        local function onCharacterAdded()
            local hum = getHumanoid()
            if hum then
                hum.JumpPower = 50 * jumpPowerMultiplierValue
            end
        end
        LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    else
        local humanoid = getHumanoid()
        if humanoid and not jumpPowerEnabled then
            humanoid.JumpPower = 50
        elseif humanoid and jumpPowerEnabled then
            humanoid.JumpPower = jumpPowerValue
        end
    end
end

function Misc.IsJumpPowerMultiplierEnabled()
    return jumpPowerMultiplierEnabled
end

-- Dọn dẹp đối tượng vật lý của Fly
local function cleanupFlyPhysics()
    if flyBodyVelocity then
        pcall(function() flyBodyVelocity:Destroy() end)
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        pcall(function() flyBodyGyro:Destroy() end)
        flyBodyGyro = nil
    end
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.PlatformStand = false
    end
end

-- Khởi tạo đối tượng BodyVelocity và BodyGyro cho nhân vật
local function setupFlyPhysics()
    cleanupFlyPhysics()

    local char = getCharacter()
    if not char then return end

    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return end

    -- Khóa trạng thái hoạt ảnh đi bộ/ngã để bay mượt mà
    humanoid.PlatformStand = true

    -- Tạo BodyVelocity cung cấp lực đẩy
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Name = "FlyVelocity"
    flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = rootPart

    -- Tạo BodyGyro giữ thăng bằng và xoay theo hướng Camera
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.Name = "FlyGyro"
    flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyGyro.P = 9e4
    flyBodyGyro.CFrame = rootPart.CFrame
    flyBodyGyro.Parent = rootPart
end

-- Fly - Cho phép bay tự do theo hướng nhìn của Camera
function Misc.SetFly(enable, speed)
    enable, speed = normalizeCall(enable, speed)
    if speed then
        flySpeed = speed
    end

    if enable then
        if flyEnabled then
            -- Nếu đang bay thì chỉ cập nhật tốc độ, không reset lại physics
            return
        end
        flyEnabled = true

        setupFlyPhysics()

        -- Tự động kích hoạt lại khi nhân vật hồi sinh
        if flyCharConn then flyCharConn:Disconnect() end
        flyCharConn = LocalPlayer.CharacterAdded:Connect(function()
            if not flyEnabled then return end
            task.wait(0.5)
            setupFlyPhysics()
        end)

        -- Vòng lặp cập nhật chuyển động mỗi frame
        if flyRenderConn then flyRenderConn:Disconnect() end
        flyRenderConn = RunService.RenderStepped:Connect(function()
            if not flyEnabled then
                if flyRenderConn then
                    flyRenderConn:Disconnect()
                    flyRenderConn = nil
                end
                cleanupFlyPhysics()
                return
            end

            local char = getCharacter()
            if not char or not char.Parent then return end

            local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not rootPart or not humanoid then return end

            -- Kiểm tra nếu vật thể bay bị mất thì tạo lại
            if not flyBodyVelocity or not flyBodyVelocity.Parent or not flyBodyGyro or not flyBodyGyro.Parent then
                setupFlyPhysics()
                return
            end

            humanoid.PlatformStand = true

            local cam = workspace.CurrentCamera
            if not cam then return end

            -- Cố định góc xoay nhân vật theo Camera
            flyBodyGyro.CFrame = cam.CFrame

            local moveVector = Vector3.new(0, 0, 0)

            -- Điều khiển PC: WASD bay chuẩn theo hướng Camera
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveVector = moveVector + cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveVector = moveVector - cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveVector = moveVector - cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveVector = moveVector + cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveVector = moveVector - Vector3.new(0, 1, 0)
            end

            -- Hỗ trợ cần gạt điều khiển trên thiết bị Mobile
            if moveVector.Magnitude == 0 and humanoid.MoveDirection.Magnitude > 0 then
                local md = humanoid.MoveDirection
                moveVector = (cam.CFrame.RightVector * md.X + cam.CFrame.LookVector * (-md.Z))
            end

            -- Áp dụng vận tốc di chuyển
            if moveVector.Magnitude > 0 then
                flyBodyVelocity.Velocity = moveVector.Unit * flySpeed
            else
                -- Đứng yên lơ lửng tại chỗ khi không nhấn phím
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    else
        -- Tắt bay
        flyEnabled = false
        if flyRenderConn then
            flyRenderConn:Disconnect()
            flyRenderConn = nil
        end
        if flyCharConn then
            flyCharConn:Disconnect()
            flyCharConn = nil
        end
        cleanupFlyPhysics()
    end
end

function Misc.IsFlyEnabled()
    return flyEnabled
end

-- Noclip - Xuyên qua vật cản
function Misc.SetNoclip(enable)
    enable = normalizeCall(enable)
    noclipEnabled = enable

    if enable then
        if noclipConn then
            noclipConn:Disconnect()
        end

        noclipConn = RunService.RenderStepped:Connect(function()
            if not noclipEnabled then
                if noclipConn then
                    noclipConn:Disconnect()
                    noclipConn = nil
                end
                return
            end

            local char = getCharacter()
            if not char then return end

            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
    end
end

function Misc.IsNoclipEnabled()
    return noclipEnabled
end

-- Infinite Jump - Nhảy không giới hạn
function Misc.SetInfJump(enable)
    enable = normalizeCall(enable)
    infJumpEnabled = enable

    if enable then
        if infJumpConn then
            infJumpConn:Disconnect()
            infJumpConn = nil
        end

        -- Lắng nghe sự kiện JumpRequest chuẩn (nhảy vô hạn trên không, hỗ trợ Spacebar PC, nút bấm Mobile và Gamepad)
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            if not infJumpEnabled then return end
            local humanoid = getHumanoid()
            if humanoid and humanoid.Health > 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        infJumpEnabled = false
        if infJumpConn then
            infJumpConn:Disconnect()
            infJumpConn = nil
        end
    end
end

function Misc.IsInfJumpEnabled()
    return infJumpEnabled
end

-- NoClip Camera - Xuyên vật thể camera (cam)
function Misc.SetNoClipCam(enable)
    enable = normalizeCall(enable)
    noClipCamEnabled = enable

    if enable then
        local success, err = pcall(function()
            workspace.Camera:ClearAllFilters()
            workspace.Camera.FieldOfView = 90 -- FOV mở rộng

            -- Tắt collision cho camera
            workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame
        end)

        -- Sử dụng Transparent để camera xuyên qua vật thể
        if noClipCamConn then
            noClipCamConn:Disconnect()
        end

        noClipCamConn = RunService.RenderStepped:Connect(function()
            if not noClipCamEnabled then
                if noClipCamConn then
                    noClipCamConn:Disconnect()
                    noClipCamConn = nil
                end
                return
            end

            -- Tạo camera mới mỗi frame để tránh collision
            local cam = workspace.CurrentCamera
            if cam then
                local camCF = cam.CFrame
                -- Di chuyển camera một chút để reset physics
                cam.CFrame = camCF * CFrame.new(0, 0, 0)
            end
        end)
    else
        if noClipCamConn then
            noClipCamConn:Disconnect()
            noClipCamConn = nil
        end
    end
end

function Misc.IsNoClipCamEnabled()
    return noClipCamEnabled
end

-- Camera Distance - Điều chỉnh khoảng cách camera
function Misc.SetCamDistance(enable, distance)
    enable, distance = normalizeCall(enable, distance)
    camDistanceEnabled = enable
    camDistanceValue = distance or 0.5

    if enable then
        if camDistanceConn then
            camDistanceConn:Disconnect()
        end

        camDistanceConn = RunService.RenderStepped:Connect(function()
            if not camDistanceEnabled then
                if camDistanceConn then
                    camDistanceConn:Disconnect()
                    camDistanceConn = nil
                end
                -- Reset camera về giá trị mặc định
                workspace.CurrentCamera.FieldOfView = 70
                workspace.CurrentCamera = workspace.CurrentCamera
                return
            end

            local cam = workspace.CurrentCamera
            if cam then
                cam.FieldOfView = camDistanceValue
            end
        end)
    else
        -- Reset về giá trị mặc định
        workspace.CurrentCamera.FieldOfView = 70
        if camDistanceConn then
            camDistanceConn:Disconnect()
            camDistanceConn = nil
        end
    end
end

function Misc.IsCamDistanceEnabled()
    return camDistanceEnabled
end

-- Time Manager - Điều chỉnh và cố định thời gian trong ngày
function Misc.SetTimeManager(enable, hour)
    enable, hour = normalizeCall(enable, hour)
    local Lighting = game:GetService("Lighting")

    if enable then
        if hour ~= nil then
            timeManagerHour = hour
        end

        -- Lưu lại ClockTime ban đầu nếu bật lần đầu
        if not timeManagerEnabled then
            originalClockTime = Lighting.ClockTime
            timeManagerEnabled = true
        end

        -- Hàm áp dụng thời gian
        local function applyTime()
            if not timeManagerEnabled or isApplyingTime then return end
            isApplyingTime = true
            pcall(function()
                Lighting.ClockTime = timeManagerHour
            end)
            isApplyingTime = false
        end

        applyTime()

        -- Lắng nghe sự kiện thay đổi thuộc tính ClockTime từ các script ngày/đêm của game
        if not lightingChangeConn then
            lightingChangeConn = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
                if timeManagerEnabled and not isApplyingTime then
                    if math.abs(Lighting.ClockTime - timeManagerHour) > 0.001 then
                        applyTime()
                    end
                end
            end)
        end

        -- Duy trì trong RenderStepped để đảm bảo mượt mà và không giật lag
        if not lightingConn then
            lightingConn = RunService.RenderStepped:Connect(function()
                if not timeManagerEnabled then
                    if lightingConn then
                        lightingConn:Disconnect()
                        lightingConn = nil
                    end
                    return
                end
                if math.abs(Lighting.ClockTime - timeManagerHour) > 0.001 then
                    applyTime()
                end
            end)
        end
    else
        timeManagerEnabled = false

        if lightingConn then
            lightingConn:Disconnect()
            lightingConn = nil
        end

        if lightingChangeConn then
            lightingChangeConn:Disconnect()
            lightingChangeConn = nil
        end

        -- Khôi phục lại thời gian gốc của game
        if originalClockTime ~= nil then
            pcall(function()
                Lighting.ClockTime = originalClockTime
            end)
            originalClockTime = nil
        end
    end
end

function Misc.IsTimeManagerEnabled()
    return timeManagerEnabled
end

-- Helper áp dụng tắt sương mù cho 1 Atmosphere
local function applyAtmosphereClear(atm)
    if not atm or not atm:IsA("Atmosphere") then return end
    if not originalAtmospheres[atm] then
        originalAtmospheres[atm] = {
            Density = atm.Density,
            Offset = atm.Offset,
            Haze = atm.Haze,
            Glare = atm.Glare
        }
    end
    pcall(function()
        atm.Density = 0
        atm.Offset = 0
        atm.Haze = 0
        atm.Glare = 0
    end)
end

-- Helper áp dụng tắt mờ xa cho 1 DepthOfFieldEffect
local function applyDoFClear(dof)
    if not dof or not dof:IsA("DepthOfFieldEffect") then return end
    if not originalDoFs[dof] then
        originalDoFs[dof] = {
            Enabled = dof.Enabled
        }
    end
    pcall(function()
        dof.Enabled = false
    end)
end

-- No Fog - Tắt sương mù hiện đại (Atmosphere, DepthOfField) và legacy (Lighting Fog)
function Misc.SetNoFog(enable, distance)
    enable, distance = normalizeCall(enable, distance)
    local Lighting = game:GetService("Lighting")

    if enable then
        noFogEnabled = true

        -- Lưu lại thông số legacy fog ban đầu
        if not originalLightingFog then
            originalLightingFog = {
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
                FogColor = Lighting.FogColor
            }
        end

        -- Hàm áp dụng cài đặt xóa sương mù
        local function applyNoFogSettings()
            -- 1. Legacy Fog
            pcall(function()
                if distance then
                    Lighting.FogEnd = distance
                    Lighting.FogStart = distance * 0.8
                else
                    Lighting.FogStart = 0
                    Lighting.FogEnd = 1e9
                end
            end)

            -- 2. Quét và tắt sương mù Atmosphere & làm mờ DepthOfField trong Lighting và Workspace
            local searchContainers = { Lighting, workspace }
            for _, container in ipairs(searchContainers) do
                if container then
                    for _, desc in ipairs(container:GetDescendants()) do
                        if desc:IsA("Atmosphere") then
                            applyAtmosphereClear(desc)
                        elseif desc:IsA("DepthOfFieldEffect") then
                            applyDoFClear(desc)
                        end
                    end
                end
            end
        end

        applyNoFogSettings()

        -- Lắng nghe khi game tạo mới Atmosphere hoặc DepthOfField (ví dụ khi đổi map/khu vực)
        if not fogDescendantConn then
            fogDescendantConn = Lighting.DescendantAdded:Connect(function(desc)
                if not noFogEnabled then return end
                if desc:IsA("Atmosphere") then
                    applyAtmosphereClear(desc)
                elseif desc:IsA("DepthOfFieldEffect") then
                    applyDoFClear(desc)
                end
            end)
        end

        -- Vòng lặp duy trì liên tục để ngăn chặn game ghi đè lại thuộc tính
        if not fogConn then
            fogConn = RunService.RenderStepped:Connect(function()
                if not noFogEnabled then
                    if fogConn then
                        fogConn:Disconnect()
                        fogConn = nil
                    end
                    return
                end

                -- Kiểm tra và đè lại Legacy Fog nếu bị game thay đổi
                if distance then
                    if Lighting.FogEnd ~= distance then
                        Lighting.FogEnd = distance
                        Lighting.FogStart = distance * 0.8
                    end
                else
                    if Lighting.FogEnd < 1e8 then
                        Lighting.FogStart = 0
                        Lighting.FogEnd = 1e9
                    end
                end

                -- Kiểm tra và đè lại Atmosphere
                for atm, _ in pairs(originalAtmospheres) do
                    if atm and atm.Parent and atm.Density > 0 then
                        pcall(function()
                            atm.Density = 0
                            atm.Haze = 0
                        end)
                    end
                end

                -- Kiểm tra và tắt DoF nếu bị game bật lại
                for dof, _ in pairs(originalDoFs) do
                    if dof and dof.Parent and dof.Enabled then
                        pcall(function()
                            dof.Enabled = false
                        end)
                    end
                end
            end)
        end
    else
        noFogEnabled = false

        -- Ngắt kết nối các sự kiện
        if fogConn then
            fogConn:Disconnect()
            fogConn = nil
        end

        if fogDescendantConn then
            fogDescendantConn:Disconnect()
            fogDescendantConn = nil
        end

        -- Khôi phục Legacy Fog ban đầu
        if originalLightingFog then
            pcall(function()
                Lighting.FogEnd = originalLightingFog.FogEnd
                Lighting.FogStart = originalLightingFog.FogStart
                Lighting.FogColor = originalLightingFog.FogColor
            end)
            originalLightingFog = nil
        end

        -- Khôi phục Atmosphere ban đầu
        for atm, props in pairs(originalAtmospheres) do
            if atm and atm.Parent then
                pcall(function()
                    atm.Density = props.Density
                    atm.Offset = props.Offset
                    atm.Haze = props.Haze
                    atm.Glare = props.Glare
                end)
            end
        end
        originalAtmospheres = {}

        -- Khôi phục DepthOfField ban đầu
        for dof, props in pairs(originalDoFs) do
            if dof and dof.Parent then
                pcall(function()
                    dof.Enabled = props.Enabled
                end)
            end
        end
        originalDoFs = {}
    end
end

function Misc.IsNoFogEnabled()
    return noFogEnabled
end

-- Helper tạo hoặc lấy đèn PointLight trên Camera
local function getOrCreateFullbrightLight()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    if fullbrightLight and fullbrightLight.Parent == cam then
        return fullbrightLight
    end
    if fullbrightLight then
        pcall(function() fullbrightLight:Destroy() end)
    end
    local light = Instance.new("PointLight")
    light.Name = "FullbrightCameraLight"
    light.Brightness = 1.5
    light.Range = 120
    light.Shadows = false
    light.Color = Color3.fromRGB(255, 255, 255)
    light.Parent = cam
    fullbrightLight = light
    return light
end

-- Fullbright - Làm sáng toàn bộ môi trường và xóa bỏ góc tối
function Misc.SetFullbright(enable)
    enable = normalizeCall(enable)
    local Lighting = game:GetService("Lighting")

    if enable then
        fullbrightEnabled = true

        -- Lưu lại thông số ánh sáng gốc của game
        if not originalLightingSettings then
            originalLightingSettings = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                ExposureCompensation = Lighting.ExposureCompensation
            }
        end

        -- Hàm áp dụng ánh sáng cực đại
        local function applyFullbright()
            pcall(function()
                Lighting.Brightness = 2
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                -- Chỉ chuyển sang ban ngày nếu TimeManager không can thiệp
                if not timeManagerEnabled then
                    Lighting.ClockTime = 14
                end
            end)
            getOrCreateFullbrightLight()
        end

        applyFullbright()

        -- Duy trì trong RenderStepped để chống script của game ghi đè
        if not fullbrightConn then
            fullbrightConn = RunService.RenderStepped:Connect(function()
                if not fullbrightEnabled then
                    if fullbrightConn then
                        fullbrightConn:Disconnect()
                        fullbrightConn = nil
                    end
                    return
                end

                if Lighting.GlobalShadows ~= false or Lighting.Brightness < 1.5 or Lighting.Ambient ~= Color3.fromRGB(255, 255, 255) then
                    applyFullbright()
                end

                -- Đảm bảo đèn gắn trên Camera luôn tồn tại (ví dụ khi Camera reset)
                if not fullbrightLight or fullbrightLight.Parent ~= workspace.CurrentCamera then
                    getOrCreateFullbrightLight()
                end
            end)
        end
    else
        fullbrightEnabled = false

        if fullbrightConn then
            fullbrightConn:Disconnect()
            fullbrightConn = nil
        end

        -- Xóa đèn client trên camera
        if fullbrightLight then
            pcall(function() fullbrightLight:Destroy() end)
            fullbrightLight = nil
        end

        -- Khôi phục lại ánh sáng ban đầu của game
        if originalLightingSettings then
            pcall(function()
                Lighting.Brightness = originalLightingSettings.Brightness
                Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
                Lighting.Ambient = originalLightingSettings.Ambient
                Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient
                Lighting.ExposureCompensation = originalLightingSettings.ExposureCompensation
                if not timeManagerEnabled then
                    Lighting.ClockTime = originalLightingSettings.ClockTime
                end
            end)
            originalLightingSettings = nil
        end
    end
end

function Misc.IsFullbrightEnabled()
    return fullbrightEnabled
end

-- Instant Proximity Prompts - Set HoldDuration = 0 để ấn 1 lần kích hoạt được
function Misc.SetInstantPrompts(enable)
    enable = normalizeCall(enable)
    instantPromptsEnabled = enable

    if enable then
        -- Set HoldDuration = 0 cho tất cả prompts hiện có
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                obj.HoldDuration = 0 -- Ấn 1 lần là kích hoạt
            end
        end
    else
        -- Reset HoldDuration về mặc định (0.3 giây)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                obj.HoldDuration = 0.3 -- Giá trị mặc định Roblox
            end
        end
    end
end

function Misc.IsInstantPromptsEnabled()
    return instantPromptsEnabled
end

-- Anti AFK - Tự động tránh kick AFK
function Misc.SetAntiAFK(enable)
    enable = normalizeCall(enable)
    antiAFKEnabled = enable

    if enable then
        antiAFKTick = tick()

        -- Ngắt kết nối cũ nếu có
        if antiAFKConn then
            antiAFKConn:Disconnect()
        end

        -- Tạo kết nối mới
        antiAFKConn = game:GetService("RunService").Heartbeat:Connect(function()
            if not antiAFKEnabled then
                if antiAFKConn then
                    antiAFKConn:Disconnect()
                    antiAFKConn = nil
                end
                return
            end

            -- Gửi input giả lập mỗi 60 giây để tránh AFK
            local now = tick()
            if now - antiAFKTick >= 60 then
                antiAFKTick = now

                -- Simulate movement để tránh kick
                local player = LocalPlayer
                if player and player.Character then
                    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        -- Di chuyển nhẹ để tránh AFK
                        rootPart.Velocity = Vector3.new(0, 50, 0)
                        wait(0.1)
                        rootPart.Velocity = Vector3.new(0, 0, 0)
                    end
                end
            end
        end)

        -- Hook vào CoreGui để ngăn AFK message
        pcall(function()
            local coreGui = game:GetService("CoreGui")
            local ui = coreGui:FindFirstChild("HealthWarning") or
                coreGui:FindFirstChild("MessagePosted").Parent
            if ui then
                ui.Enabled = false
            end
        end)
    else
        antiAFKEnabled = false
        if antiAFKConn then
            antiAFKConn:Disconnect()
            antiAFKConn = nil
        end
    end
end

function Misc.IsAntiAFKEnabled()
    return antiAFKEnabled
end

-- FPS Unlocker - Tăng FPS lên 60+
function Misc.SetFPSUnlocker(enable)
    enable = normalizeCall(enable)
    fpsUnlockerEnabled = enable

    if enable then
        -- Tắt FPS throttling
        pcall(function()
            local stats = game:GetService("Stats")
            stats:FPSUnlock()
        end)

        -- Set framerate target cao
        if fpsUnlockerConn then
            fpsUnlockerConn:Disconnect()
        end

        fpsUnlockerConn = RunService.RenderStepped:Connect(function()
            if not fpsUnlockerEnabled then
                if fpsUnlockerConn then
                    fpsUnlockerConn:Disconnect()
                    fpsUnlockerConn = nil
                end
                return
            end

            -- Yêu cầu frame cao hơn 60
            pcall(function()
                workspace:SetRealPhysicsFPS(240)
                RunService:Set3dRenderingEnabled(true)
            end)
        end)
    else
        fpsUnlockerEnabled = false
        if fpsUnlockerConn then
            fpsUnlockerConn:Disconnect()
            fpsUnlockerConn = nil
        end

        -- Reset về mặc định
        pcall(function()
            workspace:SetRealPhysicsFPS(60)
        end)
    end
end

function Misc.IsFPSUnlockerEnabled()
    return fpsUnlockerEnabled
end

-- Name Tags - Tùy chỉnh tên người chơi
function Misc.SetNameTags(enable, prefix, color)
    enable, prefix, color = normalizeCall(enable, prefix, color)
    nameTagsEnabled = enable

    if enable then
        nameTagsPrefix = prefix or ""
        nameTagsColor = color or Color3.fromRGB(255, 255, 255)

        -- Cập nhật tên tất cả người chơi
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local function updateName()
                    local character = player.Character or workspace:FindFirstChild(player.Name)
                    if character then
                        local head = character:FindFirstChild("Head")
                        if head then
                            local billboard = head:FindFirstChild("NameTag" .. player.UserId)
                            if billboard then
                                billboard:Destroy()
                            end

                            billboard = Instance.new("BillboardGui")
                            billboard.Name = "NameTag" .. player.UserId
                            billboard.Size = UDim2.new(0, 100, 0, 25)
                            billboard.StudsOffset = Vector3.new(0, 3, 0)
                            billboard.Adornee = head
                            billboard.AlwaysOnTop = true
                            billboard.Parent = head

                            local textLabel = Instance.new("TextLabel")
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.BackgroundTransparency = 1
                            textLabel.Text = nameTagsPrefix .. player.Name
                            textLabel.TextColor3 = nameTagsColor
                            textLabel.TextStrokeTransparency = 0
                            textLabel.Font = Enum.Font.SourceSans
                            textLabel.TextSize = 16
                            textLabel.Parent = billboard
                        end
                    end
                end

                updateName()

                -- Cập nhật khi nhân vật thay đổi
                local charConn
                charConn = player.CharacterAdded:Connect(function()
                    wait(1) -- Chờ nhân vật load
                    updateName()
                end)
            end
        end
    else
        -- Xóa tất cả name tags
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local head = player.Character:FindFirstChild("Head")
                if head then
                    for _, child in ipairs(head:GetChildren()) do
                        if child.Name:match("^NameTag") then
                            child:Destroy()
                        end
                    end
                end
            end
        end
    end
end

function Misc.IsNameTagsEnabled()
    return nameTagsEnabled
end

-- ==================== FREECAM ====================

-- Freecam - Camera tự do di chuyển
-- WASD: di chuyển, Space/Ctrl: lên/xuống, chuột: xoay camera
-- Chuột phải: nhập vào player/model gần tâm camera (possess), nhấn lại để thoát
function Misc.SetFreecam(enable, speed)
    enable, speed = normalizeCall(enable, speed)
    if speed then
        freecamSpeed = speed
    end

    if enable then
        if freecamEnabled then
            -- Nếu đã bật thì chỉ cập nhật tốc độ
            return
        end
        freecamEnabled = true
        local cam = workspace.CurrentCamera

        -- Lưu trạng thái camera gốc để restore khi tắt
        freecamOriginalCameraType = cam.CameraType
        freecamOriginalCameraSubject = cam.CameraSubject

        -- Khởi tạo vị trí và góc xoay từ camera hiện tại
        freecamPosition = cam.CFrame.Position
        local lookVector = cam.CFrame.LookVector
        freecamYaw = math.atan2(-lookVector.X, -lookVector.Z)
        freecamPitch = math.asin(math.clamp(lookVector.Y, -1, 1))
        freecamPossessed = nil

        -- Chặn điều khiển nhân vật để khi ấn WASD/Space chỉ camera di chuyển, nhân vật đứng yên
        pcall(function()
            ContextActionService:BindActionAtPriority(
                "FreecamBlockCharacterMovement",
                function()
                    return Enum.ContextActionResult.Sink
                end,
                false,
                Enum.ContextActionPriority.High.Value + 1000,
                Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
                Enum.KeyCode.Space, Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift
            )
        end)

        -- Cố định (Anchor) nhân vật tại chỗ để không bị trôi hoặc chịu lực vật lý
        local myChar = getCharacter()
        local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
        if myRoot then
            freecamOriginalAnchored = myRoot.Anchored
            myRoot.Anchored = true
        end

        -- Chuyển camera sang chế độ scriptable (tự điều khiển hoàn toàn)
        cam.CameraType = Enum.CameraType.Scriptable

        -- Ngắt kết nối cũ nếu có
        if freecamRightClickConn then freecamRightClickConn:Disconnect() end

        -- Chuột phải: raycast tìm player/model, nếu trúng thì possess
        freecamRightClickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not freecamEnabled then return end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                -- Nếu đang possess, thoát possess → quay lại freecam thường
                if freecamPossessed then
                    freecamPossessed = nil
                    return
                end

                -- Raycast từ tâm camera để tìm entity
                local cam = workspace.CurrentCamera
                local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
                local ray = cam:ViewportPointToRay(screenCenter.X, screenCenter.Y)

                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local myChar = getCharacter()
                rayParams.FilterDescendantsInstances = myChar and { myChar } or {}

                local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
                if result and result.Instance then
                    -- Tìm Model cha chứa part bị trúng
                    local model = result.Instance:FindFirstAncestorOfClass("Model")
                    if model then
                        local humanoid = model:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.Health > 0 then
                            -- Nhập vào entity này (possess)
                            freecamPossessed = model
                        end
                    end
                end
            end
        end)

        -- Ngắt kết nối render cũ nếu có
        if freecamConn then freecamConn:Disconnect() end

        -- Render loop: cập nhật camera mỗi frame
        freecamConn = RunService.RenderStepped:Connect(function(dt)
            if not freecamEnabled then return end
            local cam = workspace.CurrentCamera

            -- Nếu đang possess entity, camera follow phía sau entity (góc nhìn thứ 3)
            if freecamPossessed and freecamPossessed.Parent then
                local rootPart = freecamPossessed:FindFirstChild("HumanoidRootPart")
                    or freecamPossessed:FindFirstChild("Torso")
                    or freecamPossessed:FindFirstChild("UpperTorso")
                if rootPart then
                    -- Vẫn cho phép xoay camera quanh entity bằng chuột
                    local mouseDelta = UserInputService:GetMouseDelta()
                    freecamYaw = freecamYaw - mouseDelta.X * 0.003
                    freecamPitch = math.clamp(freecamPitch - mouseDelta.Y * 0.003, -1.2, 1.2)

                    -- Tính offset phía sau entity dựa trên góc xoay (giống third-person)
                    local rotCF = CFrame.Angles(0, freecamYaw, 0) * CFrame.Angles(freecamPitch, 0, 0)
                    local offset = rotCF:VectorToWorldSpace(Vector3.new(0, 3, 12))

                    -- Camera nhìn về phía entity
                    cam.CFrame = CFrame.new(rootPart.Position + offset, rootPart.Position)
                    freecamPosition = cam.CFrame.Position
                    return
                else
                    -- Entity mất root part, thoát possess
                    freecamPossessed = nil
                end
            end

            -- Xoay camera bằng chuột (khi không possess)
            local mouseDelta = UserInputService:GetMouseDelta()
            freecamYaw = freecamYaw - mouseDelta.X * 0.003
            freecamPitch = math.clamp(freecamPitch - mouseDelta.Y * 0.003, -math.pi / 2 + 0.01, math.pi / 2 - 0.01)

            -- Hướng nhìn từ góc yaw/pitch
            local lookRotation = CFrame.Angles(0, freecamYaw, 0) * CFrame.Angles(freecamPitch, 0, 0)

            -- Di chuyển bằng WASD + Space/Ctrl
            local moveDir = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + lookRotation.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - lookRotation.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - lookRotation.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + lookRotation.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            -- Chuẩn hóa hướng và áp dụng tốc độ
            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit
            end
            freecamPosition = freecamPosition + (moveDir * freecamSpeed * dt)

            -- Cập nhật camera: vị trí + hướng nhìn
            cam.CFrame = CFrame.new(freecamPosition) * lookRotation
        end)
    else
        -- Tắt freecam: ngắt kết nối, khôi phục camera và mở khóa điều khiển nhân vật
        if freecamConn then
            freecamConn:Disconnect()
            freecamConn = nil
        end
        if freecamRightClickConn then
            freecamRightClickConn:Disconnect()
            freecamRightClickConn = nil
        end

        -- Mở lại điều khiển nhân vật
        pcall(function()
            ContextActionService:UnbindAction("FreecamBlockCharacterMovement")
        end)

        -- Bỏ Anchor nhân vật
        local myChar = getCharacter()
        local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
        if myRoot then
            myRoot.Anchored = freecamOriginalAnchored or false
        end

        freecamPossessed = nil
        local cam = workspace.CurrentCamera
        cam.CameraType = freecamOriginalCameraType or Enum.CameraType.Custom
        cam.CameraSubject = freecamOriginalCameraSubject
    end
end

function Misc.IsFreecamEnabled()
    return freecamEnabled
end

-- Lấy model đang được possess trong freecam (nil nếu không possess)
function Misc.GetFreecamPossessed()
    return freecamPossessed
end

-- ==================== SPECTATOR ====================

-- Spectator - Theo dõi camera của player khác
-- player: Player object muốn spectate
function Misc.SetSpectator(enable, player)
    enable, player = normalizeCall(enable, player)
    spectatorEnabled = enable

    if enable then
        if not player then
            warn("Cần chỉ định player để spectate")
            return
        end

        -- Không spectate chính mình
        if player == LocalPlayer then
            warn("Không thể spectate chính mình")
            return
        end

        spectatorTarget = player
        local cam = workspace.CurrentCamera

        -- Lưu camera gốc
        spectatorOriginalCameraType = cam.CameraType
        spectatorOriginalCameraSubject = cam.CameraSubject

        -- Chuyển camera sang theo dõi player mục tiêu
        cam.CameraType = Enum.CameraType.Custom
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                cam.CameraSubject = humanoid
            end
        end

        -- Theo dõi khi player respawn (character thay đổi)
        if spectatorConn then spectatorConn:Disconnect() end
        spectatorConn = player.CharacterAdded:Connect(function(newChar)
            if not spectatorEnabled then return end
            task.wait(0.5) -- Chờ character load xong
            local humanoid = newChar:FindFirstChildOfClass("Humanoid")
            if humanoid then
                workspace.CurrentCamera.CameraSubject = humanoid
            end
        end)
    else
        -- Tắt spectator: khôi phục camera về chính mình
        if spectatorConn then
            spectatorConn:Disconnect()
            spectatorConn = nil
        end

        spectatorTarget = nil
        local cam = workspace.CurrentCamera
        cam.CameraType = spectatorOriginalCameraType or Enum.CameraType.Custom

        -- Khôi phục camera subject về nhân vật mình
        local myChar = getCharacter()
        if myChar then
            local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
            cam.CameraSubject = myHumanoid or spectatorOriginalCameraSubject
        else
            cam.CameraSubject = spectatorOriginalCameraSubject
        end
    end
end

function Misc.IsSpectatorEnabled()
    return spectatorEnabled
end

function Misc.GetSpectatorTarget()
    return spectatorTarget
end

-- Chuyển spectate sang player tiếp theo trong danh sách (bỏ qua chính mình)
function Misc.SpectateNext()
    if not spectatorEnabled then return end

    local players = Players:GetPlayers()
    if #players <= 1 then return end

    -- Tìm index hiện tại
    local currentIndex = 0
    for i, p in ipairs(players) do
        if p == spectatorTarget then
            currentIndex = i
            break
        end
    end

    -- Chuyển sang player tiếp theo (bỏ qua chính mình)
    local nextIndex = currentIndex
    for _ = 1, #players do
        nextIndex = (nextIndex % #players) + 1
        if players[nextIndex] ~= LocalPlayer then
            break
        end
    end

    Misc.SetSpectator(true, players[nextIndex])
end

-- Chuyển spectate sang player trước đó (bỏ qua chính mình)
function Misc.SpectatePrev()
    if not spectatorEnabled then return end

    local players = Players:GetPlayers()
    if #players <= 1 then return end

    -- Tìm index hiện tại
    local currentIndex = 0
    for i, p in ipairs(players) do
        if p == spectatorTarget then
            currentIndex = i
            break
        end
    end

    -- Chuyển sang player trước đó (bỏ qua chính mình)
    local prevIndex = currentIndex
    for _ = 1, #players do
        prevIndex = ((prevIndex - 2) % #players) + 1
        if players[prevIndex] ~= LocalPlayer then
            break
        end
    end

    Misc.SetSpectator(true, players[prevIndex])
end

-- Cleanup - Dọn dẹp tất cả khi không cần nữa
function Misc.Cleanup()
    Misc.SetSpeed(false)
    Misc.SetSpeedMultiplier(false)
    Misc.SetJumpPower(false)
    Misc.SetJumpPowerMultiplier(false)
    Misc.SetFly(false)
    Misc.SetNoclip(false)
    Misc.SetNoClipCam(false)
    Misc.SetCamDistance(false)
    Misc.SetTimeManager(false)
    Misc.SetNoFog(false)
    Misc.SetFullbright(false)
    Misc.SetInstantPrompts(false)
    Misc.SetAntiAFK(false)
    Misc.SetFPSUnlocker(false)
    Misc.SetNameTags(false)
    Misc.SetInfJump(false)
    Misc.SetFreecam(false)
    Misc.SetSpectator(false)
end

return Misc
