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
		elseif(t=="boolen")then
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
    local d = "./AI/USER_AI/RNAI/custom/"
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
	if InitStatus==0 then
		AtkDis=GetV(V_ATTACKRANGE,myid)
		InitStatus=1
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
		return
	elseif InitStatus==1 then
		InitStatus=2
		EnableNormalAttack=false
		for i,sk in ipairs(Skill) do
			local castType, effectArea
			if sk.id==0 then
				EnableNormalAttack=true
			end
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
		MyState=ST_MOVE_CMD
		DestX=msg[2]
		DestY=msg[3]
	elseif msg[1]==FOLLOW_CMD then
		--TraceAI("num of Mobs:"..#Mobs)
		--TraceAI("bestTarget:"..bestTarget)
		local t=GetTick()
		if(t-FollowCmdTime<500)then
			Aggr=Aggr%#SearchMode+1
			SearchSetting=SearchMode[Aggr]
		end
		FollowCmdTime=t
		MyState=ST_FOLLOW
	elseif msg[1]==ATTACK_OBJECT_CMD then
		MyState=ST_ATTACK
		Target=msg[2]
		if(isHomunculus) then
			TraceAI("id:"..msg[2]..",type"..GetV(V_HOMUNTYPE,msg[2]))
		end
	elseif msg[1]==SKILL_OBJECT_CMD then
		--使用鎖定目標的技能
		MyState=ST_SKILL
		ManualSkill.lv = msg[2]
		ManualSkill.id = msg[3]
		ManualSkill.target = msg[4]
		ManualSkill.range = GetV(V_SKILLATTACKRANGE_LEVEL, myid, ManualSkill.id, ManualSkill.lv)
	elseif msg[1]==SKILL_AREA_CMD then
		--使用地面技能
		MyState = ST_SKILL_GND
		ManualSkill.lv = msg[2]
		ManualSkill.id = msg[3]
		ManualSkill.x = msg[4]
		ManualSkill.y = msg[5]
		ManualSkill.range = GetV(V_SKILLATTACKRANGE_LEVEL, myid, ManualSkill.id, ManualSkill.lv)
	end
	if(msg[1]==NONE_CMD)then --預約指令
		if(rmsg[1]==MOVE_CMD)then
			if(MyState==ST_MOVE_CMD or MyState==ST_HOLD)then
				--範圍加入好友
				local x1,y1=math.min(DestX,rmsg[2]),math.min(DestY,rmsg[3])
				local x2,y2=math.max(DestX,rmsg[2]),math.max(DestY,rmsg[3])
				local tx,ty
				for i,v in ipairs(others)do
					tx,ty=GetV(V_POSITION,v)
					if(x1<=tx and tx<=x2 and y1<=ty and ty<=y2)then
						friends[#friends+1]=v
					end
				end
				MyState=ST_FOLLOW
			else
				--個別加入好友
				rmsg[2]=XYInMobs(rmsg[2],rmsg[3])
				rmsg[1]=ATTACK_OBJECT_CMD
			end
		end
		if(rmsg[1]==ATTACK_OBJECT_CMD)then
			--TraceAI("")
			if(rmsg[2]==myid)then
				friends={} --清除firend
			else
				local f_exist=false
				for i,v in ipairs(friends)do
					if(v==rmsg[2])then
						f_exist=true
						break
					end
				end
				if(f_exist==false)then
					friends[#friends+1]=rmsg[2] --添加firend
				end
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
		if(MyState==ST_FOLLOW and getObjRectDis(oid,myid)>FollowDis)then
			local x1,y1=GetV(V_POSITION,oid)
			local x2,y2=GetV(V_POSITION,myid)
			local dx,dy=getRectPos(x1,y1,x2,y2,FollowDis)
			Move(myid,dx,dy)
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
				end
				if(Target>0 and getObjRectDis(oid,Target)<15)then
					local x,y=getFreeObjRectPos(Target,myid,AtkDis,oid)
					MoveToDest(myid,x,y)
				end
			else
				--使用技能
				local chaseDis = autoUseSkill(myid, oid, Target, 2)
				--靠近以使用更多可能的技能
				if(chaseDis~=false and Target>0 and getObjRectDis(oid,Target)<15)then
					local x,y=getFreeObjRectPos(Target,myid,chaseDis,oid)
					MoveToDest(myid,x,y)
				end
			end
		end
	--攻擊目標
	elseif (MyState==ST_ATTACK) then
		-- 目標消失則回到先前狀態(FOLLOW)
		if(Target<=0 or getObjRectDis(oid, Target)>15 or GetV(V_MOTION, Target)==MOTION_DEAD)then
			RemoveTarget()
			MyState=ST_FOLLOW
		else
			-- 進入技能判定
			if(isWeakTarget(Target))then
				--使用普攻
				local dis=getObjRectDis(myid,Target)
				if(dis<=AtkDis)then
					Attack(myid,Target)
				end
				if(Target>0 and getObjRectDis(oid,Target)<15)then
					local x,y=getFreeObjRectPos(Target,myid,AtkDis,oid)
					MoveToDest(myid,x,y)
				end
			else
				--使用技能
				local chaseDis = autoUseSkill(myid, oid, Target, 2)
				--靠近以使用更多可能的技能
				if(chaseDis~=false and Target>0 and getObjRectDis(oid,Target)<15)then
					local x,y=getFreeObjRectPos(Target,myid,chaseDis,oid)
					MoveToDest(myid,x,y)
				end
			end
		end
	-- 對目標使用技能
	elseif (MyState==ST_SKILL) then
		local target = ManualSkill.target
		if(getObjRectDis(oid, target)>15 or GetV(V_MOTION, target)==MOTION_DEAD)then
			MyState=ST_FOLLOW
		elseif(getObjRectDis(myid, target) <= target)then --在範圍內則使用技能
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
function GetAutoSkill(myid) --從技能列表找出適當的技能 回傳idx及追擊格數
	local min_r=100
	local r=getObjRectDis(myid,Target)
	local t=GetTick()
	local sp=GetV(V_SP,myid)/GetV(V_MAXSP,myid)*100
	local skill_id=0
	for i,sk in ipairs(Skill) do
		if(sk.when~=2 and t-sk.stemp>=sk.delay and sk.sp[1]<=sp and sp<=sk.sp[2] and nOwnerEnemy>=sk.nOwnerEnemy and nMyEnemy>=sk.nMyEnemy and nRangeEnemy>=sk.nRangeEnemy)then
			if(r<=sk.range)then
				if(skill_id==0)then
					skill_id=i
				end
			else
				if(sk.chase==1 and min_r>sk.range)then
					min_r=sk.range
				end
			end
		end
	end
	return skill_id,min_r
end

function autoUseSkill(myId, ownerId, mobId, excludeWhen) --從技能列表使用技能，回傳追擊格數
	local minRadius = 100
	local r = {
		[0] = getObjRectDis(myId, mobId), --sk.target=0 (魔物)
		[1] = getObjRectDis(myId, ownerId), --sk.target=1 (主人)
		[2] = 0 --sk.target=2 (生命體/傭兵)
	}
	local targets = {
		[0] = mobId, --sk.target=0 (魔物)
		[1] = ownerId, --sk.target=1 (主人)
		[2] = myId --sk.target=2 (生命體/傭兵)
	}
	local t = GetTick()
	local sp = GetV(V_SP, myId) / GetV(V_MAXSP, myId) * 100
	local usedFlag = false
	for i, sk in ipairs(Skill) do
		if sk.when ~= excludeWhen and
			t - sk.stemp >= sk.delay and
			sk.sp[1] <= sp and sp <= sk.sp[2] and
			nOwnerEnemy >= sk.nOwnerEnemy and
			nMyEnemy >= sk.nMyEnemy and
			nRangeEnemy >= sk.nRangeEnemy
		then --符合使用的條件
			if usedFlag==false and r[sk.target] <= sk.range then --在使用範圍內可使用
				--使用此技能
				if sk.id == 0 then
					Attack(myId, targets[sk.target])
				elseif sk.castType == 0 then --自身類型
					SkillObject(myId, sk.lv, sk.id, myId)
				elseif sk.castType == 1 then --目標類型
					SkillObject(myId, sk.lv, sk.id, targets[sk.target])
				elseif sk.castType == 2 then --地面類型
					local x,y = GetV(V_POSITION, targets[sk.target])
					SkillGround(myId, sk.lv, sk.id, x, y)
				end
				--更新記數
				usedFlag = true
				sk.count = sk.count + 1
				if(sk.count >= sk.times)then
					sk.count = 0
					sk.stemp = t
				end
			end
			if mobId > 0 and sk.chase == 1 and r[sk.target] > sk.range and minRadius > sk.range then
				minRadius = sk.range
			end
		end
	end
	if minRadius >= 100 then
		return false
	end
	return minRadius
end
