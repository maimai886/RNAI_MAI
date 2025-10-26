-- 避障模組
-- 說明：檢測卡住狀態並自動嘗試繞路

-- 避障狀態數據
AvoidState = {
	-- 位置記錄
	lastX = 0,
	lastY = 0,
	lastCheckTime = 0,
	stuckCount = 0,
	
	-- 繞路狀態
	isAvoiding = false,
	avoidDirection = 0,  -- 繞路方向：0=右上, 1=右, 2=右下, 3=下, 4=左下, 5=左, 6=左上, 7=上
	avoidStartTime = 0,
	lastDirectionChangeTime = 0,  -- 上次切換方向的時間
	avoidTarget = 0,
	triedDirections = {},  -- 記錄已嘗試過的方向
	avoidAttempts = 0,  -- 繞路嘗試次數
	
	-- 目標追蹤（按卡住次數判斷是否放棄目標）
	currentTargetId = 0,      -- 當前追擊的目標ID
	targetStuckCount = 0,     -- 對當前目標的總卡住次數
	
	-- 配置
	checkInterval = 500,      -- 檢查間隔（毫秒）- 更快檢測
	stuckThreshold = 2,       -- 卡住閾值（格子）- 更靈敏
	stuckCountLimit = 2,      -- 判定卡住需要的次數
	avoidDuration = 800,      -- 繞路持續時間（毫秒）- 更快切換
	avoidDistance = 5,        -- 繞路距離（格子）- 增加距離
	maxAvoidTime = 8000,      -- 最大繞路時間（毫秒），超過則放棄
	maxAvoidAttempts = 3,     -- 最大嘗試次數
	maxTargetStuckCount = 5,  -- 對同一目標最大卡住次數，超過則放棄目標
}

--- 檢測是否卡住
--- @param myid number 生命體ID
--- @return boolean 是否卡住
function Avoid_IsStuck(myid)
	local currentTime = GetTick()
	local mx, my = GetV(V_POSITION, myid)
	
	-- 定期檢查位置變化
	if currentTime - AvoidState.lastCheckTime >= AvoidState.checkInterval then
		local moved = math.max(
			math.abs(mx - AvoidState.lastX),
			math.abs(my - AvoidState.lastY)
		)
		
		-- 移動距離小於閾值，增加卡住計數
		if moved < AvoidState.stuckThreshold then
			AvoidState.stuckCount = AvoidState.stuckCount + 1
		else
			AvoidState.stuckCount = 0  -- 移動正常，重置
		end
		
		-- 更新位置記錄
		AvoidState.lastX = mx
		AvoidState.lastY = my
		AvoidState.lastCheckTime = currentTime
	end
	
	return AvoidState.stuckCount >= AvoidState.stuckCountLimit
end

--- 計算繞路位置
--- @param myid number 生命體ID
--- @param targetX number 目標X
--- @param targetY number 目標Y
--- @return number, number 繞路目標X, Y
function Avoid_GetDetourPos(myid, targetX, targetY)
	local mx, my = GetV(V_POSITION, myid)
	
	-- 8個方向的偏移（順時針）
	local dirs = {
		{1, 0},   -- 0: 右
		{1, -1},  -- 1: 右上
		{0, -1},  -- 2: 上
		{-1, -1}, -- 3: 左上
		{-1, 0},  -- 4: 左
		{-1, 1},  -- 5: 左下
		{0, 1},   -- 6: 下
		{1, 1}    -- 7: 右下
	}
	
	local dir = dirs[AvoidState.avoidDirection + 1]
	local dist = AvoidState.avoidDistance
	
	-- 繞路位置 = 當前位置 + 方向偏移
	-- 同時稍微朝向目標方向移動
	local toTargetX = targetX - mx
	local toTargetY = targetY - my
	
	local avoidX = mx + dir[1] * dist + (toTargetX > 0 and 1 or (toTargetX < 0 and -1 or 0))
	local avoidY = my + dir[2] * dist + (toTargetY > 0 and 1 or (toTargetY < 0 and -1 or 0))
	
	return avoidX, avoidY
