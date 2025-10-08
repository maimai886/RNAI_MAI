--  c function

--  c function
--[[
function TraceAI (string) end                   -- 紀錄現在執行中的劇本 (輸出到 TraceAI.txt)
function MoveToOwner (id) end                   -- 讓生命體移動到主人身邊附近
function Move (id,x,y) end                      -- 讓生命體往目的地移動
function Attack (id1,id2) end                   -- 讓 id1 去攻擊 id2
function GetV (V_,id) end                       -- 獲得 id 的屬性 (V_...)
function GetActors () end                       -- 在角色視線裡的角色/NPC/魔物/物品/技能 id 集合
function GetTick () end                         -- 獲得電腦時間 (毫秒計數)
function GetMsg (id) end                        -- 取得使用者的直接命令 (回傳table)
function GetResMsg (id) end                     -- 取得使用者的預約命令 (回傳table)
function SkillObject (id,level,skill,target) end -- 對目標使用技能
function SkillGround (id,level,skill,x,y) end   -- 對地面使用技能
function IsMonster (id) end                     -- 判別是否為魔物 (是=1, 否=0)
--]]

-------------------------------------------------
-- constants 常數 (Const.lua)
-------------------------------------------------

V_OWNER     = 0   -- 把主人的編號歸還
V_POSITION  = 1   -- 現在位置 (x,y)
V_TYPE      = 2   -- 是哪一種個體? (未開放)
V_MOTION    = 3   -- 現在動作
V_ATTACKRANGE = 4 -- 攻擊範圍 (未開放，暫定1格)
V_TARGET    = 5   -- 攻擊或使用技能目標
V_SKILLATTACKRANGE = 6  -- 技能攻擊範圍 (未開放)
V_HOMUNTYPE = 7   -- 生命體種類
V_HP        = 8   -- 生命體或主人的 HP
V_SP        = 9   -- 生命體或主人的 SP
V_MAXHP     = 10  -- 生命體或主人的最大 HP
V_MAXSP     = 11  -- 生命體或主人的最大 SP
V_MERTYPE   = 12  -- 傭兵種類
V_POSITION_APPLY_SKILLATTACKRANGE = 13 -- SkillAttackRange 套用後的位置
V_SKILLATTACKRANGE_LEVEL = 14         -- 各等級 SkillAttackRange
---------------------------------

--------------------------------------------
-- 生命體種類 (GetV V_HOMUNTYPE)
--------------------------------------------
LIF            = 1   -- 麗芙
AMISTR         = 2   -- 艾咪斯可魯
FILIR          = 3   -- 飛里樂
VANILMIRTH     = 4   -- 巴尼米樂斯
LIF2           = 5   -- 麗芙(第二型)
AMISTR2        = 6   -- 艾咪斯可魯(第二型)
FILIR2         = 7   -- 飛里樂(第二型)
VANILMIRTH2    = 8   -- 巴尼米樂斯(第二型)
LIF_H          = 9   -- 進化的 麗芙
AMISTR_H       = 10  -- 進化的 艾咪斯可魯
FILIR_H        = 11  -- 進化的 飛里樂
VANILMIRTH_H   = 12  -- 進化的 巴尼米樂斯
LIF_H2         = 13  -- 進化的 麗芙(第二型)
AMISTR_H2      = 14  -- 進化的 艾咪斯可魯(第二型)
FILIR_H2       = 15  -- 進化的 飛里樂(第二型)
VANILMIRTH_H2  = 16  -- 進化的 巴尼米樂斯(第二型)
--------------------------------------------

--------------------------------------------
-- 傭兵種類 (GetV V_MERTYPE)
--------------------------------------------
ARCHER01 = 1   -- 弓箭手01
ARCHER02 = 2   -- 弓箭手02
ARCHER03 = 3   -- 弓箭手03
ARCHER04 = 4   -- 弓箭手04
ARCHER05 = 5   -- 弓箭手05
ARCHER06 = 6   -- 弓箭手06
ARCHER07 = 7   -- 弓箭手07
ARCHER08 = 8   -- 弓箭手08
ARCHER09 = 9   -- 弓箭手09
ARCHER10 = 10  -- 弓箭手10
LANCER01 = 11  -- 槍兵01
LANCER02 = 12  -- 槍兵02
LANCER03 = 13  -- 槍兵03
LANCER04 = 14  -- 槍兵04
LANCER05 = 15  -- 槍兵05
LANCER06 = 16  -- 槍兵06
LANCER07 = 17  -- 槍兵07
LANCER08 = 18  -- 槍兵08
LANCER09 = 19  -- 槍兵09
LANCER10 = 20  -- 槍兵10
SWORDMAN01 = 21 -- 劍士01
SWORDMAN02 = 22 -- 劍士02
SWORDMAN03 = 23 -- 劍士03
SWORDMAN04 = 24 -- 劍士04
SWORDMAN05 = 25 -- 劍士05
SWORDMAN06 = 26 -- 劍士06
SWORDMAN07 = 27 -- 劍士07
SWORDMAN08 = 28 -- 劍士08
SWORDMAN09 = 29 -- 劍士09
SWORDMAN10 = 30 -- 劍士10
--------------------------------------------

--------------------------
-- 動作 (GetV V_MOTION)
--------------------------
MOTION_STAND   = 0  -- 站立的動作
MOTION_MOVE    = 1  -- 移動中的動作
MOTION_ATTACK  = 2  -- 攻擊中的動作
MOTION_DEAD    = 3  -- 死亡的動作
MOTION_ATTACK2 = 9  -- 攻擊時的動作2
--------------------------

--------------------------
-- 命令 (GetMsg / GetResMsg)
--------------------------
NONE_CMD          = 0  -- 沒有命令 {命令編號}
MOVE_CMD          = 1  -- 移動 {命令編號,X座標,Y座標}
STOP_CMD          = 2  -- 停止 {命令編號}
ATTACK_OBJECT_CMD = 3  -- 攻擊 {命令編號,目標ID}
ATTACK_AREA_CMD   = 4  -- 區域攻擊 {命令編號,X座標,Y座標}
PATROL_CMD        = 5  -- 偵查 {命令編號,X座標,Y座標}
HOLD_CMD          = 6  -- 死守 {命令編號}
SKILL_OBJECT_CMD  = 7  -- 使用技能 {命令編號,選擇等級,種類,目標ID}
SKILL_AREA_CMD    = 8  -- 使用區域技能 {命令編號,選擇等級,種類,X座標,Y座標}
FOLLOW_CMD        = 9  -- 跟隨主人 {命令編號}
--------------------------
--[[ 指令結構 

MOVE_CMD
	{命令編號, X座標, Y座標}

STOP_CMD
	{命令編號}

ATTACK_OBJECT_CMD
	{命令編號, 目標ID}

ATTACK_AREA_CMD
	{命令編號, X座標, Y座標}

PATROL_CMD
	{命令編號, X座標, Y座標}

HOLD_CMD
	{命令編號}

SKILL_OBJECT_CMD
	{命令編號, 選擇等級, 種類, 目標ID}

SKILL_AREA_CMD
	{命令編號, 選擇等級, 種類, X座標, Y座標}

FOLLOW_CMD
	{命令編號}

--]]
