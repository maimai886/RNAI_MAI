-- 好友系統模組
-- 說明：
--   提供好友清單的持久化、加入、清空與矩形區域批次加入。
-- 設定：
--   - FRIENDS_FILE：好友資料的儲存檔案路徑。

local FRIENDS_FILE = "./AI/USER_AI/RNAI_MAI/custom/friends_data.lua"

friends = friends or {}

-- 函數：SaveFriendsData
-- 功能：將目前的好友清單寫入檔案（覆寫），包含職業資訊。
-- 參數：無
-- 回傳：boolean 是否成功
-- 副作用：寫入檔案 `FRIENDS_FILE`。

function SaveFriendsData()
	local success, err = pcall(function()
		local file = io.open(FRIENDS_FILE, "w")
		if not file then
			LogAI("無法創建好友數據文件: " .. FRIENDS_FILE, "friend")
			return false
		end
		file:write("-- 好友數據持久化文件\n")
		file:write("-- 自動生成，請勿手動修改\n")
		file:write("-- 格式：ID, -- 職業名稱\n\n")
		file:write("friends = {\n")
		-- 只保存有效的數字ID，並附加職業資訊
		local validCount = 0
		for i, friendId in ipairs(friends) do
			if type(friendId) == "number" and friendId > 0 then
				-- 嘗試獲取職業資訊
				local jobType = GetV(V_HOMUNTYPE, friendId)
				local jobName = "未知"
				if PLAYER_JOBS ~= nil and jobType ~= nil and PLAYER_JOBS[jobType] ~= nil then
					jobName = PLAYER_JOBS[jobType] .. "(" .. tostring(jobType) .. ")"
				elseif jobType ~= nil then
					jobName = "職業編號:" .. tostring(jobType)
				end
				file:write("  " .. tostring(friendId) .. ", -- " .. jobName .. "\n")
				validCount = validCount + 1
			end
		end
		file:write("}\n")
		file:close()
		LogAI("好友數據已保存到: " .. FRIENDS_FILE .. " (共 " .. validCount .. " 個好友)", "friend")
		return true
	end)
	if not success then
		LogAI("保存好友數據時發生錯誤: " .. tostring(err), "friend")
		return false
	end
	return true
end

-- 函數：LoadFriendsData
-- 功能：自檔案載入好友清單；若不存在則建立空表並視為成功。
-- 參數：無
-- 回傳：boolean 是否成功
function LoadFriendsData()
	local success, err = pcall(function()
		if not file_exist(FRIENDS_FILE) then
			-- 文件不存在，初始化空列表並自動創建文件
			friends = {}
			SaveFriendsData()  -- 自動創建文件
			LogAI("好友數據已初始化（新建文件）: " .. FRIENDS_FILE, "friend")
			return true
		end
		dofile(FRIENDS_FILE)
		if friends == nil then
			friends = {}
		end
		
		-- 清理無效數據：過濾掉非數字或無效的ID
		local cleanFriends = {}
		local removedCount = 0
		for i, friendId in ipairs(friends) do
			if type(friendId) == "number" and friendId > 0 then
				cleanFriends[#cleanFriends+1] = friendId
			else
				removedCount = removedCount + 1
				LogAI("已移除無效好友數據: " .. tostring(friendId) .. " (類型: " .. type(friendId) .. ")", "friend")
			end
		end
		friends = cleanFriends
		
		-- 如果清理掉了無效數據，重新保存
		if removedCount > 0 then
			SaveFriendsData()
			LogAI("已清理 " .. removedCount .. " 個無效好友數據並重新保存", "friend")
		end
		
		LogAI("好友數據已載入: " .. FRIENDS_FILE .. " (共 " .. #friends .. " 個好友)", "friend")
		return true
	end)
	if not success then
		LogAI("載入好友數據時發生錯誤: " .. tostring(err), "friend")
		friends = {}
		return false
	end
	return true
end

-- 函數：existsInFriends（內部）
-- 功能：檢查 id 是否已存在於好友清單中。
-- 參數：id(number)
-- 回傳：boolean
local function existsInFriends(id)
	for i, v in ipairs(friends) do
		if v == id then return true end
	end
	return false
end

-- 函數：Friends_Clear
-- 功能：清空好友清單並立即持久化。
-- 參數：無
-- 回傳：無
function Friends_Clear()
	friends = {}
	SaveFriendsData()
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
	if not existsInFriends(id) then
		friends[#friends+1] = id
		SaveFriendsData()
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
	local beforeCount = #friends
	
	for i, actorId in ipairs(actors) do
		-- 排除：怪物、自己、主人
		if IsMonster(actorId) == 0 and 
		   actorId ~= myid and 
		   actorId ~= oid then
			
			-- 檢查是否已經是好友
			if not existsInFriends(actorId) then
				Friends_Add(actorId)
				addedCount = addedCount + 1
			end
		end
	end
	
	LogAI("好友快照完成: 新增 " .. addedCount .. " 個好友 (總數: " .. #friends .. ")", "friend")
	
	return addedCount
end


