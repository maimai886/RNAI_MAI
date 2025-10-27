-- 好友系統模組
-- 說明：
--   提供好友清單的持久化、加入、清空與矩形區域批次加入。
-- 設定：
--   - FRIENDS_FILE：好友資料的儲存檔案路徑。

local FRIENDS_FILE = "./AI/USER_AI/RNAI_MAI/custom/friends_data.lua"

--- 從文件讀取好友列表
--- @return table 好友列表
function GetFriends()
	local friendsList = {}
	local success, err = pcall(function()
		if file_exist(FRIENDS_FILE) then
			dofile(FRIENDS_FILE)
			if friends ~= nil then
				friendsList = friends
			end
		end
	end)
	if not success then
		LogAI("讀取好友數據時發生錯誤: " .. tostring(err), "friend")
	end
	return friendsList
end

-- 函數：existsInFriends（內部）
-- 功能：檢查 id 是否已存在於好友清單中。
-- 參數：id(number)
-- 回傳：boolean
local function existsInFriends(friendsList, id)
	for i, friend in ipairs(friendsList) do
		local friendId = type(friend) == "table" and friend.id or friend
		if friendId == id then return true end
	end
	return false
end

-- 函數：Friends_Clear
-- 功能：清空好友清單並立即持久化。
-- 參數：無
-- 回傳：無
function Friends_Clear()
	local success = pcall(function()
		local file = io.open(FRIENDS_FILE, "w")
		if file then
			file:write("-- 好友數據持久化文件\n")
			file:write("-- 自動生成，請勿手動修改\n")
			file:write("-- 格式：{id = ID, job = 職業編號}\n\n")
			file:write("friends = {\n")
			file:write("}\n")
			file:close()
		end
	end)
	LogAI("已清空所有好友", "friend")
end

-- 函數：Friends_Add
-- 功能：將指定 id 加入好友清單（若尚未存在），並立即持久化。
-- 參數：id(number)
-- 回傳：無
function Friends_Add(id)
	-- 檢查 id 是否有效：必須是數字且大於0
	if id == nil or type(id) ~= "number" or id <= 0 then 
		return 
	end
	
	-- 從文件讀取現有好友列表
	local friendsList = GetFriends()
	
	if not existsInFriends(friendsList, id) then
		-- 立即查詢職業
		local jobType = GetV(V_HOMUNTYPE, id) or -1
		
		-- 追加到列表末尾
		friendsList[#friendsList+1] = {id = id, job = jobType}
		
		-- 寫回文件
		local success = pcall(function()
			local file = io.open(FRIENDS_FILE, "w")
			if file then
				file:write("-- 好友數據持久化文件\n")
				file:write("-- 自動生成，請勿手動修改\n")
				file:write("-- 格式：{id = ID, job = 職業編號}\n\n")
				file:write("friends = {\n")
				for i, friend in ipairs(friendsList) do
					local fid, fjob
					if type(friend) == "table" then
						fid, fjob = friend.id, friend.job or -1
					else
						fid, fjob = friend, -1
					end
					local jobName = "未知"
					if fjob >= 0 and PLAYER_JOBS and PLAYER_JOBS[fjob] then
						jobName = PLAYER_JOBS[fjob] .. "(" .. fjob .. ")"
					elseif fjob >= 0 then
						jobName = "職業編號:" .. fjob
					end
					file:write("  {id = " .. fid .. ", job = " .. fjob .. "}, -- " .. jobName .. "\n")
				end
				file:write("}\n")
				file:close()
			end
		end)
		
		local jobName = "未知"
		if jobType >= 0 and PLAYER_JOBS and PLAYER_JOBS[jobType] then
			jobName = PLAYER_JOBS[jobType]
		elseif jobType >= 0 then
			jobName = "職業" .. jobType
		end
		LogAI("已添加好友: ID=" .. tostring(id) .. " 職業=" .. jobName, "friend")
	end
end

-- 函數：Friends_AddInRect
-- 功能：將矩形區域內的實體加入好友清單（透過全域 `others` 與 `GetV` 取得座標）。
-- 參數：x1,y1,x2,y2(number) 矩形左上與右下座標
-- 回傳：無
function Friends_AddInRect(x1, y1, x2, y2)
	local tx, ty
	for i, v in ipairs(others) do
		tx, ty = GetV(V_POSITION, v)
		if (x1 <= tx and tx <= x2 and y1 <= ty and ty <= y2) then
			Friends_Add(v)
		end
	end
end

-- 函數：Friends_SnapshotAll
-- 功能：快照加入當前屏幕內所有玩家（非怪物、非自己、非主人、非生命體）到好友清單
-- 參數：myid(number) 生命體ID, oid(number) 主人ID
-- 回傳：number 加入的玩家數量
function Friends_SnapshotAll(myid, oid)
	local actors = GetActors()
	local addedCount = 0
	local friendsList = GetFriends()
	
	for i, actorId in ipairs(actors) do
		-- 排除：怪物、自己、主人
		if IsMonster(actorId) == 0 and 
		   actorId ~= myid and 
		   actorId ~= oid then
			
			-- 檢查是否已經是好友
			if not existsInFriends(friendsList, actorId) then
				Friends_Add(actorId)
				addedCount = addedCount + 1
				-- 重新讀取更新後的列表
				friendsList = GetFriends()
			end
		end
	end
	
	LogAI("好友快照完成: 新增 " .. addedCount .. " 個好友 (總數: " .. #friendsList .. ")", "friend")
	
	return addedCount
end


