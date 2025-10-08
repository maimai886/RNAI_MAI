-- 本檔案包含戰場物件與管理

-- 怪物清單：關聯陣列，key為怪物ID，value為怪物資料陣列
-- 怪物資料格式：{怪物ID, 此魔物攻擊對象ID, 其他人攻擊此魔物的時間, 是否在視線內(RefreshKey|-1), 分數}
Mobs={}

-- 掃描標記：每次呼叫RefreshData會在0~29999循環變換，用以判斷物件是否已經不在範圍
RefreshKey=0

-- 上次更新時間：用於節流控制，避免過於頻繁的更新
RefreshTime=0

-- 敵人計數器
nOwnerEnemy=0 -- 正在攻擊主人的敵人數量
nMyEnemy=0 -- 正在攻擊生命體的敵人數量
nRangeEnemy=0 -- 在主人攻擊範圍內的敵人數量

-- 最佳攻擊目標：分數最高的怪物ID
bestTarget=0

-- 其他物件清單：非怪物、非朋友的其他物件ID清單
others={}

--- 判斷是否為主動模式
--- @return boolean 是否為主動模式
function IsActiveMode()
	for j = 1, 8 do
		if SearchSetting[j] ~= SearchMode[2][j] then
			return false
		end
	end
	return true
end

--- 獲取好友清單
--- @return table 好友清單
function GetFriendsList()
	-- 如果 friends 變數不存在，從文件載入
	if friends == nil then
		local success, err = pcall(function()
			local friendsFile = "./AI/USER_AI/RNAI_MAI/custom/friends_data.lua"
			if file_exist(friendsFile) then
				dofile(friendsFile)
			else
				friends = {}
			end
		end)
		if not success then
			friends = {}
		end
	end
	return friends
end

