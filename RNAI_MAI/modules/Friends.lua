-- 好友系統模組
-- 說明：
--   提供好友清單的持久化、加入、清空與矩形區域批次加入。
-- 設定：
--   - FRIENDS_FILE：好友資料的儲存檔案路徑。

local FRIENDS_FILE = "./AI/USER_AI/RNAI_MAI/custom/friends_data.lua"

friends = friends or {}

-- 函數：SaveFriendsData
-- 功能：將目前的好友清單寫入檔案（覆寫）。
-- 參數：無
-- 回傳：boolean 是否成功
-- 副作用：寫入檔案 `FRIENDS_FILE`。

function SaveFriendsData()
	local success, err = pcall(function()
		local file = io.open(FRIENDS_FILE, "w")
		if not file then
			TraceAI("無法創建好友數據文件: " .. FRIENDS_FILE)
			return false
		end
		file:write("-- 好友數據持久化文件\n")
		file:write("-- 自動生成，請勿手動修改\n\n")
		file:write("friends = {\n")
		for i, friendId in ipairs(friends) do
			file:write("  " .. tostring(friendId) .. ",\n")
		end
		file:write("}\n")
		file:close()
		TraceAI("好友數據已保存到: " .. FRIENDS_FILE .. " (共 " .. #friends .. " 個好友)")
		return true
	end)
	if not success then
		TraceAI("保存好友數據時發生錯誤: " .. tostring(err))
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
			TraceAI("好友數據文件不存在: " .. FRIENDS_FILE)
			return true
		end
		dofile(FRIENDS_FILE)
		if friends == nil then
			friends = {}
		end
		TraceAI("好友數據已載入: " .. FRIENDS_FILE .. " (共 " .. #friends .. " 個好友)")
		return true
	end)
	if not success then
		TraceAI("載入好友數據時發生錯誤: " .. tostring(err))
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
	if id == nil or id <= 0 then return end
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


