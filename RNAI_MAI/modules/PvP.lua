-- PvP 模組
-- 說明：
--   提供 PvP 模式下的玩家識別與攻擊優先級判斷。
--   支援三種模式：
--     1. 無差別模式（PvPMode=1）：攻擊所有玩家，可設定優先職業
--     2. 狙擊模式（PvPMode=2）：只攻擊玩家主動指定的目標（生命體的技能或普攻標記的目標）
-- 設定：
--   - PvPMode：PvP 模式（0:關閉 / 1:無差別 / 2:狙擊），需在 HomCfg.lua 設定
--   - PvPTargetJobs：優先攻擊的職業列表（僅在模式1有效），需在 HomCfg.lua 設定

-- 狙擊目標資料檔案
local SNIPER_FILE = "./AI/USER_AI/RNAI_MAI/custom/sniper_targets.lua"

-- 玩家職業列表（用於 PvP 模式）
PLAYER_JOBS = {
	[0] = "初心者",
	[1] = "劍士", [2] = "法師", [3] = "弓手", [4] = "服事", [5] = "商人", [6] = "盜賊",
	[8] = "祭司", [9] = "巫師", [10] = "鐵匠", [11] = "獵人", [12] = "刺客", [13] = "騎士",
	[16] = "智者", [17] = "流氓", [18] = "鍊金術師", [19] = "詩人", [20] = "舞娘", [21] = "十字軍"
}

--- 檢查是否啟用 PvP 模式（包含無差別和狙擊模式）
--- @return boolean 是否啟用 PvP
function IsPvPEnabled()
	return (PvPMode ~= nil and (PvPMode == 1 or PvPMode == 2))
end

--- 檢查是否為狙擊模式
--- @return boolean 是否為狙擊模式
function IsSniperMode()
	return (PvPMode ~= nil and PvPMode == 2)
end

--- 從文件讀取狙擊目標列表
--- @return table 狙擊目標列表
function GetSniperTargets()
	local targets = {}
	local success, err = pcall(function()
		if file_exist(SNIPER_FILE) then
			dofile(SNIPER_FILE)
			if sniperTargets ~= nil then
				targets = sniperTargets
			end
		end
	end)
	if not success then
		LogAI("讀取狙擊目標時發生錯誤: " .. tostring(err), "pvp")
	end
	return targets
end

--- 檢查指定物件是否為 PvP 攻擊目標
--- @param actorId number 物件ID
--- @param myid number 生命體ID
--- @param oid number 主人ID
--- @return boolean 是否為 PvP 目標
function IsPvPTarget(actorId, myid, oid)
	-- 如果未啟用 PvP，直接返回 false
	if not IsPvPEnabled() then
		return false
	end
	
	-- 檢查是否為非怪物（玩家類型）
	local isPlayerLike = (IsMonster(actorId) == 0)
	if not isPlayerLike then
		return false
	end
	
	-- 排除自己、主人和好友
	if actorId == myid or actorId == oid then
		return false
	end
	
	if tb_exist(GetFriendsList(), actorId) then
		return false
	end
	
	-- 狙擊模式：攻擊記錄的目標 + 主人正在攻擊的玩家
	if IsSniperMode() then
		-- 從文件讀取最新的狙擊目標列表
		local targets = GetSniperTargets()
		
		-- 檢查是否在狙擊列表中
		for i, target in ipairs(targets) do
			local targetId = type(target) == "table" and target.id or target
			if targetId == actorId then
				LogAI("PvP狙擊目標（列表中）: ID=" .. tostring(actorId), "pvp")
				return true
			end
		end
		
		-- 檢查是否為主人正在攻擊/施法的目標
		local ownerTarget = GetV(V_TARGET, oid)
		if ownerTarget ~= nil and ownerTarget == actorId then
			local ownerMotion = GetV(V_MOTION, oid)
			LogAI("PvP狙擊目標（主人正在攻擊）: ID=" .. tostring(actorId) .. " 主人動作=" .. tostring(ownerMotion), "pvp")
			return true
		end
		
		return false
	end
	
	-- 無差別模式：所有玩家都可以被攻擊（優先級由評分系統決定）
	local jobType = GetV(V_HOMUNTYPE, actorId)
	if jobType ~= nil and PLAYER_JOBS[jobType] ~= nil then
		LogAI("PvP目標: ID=" .. tostring(actorId) .. " 職業=" .. PLAYER_JOBS[jobType] .. " (編號:" .. tostring(jobType) .. ")", "pvp")
	else
		LogAI("PvP目標: ID=" .. tostring(actorId) .. " 職業=未知", "pvp")
	end
	
	return true
end

--- 檢查指定物件是否為優先攻擊的職業
--- @param actorId number 物件ID
--- @return boolean 是否為優先職業
function IsPriorityPvPTarget(actorId)
	-- 如果未啟用 PvP，直接返回 false
	if not IsPvPEnabled() then
		return false
	end
	
	-- 如果 PvPTargetJobs 為空，則不區分優先級
	if PvPTargetJobs == nil or #PvPTargetJobs == 0 then
		return false
	end
	
	-- 檢查是否為優先職業
	local jobType = GetV(V_HOMUNTYPE, actorId)
	if jobType ~= nil and (PvPTargetJobs[jobType] ~= nil or tb_exist(PvPTargetJobs, jobType)) then
		LogAI("PvP優先目標: ID=" .. tostring(actorId) .. " 職業=" .. (PLAYER_JOBS[jobType] or tostring(jobType)), "pvp")
		return true
	end
	
	return false
