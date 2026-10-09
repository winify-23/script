--[[
    ESP Library - Roblox Drawing API - Version 1.6
    Features: Box2D, Box3D, Corner, Name, HealthBar, HealthText,
              Tracer, Distance, Highlight, Skeleton, TeamCheck, WallCheck, Radar
    Reference: linemaster2/esp-library
]]

local ESP = {}
ESP.__index = ESP

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ==================== CONSTANTS ====================
local SMOOTHING = 0.3
local MIN_BOX_SIZE = 10
local MIN_CORNER_SIZE = 12
local OUTLINE_THICKNESS = 4
local FILL_THICKNESS = 2
local BOX_STUD_HEIGHT = 5.6
local BOX_STUD_WIDTH = 4.0

-- Skeleton joint connections [R15]
local R15_JOINTS = {
    { "Head",          "UpperTorso" },
    { "UpperTorso",    "LowerTorso" },
    { "UpperTorso",    "LeftUpperArm" },
    { "LeftUpperArm",  "LeftLowerArm" },
    { "LeftLowerArm",  "LeftHand" },
    { "UpperTorso",    "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso",    "LeftUpperLeg" },
    { "LeftUpperLeg",  "LeftLowerLeg" },
    { "LeftLowerLeg",  "LeftFoot" },
    { "LowerTorso",    "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

-- Skeleton joint connections [R6]
local R6_JOINTS = {
    { "Head",  "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

-- 3D Box edge indices (12 edges connecting 8 corners)
local BOX3D_EDGES = {
    { 1, 2 }, { 3, 4 }, { 5, 6 }, { 7, 8 }, -- width edges
    { 1, 3 }, { 2, 4 }, { 5, 7 }, { 6, 8 }, -- height edges
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }, -- depth edges
}

-- ==================== UTILITIES ====================
local function newDrawing(type, props)
    local ok, obj = pcall(Drawing.new, type)
    if not ok or not obj then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

local function removeDrawing(d)
    if d and d.Remove then
        pcall(function() d:Remove() end)
    end
end

local function worldToScreen(point)
    local camera = Workspace.CurrentCamera
    if not camera then return Vector2.new(0, 0), false, false end
    local screenPos, onScreen = camera:WorldToViewportPoint(point)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z >= 0
end

local function getScreenCenter()
    local camera = Workspace.CurrentCamera
    if not camera then return Vector2.new(0, 0) end
    local vp = camera.ViewportSize
    -- Tâm màn hình (X chia đôi, Y chia đôi)
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function isR15(character)
    return character and character:FindFirstChild("UpperTorso") ~= nil
end

local function getPartPosition(character, partName)
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then
        return part.Position
    end
    return nil
end

local function lerpColor(ratio)
    -- Green (full hp) -> Yellow (half) -> Red (low)
    local r = math.clamp(2 - 2 * ratio, 0, 1)
    local g = math.clamp(ratio, 0, 1)
    return Color3.new(r, g, 0)
end

local function getDistance(partA, partB)
    if not partA or not partB then return 0 end
    return math.floor((partA.Position - partB.Position).Magnitude)
end

local function isBehindWall(origin, targetPos, ignoreList)
    local dir = targetPos - origin
    local dist = dir.Magnitude
    if dist < 0.2 then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList or {}
    params.IgnoreWater = true
    pcall(function()
        params.RespectCanCollide = true
    end)

    -- Thu ngắn khoảng cách 0.1 stud để tránh đâm xuyên vào bề mặt tường ngay phía sau mục tiêu
    local castDist = math.max(dist - 0.1, 0.1)
    local result = Workspace:Raycast(origin, dir.Unit * castDist, params)
    if result then
        local hitPart = result.Instance
        if not hitPart then return false end

        -- Bỏ qua part tàng hình không có va chạm (vùng trigger/zone/hiệu ứng)
        if hitPart.Transparency >= 0.95 and not hitPart.CanCollide then
            return false
        end

        -- Kiểm tra nếu part trúng thuộc về nhân vật đang xét
        for _, inst in ipairs(ignoreList or {}) do
            if hitPart:IsDescendantOf(inst) then
                return false
            end
        end
        return true -- Trúng vật cản thực sự = bị che khuất
    end
    return false
end

-- Kiểm tra xem toàn bộ nhân vật có bị che khuất hoàn toàn sau tường không
-- Chỉ coi là sau tường nếu TẤT CẢ các bộ phận trọng yếu (Đầu, Thân trên, Thân giữa, Tay) đều bị che
local function isCharacterBehindWall(origin, model, ignoreList)
    if not model then return false end

    -- Danh sách các bộ phận trọng yếu để kiểm tra tầm nhìn
    local partsToCheck = {
        model:FindFirstChild("Head"),
        model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"),
        model:FindFirstChild("HumanoidRootPart"),
        model:FindFirstChild("RightUpperArm") or model:FindFirstChild("Right Arm"),
        model:FindFirstChild("LeftUpperArm") or model:FindFirstChild("Left Arm"),
    }

    local targetPositions = {}
    for _, part in ipairs(partsToCheck) do
        if part and part:IsA("BasePart") then
            table.insert(targetPositions, part.Position)
        end
    end

    -- Nếu không có các bộ phận trên, quét các BasePart con
    if #targetPositions == 0 then
        for _, part in ipairs(model:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(targetPositions, part.Position)
                if #targetPositions >= 3 then break end
            end
        end
    end

    if #targetPositions == 0 then return false end

    -- Nếu nhìn thấy được bất kỳ bộ phận nào thì nhân vật chưa bị che khuất hoàn toàn
    for _, pos in ipairs(targetPositions) do
        if not isBehindWall(origin, pos, ignoreList) then
            return false
        end
    end

    return true
end

-- ==================== CONSTRUCTOR ====================
function ESP.new()
    local self = setmetatable({}, ESP)

    self.Objects = {}     -- [model] = ESPObject
    self.Connections = {} -- event connections

    -- Feature toggles
    self.Enabled = {
        Master     = true, -- master switch: off hides everything
        Box2D      = true,
        Box3D      = false,
        Corner     = false,
        Skeleton   = false,
        Name       = true,
        HealthBar  = true,
        HealthText = true,
        Distance   = true,
        Tracer     = false,
        Highlight  = false,
        TeamCheck  = false,
        WallCheck  = false,
        Radar      = false,
    }

    -- Colors
    self.Colors = {
        Box        = Color3.fromRGB(255, 255, 255),
        Name       = Color3.fromRGB(255, 255, 255),
        Health     = Color3.fromRGB(0, 255, 0),
        Distance   = Color3.fromRGB(255, 255, 255),
        Tracer     = Color3.fromRGB(255, 255, 255),
        Skeleton   = Color3.fromRGB(255, 255, 255),
        Corner     = Color3.fromRGB(255, 255, 255),
        Ally       = Color3.fromRGB(0, 255, 0),
        Enemy      = Color3.fromRGB(255, 0, 0),
        Self       = Color3.fromRGB(0, 255, 255),
        BehindWall = Color3.fromRGB(128, 128, 128),
        Highlight  = Color3.fromRGB(255, 0, 0),
    }

    -- Name display mode: "Username", "DisplayName", "Both"
    self.NameMode = "Username"
    -- Health text format: "Percent" (100%), "Fraction" (100/100)
    self.HealthTextFormat = "Percent"
    -- Show ESP on the local player too (default: off)
    self.ShowSelf = false

    -- Radar config
    self.RadarSize = 130               -- radius in pixels
    self.RadarRange = 200              -- visible range in studs
    self.RadarPosition = "BottomRight" -- "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Center", "Custom"
    self.RadarCustomPosition = nil     -- Vector2, set by dragging or manually
    self.RadarNorthLock = true         -- true: N fixed at top; false: rotates with camera
    self.RadarShowNames = true
    self.RadarShowDirection = true
    self.RadarShowRings = true

    -- Config
    self.CornerSize = 12
    self.TracerOrigin = "Bottom" -- "Bottom", "Center", "Top"

    -- Internal
    self._hasDrawing = false
    self._renderConn = nil
    self._running = false
    self._playerCharMap = {}
    self._radar = nil
    self._radarSmooth = {}
    self._radarDragConns = {}
    self._radarDragging = false
    self._radarDragOffset = nil
    self._radarCx, self._radarCy = nil, nil

    -- Check Drawing API availability
    pcall(function()
        local test = Drawing.new("Square")
        if test then
            self._hasDrawing = true
            test:Remove()
        end
    end)

    return self
end

-- ==================== TEAM CHECK ====================
function ESP:IsTeammate(player)
    if not player then return false end
    if not self.Enabled.TeamCheck then return false end
    -- Only check team if BOTH players have an actual team assigned
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    -- If either player has no team, they are NOT teammates
    return false
end

function ESP:GetPlayerFromModel(model)
    if not model then return nil end
    local byName = Players:FindFirstChild(model.Name)
    if byName then return byName end
    local byChar = Players:GetPlayerFromCharacter(model)
    if byChar then return byChar end
    return nil
end

function ESP:GetColor(player)
    -- Own ESP gets its own color (ShowSelf), checked before TeamCheck
    if player == LocalPlayer then
        return self.Colors.Self
    end
    if not self.Enabled.TeamCheck then
        return self.Colors.Box
    end
    if player and self:IsTeammate(player) then
        return self.Colors.Ally
    end
    return self.Colors.Enemy
end

-- ==================== TARGET MANAGEMENT ====================
function ESP:AddTarget(model)
    if not model then return end
    if self.Objects[model] then return end

    local obj = {}
    obj.Target = model
    obj.Drawings = {}
    obj.HighlightInstance = nil
    obj._prevBounds = nil

    -- Create 2D Box drawings (outline + fill)
    obj.Drawings.Box2DOutline = newDrawing("Square", {
        Visible = false, Thickness = OUTLINE_THICKNESS, Filled = false, Color = Color3.new(0, 0, 0)
    })
    for i = 1, 4 do
        obj.Drawings["Box2D" .. i] = newDrawing("Line", {
            Visible = false, Thickness = FILL_THICKNESS, Color = self.Colors.Box
        })
    end

    -- Create 3D Box drawings (12 edges, outline + fill)
    for i = 1, 12 do
        obj.Drawings["Box3DOutline" .. i] = newDrawing("Line", {
            Visible = false, Thickness = OUTLINE_THICKNESS, Color = Color3.new(0, 0, 0)
        })
        obj.Drawings["Box3D" .. i] = newDrawing("Line", {
            Visible = false, Thickness = FILL_THICKNESS, Color = self.Colors.Box
        })
    end

    -- Create Corner drawings (8 corner lines)
    for i = 1, 8 do
        obj.Drawings["CornerOutline" .. i] = newDrawing("Line", {
            Visible = false, Thickness = OUTLINE_THICKNESS, Color = Color3.new(0, 0, 0)
        })
        obj.Drawings["Corner" .. i] = newDrawing("Line", {
            Visible = false, Thickness = FILL_THICKNESS, Color = self.Colors.Corner
        })
    end

    -- Create Skeleton drawings (14 joints max for R15)
    for i = 1, 14 do
        obj.Drawings["SkeletonOutline" .. i] = newDrawing("Line", {
            Visible = false, Thickness = OUTLINE_THICKNESS, Color = Color3.new(0, 0, 0)
        })
        obj.Drawings["Skeleton" .. i] = newDrawing("Line", {
            Visible = false, Thickness = FILL_THICKNESS, Color = self.Colors.Skeleton
        })
    end

    -- Name text
    obj.Drawings.Name = newDrawing("Text", {
        Visible = false, Center = true, Outline = true, Size = 13, Font = 2, Color = self.Colors.Name
    })

    -- Health bar (outline + fill)
    obj.Drawings.HealthOutline = newDrawing("Line", {
        Visible = false, Thickness = 5, Color = Color3.new(0, 0, 0)
    })
    obj.Drawings.Health = newDrawing("Line", {
        Visible = false, Thickness = 3, Color = self.Colors.Health
    })

    -- Health text
    obj.Drawings.HealthText = newDrawing("Text", {
        Visible = false, Center = false, Outline = true, Size = 11, Font = 2, Color = Color3.new(1, 1, 1)
    })

    -- Distance text
    obj.Drawings.Distance = newDrawing("Text", {
        Visible = false, Center = true, Outline = true, Size = 11, Font = 2, Color = self.Colors.Distance
    })

    -- Tracer line
    obj.Drawings.Tracer = newDrawing("Line", {
        Visible = false, Thickness = 1, Color = self.Colors.Tracer
    })

    -- WallCheck indicator
    obj.Drawings.WallIndicator = newDrawing("Text", {
        Visible = false, Center = true, Outline = true, Size = 10, Font = 2, Color = self.Colors.BehindWall
    })

    -- Highlight instance
    obj.HighlightInstance = nil

    -- Public methods
    function obj:setVisible(v)
        for _, drawing in pairs(self.Drawings) do
            if drawing then
                pcall(function() drawing.Visible = v end)
            end
        end
        if self.HighlightInstance then
            pcall(function() self.HighlightInstance.Enabled = v end)
        end
    end

    self.Objects[model] = obj
end

function ESP:RemoveTarget(model)
    local obj = self.Objects[model]
    if not obj then return end

    for _, drawing in pairs(obj.Drawings) do
        removeDrawing(drawing)
    end
    if obj.HighlightInstance then
        pcall(function() obj.HighlightInstance:Destroy() end)
    end
    self.Objects[model] = nil
end

-- ==================== BOUNDING BOX ====================
-- Tạo 8 đỉnh trong không gian 3D của đối tượng (dùng cho Box3D)
local function project3DBox(cf, size)
    local half = size / 2
    local corners = {}

    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local worldPt = cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)
                table.insert(corners, worldPt)
            end
        end
    end

    return corners
end

-- ==================== RENDER: BOX 2D ====================
local function renderBox2D(drawings, minX, minY, maxX, maxY, color)
    local w = maxX - minX
    local h = maxY - minY

    if w < MIN_BOX_SIZE or h < MIN_BOX_SIZE then
        for i = 1, 4 do
            if drawings["Box2D" .. i] then drawings["Box2D" .. i].Visible = false end
        end
        if drawings.Box2DOutline then drawings.Box2DOutline.Visible = false end
        return
    end

    -- Outline
    if drawings.Box2DOutline then
        drawings.Box2DOutline.Visible = true
        drawings.Box2DOutline.Position = Vector2.new(minX, minY)
        drawings.Box2DOutline.Size = Vector2.new(w, h)
        drawings.Box2DOutline.Color = Color3.new(0, 0, 0)
    end

    -- 4 fill edges
    local edges = {
        { Vector2.new(minX, minY),     Vector2.new(maxX, minY) },     -- top
        { Vector2.new(maxX, minY),     Vector2.new(maxX, minY + h) }, -- right
        { Vector2.new(maxX, minY + h), Vector2.new(minX, minY + h) }, -- bottom
        { Vector2.new(minX, minY + h), Vector2.new(minX, minY) },     -- left
    }
    for i, edge in ipairs(edges) do
        local d = drawings["Box2D" .. i]
        if d then
            d.Visible = true
            d.From = edge[1]
            d.To = edge[2]
            d.Color = color
        end
    end

    return minX, minY, w, h
end

-- ==================== RENDER: BOX 3D ====================
local function renderBox3D(drawings, worldCorners, color)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local camCF = camera.CFrame
    local NEAR_PLANE_Z = 0.5

    for i, edge in ipairs(BOX3D_EDGES) do
        local w1 = worldCorners[edge[1]]
        local w2 = worldCorners[edge[2]]
        if not w1 or not w2 then continue end

        local p1 = camCF:PointToObjectSpace(w1)
        local p2 = camCF:PointToObjectSpace(w2)

        -- Khoảng cách phía trước camera (-Z là trục nhìn thẳng của camera)
        local z1 = -p1.Z
        local z2 = -p2.Z

        local outlineD = drawings["Box3DOutline" .. i]
        local d = drawings["Box3D" .. i]

        -- Cả hai điểm đều ở sau camera: ẩn đoạn thẳng này
        if z1 < NEAR_PLANE_Z and z2 < NEAR_PLANE_Z then
            if outlineD then outlineD.Visible = false end
            if d then d.Visible = false end
            continue
        end

        local finalW1 = w1
        local finalW2 = w2

        -- Điểm 1 ở sau camera: cắt đoạn thẳng đến mặt phẳng gần
        if z1 < NEAR_PLANE_Z and z2 >= NEAR_PLANE_Z then
            local t = (NEAR_PLANE_Z - z1) / (z2 - z1)
            local clippedP1 = p1:Lerp(p2, t)
            finalW1 = camCF:PointToWorldSpace(clippedP1)
        -- Điểm 2 ở sau camera: cắt đoạn thẳng đến mặt phẳng gần
        elseif z2 < NEAR_PLANE_Z and z1 >= NEAR_PLANE_Z then
            local t = (NEAR_PLANE_Z - z2) / (z1 - z2)
            local clippedP2 = p2:Lerp(p1, t)
            finalW2 = camCF:PointToWorldSpace(clippedP2)
        end

        local s1, onScreen1, inFront1 = worldToScreen(finalW1)
        local s2, onScreen2, inFront2 = worldToScreen(finalW2)

        if inFront1 and inFront2 then
            if outlineD then
                outlineD.Visible = true
                outlineD.From = s1
                outlineD.To = s2
                outlineD.Color = Color3.new(0, 0, 0)
            end
            if d then
                d.Visible = true
                d.From = s1
                d.To = s2
                d.Color = color
            end
        else
            if outlineD then outlineD.Visible = false end
            if d then d.Visible = false end
        end
    end
end

-- ==================== RENDER: CORNER ====================
local function renderCorner(drawings, minX, minY, maxX, maxY, color, cornerSize)
    local w = maxX - minX
    local h = maxY - minY

    if w < MIN_BOX_SIZE or h < MIN_BOX_SIZE then
        for i = 1, 8 do
            if drawings["Corner" .. i] then drawings["Corner" .. i].Visible = false end
            if drawings["CornerOutline" .. i] then drawings["CornerOutline" .. i].Visible = false end
        end
        return
    end

    local cSize = math.max(cornerSize or MIN_CORNER_SIZE, MIN_CORNER_SIZE)
    -- Clamp corner size to half the box dimension
    cSize = math.min(cSize, math.floor(w / 4), math.floor(h / 4))
    cSize = math.max(cSize, MIN_CORNER_SIZE)

    -- 4 corners, 2 lines each = 8 lines
    local cornerLines = {
        -- Top-left
        { Vector2.new(minX, minY), Vector2.new(minX + cSize, minY) },
        { Vector2.new(minX, minY), Vector2.new(minX, minY + cSize) },
        -- Top-right
        { Vector2.new(maxX, minY), Vector2.new(maxX - cSize, minY) },
        { Vector2.new(maxX, minY), Vector2.new(maxX, minY + cSize) },
        -- Bottom-left
        { Vector2.new(minX, maxY), Vector2.new(minX + cSize, maxY) },
        { Vector2.new(minX, maxY), Vector2.new(minX, maxY - cSize) },
        -- Bottom-right
        { Vector2.new(maxX, maxY), Vector2.new(maxX - cSize, maxY) },
        { Vector2.new(maxX, maxY), Vector2.new(maxX, maxY - cSize) },
    }

    for i, line in ipairs(cornerLines) do
        -- Outline
        local outlineD = drawings["CornerOutline" .. i]
        if outlineD then
            outlineD.Visible = true
            outlineD.From = line[1]
            outlineD.To = line[2]
            outlineD.Color = Color3.new(0, 0, 0)
        end
        -- Fill
        local d = drawings["Corner" .. i]
        if d then
            d.Visible = true
            d.From = line[1]
            d.To = line[2]
            d.Color = color
        end
    end
end

-- ==================== RENDER: SKELETON ====================
local function renderSkeleton(drawings, character, color)
    local joints = isR15(character) and R15_JOINTS or R6_JOINTS
    local jointCount = #joints

    for i, joint in ipairs(joints) do
        local posA = getPartPosition(character, joint[1])
        local posB = getPartPosition(character, joint[2])

        -- Outline
        local outlineD = drawings["SkeletonOutline" .. i]
        if outlineD then
            if posA and posB then
                local sA, onA = worldToScreen(posA)
                local sB, onB = worldToScreen(posB)
                if onA and onB then
                    outlineD.Visible = true
                    outlineD.From = sA
                    outlineD.To = sB
                    outlineD.Color = Color3.new(0, 0, 0)
                else
                    outlineD.Visible = false
                end
            else
                outlineD.Visible = false
            end
        end

        -- Fill
        local d = drawings["Skeleton" .. i]
        if d then
            if posA and posB then
                local sA, onA = worldToScreen(posA)
                local sB, onB = worldToScreen(posB)
                if onA and onB then
                    d.Visible = true
                    d.From = sA
                    d.To = sB
                    d.Color = color
                else
                    d.Visible = false
                end
            else
                d.Visible = false
            end
        end
    end

    -- Hide unused skeleton slots
    for i = jointCount + 1, 14 do
        if drawings["Skeleton" .. i] then drawings["Skeleton" .. i].Visible = false end
        if drawings["SkeletonOutline" .. i] then drawings["SkeletonOutline" .. i].Visible = false end
    end
end

-- ==================== RENDER: NAME ====================
local function renderName(drawings, player, minX, slimW, minY, color, nameMode)
    local d = drawings.Name
    if not d then return end
    d.Visible = true
    if not player then
        d.Text = "Unknown"
    elseif nameMode == "DisplayName" then
        d.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
    elseif nameMode == "Both" then
        local dn = player.DisplayName ~= "" and player.DisplayName or player.Name
        d.Text = dn .. " (" .. player.Name .. ")"
    else
        d.Text = player.Name
    end
    d.Position = Vector2.new(minX + slimW / 2, minY - 16)
    d.Color = color
end

-- ==================== RENDER: HEALTH BAR ====================
local function renderHealthBar(drawings, humanoid, minX, minY, h, ratio)
    local barD = drawings.Health
    local outlineD = drawings.HealthOutline
    if not barD or not humanoid then
        if barD then barD.Visible = false end
        if outlineD then outlineD.Visible = false end
        return
    end

    local hp = humanoid.Health
    local maxHp = humanoid.MaxHealth
    if not ratio then
        ratio = math.clamp(maxHp > 0 and hp / maxHp or 0, 0, 1)
    end
    local barH = h * ratio

    local outlineX = minX - 6
    local barX = minX - 5
    local barTop = minY + h - barH

    -- Viền ngoài thanh máu
    if outlineD then
        outlineD.Visible = true
        outlineD.From = Vector2.new(outlineX, minY + h)
        outlineD.To = Vector2.new(outlineX, minY)
        outlineD.Color = Color3.new(0, 0, 0)
    end

    -- Thanh máu
    barD.Visible = true
    barD.From = Vector2.new(barX, minY + h)
    barD.To = Vector2.new(barX, barTop)
    barD.Color = lerpColor(ratio)

    return ratio
end

-- ==================== RENDER: HEALTH TEXT ====================
local function renderHealthText(drawings, humanoid, minX, minY, h, ratio, format, hasHealthBar)
    local d = drawings.HealthText
    if not d then return end
    if not humanoid then
        d.Visible = false
        return
    end

    local hp = math.max(0, math.floor(humanoid.Health))
    local maxHp = math.max(1, math.floor(humanoid.MaxHealth))
    if not ratio then
        ratio = math.clamp(maxHp > 0 and (humanoid.Health / humanoid.MaxHealth) or 0, 0, 1)
    end
    local pct = math.floor(ratio * 100)

    d.Visible = true
    if format == "Fraction" then
        d.Text = string.format("%d/%d", hp, maxHp)
    else
        d.Text = string.format("%d%%", pct)
    end

    -- Tính chiều rộng chữ để căn lề phải sát cạnh hộp hoặc thanh máu
    local textWidth = #d.Text * 7
    pcall(function()
        if d.TextBounds and d.TextBounds.X > 0 then
            textWidth = d.TextBounds.X
        end
    end)

    -- Khoảng cách đệm: có thanh máu cách 10px, không có cách 5px
    local offset = hasHealthBar and 10 or 5
    d.Position = Vector2.new(minX - offset - textWidth, minY + h / 2 - 6)
    d.Color = lerpColor(ratio)
end

-- ==================== RENDER: DISTANCE ====================
local function renderDistance(drawings, model, maxY, slimX, slimW, color)
    local d = drawings.Distance
    if not d then return end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = model:FindFirstChild("HumanoidRootPart")

    if myHRP and targetHRP then
        local dist = getDistance(myHRP, targetHRP)
        d.Visible = true
        d.Text = string.format("%dm", dist)
        d.Position = Vector2.new(slimX + slimW / 2, maxY + 2)
        d.Color = color
    else
        d.Visible = false
    end
end

-- ==================== RENDER: TRACER ====================
local function renderTracer(drawings, slimX, slimW, minY, h, color, origin)
    local d = drawings.Tracer
    if not d then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end
    local vp = camera.ViewportSize

    local targetX = slimX + slimW / 2
    local from, to

    -- Xác định điểm xuất phát trên màn hình và điểm đích trên đối tượng
    if origin == "Top" then
        -- Xuất phát từ giữa mép trên màn hình, nối tới đỉnh đầu đối tượng
        from = Vector2.new(vp.X / 2, 0)
        to = Vector2.new(targetX, minY)
    elseif origin == "Center" then
        -- Xuất phát từ tâm màn hình, nối tới giữa thân đối tượng
        from = Vector2.new(vp.X / 2, vp.Y / 2)
        to = Vector2.new(targetX, minY + h / 2)
    else -- "Bottom"
        -- Xuất phát từ giữa mép dưới màn hình, nối tới chân đối tượng
        from = Vector2.new(vp.X / 2, vp.Y)
        to = Vector2.new(targetX, minY + h)
    end

    d.Visible = true
    d.From = from
    d.To = to
    d.Color = color
end

-- ==================== RENDER: HIGHLIGHT ====================
local function renderHighlight(obj, model, color)
    if not obj.HighlightInstance then
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Highlight"
        hl.Adornee = model
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Parent = model
        obj.HighlightInstance = hl
    end

    local hl = obj.HighlightInstance
    if hl then
        hl.Enabled = true
        hl.FillColor = color
        hl.OutlineColor = color
    end
end

local function hideHighlight(obj)
    if obj.HighlightInstance then
        obj.HighlightInstance.Enabled = false
    end
end

-- ==================== RENDER: WALLCHECK ====================
local function renderWallCheck(drawings, model, minX, slimW, minY, color, wallColor)
    local myChar = LocalPlayer.Character
    local camera = Workspace.CurrentCamera
    if not myChar or not camera then return false end

    local behindWall = isCharacterBehindWall(
        camera.CFrame.Position,
        model,
        { myChar, model }
    )

    local indicator = drawings.WallIndicator
    if behindWall then
        if indicator then
            indicator.Visible = true
            indicator.Text = "[W]"
            indicator.Position = Vector2.new(minX + slimW / 2, minY - 30)
            indicator.Color = wallColor or Color3.fromRGB(128, 128, 128)
        end
        return true
    else
        if indicator then indicator.Visible = false end
        return false
    end
end

-- ==================== RADAR ====================
local MAX_RADAR_PLAYERS = 64
local RADAR_BG_COLOR = Color3.fromRGB(15, 15, 15)
local RADAR_GRID_COLOR = Color3.fromRGB(65, 65, 65)
local RADAR_BORDER_COLOR = Color3.fromRGB(210, 210, 210)
local RADAR_LABEL_COLOR = Color3.fromRGB(255, 255, 255)
local RADAR_CENTER_COLOR = Color3.fromRGB(255, 70, 70)

-- Mouse-pointer polygon (tip at origin), from the mouse-pointer-2 icon
local POINTER_PTS = {
    { 0.000,  0.000 },  -- tip
    { 0.651,  -0.651 }, -- rounded tip corner
    { 16.651, 5.849 },  -- far right
    { 16.588, 6.796 },  -- notch start
    { 10.464, 8.376 },  -- notch inner
    { 9.026,  9.811 },  -- notch bottom
    { 7.447,  15.937 }, -- tail tip
    { 6.500,  16.000 }, -- tail rounded corner
}
local POINTER_SCALE = 0.8
-- Natural pointing direction of POINTER_PTS (tail -> tip) in screen coords
local POINTER_BASE_ANGLE = math.atan2(-15.937, -7.447)

-- Lazily create radar drawings on first render (radar off = zero cost)
function ESP:_initRadarDrawings()
    local d = {}
    local function mk(type, props)
        local obj = newDrawing(type, props)
        if obj then obj.Visible = false end
        return obj
    end

    -- Static visuals
    d.Bg = mk("Circle", { Filled = true, Color = RADAR_BG_COLOR, Transparency = 0.5 })
    d.Border = mk("Circle", { Filled = false, Thickness = 2, Color = RADAR_BORDER_COLOR })
    d.Ring1 = mk("Circle", { Filled = false, Thickness = 1, Color = RADAR_GRID_COLOR })
    d.Ring2 = mk("Circle", { Filled = false, Thickness = 1, Color = RADAR_GRID_COLOR })
    d.Grid = {}
    for i = 1, 8 do
        d.Grid[i] = mk("Line", { Thickness = 1, Color = RADAR_GRID_COLOR })
    end
    d.NorthLabel = mk("Text", { Center = true, Size = 13, Font = 2, Color = RADAR_LABEL_COLOR, Text = "N" })
    d.EastLabel = mk("Text", { Center = true, Size = 13, Font = 2, Color = RADAR_LABEL_COLOR, Text = "E" })
    d.SouthLabel = mk("Text", { Center = true, Size = 13, Font = 2, Color = RADAR_LABEL_COLOR, Text = "S" })
    d.WestLabel = mk("Text", { Center = true, Size = 13, Font = 2, Color = RADAR_LABEL_COLOR, Text = "W" })
    d.Center = mk("Circle", { Filled = true, Radius = 3, Color = RADAR_CENTER_COLOR })

    -- Ring distance labels (studs at 33% / 66% of range)
    d.Ring1Label = mk("Text", { Center = true, Size = 10, Font = 2, Outline = true, Color = RADAR_LABEL_COLOR })
    d.Ring2Label = mk("Text", { Center = true, Size = 10, Font = 2, Outline = true, Color = RADAR_LABEL_COLOR })

    -- Per-player markers (pooled, max 64)
    d.Dots = {}
    d.Arrows = {}
    d.Names = {}
    for i = 1, MAX_RADAR_PLAYERS do
        d.Dots[i] = mk("Circle", { Filled = true, Radius = 3.5 })
        local arr = {}
        for j = 1, 8 do
            arr[j] = mk("Line", { Thickness = 2 })
        end
        d.Arrows[i] = arr
        d.Names[i] = mk("Text", { Center = false, Size = 10, Font = 2, Outline = true })
    end

    self._radar = d
    self._radarSmooth = {}

    -- Drag support: hold left click inside the radar to reposition it
    local UIS = game:GetService("UserInputService")
    local function hitRadar(mousePos)
        if not self._radarCx or not self._radarCy then return false end
        local dx, dy = mousePos.X - self._radarCx, mousePos.Y - self._radarCy
        return (dx * dx + dy * dy) <= (self.RadarSize * self.RadarSize)
    end
    table.insert(self._radarDragConns, UIS.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local m = UIS:GetMouseLocation()
            if hitRadar(m) then
                self._radarDragging = true
                self._radarDragOffset = Vector2.new(self._radarCx - m.X, self._radarCy - m.Y)
            end
        end
    end))
    table.insert(self._radarDragConns, UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and self._radarDragging then
            local m = UIS:GetMouseLocation()
            self.RadarCustomPosition = Vector2.new(m.X + self._radarDragOffset.X, m.Y + self._radarDragOffset.Y)
            self.RadarPosition = "Custom"
        end
    end))
    table.insert(self._radarDragConns, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._radarDragging = false
        end
    end))
