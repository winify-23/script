--[[
    Farm Positions Library - Tính vị trí đứng tương đối với mục tiêu.

    Ví dụ:
        local FarmPositions = require(https://raw.githubusercontent.com/WiniFyCode/Roblox/refs/heads/main/libs/FarmPositions.lua)
        local targetCFrame = FarmPositions.Get(enemy, "Behind", {Distance = 10})
        if targetCFrame then
            humanoidRootPart.CFrame = targetCFrame
        end

    Các mode chính: Behind, Front, Above, Below, Orbit.
    Alias "Font" cũng được chấp nhận và được chuẩn hóa thành "Front".
--]]

local FarmPositions = {}

local DEFAULT_DISTANCE = 10
local DEFAULT_HEIGHT = 10
local DEFAULT_RADIUS = 12

local MODE_ALIASES = {
    behind = "behind",
    front = "front",
    font = "front",
    above = "above",
    below = "below",
    orbit = "orbit",
    left = "left",
    right = "right",
}

-- Chuẩn hóa mode để API không phụ thuộc vào hoa thường hoặc lỗi gõ "font".
local function normalizeMode(mode)
    local normalized = string.lower(tostring(mode or FarmPositions._mode or "behind"))
    return MODE_ALIASES[normalized]
end

-- Lấy CFrame đại diện cho mục tiêu từ Model, BasePart, CFrame hoặc Vector3.
local function resolveTargetCFrame(target)
    if typeof(target) == "CFrame" then
        return target
    end

    if typeof(target) == "Vector3" then
        return CFrame.new(target)
    end

    if typeof(target) ~= "Instance" then
        return nil, "Target phải là Model, BasePart, CFrame hoặc Vector3"
    end

    if target:IsA("BasePart") then
        return target.CFrame
    end

    if target:IsA("Model") then
        local root = target:FindFirstChild("HumanoidRootPart")
            or target.PrimaryPart
            or target:FindFirstChildWhichIsA("BasePart", true)

        if root and root:IsA("BasePart") then
            return root.CFrame
        end

        -- GetPivot vẫn hỗ trợ model không có part root rõ ràng.
        local ok, pivot = pcall(function()
            return target:GetPivot()
        end)
        if ok and typeof(pivot) == "CFrame" then
            return pivot
        end
    end

    return nil, "Không thể lấy CFrame từ target"
end

-- Trả về danh sách mode để đưa vào dropdown UI.
function FarmPositions.Modes()
    return {"Behind", "Front", "Above", "Below", "Orbit", "Left", "Right"}
end

-- Đặt mode mặc định cho những lần gọi không truyền mode.
function FarmPositions.SetMode(mode)
    local normalized = normalizeMode(mode)
    if not normalized then
        return false, "Mode không hợp lệ: " .. tostring(mode)
    end

    FarmPositions._mode = normalized
    return true
end

-- Lấy mode mặc định hiện tại ở dạng tên dễ hiển thị.
function FarmPositions.GetMode()
    return FarmPositions._mode or "behind"
end

-- Tính CFrame đứng quanh mục tiêu theo mode được chọn.
function FarmPositions.Get(target, mode, options)
    options = options or {}

    local targetCFrame, targetError = resolveTargetCFrame(target)
    if not targetCFrame then
        return nil, targetError
    end

    local normalizedMode = normalizeMode(mode)
    if not normalizedMode then
        return nil, "Mode không hợp lệ: " .. tostring(mode)
    end

    local targetPosition = targetCFrame.Position
    local distance = tonumber(options.Distance) or DEFAULT_DISTANCE
    local height = tonumber(options.Height) or DEFAULT_HEIGHT
    local verticalOffset = tonumber(options.VerticalOffset) or 0
    local destination

    if normalizedMode == "behind" then
        -- Phía sau được tính theo hướng LookVector của mục tiêu.
        destination = (targetCFrame * CFrame.new(0, verticalOffset, distance)).Position
    elseif normalizedMode == "front" then
        -- Phía trước là hướng ngược lại phía sau của mục tiêu.
        destination = (targetCFrame * CFrame.new(0, verticalOffset, -distance)).Position
    elseif normalizedMode == "left" then
        -- Đứng bên trái theo hệ trục local của mục tiêu.
        destination = (targetCFrame * CFrame.new(-distance, verticalOffset, 0)).Position
    elseif normalizedMode == "right" then
        -- Đứng bên phải theo hệ trục local của mục tiêu.
        destination = (targetCFrame * CFrame.new(distance, verticalOffset, 0)).Position
    elseif normalizedMode == "above" then
        -- Above/Below giữ nguyên mặt phẳng XZ và chỉ thay đổi độ cao.
        destination = targetPosition + Vector3.new(0, height + verticalOffset, 0)
    elseif normalizedMode == "below" then
        -- Giữ offset âm để nhân vật đứng bên dưới mục tiêu.
        destination = targetPosition + Vector3.new(0, -height + verticalOffset, 0)
    elseif normalizedMode == "orbit" then
        -- Orbit dùng góc truyền vào; caller tự tăng góc trong loop farm.
        local radius = tonumber(options.Radius) or distance or DEFAULT_RADIUS
        local angle = tonumber(options.Angle) or 0
        local offset = Vector3.new(math.cos(angle) * radius, verticalOffset, math.sin(angle) * radius)
        destination = targetPosition + offset
    end

    if options.FaceTarget == false then
        return CFrame.new(destination)
    end

    -- Mặc định luôn quay mặt về mục tiêu để thuận tiện cho việc tấn công.
    local lookTarget = targetPosition + Vector3.new(0, tonumber(options.LookAtHeight) or 0, 0)
    return CFrame.lookAt(destination, lookTarget)
end

-- Chỉ lấy Vector3 từ kết quả Get khi caller không cần hướng quay mặt.
function FarmPositions.GetPosition(target, mode, options)
    local targetCFrame, err = FarmPositions.Get(target, mode, options)
    if not targetCFrame then
        return nil, err
    end

    return targetCFrame.Position
end

-- Di chuyển local character tới vị trí farm; có thể truyền options.Move để tự tween.
function FarmPositions.Move(target, mode, options)
    options = options or {}

    local targetCFrame, err = FarmPositions.Get(target, mode, options)
    if not targetCFrame then
        return false, err
    end

    if type(options.Move) == "function" then
        local ok, result = pcall(options.Move, targetCFrame, target)
        if not ok then
            return false, result
        end
        return result ~= false, targetCFrame
    end

    local localPlayer = game:GetService("Players").LocalPlayer
    local character = localPlayer and localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false, "Không tìm thấy HumanoidRootPart của local player"
    end

    -- Gán CFrame trực tiếp để thư viện giữ behavior giống Teleport.ToPosition.
    rootPart.CFrame = targetCFrame
    return true, targetCFrame
end

return FarmPositions
