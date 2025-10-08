-- 常數
ST_FOLLOW=0
ST_MOVE_CMD=1
ST_HOLD=2
ST_ATTACK=3
ST_SKILL=4
ST_ATTACK_PRE=5
ST_SKILL_GND=6

--狀態廣域變數
AITick=-1
InitStatus=0
MyState=0
DestX=0
DestY=0
Target=0
ManualSkill = {
	["id"] = 0,
	["lv"] = 0,
	["target"] = 0,
	["x"] = 0,
	["y"] = 0,
	["range"]=0
}
AtkDis=1

Aggr=1
MoveCmdTime=0
FollowCmdTime=0
MyMotion=0
MyMotion_t=0
EnableNormalAttack=true

 -- 載入好友系統模組
 pcall(function() dofile("./AI/USER_AI/RNAI_MAI/modules/Friends.lua") end)

 -- 載入守衛模組
 pcall(function() dofile("./AI/USER_AI/RNAI_MAI/modules/Guard.lua") end)

 -- 載入跳舞模組
 pcall(function() dofile("./AI/USER_AI/RNAI_MAI/modules/DanceAttack.lua") end)

-- 區間檢查：range 為 {min, max}；若未提供則一律通過
function isInRange(value, range)
	if range==nil then return true end
	local minVal = range[1] or 0
	local maxVal = range[2] or 100
	return value >= minVal and value <= maxVal
end

-- 取得需求敵數，未填寫時以 0 視為不限制
function needOrZero(v)
	return v or 0
end

 function MoveToDest(id,x,y) -- 移動到指定位置，完成回傳true
	local mx,my=GetV(V_POSITION,id)
	local vx=x-mx
	local vy=y-my
	local t=GetTick()
	if(vx==0 and vy==0)then
		-- TraceAI("return true")
		return true
	end
	vx= (vx< -10) and -10 or ((vx>10) and 10 or vx)
	vy= (vy< -10) and -10 or ((vy>10) and 10 or vy)
	if(t-MoveCmdTime>=MoveDelay)then
		-- TraceAI("move("..(mx+vx)..","..(my+vy))
		Move(id,mx+vx,my+vy)
		MoveCmdTime=t	
	end
	return false
end

