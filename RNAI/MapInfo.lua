-- 本檔案包含戰場物件與管理

Mobs={} -- 關聯陣列，key: 怪物id，value: {怪物id, 此魔物攻擊對象id, 其他人攻擊此魔物的時間, 是否在視線內(RefreshKey|-1), score}
RefreshKey=0 -- 每次呼叫RefreshData會在0~29999變換，用以判斷物件是否已經不在範圍
RefreshTime=0
nOwnerEnemy=0
nMyEnemy=0
nRangeEnemy=0
bestTarget=0

plantsInitFlag=false
plants={
	[3790]=true,
	[1078]=true,
	[1079]=true,
	[1080]=true,
	[1081]=true,
	[1082]=true,
	[1083]=true,
	[1084]=true
}
friends={}
others={}

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
function RemoveTarget()
	if bestTarget~=0 and Mobs[bestTarget]~=nil then
		Mobs[bestTarget] = nil
	end
	bestTarget = 0
end
function RefreshData(myid,oid) --更新戰場情報
	local t=GetTick()
	if(t-RefreshTime>333)then --每1/3秒更新一次，降低計算消耗
		RefreshTime=t
	else
		return
	end
	nOwnerEnemy=0
	nMyEnemy=0
	nRangeEnemy=0
	RefreshKey=(RefreshKey+1)%30000
	local A=GetActors()
	local idx,tar,isplants,isfriend,mobTypeId
	others={}
	local otar,mtar=GetV(V_TARGET,oid),GetV(V_TARGET,myid)
	--更新Mobs的RefreshKey與Target，加入新的Mob，並把其他物件放others
	for i,v in ipairs(A)do --for each v in A
		mobTypeId=GetV(V_HOMUNTYPE,v)
		--是否為植物
		if mobTypeId~=nil and plants[mobTypeId]~=nil then
			isplants=true
		else
			isplants=false
		end
		--
		if(IsMonster(v)==1 and isplants==false)then
			if(GetV(V_MOTION,v)~=MOTION_DEAD)then
				if Mobs[v]==nil then -- 未在清單則加入
					Mobs[v]={v,0,0,0}
				end
				--更新掃描紀錄、攻擊對象、敵人計數
				Mobs[v][4]=(getObjRectDis(oid,v)>14) and -1 or RefreshKey
				tar=GetV(V_TARGET,v)
				if(tar>0 and IsMonster(tar)==0)then
					Mobs[v][2]=tar
					if(tar==myid)then
						nMyEnemy=nMyEnemy+1
					elseif(tar==oid)then
						nOwnerEnemy=nOwnerEnemy+1
					end
				end
				if(getObjRectDis(oid,v)<=RadiusAggr)then
					nRangeEnemy=nRangeEnemy+1
				end
			end
		elseif(v~=oid and v~=myid and tb_exist(friends,v)==false)then
			others[#others+1]=v
		end
	end
	--刪除RefreshKey不符合的Mob(過時)
	for k,mobInfo in pairs(Mobs) do
		if mobInfo[4]~=RefreshKey then
			Mobs[k]=nil
		end
	end
	--更新被其他玩家攻擊的時間
	for i,v in ipairs(others)do
		tar=GetV(V_TARGET,v)
		if(tar>0 and IsMonster(tar)==1)then
			if(Mobs[tar]~=nil)then
				Mobs[tar][3]=t
			end
		end
	end
	local max_score,score=-10000,0
	local d1,d2
	bestTarget=0
	for i,v in pairs(Mobs)do
		--更新分數
		d1=getObjRectDis(oid,v[1])
		d2=getObjRectDis(myid,v[1])
		
		score=(d1<=RadiusAggr)and SearchSetting[8] or SearchSetting[7]
		
		--[[isfriend=false
		for j,u in ipairs(friends)do
			if(v[2]==u)then
				isfriend=true
				break
			end
		end--]]
		score=score+((v[2]==0 or tb_exist(friends,v[2]))and 0 or((v[2]==oid)and SearchSetting[1] or((v[2]==myid)and SearchSetting[2] or SearchSetting[3])))
		
		score=score+((v[1]==otar)and SearchSetting[4] or 0)
		score=score+((v[1]==mtar)and SearchSetting[5] or 0)
		score=score+((t-v[3]<3000)and SearchSetting[6] or 0)
		score=(score>=0) and (score*100+30-d1-d2) or -1
		Mobs[i][5]=score
		if(score>max_score)then
			max_score=score
			bestTarget=i
		end
	end
end
