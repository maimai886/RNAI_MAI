-- 跟隨距離（格；以矩形距離計）：超過此距離會主動靠近主人
FollowDis=3
-- 移動指令最小間隔（毫秒）：限制下達移動的頻率，避免過度抖動
MoveDelay=500
-- 搜尋/交戰半徑（格）：目標評分時用於判斷範圍內外（SearchSetting[7]/[8]）
RadiusAggr=12

-- {主人被打,生命體被打,其他玩家被打,主人攻擊,生命體攻擊,其他玩家攻擊,範圍外,範圍內}
SearchMode={{128,0,0,256,0,0,-128,-128},{256,128,0,256,30,64,-128,1}}

-- 攻擊模式 1:被動 2:主動 對應SearchMode的索引
SearchSetting=SearchMode[2]

-- 弱目標 對此清單中的怪物使用普攻
-- example:WeakTargets={1234,1235,1236}
WeakTargets={}

-- 1078紅草,1079藍草,1080綠草,1081黃草,1082白草,1083光芒草,1084黑菇,1085紅菇,1555苗娃,2569獸副黑影
-- 忽略目標（不列入評分、不主動攻擊）。
-- example:IgnoreTargets={1078,1079,1080}
IgnoreTargets={1078,1079,1080,1081,1082,1083,1084,1085,1555,2569}

-- 指定攻擊目標（優先模式）：當此陣列有值時，只攻擊清單中的怪物(啟用即WeakTargets IgnoreTargets無效)
-- 若為空陣列 {} 則使用一般模式（攻擊所有非忽略目標）
-- example:TargetMonsters={1002,1007,1011,1118} -- 只攻擊波利、瘋兔、綠棉蟲、噬人花
TargetMonsters={}

-- 優先攻擊目標：當地圖中出現此列表中的怪物時，生命體會優先攻擊這些目標
-- 此參數會給予列表中的怪物更高的攻擊優先級，但仍會攻擊其他非忽略目標
-- example:MainTargets={1068,3903,3974} -- 優先攻擊獸副花、蟲副蛋、蟲副王蛋
MainTargets={1068,3903,3974}

-- PvP 模式：0關閉（只評分怪物）、1開啟（玩家也納入評分）。
-- 注意：朋友（friends）、自己（myid）與主人（oid）不會被納入攻擊目標。
PvPMode=0

-- 守衛模式：0關閉（跟隨模式）、1開啟（守衛模式）、2轉圈模式
-- 守衛模式下生命體會保持在玩家前方6格保護玩家 並且將距離最近的怪物試為優先攻擊目標
-- 轉圈模式下生命體將不停在玩家周圍轉圈
GuardMode=0
-- 守衛/轉圈距離（格）：生命體與玩家的距離
GuardDistance=3

-- 跳舞攻擊模式
UseDanceAttack=0 -- 是否啟用跳舞攻擊 0關閉、1一般舞步、2狂暴舞步
DanceMinSP={70,100} -- 施放跳舞攻擊的SP區間

Skill={}

Skill[#Skill+1]={}
Skill[#Skill].id=8013 --善變
Skill[#Skill].lv=5
Skill[#Skill].target=0
Skill[#Skill].when=1
Skill[#Skill].times=1
Skill[#Skill].delay=3000
Skill[#Skill].sp={70,100} -- SP區間：搭配混亂祈福保持70%魔量，應對緊急狀況
Skill[#Skill].hp={0,100}
Skill[#Skill].ownerSp={0,100}
Skill[#Skill].ownerHp={0,100}
Skill[#Skill].nMyEnemy=0
Skill[#Skill].nOwnerEnemy=0
Skill[#Skill].nRangeEnemy=0
Skill[#Skill].chase=1
Skill[#Skill].stemp=0
Skill[#Skill].count=0

Skill[#Skill+1]={}
Skill[#Skill].id=8014 -- 混亂祈福
Skill[#Skill].lv=4
Skill[#Skill].target=0
Skill[#Skill].when=1
Skill[#Skill].times=1
Skill[#Skill].delay=1000
Skill[#Skill].sp={0,100}
Skill[#Skill].hp={0,50} -- 生命體HP區間設定：0-50%時使用此技能
Skill[#Skill].nMyEnemy=0
Skill[#Skill].nOwnerEnemy=0
Skill[#Skill].nRangeEnemy=0
Skill[#Skill].chase=1
Skill[#Skill].stemp=0
Skill[#Skill].count=0

Skill[#Skill+1]={}
Skill[#Skill].id=8014 -- 混亂祈福
Skill[#Skill].lv=3
Skill[#Skill].target=0
Skill[#Skill].when=1
Skill[#Skill].times=1
Skill[#Skill].delay=1000
Skill[#Skill].ownerSp={0,100}
Skill[#Skill].ownerHp={0,50} -- 主人HP區間設定：0-50%時使用此技能
Skill[#Skill].nMyEnemy=0
Skill[#Skill].nOwnerEnemy=0
Skill[#Skill].nRangeEnemy=0
Skill[#Skill].chase=1
Skill[#Skill].stemp=0
Skill[#Skill].count=0

Skill[#Skill+1]={}
Skill[#Skill].id=0 -- 普攻技能ID（0代表普通攻擊）
Skill[#Skill].lv=1 -- 技能等級（普攻固定為1級）
Skill[#Skill].target=0 -- 目標類型：0=魔物，1=主人，2=生命體/傭兵
Skill[#Skill].when=1 -- 使用時機：1=攻擊時，2=被攻擊時，3=常駐
Skill[#Skill].times=1 -- 連續使用次數：1=使用1次後冷卻
Skill[#Skill].delay=0 -- 冷卻延遲時間（毫秒）：0=無延遲
Skill[#Skill].sp={0,100} -- SP區間：0%-100%（任何SP狀態都可使用）
Skill[#Skill].hp={0,100} -- HP區間：0%-100%（任何HP狀態都可使用）
Skill[#Skill].ownerSp={0,100} -- 主人SP區間：0%-100%
Skill[#Skill].ownerHp={0,100} -- 主人HP區間：0%-100%
Skill[#Skill].nMyEnemy=0 -- 生命體敵人數量條件：0=無限制
Skill[#Skill].nOwnerEnemy=0 -- 主人敵人數量條件：0=無限制
Skill[#Skill].nRangeEnemy=0 -- 範圍內敵人數量條件：0=無限制
Skill[#Skill].chase=1 -- 是否追擊：1=會追擊，0=不追擊
Skill[#Skill].stemp=0 -- 上次使用時間戳記（系統自動管理）
Skill[#Skill].count=0 -- 使用計數器（系統自動管理）