end

function ESP:_hideRadar()
    local d = self._radar
    if not d then return end
    local static = { d.Bg, d.Border, d.Ring1, d.Ring2, d.Ring1Label, d.Ring2Label, d.NorthLabel, d.EastLabel, d
        .SouthLabel, d.WestLabel, d.Center }
    for _, v in ipairs(static) do
        if v then pcall(function() v.Visible = false end) end
    end
    for i = 1, 8 do
        if d.Grid[i] then pcall(function() d.Grid[i].Visible = false end) end
    end
    for i = 1, MAX_RADAR_PLAYERS do
        if d.Dots[i] then pcall(function() d.Dots[i].Visible = false end) end
        for j = 1, 8 do
            if d.Arrows[i] and d.Arrows[i][j] then pcall(function() d.Arrows[i][j].Visible = false end) end
        end
        if d.Names[i] then pcall(function() d.Names[i].Visible = false end) end
    end
end

function ESP:_getRadarCenter(vp, r)
    local x, y
    local p = self.RadarPosition
    if p == "Custom" and self.RadarCustomPosition then
        x, y = self.RadarCustomPosition.X, self.RadarCustomPosition.Y
    elseif p == "TopLeft" then
        x, y = r + 16, r + 16
    elseif p == "TopRight" then
        x, y = vp.X - r - 16, r + 16
    elseif p == "BottomLeft" then
        x, y = r + 16, vp.Y - r - 16
    elseif p == "BottomRight" then
        x, y = vp.X - r - 16, vp.Y - r - 16
    else
        x, y = vp.X / 2, vp.Y / 2
    end
    -- Keep fully visible (margin leaves room for the N/E/S/W labels)
    x = math.clamp(x, r + 16, vp.X - r - 16)
    y = math.clamp(y, r + 16, vp.Y - r - 16)
    return x, y