end

--- 選擇最佳繞路方向（基於目標方向）
--- @param myid number 生命體ID
--- @param targetX number 目標X
--- @param targetY number 目標Y
--- @return number 方向索引 (0-7)
function Avoid_ChooseBestDirection(myid, targetX, targetY)
	local mx, my = GetV(V_POSITION, myid)
	local dx = targetX - mx
	local dy = targetY - my
	
	-- 計算到目標的主方向
	local mainDir = 0
	if math.abs(dx) > math.abs(dy) then
		-- 主要是左右移動
		if dx > 0 then
			mainDir = 0  -- 右
		else
			mainDir = 4  -- 左
		end
	else
		-- 主要是上下移動
		if dy > 0 then
			mainDir = 6  -- 下
		else
			mainDir = 2  -- 上
		end
	end
	
	-- 優先選擇順序：主方向的左右兩側，然後是主方向，最後是其他方向
	local tryOrder = {
		(mainDir + 1) % 8,  -- 主方向右側
		(mainDir + 7) % 8,  -- 主方向左側
		mainDir,            -- 主方向
		(mainDir + 2) % 8,  -- 右側+1
		(mainDir + 6) % 8,  -- 左側+1
		(mainDir + 3) % 8,  -- 右側+2
		(mainDir + 5) % 8,  -- 左側+2
		(mainDir + 4) % 8   -- 反方向（最後選擇）
	}
	
	-- 選擇第一個未嘗試過的方向
	for _, dir in ipairs(tryOrder) do
		if not AvoidState.triedDirections[dir] then
			return dir
		end
	end
	
	-- 如果所有方向都試過了，重置並選擇主方向的側面
	return tryOrder[1]
end

