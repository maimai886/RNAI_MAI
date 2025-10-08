-- 跳舞攻擊模組
-- 說明：
--   在一般攻擊時插入「舞步」行為：短距離移動→攻擊→回位，提升貼身類型輸出與安全性。
-- 設定：
--   - UseDanceAttack：是否啟用（0:停用 / 1:一般舞步 / 2:狂暴舞步）
--   - DanceMinSP：SP 門檻；可為數值（最少 SP）或表 {minPercent,maxPercent}
--   - DanceIntervalMs：舞步行為的最小觸發間隔（毫秒）
--   - MyAttackStanceX/Y：回位站樁點（若為 0 會於首次使用時記錄當前位置）

UseDanceAttack = UseDanceAttack or 0
DanceMinSP = DanceMinSP or 0
DanceIntervalMs = 10
MyAttackStanceX = 0
MyAttackStanceY = 0
local DanceLastTick = 0
local PrevDanceEnemyId = 0 -- 上一次的敵人 ID（用於偵測目標變更）
local BerserkDanceAngle = 0 -- 狂暴舞步角度（用於環繞移動）

-- 局部快取常用全域函數，降低全域表查找成本
local fn_GetV = GetV
local fn_Move = Move
local fn_Attack = Attack
local fn_GetTick = GetTick
local fn_getRectDis = getRectDis
local fn_getObjRectDis = getObjRectDis
local fn_GetDistanceAPR = GetDistanceAPR
local fn_GetMoveBounds = GetMoveBounds
local fn_IsInAttackSight = IsInAttackSight
local fn_Closest = Closest
local fn_IsMonster = IsMonster
local fn_getRectPos = getRectPos

-- 函數：isDanceSpSatisfied（內部）
-- 功能：檢查 SP 是否符合舞步觸發條件（數值或百分比區間）。
-- 參數：myId(number)
-- 回傳：boolean
local function isDanceSpSatisfied(myId)
    local cfg = DanceMinSP or 0
    if type(cfg) == "table" then
        local sp = GetV(V_SP, myId) / GetV(V_MAXSP, myId) * 100
        local minp = cfg[1] or 0
        local maxp = cfg[2] or 100
        return sp >= minp and sp <= maxp
    else
        return GetV(V_SP, myId) >= cfg
    end
end

-- 函數：AdjustCW（內部）
-- 功能：根據與敵人相對位置，回傳順時針調整後的相鄰座標。
-- 參數：x,y 為當前座標；ox,oy 為敵人座標
-- 回傳：(nx, ny)
local function AdjustCW(x, y, ox, oy)
    local dx, dy = x - ox, y - oy
    if math.abs(dx) == math.abs(dy) then
        if dx <= 0 and dy < 0 then return x+1, y end
        if dx < 0  and dy >= 0 then return x,   y-1 end
        if dx >= 0 and dy > 0  then return x-1, y end
        return x, y+1
    else
        if math.abs(dx) < math.abs(dy) then
            if dy < 0 then return x+1, y else return x-1, y end
        else
            if dx < 0 then return x, y-1 else return x, y+1 end
        end
    end
end

-- 函數：AdjustCCW（內部）
-- 功能：根據與敵人相對位置，回傳逆時針調整後的相鄰座標。
-- 參數：x,y 為當前座標；ox,oy 為敵人座標
-- 回傳：(nx, ny)
local function AdjustCCW(x, y, ox, oy)
    local dx, dy = x - ox, y - oy
    if math.abs(dx) == math.abs(dy) then
        if dx <= 0 and dy < 0 then return x,   y+1 end
        if dx < 0  and dy >= 0 then return x+1, y   end
        if dx >= 0 and dy > 0  then return x,   y-1 end
        return x-1, y
    else
        if math.abs(dx) < math.abs(dy) then
            if dy < 0 then return x-1, y else return x+1, y end
        else
            if dx < 0 then return x, y+1 else return x, y-1 end
        end
    end
end

-- 函數：GetDanceCell（內部）
-- 功能：在回位點四周挑選與敵人保持棋王距離 1 的座標，若無則採順/逆時針調整。
-- 參數：stanceX,stanceY 回位座標；enemyId 敵人 ID
-- 回傳：(nx, ny)
local function GetDanceCell(stanceX, stanceY, enemyId)
    local ex, ey = GetV(V_POSITION, enemyId)
    local candidates = {
        {stanceX+1, stanceY},
        {stanceX-1, stanceY},
        {stanceX, stanceY+1},
        {stanceX, stanceY-1}
    }
    for i=1,#candidates do
        local cx, cy = candidates[i][1], candidates[i][2]
        if getRectDis(ex, ey, cx, cy) == 1 then
            return cx, cy
        end
    end
    local r = math.random(2)
    if r == 1 then return AdjustCW(stanceX, stanceY, ex, ey) end
    return AdjustCCW(stanceX, stanceY, ex, ey)
end