end

function ESP:_renderRadar(camera, myHRP)
    if not self._radar then
        self:_initRadarDrawings()
    end
    local d = self._radar
    local vp = camera.ViewportSize
    local r = self.RadarSize

    local cx, cy = self:_getRadarCenter(vp, r)
    self._radarCx, self._radarCy = cx, cy

    -- Camera yaw on the XZ plane (-Z is treated as north/top)
    local camLook = camera.CFrame.LookVector
    local camYaw = math.atan2(camLook.X, -camLook.Z)
    local northLock = self.RadarNorthLock

    -- Static visuals
    local function placeCircle(dr, radius, visible)
        if not dr then return end
        dr.Position = Vector2.new(cx, cy)
        dr.Radius = radius
        dr.Visible = visible
    end
    placeCircle(d.Bg, r, true)
    placeCircle(d.Border, r, true)
    placeCircle(d.Ring1, r * 0.33, self.RadarShowRings)
    placeCircle(d.Ring2, r * 0.66, self.RadarShowRings)

    -- Distance labels on each ring (tied to ring visibility)
    if d.Ring1Label then
        d.Ring1Label.Text = tostring(math.floor(self.RadarRange * 0.33))
        d.Ring1Label.Position = Vector2.new(cx + 8, cy - r * 0.33)
        d.Ring1Label.Visible = self.RadarShowRings
    end
    if d.Ring2Label then
        d.Ring2Label.Text = tostring(math.floor(self.RadarRange * 0.66))
        d.Ring2Label.Position = Vector2.new(cx + 8, cy - r * 0.66)
        d.Ring2Label.Visible = self.RadarShowRings
    end

    -- Radial grid lines
    for i = 1, 8 do
        local g = d.Grid[i]
        if not g then continue end
        local ang = (i - 1) * math.pi / 4
        g.From = Vector2.new(cx, cy)
        g.To = Vector2.new(cx + math.sin(ang) * r, cy - math.cos(ang) * r)
        g.Visible = true
    end

    -- Cardinal labels
    local labelOff = r + 14
    local labels = {
        { d.NorthLabel, cx,            cy - labelOff },
        { d.EastLabel,  cx + labelOff, cy },
        { d.SouthLabel, cx,            cy + labelOff },
        { d.WestLabel,  cx - labelOff, cy },
    }
    for _, l in ipairs(labels) do
        if l[1] then
            l[1].Position = Vector2.new(l[2], l[3])
            l[1].Visible = true
        end
    end

    -- Center dot
    if d.Center then
        d.Center.Position = Vector2.new(cx, cy)
        d.Center.Visible = true
    end

    -- Player markers
    local myChar = LocalPlayer.Character
    local slot = 0
    local maxDist = math.max(self.RadarRange, 1)
    for model in pairs(self.Objects) do
        slot = slot + 1
        if slot > MAX_RADAR_PLAYERS then break end

        local dot = d.Dots[slot]
        local nameD = d.Names[slot]
        local arr = d.Arrows[slot]

        local function hideSlot()
            if dot then pcall(function() dot.Visible = false end) end
            if nameD then pcall(function() nameD.Visible = false end) end
            for j = 1, 8 do
                if arr and arr[j] then pcall(function() arr[j].Visible = false end) end
            end
        end

        if not myHRP or model == myChar then
            hideSlot()
            continue
        end

        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or not hrp then
            hideSlot()
            continue
        end

        local rel = hrp.Position - myHRP.Position
        local dist = rel.Magnitude
        if dist > self.RadarRange then
            hideSlot()
            continue
        end

        -- World angle on the XZ plane (-Z = 0 = top)
        local ang = math.atan2(rel.X, -rel.Z)
        if not northLock then
            ang = ang - camYaw
        end

        local scale = dist / maxDist * (r - 12)
        local tx = cx + math.sin(ang) * scale
        local ty = cy - math.cos(ang) * scale

        -- Smooth marker movement (keyed by model so slot order changes don't jump)
        local smooth = self._radarSmooth[model]
        if smooth then
            tx = smooth.X + (tx - smooth.X) * SMOOTHING
            ty = smooth.Y + (ty - smooth.Y) * SMOOTHING
        end
        self._radarSmooth[model] = Vector2.new(tx, ty)

        local player = self:GetPlayerFromModel(model)
        local color = self:GetColor(player)
        if self.Enabled.WallCheck then
            local ignore = {}
            if myChar then table.insert(ignore, myChar) end
            table.insert(ignore, model)
            if isCharacterBehindWall(camera.CFrame.Position, model, ignore) then
                color = self.Colors.BehindWall
            end
        end

        -- Marker: mouse-pointer shape (points where the player faces) or plain dot
        if self.RadarShowDirection then
            -- Pointer tip anchored at the marker position, rotated to the facing heading
            if dot then pcall(function() dot.Visible = false end) end
            local look = hrp.CFrame.LookVector
            local heading = math.atan2(look.X, -look.Z)
            if not northLock then heading = heading - camYaw end
            local rot = heading - POINTER_BASE_ANGLE
            local c, s = math.cos(rot), math.sin(rot)
            for j = 1, 8 do
                local line = arr and arr[j]
                if not line then continue end
                local p1 = POINTER_PTS[j]
                local p2 = POINTER_PTS[j % 8 + 1]
                line.From = Vector2.new(
                    tx + (p1[1] * c - p1[2] * s) * POINTER_SCALE,
                    ty + (p1[1] * s + p1[2] * c) * POINTER_SCALE
                )
                line.To = Vector2.new(
                    tx + (p2[1] * c - p2[2] * s) * POINTER_SCALE,
                    ty + (p2[1] * s + p2[2] * c) * POINTER_SCALE
                )
                line.Color = color
                line.Visible = true
            end
        else
            if dot then
                dot.Position = Vector2.new(tx, ty)
                dot.Color = color
                dot.Visible = true
            end
            for j = 1, 8 do
                if arr and arr[j] then pcall(function() arr[j].Visible = false end) end
            end
        end

        -- Name label
        if self.RadarShowNames and nameD then
            nameD.Text = player and player.Name or "Unknown"
            nameD.Position = Vector2.new(tx + 11, ty - 11)
            nameD.Color = color
            nameD.Visible = true
        elseif nameD then
            pcall(function() nameD.Visible = false end)
        end
    end

    -- Hide unused slots
    for i = slot + 1, MAX_RADAR_PLAYERS do
        if d.Dots[i] then pcall(function() d.Dots[i].Visible = false end) end
        for j = 1, 8 do
            if d.Arrows[i] and d.Arrows[i][j] then pcall(function() d.Arrows[i][j].Visible = false end) end
        end
        if d.Names[i] then pcall(function() d.Names[i].Visible = false end) end
    end
end

-- ==================== MAIN RENDER ====================
function ESP:Render()
    if not self._hasDrawing then return end

    -- Master switch: hide everything and skip rendering
    if not self.Enabled.Master then
        for _, obj in pairs(self.Objects) do
            obj:setVisible(false)
        end
        self:_hideRadar()
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for model, obj in pairs(self.Objects) do
        local character = model
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        -- Skip dead targets
        if not humanoid or humanoid.Health <= 0 then
            obj:setVisible(false)
            continue
        end

        local player = self:GetPlayerFromModel(model)

        -- Ẩn ESP của bản thân nếu tính năng ShowSelf không được bật
        if player == LocalPlayer and not self.ShowSelf then
            obj:setVisible(false)
            continue
        end

        -- Kiểm tra đồng đội (bỏ qua bản thân để ShowSelf không bị chặn bởi TeamCheck)
        if self.Enabled.TeamCheck and player and player ~= LocalPlayer and self:IsTeammate(player) then
            obj:setVisible(false)
            continue
        end

        -- Chiếu tọa độ HumanoidRootPart lên màn hình
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            obj:setVisible(false)
            continue
        end
        local hrpScreen, hrpOnScreen, hrpInFront = worldToScreen(hrp.Position)
        -- Chỉ ẩn khi HRP ở sau camera
        if not hrpInFront then
            obj:setVisible(false)
            continue
        end

        -- Tính toán kích thước hộp từ vị trí HRP và khoảng cách tới camera
        local topPos = hrp.Position + Vector3.new(0, BOX_STUD_HEIGHT / 2, 0)
        local botPos = hrp.Position - Vector3.new(0, BOX_STUD_HEIGHT / 2, 0)
        local topScreen, _, topInFront = worldToScreen(topPos)
        local botScreen, _, botInFront = worldToScreen(botPos)

        local minY, maxY, h
        if topInFront and botInFront and botScreen.Y > topScreen.Y then
            minY = topScreen.Y
            maxY = botScreen.Y
            h = maxY - minY
        else
            -- Ước lượng chiều cao theo góc nhìn và cự ly camera nếu một điểm nằm ngoài tầm nhìn trước
            local camDist = (camera.CFrame.Position - hrp.Position).Magnitude
            if camDist < 0.5 then camDist = 0.5 end
            local fovRad = math.rad(camera.FieldOfView)
            h = (BOX_STUD_HEIGHT / (camDist * math.tan(fovRad / 2) * 2)) * camera.ViewportSize.Y
            minY = hrpScreen.Y - h / 2
            maxY = hrpScreen.Y + h / 2
        end

        if h < MIN_BOX_SIZE then
            obj:setVisible(false)
            continue
        end
        local fullW = h * (BOX_STUD_WIDTH / BOX_STUD_HEIGHT)
        local slimW = fullW * 0.7
        local minX = hrpScreen.X - slimW / 2
        local maxX = hrpScreen.X + slimW / 2
        local slimX = minX

        -- Giới hạn hộp theo khung nhìn màn hình
        local vp = camera.ViewportSize
        if minX < 0 then minX = 0 end
        if maxX > vp.X then maxX = vp.X end
        if minY < 0 then minY = 0 end
        if maxY > vp.Y then maxY = vp.Y end
        slimW = maxX - minX
        if slimW < MIN_BOX_SIZE then
            obj:setVisible(false)
            continue
        end
        slimX = minX
        h = maxY - minY

        local color = self:GetColor(player)
        local drawings = obj.Drawings

        -- WallCheck (không áp dụng xuyên tường lên chính bản thân)
        local isBehindWall = false
        if self.Enabled.WallCheck and model ~= myChar then
            isBehindWall = renderWallCheck(drawings, model, slimX, slimW, minY, color, self.Colors.BehindWall)
        else
            if drawings.WallIndicator then drawings.WallIndicator.Visible = false end
        end

        -- Nếu sau tường thì dùng màu ẩn sau tường
        local renderColor = isBehindWall and self.Colors.BehindWall or color

        -- Box 2D
        if self.Enabled.Box2D then
            renderBox2D(drawings, minX, minY, maxX, maxY, renderColor)
        else
            for i = 1, 4 do
                if drawings["Box2D" .. i] then drawings["Box2D" .. i].Visible = false end
            end
            if drawings.Box2DOutline then drawings.Box2DOutline.Visible = false end
        end

        -- Box 3D
        if self.Enabled.Box3D then
            local box3DW = BOX_STUD_WIDTH * 0.7
            local corners = project3DBox(hrp.CFrame, Vector3.new(box3DW, BOX_STUD_HEIGHT, box3DW))
            renderBox3D(drawings, corners, renderColor)
        else
            for i = 1, 12 do
                if drawings["Box3D" .. i] then drawings["Box3D" .. i].Visible = false end
                if drawings["Box3DOutline" .. i] then drawings["Box3DOutline" .. i].Visible = false end
            end
        end

        -- Corner
        if self.Enabled.Corner then
            renderCorner(drawings, slimX, minY, slimX + slimW, maxY, renderColor, self.CornerSize)
        else
            for i = 1, 8 do
                if drawings["Corner" .. i] then drawings["Corner" .. i].Visible = false end
                if drawings["CornerOutline" .. i] then drawings["CornerOutline" .. i].Visible = false end
            end
        end

        -- Skeleton
        if self.Enabled.Skeleton then
            renderSkeleton(drawings, character, renderColor)
        else
            for i = 1, 14 do
                if drawings["Skeleton" .. i] then drawings["Skeleton" .. i].Visible = false end
                if drawings["SkeletonOutline" .. i] then drawings["SkeletonOutline" .. i].Visible = false end
            end
        end

        -- Name
        if self.Enabled.Name then
            renderName(drawings, player, slimX, slimW, minY, renderColor, self.NameMode)
        else
            if drawings.Name then drawings.Name.Visible = false end
        end

        -- Tính toán trước tỷ lệ máu để dùng chung cho HealthBar và HealthText
        local hp = humanoid.Health
        local maxHp = humanoid.MaxHealth
        local ratio = math.clamp(maxHp > 0 and (hp / maxHp) or 0, 0, 1)

        -- Health Bar
        if self.Enabled.HealthBar then
            renderHealthBar(drawings, humanoid, slimX, minY, h, ratio)
        else
            if drawings.Health then drawings.Health.Visible = false end
            if drawings.HealthOutline then drawings.HealthOutline.Visible = false end
        end

        -- Health Text
        if self.Enabled.HealthText then
            renderHealthText(drawings, humanoid, slimX, minY, h, ratio, self.HealthTextFormat, self.Enabled.HealthBar)
        else
            if drawings.HealthText then drawings.HealthText.Visible = false end
        end

        -- Distance (không hiển thị khoảng cách 0m cho chính mình)
        if self.Enabled.Distance and model ~= myChar then
            renderDistance(drawings, model, minY + h, slimX, slimW, renderColor)
        else
            if drawings.Distance then drawings.Distance.Visible = false end
        end

        -- Tracer (không vẽ đường chỉ dẫn vào chính bản thân)
        if self.Enabled.Tracer and model ~= myChar then
            renderTracer(drawings, slimX, slimW, minY, h, renderColor, self.TracerOrigin)
        else
            if drawings.Tracer then drawings.Tracer.Visible = false end
        end

        -- Highlight
        if self.Enabled.Highlight then
            renderHighlight(obj, model, renderColor)
        else
            hideHighlight(obj)
        end

        -- Hide wall indicator if wallcheck disabled
        if not self.Enabled.WallCheck then
            if drawings.WallIndicator then drawings.WallIndicator.Visible = false end
        end
    end

    -- Radar overlay
    if self.Enabled.Radar then
        self:_renderRadar(camera, myHRP)
    else
        self:_hideRadar()
    end
end

-- ==================== AUTO TARGET MANAGEMENT ====================
function ESP:StartAutoManage()
    -- Track player -> character mapping for cleanup on leave
    self._playerCharMap = {}

    -- Add a player's character and keep it updated across respawns
    local function trackCharacter(plr, char)
        -- Drop the previous character of this player (respawn)
        local oldChar = self._playerCharMap[plr]
        if oldChar and oldChar ~= char then
            self:RemoveTarget(oldChar)
        end
        self._playerCharMap[plr] = char
        self:AddTarget(char)
    end

    -- Thêm tất cả người chơi hiện có (bao gồm LocalPlayer để hỗ trợ ShowSelf linh hoạt)
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            trackCharacter(plr, char)
        end
        table.insert(self.Connections, plr.CharacterAdded:Connect(function(newChar)
            task.wait(0.5)
            trackCharacter(plr, newChar)
        end))
    end

    -- Lắng nghe người chơi mới tham gia
    table.insert(self.Connections, Players.PlayerAdded:Connect(function(plr)
        local char = plr.Character
        if char then
            trackCharacter(plr, char)
        end
        table.insert(self.Connections, plr.CharacterAdded:Connect(function(newChar)
            task.wait(0.5)
            trackCharacter(plr, newChar)
        end))
    end))

    -- Listen for player removal
    table.insert(self.Connections, Players.PlayerRemoving:Connect(function(plr)
        local char = self._playerCharMap[plr]
        if char then
            self:RemoveTarget(char)
            self._playerCharMap[plr] = nil
        end
    end))
end

-- ==================== START / STOP ====================
function ESP:Start()
    if self._renderConn then return end
    self._running = true
    self._renderConn = RunService.RenderStepped:Connect(function()
        if not self._running then return end
        pcall(function() self:Render() end)
    end)
end

function ESP:Stop()
    self._running = false
    if self._renderConn then
        self._renderConn:Disconnect()
        self._renderConn = nil
    end
    -- Hide all drawings
    for _, obj in pairs(self.Objects) do
        pcall(function() obj:setVisible(false) end)
    end
    self:_hideRadar()
end

-- ==================== CLEANUP ====================
function ESP:Cleanup()
    self:Stop()

    -- Disconnect events
    for _, conn in ipairs(self.Connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    self.Connections = {}

    -- Disconnect radar drag listeners and drop radar state
    for _, conn in ipairs(self._radarDragConns) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    self._radarDragConns = {}
    self._radar = nil
    self._radarSmooth = {}

    -- Remove all targets
    for model, obj in pairs(self.Objects) do
        for _, drawing in pairs(obj.Drawings) do
            removeDrawing(drawing)
        end
        if obj.HighlightInstance then
            pcall(function() obj.HighlightInstance:Destroy() end)
        end
    end
    self.Objects = {}
end

function ESP:Destroy()
    self:Cleanup()
end

-- ==================== RETURN ====================
return ESP
