-- 日誌輸出模組
-- 說明：
--   提供統一的日誌輸出功能，支援分類輸出到不同文件。
--   當 EnableDebugLog 開啟時，日誌會輸出到 RNAI_MAI/log/ 目錄下的對應文件。
-- 設定：
--   - EnableDebugLog：日誌開關（0:關閉 / 1:開啟）
--   - LogCategories：控制哪些類別要輸出（nil = 全部輸出）

-- 日誌分類配置（在 custom/*.lua 中設置）
-- 設為 nil 則輸出所有類別，設為 table 則只輸出指定類別
-- 例如：LogCategories = {combat = true, move = false}
LogCategories = LogCategories or nil

-- 日誌文件映射表
local LOG_FILES = {
	combat = "./AI/USER_AI/RNAI_MAI/log/combat.log",      -- 戰鬥日誌
	skill = "./AI/USER_AI/RNAI_MAI/log/skill.log",        -- 技能日誌
	move = "./AI/USER_AI/RNAI_MAI/log/move.log",          -- 移動日誌
	friend = "./AI/USER_AI/RNAI_MAI/log/friend.log",      -- 好友日誌
	pvp = "./AI/USER_AI/RNAI_MAI/log/pvp.log",            -- PvP日誌
	map = "./AI/USER_AI/RNAI_MAI/log/map.log",            -- 地圖刷新日誌
	guard = "./AI/USER_AI/RNAI_MAI/log/guard.log",        -- 守衛日誌
	dance = "./AI/USER_AI/RNAI_MAI/log/dance.log",        -- 跳舞攻擊日誌
	init = "./AI/USER_AI/RNAI_MAI/log/init.log",          -- 初始化日誌
	default = "./AI/USER_AI/RNAI_MAI/log/general.log"     -- 一般日誌（無分類）
}

--- 調試日誌輸出函數（支援分類輸出）
--- @param msg string 要輸出的訊息
--- @param category string 可選，日誌類別（combat/skill/move/friend/pvp/map/guard/dance/init）
--- @return nil
--- 使用方法：
---   LogAI("訊息") - 輸出到 general.log
---   LogAI("訊息", "combat") - 輸出到 combat.log
---   LogAI("訊息", "move") - 輸出到 move.log
function LogAI(msg, category)
	-- 快速返回：如果未啟用調試日誌，直接返回，節省效能
	if EnableDebugLog == nil or EnableDebugLog == 0 then
		return
	end
	
	-- 如果設置了分類過濾，檢查是否要輸出此類別
	if LogCategories ~= nil and category ~= nil then
		if LogCategories[category] ~= true then
			return  -- 此類別被過濾掉
		end
	end
	
	-- 確定輸出文件
	local logFile = LOG_FILES.default
	if category ~= nil and LOG_FILES[category] ~= nil then
		logFile = LOG_FILES[category]
	end
	
	-- 輸出到檔案
	local success, err = pcall(function()
		local file = io.open(logFile, "a")
		if file then
			-- 添加時間戳記：實際時間 + 遊戲時間
			local realTime = os.date("%H:%M:%S")  -- 實際時間 時:分:秒
			local gameTick = GetTick()             -- 遊戲時間（毫秒）
			local timestamp = string.format("[%s|%d] ", realTime, gameTick)
			file:write(timestamp .. tostring(msg) .. "\n")
			file:close()
		end
	end)
	
	-- 如果寫入失敗，使用 TraceAI 作為備用方案
	if not success then
		TraceAI("[LogAI錯誤] " .. tostring(msg))
	end
end

--- 清空日誌檔案
--- @return nil
function LogAI_Clear()
	if EnableDebugLog == nil or EnableDebugLog == 0 then
		return
	end
	
	local success = pcall(function()
		local file = io.open(LOG_FILE, "w")
		if file then
			file:write("-- RNAI_MAI 調試日誌\n")
			file:write("-- 時間: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
			file:close()
		end
	end)
	
	if not success then
		TraceAI("[LogAI_Clear錯誤] 無法清空日誌檔案")
	end
end

