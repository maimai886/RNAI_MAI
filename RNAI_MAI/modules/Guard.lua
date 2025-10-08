-- 守衛與轉圈模組
-- 說明：
--   提供兩種行為輔助：
--   1) 守衛模式：依玩家面向方向，保持在玩家前方指定距離。
--   2) 轉圈模式：依時間步進，於玩家周圍固定半徑位置循環移動。
-- 設定：
--   可由外部（例如 `HomCfg.lua`）覆寫下列參數：
--   - GuardUpdateInterval：守衛位置的重新計算間隔（毫秒）
--   - CircleUpdateInterval：轉圈位置的重新計算間隔（毫秒）
--   - CircleStepMs：轉圈步進的時間步長（毫秒）

-- 方位偏移常數（避免每次建立表）：用於從玩家中心位置向外偏移目標點
local DIR_OFFSETS_GUARD = {
	{0, -1},   -- 上 (0)
	{1, -1},   -- 右上 (1)
	{1, 0},    -- 右 (2)
	{1, 1},    -- 右下 (3)
	{0, 1},    -- 下 (4)
	{-1, 1},   -- 左下 (5)
	{-1, 0},   -- 左 (6)
	{-1, -1}   -- 左上 (7)
}

-- 轉圈偏移常數（順時針）：圍繞玩家 8 個方位的相對偏移
local DIR_OFFSETS_CIRCLE = {
	{-1, -1},   -- 左上 (0)
	{0, -1},    -- 上 (1)
	{1, -1},    -- 右上 (2)
	{1, 0},     -- 右 (3)
	{1, 1},     -- 右下 (4)
	{0, 1},     -- 下 (5)
	{-1, 1},    -- 左下 (6)
	{-1, 0}     -- 左 (7)
}

-- 更新間隔與步進（可被外部設定覆蓋）
GuardUpdateInterval = GuardUpdateInterval or 100
CircleUpdateInterval = CircleUpdateInterval or 100
CircleStepMs = CircleStepMs or 1000

-- 模組內部快取狀態：用於節流計算，避免每個 tick 都重算
local guardLastTick = 0
local circleLastTick = 0
local circleLastIndex = 1

-- 玩家方向檢測快取：記錄上次玩家位置、方向與時間戳
local OwnerLastPos = {x=0, y=0, tick=0}
local OwnerDirection = 0 -- (0-7)

-- 計算玩家移動方向
-- 參數：
--   oid(number) 玩家物件 ID
-- 回傳：
--   number（0~7）：對應八方向（0:上,1:右上,2:右,3:右下,4:下,5:左下,6:左,7:左上）
-- 說明：
--   - 以位置變化的符號快速判斷方向；
--   - 100ms 以內重複呼叫時回傳上次方向以節流；
--   - 不移動時維持上次方向並更新時間戳。
function calculateOwnerDirection(oid)
	local ox, oy = GetV(V_POSITION, oid)
	local currentTick = GetTick()
	if OwnerLastPos.tick ~= 0 and currentTick - OwnerLastPos.tick < 100 then
		return OwnerDirection
	end
	local dx = ox - OwnerLastPos.x
	local dy = oy - OwnerLastPos.y
	if dx == 0 and dy == 0 then
		OwnerLastPos.tick = currentTick
		return OwnerDirection
	end
	local sx = (dx > 0) and 1 or ((dx < 0) and -1 or 0)
	local sy = (dy > 0) and 1 or ((dy < 0) and -1 or 0)
	local direction
	if sx == 0 and sy == -1 then
		direction = 0
	elseif sx == 1 and sy == -1 then
		direction = 1
	elseif sx == 1 and sy == 0 then
		direction = 2
	elseif sx == 1 and sy == 1 then
		direction = 3
	elseif sx == 0 and sy == 1 then
		direction = 4
	elseif sx == -1 and sy == 1 then
		direction = 5
	elseif sx == -1 and sy == 0 then
		direction = 6
	else
		direction = 7
	end
	OwnerLastPos.x = ox
	OwnerLastPos.y = oy
	OwnerLastPos.tick = currentTick
	OwnerDirection = direction
	return direction
end

-- 取得守衛位置（玩家前方固定距離）
-- 參數：
--   myid(number)  生命體/傭兵 ID
--   oid(number)   玩家 ID
-- 回傳：
--   (tx, ty) or (nil, nil)
--   - 當需要移動（與目標點棋王距離 > 1）時，回傳目標座標；
--   - 否則回傳 nil, nil 表示可維持現狀。
-- 副作用：
--   使用內部快取 guardLastTick 節流計算頻率。
function getGuardPosition(myid, oid)
	local ox, oy = GetV(V_POSITION, oid)
	local mx, my = GetV(V_POSITION, myid)
	local now = GetTick()
	if guardLastTick ~= 0 and now - guardLastTick < GuardUpdateInterval then
		local direction = OwnerDirection
		local guardDistance = GuardDistance or 6
		local off = DIR_OFFSETS_GUARD[direction + 1]
		local tx = ox + off[1] * guardDistance
		local ty = oy + off[2] * guardDistance
		local manhattan = math.abs(mx - tx) + math.abs(my - ty)
		if manhattan > 1 then
			return tx, ty
		end
		return nil, nil
	end
	guardLastTick = now
	local direction = calculateOwnerDirection(oid)
	local guardDistance = GuardDistance or 6
	local off = DIR_OFFSETS_GUARD[direction + 1]
	local targetX = ox + off[1] * guardDistance
	local targetY = oy + off[2] * guardDistance
	local manhattan = math.abs(mx - targetX) + math.abs(my - targetY)
	if manhattan > 1 then
		return targetX, targetY
	end
	return nil, nil
end

-- 取得轉圈位置（玩家周圍固定半徑，隨時間步進）
-- 參數：
--   myid(number)  生命體/傭兵 ID
--   oid(number)   玩家 ID
-- 回傳：
--   (tx, ty) or (nil, nil)
--   - 當需要移動（與目標點棋王距離大於門檻）時，回傳目標座標；
--   - 否則回傳 nil, nil。
-- 說明：
--   - 以 `CircleStepMs` 控制 8 個方位的步進速度；
--   - 門檻會依 `GuardDistance` 調整，距離越大門檻越寬。
function getCirclePosition(myid, oid)
	local ox, oy = GetV(V_POSITION, oid)
	local mx, my = GetV(V_POSITION, myid)
	local now = GetTick()
	if circleLastTick ~= 0 and now - circleLastTick < CircleUpdateInterval then
		local guardDistance = GuardDistance or 6
		local off = DIR_OFFSETS_CIRCLE[circleLastIndex]
		local tx = ox + off[1] * guardDistance
		local ty = oy + off[2] * guardDistance
		local manhattan = math.abs(mx - tx) + math.abs(my - ty)
		if manhattan > 1 then
			return tx, ty
		end
		return nil, nil
	end
	circleLastTick = now
	local guardDistance = GuardDistance or 6
	local positionIndex = math.floor((now / CircleStepMs) % 8) + 1
	circleLastIndex = positionIndex
	local off = DIR_OFFSETS_CIRCLE[positionIndex]
	local targetX = ox + off[1] * guardDistance
	local targetY = oy + off[2] * guardDistance
	local manhattan = math.abs(mx - targetX) + math.abs(my - targetY)
	local threshold = 1
	if guardDistance <= 3 then
		threshold = 1
	elseif guardDistance <= 6 then
		threshold = 2
	else
		threshold = 3
	end
	if manhattan > threshold then
		return targetX, targetY
	end
	return nil, nil
end