--- 輸出 GetActors 詳細資訊的函數
--- @param myid number 生命體ID
--- @param oid number 主人ID
--- @param title string 輸出標題（可選）
--- @return nil
function DebugGetActors(myid, oid, title)
	title = title or "GetActors 詳細資訊"
	local A = GetActors()
	TraceAI("=== " .. title .. " ===")
	TraceAI("GetActors 數量: " .. tostring(#A))
	TraceAI("GetActors 內容展開:")
	
	for i, actorId in ipairs(A) do
		local x, y = GetV(V_POSITION, actorId)
		local motion = GetV(V_MOTION, actorId)
		local target = GetV(V_TARGET, actorId)
		local homunType = GetV(V_HOMUNTYPE, actorId)
		local type = GetV(V_TYPE, actorId)
		local isMonster = IsMonster(actorId)
		local hp = GetV(V_HP, actorId)
		local maxHp = GetV(V_MAXHP, actorId)
		local owner = GetV(V_OWNER, actorId)
		
		-- 判斷物件身份
		local identity = ""
		if actorId == myid then
			identity = "[生命體]"
		elseif actorId == oid then
			identity = "[主人]"
		elseif isMonster == 1 then
			identity = "[怪物]"
		else
			identity = "[其他]"
		end
		
		TraceAI("  [" .. i .. "] " .. identity .. " 流水號=" .. tostring(actorId) .. 
			" 位置=(" .. tostring(x) .. "," .. tostring(y) .. ")" ..
			" 動作=" .. tostring(motion) ..
			" 目標=" .. tostring(target) ..
			" ID=" .. tostring(homunType) ..
			" 物件類型=" .. tostring(type) ..
			" 怪物=" .. tostring(isMonster) ..
			" HP=" .. tostring(hp) .. "/" .. tostring(maxHp) ..
			" 主人=" .. tostring(owner))
	end
	TraceAI("=== " .. title .. " 結束 ===")
end

--- 檢查並輸出好友清單
--- @param myid number 生命體ID
--- @param oid number 主人ID
--- @return nil
function DebugFriends(myid, oid)
	local friendsList = GetFriendsList()
	TraceAI("=== 好友清單檢查 ===")
	TraceAI("好友數量: " .. tostring(#friendsList))
	
	if #friendsList == 0 then
		TraceAI("好友清單為空")
	else
		TraceAI("好友清單內容:")
		for i, friendId in ipairs(friendsList) do
			-- 檢查 friendId 是否為有效數字，避免 GetV 錯誤
			if type(friendId) == "number" then
				local x, y = GetV(V_POSITION, friendId)
				local motion = GetV(V_MOTION, friendId)
				local target = GetV(V_TARGET, friendId)
				local homunType = GetV(V_HOMUNTYPE, friendId)
				local isMonster = IsMonster(friendId)
				local hp = GetV(V_HP, friendId)
				local maxHp = GetV(V_MAXHP, friendId)
				local owner = GetV(V_OWNER, friendId)
				
				-- 判斷好友身份
				local identity = ""
				if friendId == myid then
					identity = "[生命體]"
				elseif friendId == oid then
					identity = "[主人]"
				elseif isMonster == 1 then
					identity = "[怪物]"
				else
					identity = "[其他]"
				end
				
				TraceAI("  好友[" .. i .. "] " .. identity .. " ID=" .. tostring(friendId) .. 
					" 位置=(" .. tostring(x) .. "," .. tostring(y) .. ")" ..
					" 動作=" .. tostring(motion) ..
					" 目標=" .. tostring(target) ..
					" 類型=" .. tostring(homunType) ..
					" 怪物=" .. tostring(isMonster) ..
					" HP=" .. tostring(hp) .. "/" .. tostring(maxHp) ..
					" 主人=" .. tostring(owner))
			else
				TraceAI("  好友[" .. i .. "] 無效ID: " .. tostring(friendId))
			end
		end
	end
	TraceAI("=== 好友清單檢查結束 ===")
end

--- 檢查指定座標是否有怪物
--- @param x number 要檢查的X座標
--- @param y number 要檢查的Y座標
--- @return number|false 該座標的怪物ID，無則回傳false
function XYInMobs(x,y)
	local a,b
	local Objs=GetActors()
	for i,v in ipairs(Objs)do
		a,b=GetV(V_POSITION,v)
		if(a==x and b==y)then
			return v
		end
	end
	return false
end
--- 清除當前最佳目標
--- @return nil
function RemoveTarget()
	if bestTarget~=0 and Mobs[bestTarget]~=nil then
Mobs[bestTarget] = nil
	end
	bestTarget = 0
end


--- 更新戰場情報與目標評分系統
--- @param myid number 生命體ID
--- @param oid number 主人ID
--- @return nil
--- @note 每333ms執行一次，避免效能問題
function RefreshData(myid,oid)
	local t=GetTick() -- 取得當前時間戳
	local isActiveMode = IsActiveMode() -- 判斷是否為主動模式

	if(t-RefreshTime>333)then -- 節流控制：每1/3秒更新一次，降低計算消耗
		RefreshTime=t -- 更新上次執行時間
	else
		return -- 未到更新時間，直接返回
	end
	
	nOwnerEnemy=0 -- 重置主人被攻擊的敵人數量
	nMyEnemy=0 -- 重置生命體被攻擊的敵人數量
	nRangeEnemy=0 -- 重置範圍內敵人數量
	RefreshKey=(RefreshKey+1)%30000 -- 更新掃描標記，用於判斷物件是否過期
	local A=GetActors() -- 取得視線內所有物件
	local enablePvP = (PvPMode~=nil and PvPMode==1)
	-- 輸出 GetActors 內容
	DebugGetActors(myid, oid, "RefreshData 掃描")
	-- 檢查好友清單
	DebugFriends(myid, oid)
	
	local idx,tar,isignored,isfriend,mobTypeId -- 宣告區域變數
	others={} -- 清空其他物件清單
	local otar,mtar=GetV(V_TARGET,oid),GetV(V_TARGET,myid) -- 取得主人和生命體的攻擊目標
	-- 第一階段：掃描所有物件，分類為怪物或（在PvP模式下）玩家，其他物件歸為others
	for i,v in ipairs(A)do -- 遍歷視線內所有物件
		mobTypeId=GetV(V_HOMUNTYPE,v) -- 取得物件的怪物類型ID（玩家/NPC將為nil）
		-- 忽略清單（特定目標；支援列表與鍵值表；資料來自 HomCfg.lua 的 IgnoreTargets）
		isignored = (mobTypeId~=nil and IgnoreTargets~=nil and (IgnoreTargets[mobTypeId]~=nil or tb_exist(IgnoreTargets,mobTypeId))) and true or false
		-- 指定攻擊模式檢查：若TargetMonsters有值，只攻擊清單中的怪物
		local isTargetMode = (TargetMonsters~=nil and #TargetMonsters>0)
		local isInTargetList = (isTargetMode and mobTypeId~=nil and (TargetMonsters[mobTypeId]~=nil or tb_exist(TargetMonsters,mobTypeId))) and true or false
		-- PvP 模式
		local isPlayerLike = (IsMonster(v)==0)
		local isActivePlayer = false
		
		-- 如果是非怪物且啟用PvP，檢查是否為活躍玩家
		if enablePvP and isPlayerLike and v~=oid and v~=myid and tb_exist(GetFriendsList(),v)==false then
			local motion = GetV(V_MOTION, v)
			local target = GetV(V_TARGET, v)
			
			-- 檢查是否有活動跡象：移動、攻擊、放技能或有攻擊目標
			if motion==MOTION_MOVE or motion==MOTION_RUN or
			   motion==MOTION_ATTACK or motion==MOTION_ATTACK2 or motion==MOTION_ATTACK3 or
			   motion==MOTION_SKILL or motion==MOTION_SKILL2 or motion==MOTION_SKILL3 or
			   (target>0 and IsMonster(target)==1) then
				isActivePlayer = true
			end
		end
		
		-- 判斷是否加入Mobs清單：
		-- 1) 怪物：非忽略 + (非指定模式 或 在指定清單中)
		-- 2) 玩家（PvP）：啟用PvP + 活躍玩家
		if( (IsMonster(v)==1 and isignored==false and (not isTargetMode or isInTargetList))
			or (enablePvP and isActivePlayer) ) then
			if(GetV(V_MOTION,v)~=MOTION_DEAD)then -- 檢查存活
				if Mobs[v]==nil then -- 未在清單則加入
					Mobs[v]={v,0,0,0}
				end
				Mobs[v][4]=(getObjRectDis(oid,v)>14) and -1 or RefreshKey -- 視線標記
				tar=GetV(V_TARGET,v)
				if(tar>0 and IsMonster(tar)==0)then
					-- 檢查是否攻擊朋友，如果是則從Mobs清單中移除
					if(tb_exist(GetFriendsList(),tar))then
						Mobs[v]=nil -- 攻擊朋友，不加入清單
					else
						Mobs[v][2]=tar
						if(tar==myid)then nMyEnemy=nMyEnemy+1
						elseif(tar==oid)then nOwnerEnemy=nOwnerEnemy+1 end
					end
				end
				if(getObjRectDis(oid,v)<=RadiusAggr)then nRangeEnemy=nRangeEnemy+1 end
			end
		elseif(v~=oid and v~=myid and tb_exist(GetFriendsList(),v)==false)then
			others[#others+1]=v
		end
	end
	-- 第二階段：清理過期的怪物資料
	for k,mobInfo in pairs(Mobs) do
		if mobInfo[4]~=RefreshKey then
			Mobs[k]=nil
		end
	end
	-- 第三階段：更新怪物被其他玩家攻擊的時間記錄
	for i,v in ipairs(others)do
		tar=GetV(V_TARGET,v)
		if(tar>0 and IsMonster(tar)==1)then
			if(Mobs[tar]~=nil)then
				Mobs[tar][3]=t
			end
		end
	end
	-- 第四階段：計算每個怪物的攻擊優先權分數
	local max_score,score=-1,0
	local d1,d2
	bestTarget=0
	
	-- 守衛模式：尋找離玩家最近的怪物
	local nearestMonster = nil
	local nearestDistance = 999
	if(GuardMode~=0)then
		for i,v in pairs(Mobs)do
			d1=getObjRectDis(oid,v[1])
			if d1 < nearestDistance then
				nearestDistance = d1
				nearestMonster = i
			end
		end
	end
	
	-- 第五階段：計算每個怪物的攻擊優先權分數
	for i,v in pairs(Mobs)do
		-- 計算距離
		d1=getObjRectDis(oid,v[1])
		d2=getObjRectDis(myid,v[1])
		
		-- 取得怪物類型ID
		local mobTypeId = GetV(V_HOMUNTYPE,i)
		
		-- 初始化分數為0
		score = 0
		
		-- 判斷是否為主動模式
		if(isActiveMode)then
			-- PvP優先： 最先攻擊玩家(但因為官方提供的函數只能判斷是否為怪物，現在藉由活動跡象判斷是否為玩家，但有機會會判斷錯誤)
			if(enablePvP and IsMonster(i)==0)then
				score = score + 999 -- PvP玩家優先權重
			-- 優先攻擊目標：給予優先目標列表中的怪物高權重
			elseif(MainTargets~=nil and #MainTargets>0 and mobTypeId~=nil and (MainTargets[mobTypeId]~=nil or tb_exist(MainTargets,mobTypeId)))then
				score = score + 500 -- 優先目標權重，比守衛模式高但比PvP低
			-- 守衛模式：給離玩家最近的怪物高分，但分數比PvP玩家優先權重低
			elseif((GuardMode~= 0) and i==nearestMonster)then
				-- 守衛模式，根據距離給分，最遠距離為RadiusAggr，越遠分數越低，最遠為0分
				local dist = d1 + d2
				local maxDist = RadiusAggr * 2
				local guardScore = 0
				if dist < maxDist then
					guardScore = math.floor((maxDist - dist) * 999 / maxDist)
				end
				score = score + guardScore
			end
		end



		-- 攻擊目標權重：根據怪物攻擊的對象給予不同權重
		if(v[2]==oid)then
			-- 攻擊主人的怪物權重
			score = score + SearchSetting[1]
		elseif(v[2]==myid)then
			-- 攻擊生命體的怪物權重
			score = score + SearchSetting[2]
		elseif(v[2]>0)then
			-- 攻擊其他玩家的怪物權重
			score = score + SearchSetting[3]
		end

		-- 主人/生命體目標權重：如果怪物是主人或生命體的攻擊目標
		if(v[1]==otar)then
			score = score + SearchSetting[4] -- 主人攻擊目標權重
		end
		if(v[1]==mtar)then
			score = score + SearchSetting[5] -- 生命體攻擊目標權重
		end

		-- 被攻擊時間權重：最近被攻擊的怪物優先
		if(t-v[3]<3000)then
			score = score + SearchSetting[6] -- 最近被攻擊權重
		end

		-- 基礎分數：範圍內外權重
		if(d1<=RadiusAggr)then
			score = score + SearchSetting[8] -- 範圍內權重
		else
			score = score + SearchSetting[7] -- 範圍外權重
		end
		
		TraceAI("score = " .. score)
		Mobs[i][5]=score
		if(score>max_score)then
			max_score=score
			bestTarget=i
		end
	end
end