-- 函數：GetBerserkDanceCell（內部）
-- 功能：狂暴舞步 - 圍繞敵人做大幅度的環繞移動，讓敵人難以鎖定
-- 參數：enemyId 敵人 ID
-- 回傳：(nx, ny)
local function GetBerserkDanceCell(enemyId)
    local ex, ey = GetV(V_POSITION, enemyId)
    
    -- 更新環繞角度（每次增加45度）
    BerserkDanceAngle = (BerserkDanceAngle + 45) % 360
    
    -- 計算環繞半徑（2-3格範圍）
    local radius = 2 + math.random(0, 1)
    
    -- 將角度轉換為弧度
    local radians = math.rad(BerserkDanceAngle)
    
    -- 計算環繞座標
    local nx = ex + math.floor(radius * math.cos(radians))
    local ny = ey + math.floor(radius * math.sin(radians))
    
    -- 確保座標在合理範圍內
    local mx, my = GetV(V_POSITION, GetV(V_OWNER, enemyId))
    local distance = getRectDis(mx, my, nx, ny)
    if distance > 12 then
        -- 如果距離主人太遠，調整到較近的位置
        local angle = math.atan2(ny - ey, nx - ex)
        radius = math.min(radius, 2)
        nx = ex + math.floor(radius * math.cos(angle))
        ny = ey + math.floor(radius * math.sin(angle))
    end
    
    return nx, ny
end

-- 函數：DanceAttack_TryExecute
-- 功能：嘗試執行舞步（節流、距離與視野檢查），流程：移動→攻擊→回位。
-- 參數：
--   myId(number)    生命體/傭兵 ID
--   enemyId(number) 目標敵人 ID
--   ownerId(number) 玩家 ID
-- 回傳：boolean 是否有執行舞步
function DanceAttack_TryExecute(myId, enemyId, ownerId)
    if UseDanceAttack == 0 then return end
    if enemyId == nil or enemyId <= 0 then return end
    if fn_GetV(V_HOMUNTYPE, myId) == nil then return end
    if not isDanceSpSatisfied(myId) then return end

	-- 手動移動/原地待命期間不執行舞步，避免干擾普通移動
	if MyState == ST_MOVE_CMD or MyState == ST_HOLD then return false end

	-- 僅對怪物執行舞步，避免把玩家/友方當作目標導致奇怪移動
	if IsMonster and IsMonster(enemyId) ~= 1 then return false end

    local now = fn_GetTick()
	if DanceLastTick ~= 0 and (now - DanceLastTick) < DanceIntervalMs then return false end

	-- 一次性取得必要座標與距離，避免重複計算
	local ox, oy = fn_GetV(V_POSITION, ownerId)
	local mx, my = fn_GetV(V_POSITION, myId)
	local ex, ey = fn_GetV(V_POSITION, enemyId)
	local ownerEnemyDis = fn_getRectDis(ox, oy, ex, ey)
	local meEnemyDis = fn_getRectDis(mx, my, ex, ey)
	if ownerEnemyDis >= 13 then return false end
	if meEnemyDis > AtkDis then return false end

	-- 目標變更時重設站樁點（避免沿用遠處）
	if enemyId ~= PrevDanceEnemyId then
		MyAttackStanceX, MyAttackStanceY = 0, 0
		PrevDanceEnemyId = enemyId
	end

    local nx, ny
    
    if UseDanceAttack == 2 then
        -- 狂暴舞步模式：圍繞敵人做大幅度環繞移動
        nx, ny = GetBerserkDanceCell(enemyId)
    else
        -- 一般舞步模式：在回位點附近小範圍移動
        if MyAttackStanceX == 0 or MyAttackStanceX == nil then
            MyAttackStanceX, MyAttackStanceY = mx, my
        end
        nx, ny = GetDanceCell(MyAttackStanceX, MyAttackStanceY, enemyId)
    end

    if fn_IsInAttackSight and fn_IsInAttackSight(myId, enemyId) == false then
        local tx, ty = fn_Closest and fn_Closest(myId, ex, ey, 1, nil)
        if tx and ty then nx, ny = tx, ty end
    end

	    if fn_GetDistanceAPR and fn_GetMoveBounds then
	        if fn_GetDistanceAPR(ownerId, nx, ny) >= fn_GetMoveBounds() then return false end
    end

	    if fn_getRectDis(ox, oy, nx, ny) > 15 then return false end

    fn_Move(myId, nx, ny)
    fn_Attack(myId, enemyId)
    
    if UseDanceAttack == 2 then
        -- 狂暴舞步模式：不回位，持續環繞移動
        -- 不需要回位邏輯
    else
        -- 一般舞步模式：將本次攻擊位置設定為新的站樁點（記憶貼怪位置）
        MyAttackStanceX, MyAttackStanceY = nx, ny
        -- 若仍緊貼敵人則不回位；離開時最多後退 1 格
        do
            local cx, cy = fn_GetV(V_POSITION, myId)
            local stickEnemy = fn_getObjRectDis and (fn_getObjRectDis(myId, enemyId) <= 1) or (fn_getRectDis(cx, cy, ex, ey) <= 1)
            if not stickEnemy then
                if fn_getRectPos then
                    local rx, ry = fn_getRectPos(cx, cy, MyAttackStanceX, MyAttackStanceY, 1)
                    fn_Move(myId, rx, ry)
                else
                    fn_Move(myId, MyAttackStanceX, MyAttackStanceY)
                end
            end
        end
    end
    DanceLastTick = now
    return true
end