--- 避障
--- @param myid number 生命體ID
--- @param targetId number 目標ID
--- @param desiredDist number 期望距離
--- @param oid number 主人ID
--- @return boolean|string 是否完成移動，或 "change_target" 表示應該切換目標
function Avoid_MoveTo(myid, targetId, desiredDist, oid)
	local currentTime = GetTick()
	local mx, my = GetV(V_POSITION, myid)
	local tx, ty = GetV(V_POSITION, targetId)
	local ox, oy = GetV(V_POSITION, oid)
	
	-- 目標不存在
	if tx == nil or ty == nil then
		Avoid_Reset()
		return false
	end
	
	-- 檢查目標是否改變
	if AvoidState.currentTargetId ~= targetId then
		-- 目標改變，重置卡住計數
		AvoidState.currentTargetId = targetId
		AvoidState.targetStuckCount = 0
		LogAI("切換到新目標 ID:" .. targetId, "move")
	end
	
	-- 檢查與主人的距離（嚴格遵循交戰半徑）
	if ox ~= nil and oy ~= nil then
		local distToOwner = math.max(math.abs(ox - mx), math.abs(oy - my))
		local maxDist = RadiusAggr or 12
		
		-- 如果已經距離主人太遠，優先返回主人身邊
		if distToOwner > maxDist then
			if AvoidState.isAvoiding then
				LogAI("繞路時距離主人太遠(" .. distToOwner .. "格，超過交戰半徑" .. maxDist .. "格)，立即返回主人", "move")
				Avoid_Reset()
			end
			-- 直接往主人方向移動
			local x, y = getFreeObjRectPos(oid, myid, 3, oid)
			MoveToDest(myid, x, y)
			return false
		end
	end
	
	-- 檢查是否到達
	local dist = math.max(math.abs(tx - mx), math.abs(ty - my))
	if dist <= desiredDist then
		if AvoidState.isAvoiding then
			LogAI("避障成功，到達目標", "move")
		end
		-- 成功到達，重置目標卡住計數
		AvoidState.targetStuckCount = 0
		Avoid_Reset()
		return true
	end
	
	-- 檢測卡住
	local isStuck = Avoid_IsStuck(myid)
	
	-- 如果卡住或正在繞路中
	if isStuck or AvoidState.isAvoiding then
		-- 剛檢測到卡住，開始繞路
		if isStuck and not AvoidState.isAvoiding then
			-- 增加對當前目標的卡住計數
			AvoidState.targetStuckCount = AvoidState.targetStuckCount + 1
			
			-- 檢查是否卡住次數過多，放棄該目標
			if AvoidState.targetStuckCount > AvoidState.maxTargetStuckCount then
				LogAI("對目標 " .. targetId .. " 卡住次數過多(第" .. AvoidState.targetStuckCount .. "次)，放棄此目標", "move")
				Avoid_Reset()
				AvoidState.targetStuckCount = 0  -- 重置計數，準備切換新目標
				return "change_target"  -- 返回特殊值，通知主程式切換目標
			end
			
			AvoidState.isAvoiding = true
			AvoidState.avoidStartTime = currentTime
			AvoidState.lastDirectionChangeTime = currentTime
			AvoidState.avoidTarget = targetId
			AvoidState.triedDirections = {}  -- 重置已嘗試的方向
			AvoidState.avoidAttempts = 0
			-- 智能選擇繞路方向（基於目標方向）
			AvoidState.avoidDirection = Avoid_ChooseBestDirection(myid, tx, ty)
			AvoidState.triedDirections[AvoidState.avoidDirection] = true
			AvoidState.stuckCount = 0
			LogAI("檢測到卡住(第" .. AvoidState.targetStuckCount .. "次)，開始智能繞路 方向=" .. AvoidState.avoidDirection, "move")
		end
		
		-- 檢查是否繞路次數過多，放棄
		if AvoidState.avoidAttempts >= AvoidState.maxAvoidAttempts then
			LogAI("繞路嘗試次數過多(" .. AvoidState.avoidAttempts .. "次)，放棄繞路", "move")
			Avoid_Reset()
			return false
		end
		
		-- 檢查是否繞路時間過長，放棄
		if currentTime - AvoidState.avoidStartTime >= AvoidState.maxAvoidTime then
			local duration = (currentTime - AvoidState.avoidStartTime) / 1000
			LogAI("繞路時間過長(" .. string.format("%.1f", duration) .. "秒)，放棄繞路", "move")
			Avoid_Reset()
			return false
		end
		
		-- 檢查是否該切換方向了
		if currentTime - AvoidState.lastDirectionChangeTime >= AvoidState.avoidDuration then
			-- 記錄當前方向失敗
			AvoidState.triedDirections[AvoidState.avoidDirection] = true
			AvoidState.avoidAttempts = AvoidState.avoidAttempts + 1
			
			-- 選擇新的方向（智能選擇，避開已嘗試的方向）
			local newDirection = Avoid_ChooseBestDirection(myid, tx, ty)
			AvoidState.avoidDirection = newDirection
			AvoidState.lastDirectionChangeTime = currentTime
			LogAI("切換繞路方向=" .. AvoidState.avoidDirection .. " (嘗試次數:" .. AvoidState.avoidAttempts .. ")", "move")
		end
		
		-- 計算繞路位置
		local avoidX, avoidY = Avoid_GetDetourPos(myid, tx, ty)
		MoveToDest(myid, avoidX, avoidY)
		return false
	end
	
	-- 正常移動
	local x, y = getFreeObjRectPos(targetId, myid, desiredDist, oid)
	MoveToDest(myid, x, y)
	return false
end

--- 重置避障狀態
function Avoid_Reset()
	AvoidState.isAvoiding = false
	AvoidState.avoidTarget = 0
	AvoidState.stuckCount = 0
	AvoidState.triedDirections = {}
	AvoidState.avoidAttempts = 0
end

LogAI("避障模組已載入", "init")

