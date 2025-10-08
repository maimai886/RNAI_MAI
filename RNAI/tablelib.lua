function tb_search_i(tb,value)
	for i,v in ipairs(tb) do
		if(v==value)then
			return i
		end
	end
	return false
end
function tb_exist(tb,value)
	for i,v in ipairs(tb) do
		if(v==value)then
			return true
		end
	end
	return false
end
function tb_property_exist(tb,property,value)
	for i,v in ipairs(tb) do
		if(v[property]==value)then
			return true
		end
	end
	return false
end

function file_exist(filename)
	local fp=io.open(filename,"r")
	if(fp==nil)then
		return false
	end
	fp:close()
	return true
end