end


-- ==================== 狙擊模式相關功能 ====================

--- 處理玩家攻擊指令（在狙擊模式下記錄目標）
--- @param targetId number 攻擊目標ID
--- @param skillId number 技能ID（0為普攻）
--- @param myid number 生命體ID
--- @param oid number 主人ID
--- @return nil
function Sniper_HandleAttackCommand(targetId, skillId, myid, oid)
	-- 只在狙擊模式下處理
	if not IsSniperMode() then
		return
	end
	
	LogAI("狙擊模式：目標ID=" .. tostring(targetId) .. " 技能ID=" .. tostring(skillId) .. " 生命體ID=" .. tostring(myid) .. " 主人ID=" .. tostring(oid), "pvp")
	-- 檢查目標是否有效
	if targetId == nil or targetId <= 0 then
		return
	end
	
	-- 特殊操作：使用狙擊技能點玩家 = 清空所有狙擊名單
	if targetId == oid then
		-- 檢查是否為狙擊標記技能
		local isMarkSkill = false
		if SniperMarkSkills == nil or #SniperMarkSkills == 0 then
			-- 列表為空：任何技能都可以清空
			isMarkSkill = true
		else
			-- 列表有值：只有指定技能可以清空
			isMarkSkill = (SniperMarkSkills[skillId] ~= nil or tb_exist(SniperMarkSkills, skillId))
		end
		
		if isMarkSkill then
			Sniper_ClearTargets()
			LogAI("玩家對自己使用狙擊技能，已清空所有狙擊目標", "pvp")
		end
		return
	end
	
	-- 檢查是否為玩家（非怪物、非自己、非生命體、非好友、V_HOMUNTYPE < 50）
	if IsMonster(targetId) == 0 and 
	   targetId ~= oid and 
	   targetId ~= myid and
	   not tb_exist(GetFriendsList(), targetId) and
	   GetV(V_HOMUNTYPE, targetId) < 50 then
		
		-- 檢查技能是否在標記列表中
		local isMarkSkill = false
		if SniperMarkSkills == nil or #SniperMarkSkills == 0 then
			-- 列表為空：任何技能都可以標記
			isMarkSkill = true
		else
			-- 列表有值：檢查技能是否在列表中
			isMarkSkill = (SniperMarkSkills[skillId] ~= nil or tb_exist(SniperMarkSkills, skillId))
		end
		
		-- 記錄狙擊目標
		if isMarkSkill then
			-- 從文件讀取現有目標列表
			local targets = GetSniperTargets()
			
			-- 檢查是否已存在
			local exists = false
			for i, target in ipairs(targets) do
				local id = type(target) == "table" and target.id or target
				if id == targetId then
					exists = true
					break
				end
			end
			
			if not exists then
				-- 立即查詢職業
				local jobType = GetV(V_HOMUNTYPE, targetId) or -1
				
				-- 追加到列表末尾
				targets[#targets+1] = {id = targetId, job = jobType}
				
				-- 寫回文件
				local success = pcall(function()
					local file = io.open(SNIPER_FILE, "w")
					if file then
						file:write("-- 狙擊目標持久化文件\n")
						file:write("-- 自動生成，請勿手動修改\n")
						file:write("-- 格式：{id = ID, job = 職業編號}\n\n")
						file:write("sniperTargets = {\n")
						for i, target in ipairs(targets) do
							local tid, tjob
							if type(target) == "table" then
								tid, tjob = target.id, target.job or -1
							else
								tid, tjob = target, -1
							end
							local jobName = "未知"
							if tjob >= 0 and PLAYER_JOBS[tjob] then
								jobName = PLAYER_JOBS[tjob] .. "(" .. tjob .. ")"
							elseif tjob >= 0 then
								jobName = "職業編號:" .. tjob
							end
							file:write("  {id = " .. tid .. ", job = " .. tjob .. "}, -- " .. jobName .. "\n")
						end
						file:write("}\n")
						file:close()
					end
				end)
				
				local jobName = "未知"
				if jobType >= 0 and PLAYER_JOBS[jobType] then
					jobName = PLAYER_JOBS[jobType]
				elseif jobType >= 0 then
					jobName = "職業" .. jobType
				end
				LogAI("已記錄狙擊目標: ID=" .. tostring(targetId) .. " 職業=" .. jobName .. " (技能ID:" .. tostring(skillId) .. ")", "pvp")
			end
		end
	end
end

--- 清空狙擊目標清單
--- @return nil
function Sniper_ClearTargets()
	-- 直接寫入空列表到文件
	local success = pcall(function()
		local file = io.open(SNIPER_FILE, "w")
		if file then
			file:write("-- 狙擊目標持久化文件\n")
			file:write("-- 自動生成，請勿手動修改\n")
			file:write("-- 格式：{id = ID, job = 職業編號}\n\n")
			file:write("sniperTargets = {\n")
			file:write("}\n")
			file:close()
		end
	end)
	LogAI("已清空所有狙擊目標", "pvp")
end

--- 取得狙擊目標數量
--- @return number 狙擊目標數量
function Sniper_GetTargetCount()
	local targets = GetSniperTargets()
	return #targets
end

