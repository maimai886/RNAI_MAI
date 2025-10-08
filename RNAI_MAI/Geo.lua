function getObjRectDis(id1,id2) -- 取得距離(方形)
	local x1,y1=GetV(V_POSITION,id1)
	local x2,y2=GetV(V_POSITION,id2)
	return math.max(math.abs(x1-x2),math.abs(y1-y2))
end
function getRectDis(x1,y1,x2,y2) -- 取得距離(方形)
	return math.max(math.abs(x1-x2),math.abs(y1-y2))
end
function getObjRectPos(cid,mid,len)
	local x1,y1=GetV(V_POSITION,cid)
	local x2,y2=GetV(V_POSITION,mid)
	return getRectPos(x1,y1,x2,y2,len)
end
function getRectPos(cx,cy,dx,dy,len) -- 取得由cx,cy，往dx,dy方向，距離len的座標
	local vx=dx-cx
	local vy=dy-cy
	if (vx==0 and vy==0) then
		return cx,cy
	end
	if (math.abs(vx)>len) then
		vx= (vx>0) and len or -len
	end
	if (math.abs(vy)>len) then
		vy= (vy>0) and len or -len
	end
	return cx+vx,cy+vy
end
function getFreeObjRectPos(cid,mid,len,oid)
	local x1,y1=GetV(V_POSITION,cid)
	local x2,y2=GetV(V_POSITION,mid)
	local x3,y3=GetV(V_POSITION,oid)
	local x,y=getRectPos(x1,y1,x2,y2,len)
	if(x3==x and y3==y)then
		x,y=x1,y1
	end
	return getRectPos(x3,y3,x,y,14)
end