function isWeakTarget(t)

	if(#WeakTargets==0)then
		return false
	end
	for i,v in ipairs(WeakTargets)do
		if(GetV(V_HOMUNTYPE,t)==v)then
			return true
		end
	end
	return false
end

function log_var(arr)
	local s = ""
	for i,v in ipairs(arr) do
		local t=type(v)
		if(t=="string")then
			s = s..v.." "
		elseif(t=="boolean")then
			s = s..(v and "True" or "False").." "
		elseif(v==nil)then
			s = s.."[nil] "
		elseif(t=="number")then
			s = s..v.." "
		end
	end
	TraceAI(s)
end

function getSepcFilename(myid)
    local t = GetV(V_HOMUNTYPE, myid)
    local d = "./AI/USER_AI/RNAI_MAI/custom/"
    if (t ~= nil) then
        -- 生命體
        if t < 48 then
            local arr = {"lif", "amistr", "filir", "vanilmirth"}
            t = d .. arr[(t - 1) % 4 + 1] .. ".lua"
        else
            local arr = {"eira", "bayeri", "sera", "dieter", "eleanor"}
            t = d .. arr[(t - 48) % 5 + 1] .. ".lua"
        end
    else
        -- 傭兵
        t = GetV(V_MERTYPE, myid) - 1
        if (t ~= 0) then
            -- 一般 NPC 傭兵
            t = d .. ((t < 10) and "arc" or (t < 20 and "lan" or "swd")) .. (t % 10 == 9 and "" or "0") .. (t % 10 + 1) .. ".lua"
        else
            -- 商城傭兵、1等弓
            local arr = {
                {256, 200, "arc01"}, -- 1等弓傭兵
                {8614, 220, "wander_man"}, -- 邪骸浪人
                {6157, 256, "wicked_nymph"}, -- 妖仙女
                {9815, 234, "kasa_tiger"}, -- 火鳥/虎王
                {9517, 260, "salamander"}, -- 火蜥蜴
                {14493, 243, "teddy_bear"}, -- 玩偶熊
                {6120, 182, "mimic"}, -- 邪惡箱
                {7543, 180, "disguise"}, -- 假面鬼
                {10000, 221, "alice"} -- 愛麗絲女僕
            }
            local mhp = GetV(V_MAXHP, myid)
            local msp = GetV(V_MAXSP, myid)
            local fitName = false
            for i, a in ipairs(arr) do
                for j = 0, 5 do
                    local hp = a[1] * (1 + j / 20)
                    if (mhp <= hp and hp < mhp + 1) then
                        for k = 0, 5 do
                            local sp = a[2] * (1 + k / 20)
                            if (msp <= sp and sp < msp + 1) then
                                fitName = a[3]
                                break
                            end
                        end
                    end
                    if (fitName ~= false) then break end
                end
                if (fitName ~= false) then break end
            end
            if (fitName == false) then return false end
            t = d .. fitName .. ".lua"
        end
    end
    return t
end

function AI(myid)
	local currentTick=GetTick()
	if(AITick==currentTick) then
		return
	else
		AITick=currentTick
	end
	local oid=GetV(V_OWNER,myid)
	local msg=GetMsg(myid)
	local rmsg=GetResMsg(myid)
	local isHomunculus=GetV(V_HOMUNTYPE,myid)~=nil --是否為生命體

	-- 強制拉回判斷
	if type(ForceReturnDis) == "number" and oid and oid > 0 then
		local mx, my = GetV(V_POSITION, myid)
		local ox, oy = GetV(V_POSITION, oid)
		local dis = getRectDis(mx, my, ox, oy)
		if dis > ForceReturnDis then
			MoveToDest(myid, ox, oy)
			return
		end
	end
	if InitStatus==0 then
		AtkDis=GetV(V_ATTACKRANGE,myid)
		InitStatus=1
		local mytype=GetV(V_HOMUNTYPE,myid)
		if(tb_property_exist(Skill,"id",0)==false)then
			EnableNormalAttack=false
		end
		local sepcFilename = getSepcFilename(myid)
		-- log_var("sepcFilename = ",sepcFilename)
		if(type(sepcFilename)=="string" and file_exist(sepcFilename))then
			-- TraceAI("file "..sepcFilename.." exist")
			dofile(sepcFilename)
		end
		for i,sMode in ipairs(SearchMode) do
			if(SearchSetting==sMode) then
				Aggr=i
				break
			end
		end
		
		-- 載入持久化好友數據
		LoadFriendsData()
		
		return
	elseif InitStatus==1 then
		InitStatus=2
		for i,sk in ipairs(Skill) do
			local castType, effectArea
			if SkillData[sk.id]~=nil then
				local skData = SkillData[sk.id]
				castType = SkillData[sk.id][1]
				if SkillData[sk.id][2][sk.lv]~=nil then
					effectArea = SkillData[sk.id][2][sk.lv]
				else
					effectArea = 0
				end
			else
				castType = 1
				effectArea = 0
			end
			if sk["castType"] == nil then
				sk["castType"] = castType
			end
			if sk["effectArea"] == nil then
				sk["effectArea"] = effectArea
			end
			if sk["range"]==nil then
				if sk.id==0 then
					sk["range"]=GetV(V_ATTACKRANGE,myid)
				elseif sk.target==2 then
					sk["range"]=100
				elseif sk.castType==0 then
					-- 對自身使用的技能中，如果 effectArea 是 0，都當作是 buff 類技能，讓半徑為 14
					sk["range"] = sk["effectArea"] == 0 and 14 or (sk["effectArea"] - 1) / 2
				else
					sk["range"]=GetV(V_SKILLATTACKRANGE_LEVEL,myid,sk.id,sk.lv)
				end
			end
		end
	end
	--傭兵動作狀態更新
	local mymo=GetV(V_MOTION,myid)
	if(mymo~=MyMotion)then
		MyMotion=mymo
		MyMotion_t=GetTick()
	end
	--地圖狀態更新
	RefreshData(myid,oid)
	-- 玩家指令
	if msg[1]==MOVE_CMD then
		-- 移動指令
		-- 效果：生命體/傭兵會朝座標 (msg[2], msg[3]) 移動；
		--       抵達後切換為 HOLD（原地待命，不主動尋敵，只在範圍內反擊）。
		MyState=ST_MOVE_CMD
		DestX=msg[2]
		DestY=msg[3]
	elseif msg[1]==FOLLOW_CMD then
		-- 跟隨指令
		-- 效果（單次）：切換為跟隨狀態，維持與主人的距離（`FollowDis`）。
		-- 效果（500ms 內連按兩次）：在被動/主動模式間切換（輪替 `SearchMode` → `SearchSetting`）。
		-- 提示：Alt+T 連按兩次會觸發此切換；單按一次僅進入跟隨，不切模式。
		local t=GetTick()
		if(t-FollowCmdTime<500)then
			Aggr=Aggr%#SearchMode+1
			SearchSetting=SearchMode[Aggr]
		end
		FollowCmdTime=t
		MyState=ST_FOLLOW
	elseif msg[1]==ATTACK_OBJECT_CMD then
		-- 攻擊指令（對象）
		-- 效果：強制指定攻擊目標（即使在被動模式也會進入攻擊流程）。
		--       若目標消失或過遠，後續會自動回到跟隨。
		MyState=ST_ATTACK
		Target=msg[2]
		if(isHomunculus) then
			TraceAI("id:"..msg[2]..",type"..GetV(V_HOMUNTYPE,msg[2]))
		end
	elseif msg[1]==SKILL_OBJECT_CMD then
		-- 技能指令（目標型）
		-- 效果：設定對單一對象施放的技能與等級；若距離不足會自動接近，
		--       進入 `ST_SKILL` 狀態，施放後若對象是怪物會轉入攻擊，否則回到跟隨。
		MyState=ST_SKILL
		ManualSkill.lv = msg[2]
		ManualSkill.id = msg[3]
		ManualSkill.target = msg[4]
		ManualSkill.range = GetV(V_SKILLATTACKRANGE_LEVEL, myid, ManualSkill.id, ManualSkill.lv)
	elseif msg[1]==SKILL_AREA_CMD then
		-- 技能指令（地面型）
		-- 效果：設定對地面座標施放的技能與等級；若距離不足會自動接近，
		--       在施放完成後回到跟隨。
		MyState = ST_SKILL_GND
		ManualSkill.lv = msg[2]
		ManualSkill.id = msg[3]
		ManualSkill.x = msg[4]
		ManualSkill.y = msg[5]
		ManualSkill.range = GetV(V_SKILLATTACKRANGE_LEVEL, myid, ManualSkill.id, ManualSkill.lv)
	end
	if(msg[1]==NONE_CMD)then -- 預約指令
		-- 效果：處理保留（預約）指令。搭配 Shift/Alt 右鍵可把移動/攻擊加入預約佇列。
		if(rmsg[1]==MOVE_CMD)then
			if(MyState==ST_MOVE_CMD or MyState==ST_HOLD)then
				-- 以移動矩形範圍加入好友（改用模組）
				local x1,y1=math.min(DestX,rmsg[2]),math.min(DestY,rmsg[3])
				local x2,y2=math.max(DestX,rmsg[2]),math.max(DestY,rmsg[3])
				Friends_AddInRect(x1,y1,x2,y2)
				MyState=ST_FOLLOW
			else
				-- 以單一座標加入好友（保持行為不變）
				rmsg[2]=XYInMobs(rmsg[2],rmsg[3])
				rmsg[1]=ATTACK_OBJECT_CMD
			end
		end
		if(rmsg[1]==ATTACK_OBJECT_CMD)then
			-- 攻擊預約 → 好友清單維護（改用模組）
			if(rmsg[2]==myid)then
				Friends_Clear()
			else
				Friends_Add(rmsg[2])
			end
		end
	end
	--移動(到達後堅守位置)
	if(MyState==ST_MOVE_CMD) then
		if(MoveToDest(myid,DestX,DestY)==true) then
			MyState=ST_HOLD
			-- TraceAI("ST_HOLD")
		end
	--跟隨
	elseif (MyState==ST_FOLLOW) then
		-- 常駐技能使用
		autoUseSkill(myid, oid, oid, 1) --第三個參數原本是怪物id，這邊用 oid
		if(bestTarget>0 and Mobs[bestTarget][5]>=0)then
			MyState=ST_ATTACK_PRE
		end
		
		-- 守衛模式或一般跟隨模式
		if(MyState==ST_FOLLOW)then
			if(GuardMode==1)then
				-- 守衛模式：生命體保持在玩家前方
				local guardX, guardY = getGuardPosition(myid, oid)
				if(guardX ~= nil and guardY ~= nil)then
					MoveToDest(myid, guardX, guardY)
				end
			elseif(GuardMode==2)then
				-- 轉圈模式：生命體在玩家周圍轉圈
				local circleX, circleY = getCirclePosition(myid, oid)
				if(circleX ~= nil and circleY ~= nil)then
					MoveToDest(myid, circleX, circleY)
				end
			else
				-- 一般跟隨模式：保持跟隨距離
				if(getObjRectDis(oid,myid)>FollowDis)then
					local x1,y1=GetV(V_POSITION,oid)
					local x2,y2=GetV(V_POSITION,myid)
					local dx,dy=getRectPos(x1,y1,x2,y2,FollowDis)
					Move(myid,dx,dy)
				end
			end
		end
	--追擊目標
	elseif (MyState==ST_ATTACK_PRE) then
		-- 目標消失則回到先前狀態(FOLLOW)
		if(bestTarget<=0 or Mobs[bestTarget][5]<0)then
			RemoveTarget()
			MyState=ST_FOLLOW
		else
			Target=Mobs[bestTarget][1]
			-- 進入技能判定
			if(isWeakTarget(Target))then
				--使用普攻
				local dis=getObjRectDis(myid,Target)
				if(dis<=AtkDis)then
					Attack(myid,Target)
					DanceAttack_TryExecute(myid, Target, oid)
				end
				if(Target>0 and getObjRectDis(oid,Target)<RadiusAggr)then
					local x,y=getFreeObjRectPos(Target,myid,AtkDis,oid)
					MoveToDest(myid,x,y)
				end
			else
				--使用技能
				local chaseDis = autoUseSkill(myid, oid, Target, 2)
				--靠近以使用更多可能的技能
				if(chaseDis~=false and Target>0 and getObjRectDis(oid,Target)<RadiusAggr)then
					local x,y=getFreeObjRectPos(Target,myid,chaseDis,oid)
					MoveToDest(myid,x,y)
				end
			end
		end
	--攻擊目標
	elseif (MyState==ST_ATTACK) then
		-- 目標消失則回到先前狀態(FOLLOW)
		if(Target<=0 or getObjRectDis(oid, Target)>RadiusAggr or GetV(V_MOTION, Target)==MOTION_DEAD)then
			RemoveTarget()
			MyState=ST_FOLLOW
		else
			-- 進入技能判定
			if(isWeakTarget(Target))then
				--使用普攻
				local dis=getObjRectDis(myid,Target)
				if(dis<=AtkDis)then
					Attack(myid,Target)
					DanceAttack_TryExecute(myid, Target, oid)
				end
				if(Target>0 and getObjRectDis(oid,Target)<RadiusAggr)then
					local x,y=getFreeObjRectPos(Target,myid,AtkDis,oid)
					MoveToDest(myid,x,y)
				end
			else
				--使用技能
				local chaseDis = autoUseSkill(myid, oid, Target, 2)
				--靠近以使用更多可能的技能
				if(chaseDis~=false and Target>0 and getObjRectDis(oid,Target)<RadiusAggr)then
					local x,y=getFreeObjRectPos(Target,myid,chaseDis,oid)
					MoveToDest(myid,x,y)
				end
			end
		end
	-- 對目標使用技能
	elseif (MyState==ST_SKILL) then
		local target = ManualSkill.target
		if(getObjRectDis(oid, target)>RadiusAggr or GetV(V_MOTION, target)==MOTION_DEAD)then
			MyState=ST_FOLLOW
		elseif(getObjRectDis(myid, target) <= ManualSkill.range)then --在範圍內則使用技能
			SkillObject(myid, ManualSkill.lv, ManualSkill.id, target)
			if(IsMonster(target)==1)then
				Target = target
				MyState = ST_ATTACK
			else
				MyState = ST_FOLLOW
			end
		else -- 如果距離太遠需要追擊
			local x,y=getFreeObjRectPos(target, myid, ManualSkill.range, oid)
			MoveToDest(myid, x, y)
		end
	-- 對地面使用技能
	elseif (MyState==ST_SKILL_GND) then
		local x,y = GetV(V_POSITION, myid)
		local dis = getRectDis(x, y, ManualSkill.x, ManualSkill.y)
		if(dis <= ManualSkill.range) then --在範圍內則使用技能
			SkillGround(myid, ManualSkill.lv, ManualSkill.id, ManualSkill.x, ManualSkill.y)
			MyState=ST_FOLLOW
		else -- 如果距離太遠需要追擊
			x,y=getRectPos(ManualSkill.x, ManualSkill.y, x, y, ManualSkill.range)
			MoveToDest(myid, x, y)
		end
	end
end

-- 從技能列表找出適當的技能 回傳idx及追擊格數
function GetAutoSkill(myid) --從技能列表找出適當的技能 回傳idx及追擊格數
	local min_r=100 -- 最小追擊距離，初始值設為100
	local r=getObjRectDis(myid,Target) -- 計算與目標的距離
	local t=GetTick() -- 取得當前時間戳記
	local sp=GetV(V_SP,myid)/GetV(V_MAXSP,myid)*100 -- 計算生命體SP百分比
	local hp=GetV(V_HP,myid)/GetV(V_MAXHP,myid)*100 -- 計算生命體HP百分比
	local ownerId=GetV(V_OWNER,myid) -- 取得主人ID
	local ownerSp=GetV(V_SP,ownerId)/GetV(V_MAXSP,ownerId)*100 -- 計算主人SP百分比
	local ownerHp=GetV(V_HP,ownerId)/GetV(V_MAXHP,ownerId)*100 -- 計算主人HP百分比
	local skill_id=0 -- 選中的技能ID，0表示無可用技能
	for i,sk in ipairs(Skill) do -- 遍歷所有技能
		-- 條件預先判斷（有填才檢查）
		local okSp = isInRange(sp, sk.sp) -- SP 範圍（可選）
		local okHp = isInRange(hp, sk.hp) -- HP 範圍（可選）
		local okOwnerSp = isInRange(ownerSp, sk.ownerSp) -- 主人 SP 範圍（可選）
		local okOwnerHp = isInRange(ownerHp, sk.ownerHp) -- 主人 HP 範圍（可選）
		local needOwnerEnemy = needOrZero(sk.nOwnerEnemy) -- 主人敵數（未填=0）
		local needMyEnemy = needOrZero(sk.nMyEnemy) -- 自身敵數（未填=0）
		local needRangeEnemy = needOrZero(sk.nRangeEnemy) -- 範圍敵數（未填=0）
		-- 綜合條件：非排除、冷卻時間到、各種可選區間通過、敵數需求符合
		if(sk.when~=2 and t-sk.stemp>=sk.delay and okSp and okHp and okOwnerSp and okOwnerHp and nOwnerEnemy>=needOwnerEnemy and nMyEnemy>=needMyEnemy and nRangeEnemy>=needRangeEnemy)then
			if(r<=sk.range)then -- 如果在技能範圍內
				if(skill_id==0)then -- 如果還沒選中技能
					skill_id=i -- 選中此技能
				end
			else -- 如果不在技能範圍內
				if(sk.chase==1 and min_r>sk.range)then -- 如果此技能可追擊且距離更近
					min_r=sk.range -- 更新最小追擊距離
				end
			end
		end
	end
	return skill_id,min_r -- 回傳選中的技能ID和最小追擊距離
end

-- 從技能列表使用技能，回傳追擊格數
function autoUseSkill(myid, oid, mobId, excludeWhen) --從技能列表使用技能，回傳追擊格數
	local minRadius = 100 -- 最小追擊半徑，初始值設為100
	local r = { -- 距離陣列，儲存與不同目標的距離
		[0] = getObjRectDis(myid, mobId), --sk.target=0 (魔物) 與魔物的距離
		[1] = getObjRectDis(myid, oid), --sk.target=1 (主人) 與主人的距離
		[2] = 0 --sk.target=2 (生命體/傭兵) 對自身使用技能距離為0
	}
	local targets = { -- 目標陣列，儲存不同目標的ID
		[0] = mobId, --sk.target=0 (魔物) 魔物ID
		[1] = oid, --sk.target=1 (主人) 主人ID
		[2] = myid --sk.target=2 (生命體/傭兵) 自身ID
	}
	local t = GetTick() -- 取得當前時間戳記
	local sp = GetV(V_SP, myid) / GetV(V_MAXSP, myid) * 100 -- 計算生命體SP百分比
	local hp = GetV(V_HP, myid) / GetV(V_MAXHP, myid) * 100 -- 計算生命體HP百分比
	local ownerSp=GetV(V_SP,oid)/GetV(V_MAXSP,oid)*100 -- 計算主人SP百分比
	local ownerHp=GetV(V_HP,oid)/GetV(V_MAXHP,oid)*100 -- 計算主人HP百分比
	local usedFlag = false -- 技能使用標記，確保一次只使用一個技能
	for i, sk in ipairs(Skill) do -- 遍歷所有技能
		-- 條件預先判斷（有填才檢查）
		local okSp = isInRange(sp, sk.sp) -- SP 範圍（可選）
		local okHp = isInRange(hp, sk.hp) -- HP 範圍（可選）
		local okOwnerSp = isInRange(ownerSp, sk.ownerSp) -- 主人 SP 範圍（可選）
		local okOwnerHp = isInRange(ownerHp, sk.ownerHp) -- 主人 HP 範圍（可選）
		local needOwnerEnemy = needOrZero(sk.nOwnerEnemy) -- 主人敵數（未填=0）
		local needMyEnemy = needOrZero(sk.nMyEnemy) -- 自身敵數（未填=0）
		local needRangeEnemy = needOrZero(sk.nRangeEnemy) -- 範圍敵數（未填=0）
		-- 綜合條件：非排除、冷卻時間到、各種可選區間通過、敵數需求符合
		if sk.when ~= excludeWhen and
			t - sk.stemp >= sk.delay and
			okSp and okHp and okOwnerSp and okOwnerHp and
			nOwnerEnemy >= needOwnerEnemy and
			nMyEnemy >= needMyEnemy and
			nRangeEnemy >= needRangeEnemy
		then --符合使用的條件
			if usedFlag==false and r[sk.target] <= sk.range then --在使用範圍內可使用且尚未使用技能
				--使用此技能
				if sk.id == 0 then -- 普通攻擊
					Attack(myid, targets[sk.target])
					DanceAttack_TryExecute(myid, targets[sk.target], oid)
				elseif sk.castType == 0 then --自身類型技能
					SkillObject(myid, sk.lv, sk.id, myid)
				elseif sk.castType == 1 then --目標類型技能
					SkillObject(myid, sk.lv, sk.id, targets[sk.target])
				elseif sk.castType == 2 then --地面類型技能
					local x,y = GetV(V_POSITION, targets[sk.target]) -- 取得目標位置
					SkillGround(myid, sk.lv, sk.id, x, y) -- 在目標位置施放地面技能
				end
				--更新記數
				usedFlag = true -- 標記已使用技能
				sk.count = sk.count + 1 -- 增加技能使用次數
				if(sk.count >= sk.times)then -- 如果達到使用次數限制
					sk.count = 0 -- 重置計數
					sk.stemp = t -- 更新最後使用時間
				end
			end
			-- 計算追擊距離：如果有魔物目標且技能可追擊且距離超出範圍
			if mobId > 0 and sk.chase == 1 and r[sk.target] > sk.range and minRadius > sk.range then
				minRadius = sk.range -- 更新最小追擊半徑
			end
		end
	end
	if minRadius >= 100 then -- 如果沒有需要追擊的技能
		return false -- 回傳false表示無需追擊
	end
	return minRadius -- 回傳最小追擊半徑
end
