extends Node2D

# ==============================================================================
# 《小岛日记 (Little Island Diary)》 —— 真实像素图标接入 + 完整岛屿生态 + 全面屏无留白正式版
# 核心架构与完成项：
# 1. 统一图标资源映射加载器 (ICON_PATHS + _get_icon_tex)：
#    - 真实加载 res://sprites/tools_items/*.png 与 res://sprites/ui/*.png 共 31+ 个 PNG 图标
#    - 快捷栏 6 槽全部替换为真实 PNG 图标 + 选中高亮框 + 右下角数量角标
#    - 顶部状态栏接入 calendar_ui.png、weather_ui.png、coins_ui.png
#    - 顶部右侧按钮组（岛建、背包、地图、设置/菜单）与右侧操作按钮（互动、使用、取消）全部接入真实图标+短标签
#    - 岛建模式独立图标工具栏（草地、铲平、造高地、水域、道路、植物、建筑、装饰、移动物体、撤销、重做、确认、取消）
#    - 背包与商店网格全部显示真实物品 PNG 图标、名称、数量与价格
# 2. 彻底修复手机全面屏左右灰色留白：
#    - RenderingServer.set_default_clear_color(PAL_OCEAN_BLUE)
#    - 海洋背景与动态波浪无限延伸覆盖 [-24..GRID_WIDTH+24]，放宽摄像机边界
#    - 所有全屏遮罩与 HUD 根节点动态跟随 get_viewport_rect().size 自适应布局
# 3. 完整岛屿生态与深度 Y-Sort 渲染：
#    - 44x44 丰富岛屿分区：西北松林、东北高地瀑布、中央喷泉广场、西侧住宅庭院、东侧河畔集市、南侧金沙滩与木栈桥码头
#    - 地形自然衔接：草地深浅花簇、沙滩圆角齿边、河岸鹅卵石与浪花、石板路自动连通、木桥栏杆
#    - 严格 Y-Sort 深度排序：地面 -> 树干/阴影 -> 建筑/装饰/玩家/5位小动物按 Y 坐标交错绘制 -> 树冠遮挡层
# ==============================================================================

const GRID_WIDTH: int = 64
const GRID_HEIGHT: int = 64
# 旧版 44x44 岛屿核心在新地图中的平移量（保证原建筑/广场/河道相对位置不变）
const MAP_CORE_OX: int = 10
const MAP_CORE_OY: int = 10
const LEGACY_GRID_SIZE: int = 44
const TILE_SIZE: int = 16
const SAVE_PATH: String = "user://little_island_diary_save_v2.json"
const TEMP_SAVE_PATH: String = "user://little_island_diary_save_v2.tmp"
const BAK_SAVE_PATH: String = "user://little_island_diary_save_v2.bak"
const SAVE_VERSION: int = 10

# --- 《小岛日记》V1.0 核心锁定色板 ---
const PAL_CREAM      := Color("#FFF2D6")
const PAL_CREAM_DARK := Color("#F2DEC0")
const PAL_SKY_BLUE   := Color("#74C9ED")
const PAL_OCEAN_BLUE := Color("#379CC9")
const PAL_DEEP_OCEAN := Color("#2B82AB")
const PAL_GRASS      := Color("#83C96D")
const PAL_GRASS_ALT  := Color("#78BE62")
const PAL_HIGH_GRASS := Color("#91D47A")
const PAL_FOREST     := Color("#39815D")
const PAL_SAND       := Color("#F5DDA1")
const PAL_SAND_ALT   := Color("#EBD193")
const PAL_WET_SAND   := Color("#D9BC7E")
const PAL_EARTH      := Color("#B98761")
const PAL_WOOD       := Color("#8A5B45")
const PAL_PINK       := Color("#EE8398")
const PAL_CORAL      := Color("#F08A61")
const PAL_GOLD       := Color("#F7D460")
const PAL_OUTLINE    := Color("#544A44")

# --- 统一图标资源映射表（指向项目内 res://sprites/ 下的真实 PNG 文件） ---
const ICON_PATHS: Dictionary = {
	# 工具与物品图标 (res://sprites/tools_items/)
	"shovel":         "res://sprites/tools_items/shovel.png",
	"axe":            "res://sprites/tools_items/axe.png",
	"watering_can":   "res://sprites/tools_items/watering_can.png",
	"bug_net":        "res://sprites/tools_items/bug_net.png",
	"fishing_rod":    "res://sprites/tools_items/fishing_rod.png",
	"flower":         "res://sprites/tools_items/flower.png",
	"potted_plant":   "res://sprites/tools_items/potted_plant.png",
	"grass_tile":     "res://sprites/tools_items/grass_tile.png",
	"dirt_tile":      "res://sprites/tools_items/dirt_tile.png",
	"raised_terrain": "res://sprites/tools_items/raised_terrain.png",
	"water_tile":     "res://sprites/tools_items/water_tile.png",
	"stone_path":     "res://sprites/tools_items/stone_path.png",
	"house":          "res://sprites/tools_items/house.png",
	"shop":           "res://sprites/tools_items/shop.png",
	"hammer":         "res://sprites/tools_items/hammer.png",
	"backpack":       "res://sprites/tools_items/backpack.png",
	"island_map":     "res://sprites/tools_items/island_map.png",
	"settings":       "res://sprites/tools_items/settings.png",
	"interact_hand":  "res://sprites/tools_items/interact_hand.png",
	"use_tool":       "res://sprites/tools_items/use_tool.png",
	"confirm":        "res://sprites/tools_items/confirm.png",
	"cancel":         "res://sprites/tools_items/cancel.png",
	"undo":           "res://sprites/tools_items/undo.png",
	"redo":           "res://sprites/tools_items/redo.png",
	"wood":           "res://sprites/tools_items/wood.png",
	"shell":          "res://sprites/tools_items/shell.png",
	"fish":           "res://sprites/tools_items/fish.png",
	"butterfly":      "res://sprites/tools_items/butterfly.png",
	"apple":          "res://sprites/tools_items/apple.png",
	"bench":          "res://sprites/tools_items/bench.png",
	"street_lamp":    "res://sprites/tools_items/street_lamp.png",
	"carrot":         "res://sprites/tools_items/flower.png",
	"tomato":         "res://sprites/tools_items/apple.png",
	"pumpkin":        "res://sprites/tools_items/grass_tile.png",
	"strawberry":     "res://sprites/tools_items/butterfly.png",

	# 系统 UI 专用图标 (res://sprites/ui/)
	"calendar_ui":    "res://sprites/ui/calendar_ui.png",
	"weather_ui":     "res://sprites/ui/weather_ui.png",
	"coins_ui":       "res://sprites/ui/coins_ui.png",
	"backpack_ui":    "res://sprites/ui/backpack_ui.png",
	"map_ui":         "res://sprites/ui/map_ui.png",
	"settings_ui":    "res://sprites/ui/settings_ui.png",
	"shop_ui":        "res://sprites/ui/shop_ui.png",
	"home_ui":        "res://sprites/ui/home_ui.png",
	"mail_ui":        "res://sprites/ui/mail_ui.png",
	"interact_ui":    "res://sprites/ui/interact_ui.png",
	"use_tool_ui":    "res://sprites/ui/use_tool_ui.png",
	"confirm_ui":     "res://sprites/ui/confirm_ui.png",
	"cancel_ui":      "res://sprites/ui/cancel_ui.png",
	"undo_ui":        "res://sprites/ui/undo_ui.png",
	"redo_ui":        "res://sprites/ui/redo_ui.png",
	"grass_ui":       "res://sprites/ui/grass_ui.png",
	"river_ui":       "res://sprites/ui/river_ui.png",
	"move_ui":        "res://sprites/ui/move_ui.png",

	# 室内外精致像素家具与设施贴图 (res://sprites/furniture/)
	"bed":            "res://sprites/furniture/bed.png",
	"sofa":           "res://sprites/furniture/sofa.png",
	"table":          "res://sprites/furniture/table.png",
	"chair":          "res://sprites/furniture/chair.png",
	"bookshelf":      "res://sprites/furniture/bookshelf.png",
	"lamp":           "res://sprites/furniture/lamp.png",
	"rug":            "res://sprites/furniture/rug.png",
	"wardrobe":       "res://sprites/furniture/wardrobe.png",
	"record_player":  "res://sprites/furniture/record_player.png",
	"storage_box":    "res://sprites/furniture/storage_box.png",
	"display_case":   "res://sprites/furniture/display_case.png",
	"seed_rack":      "res://sprites/furniture/seed_rack.png",
	"shell_rack":     "res://sprites/furniture/shell_rack.png",
	"sports_gear":    "res://sprites/furniture/sports_gear.png",
	"map_wall":       "res://sprites/furniture/map_wall.png",
	"stove_counter":  "res://sprites/furniture/stove_counter.png",
	"stairs_up":      "res://sprites/furniture/stairs_up.png",
	"stairs_down":    "res://sprites/furniture/stairs_down.png",
	"double_bed":     "res://sprites/furniture/double_bed.png",
	"fridge":         "res://sprites/furniture/fridge.png",
	"fish_tank":      "res://sprites/furniture/fish_tank.png",
	"clock":          "res://sprites/furniture/clock.png",
	"trash_can":      "res://sprites/furniture/trash_can.png",
	"telescope":      "res://sprites/furniture/telescope.png",
	"easel":          "res://sprites/furniture/easel.png",
	"piano":          "res://sprites/furniture/piano.png",
	"counter_desk":   "res://sprites/furniture/counter_desk.png"
}

const CHAR_WALK_PATHS: Dictionary = {
	"player": "res://sprites/characters/player_walk.png",
	"bear":   "res://sprites/characters/bear_walk.png",
	"cat":    "res://sprites/characters/cat_walk.png",
	"rabbit": "res://sprites/characters/rabbit_walk.png",
	"deer":   "res://sprites/characters/deer_walk.png",
	"fox":    "res://sprites/characters/fox_walk.png",
	"frog":   "res://sprites/characters/frog_walk.png",
	"otter":  "res://sprites/characters/otter_walk.png",
	"bird":   "res://sprites/characters/bird_walk.png"
}

const PORTRAIT_EXPRS: Array = ["neutral", "happy", "surprised", "sleepy", "shy", "angry", "confused"]
const EXPR_CN_NAMES: Dictionary = {
	"neutral": "普通",
	"happy": "开心",
	"surprised": "惊讶",
	"sleepy": "困倦",
	"shy": "害羞",
	"angry": "生气",
	"confused": "疑惑"
}

var _icon_cache: Dictionary = {}
var _walk_tex_cache: Dictionary = {}
var _portrait_tex_cache: Dictionary = {}

enum GameState {
	TITLE_SCREEN = 0,
	EXPLORE_MODE = 1,
	BUILD_MODE = 2
}

enum GroundType {
	DEEP_WATER = 0,
	SHALLOW_WATER = 1,
	SAND = 2,
	GRASS = 3,
	RIVER = 4,
	BRIDGE = 5,
	STONE_PATH = 6,
	WOOD_PATH = 7,
	TILLED_SOIL = 8
}

enum ObjectType {
	NONE = 0,
	TREE_OAK = 1,
	FLOWER_PINK = 2,
	WEED = 3,
	SHELL = 4,
	BUSH = 5,
	BENCH = 6,
	LAMP = 7,
	FENCE = 8,
	HOUSE = 9,
	SHOP = 10,
	CONSTRUCTION = 11,
	FLOWER_WATERED = 12,
	FOUNTAIN = 13,
	MAILBOX = 14,
	FLOWER_PLANTER = 15,
	SIGNBOARD = 16,
	TREE_PINE = 17,
	TREE_PALM = 18,
	FLOWER_YELLOW = 19,
	ROCK = 20,
	STUMP = 21,
	MUSHROOM = 22,
	VILLAGER_HOUSE = 23,
	RAMP = 24,
	LIBRARY = 25,
	CANTEEN = 26,
	SPORTS = 27,
	FURNITURE_SHOP = 28,
	SEED_SHOP = 29,
	BOOKSHELF = 30,
	RECORD_PLAYER = 31,
	SHELL_SHELF = 32,
	DINING_TABLE = 33,
	BED = 34,
	SOFA = 35,
	CHAIR = 36,
	WARDROBE = 37,
	STORAGE_BOX = 38,
	RUG = 39,
	DISPLAY_CASE = 40
}

enum BuildTool {
	GROUND_GRASS = 0,
	FLATTEN = 1,
	CLIFF_RAISE = 2,
	RIVER_DIG = 3,
	ROAD_PAVE = 4,
	PLANT_PUT = 5,
	BUILDING_PUT = 6,
	DECOR_PUT = 7,
	MOVE_OBJECT = 8,
	FARM = 9
}

# --- 核心游戏状态 ---
var game_state: int = GameState.TITLE_SCREEN
var coins: int = 1800
var env_anim_time: float = 0.0

# --- 地图与地形三维状态 ---
var ground_grid: Array = []     # [x][y] -> GroundType
var elevation_grid: Array = []  # [x][y] -> 0:水面, 1:平地, 2:二层高地
var object_grid: Array = []     # [x][y] -> ObjectType

# --- 玩家角色与摄像机 ---
var player_pos: Vector2 = Vector2(21.5 * TILE_SIZE, 22.5 * TILE_SIZE)
var player_facing: Vector2 = Vector2.DOWN
var walk_anim_time: float = 0.0
var tool_swing_timer: float = 0.0

# --- 点击地面自动寻路 ---
var auto_path: Array[Vector2i] = []
var path_target_cell: Vector2i = Vector2i(-1, -1)
var path_last_pos: Vector2 = Vector2.ZERO
var path_stuck_time: float = 0.0
const BASE_MOVE_SPEED: float = 90.0
const COLLISION_HALF_SIZE: Vector2 = Vector2(4.2, 4.2)
var camera: Camera2D

# --- 首批 8 位动物居民（熊、猫、兔子、鹿、狐狸、青蛙、海獭、小鸟） ---
const VILLAGER_HOUSE_CELLS: Dictionary = {
	"bear":   Vector2i(22, 33),
	"cat":    Vector2i(18, 31),
	"rabbit": Vector2i(16, 36),
	"deer":   Vector2i(26, 24),
	"fox":    Vector2i(44, 34),
	"frog":   Vector2i(18, 42),
	"otter":  Vector2i(34, 44),
	"bird":   Vector2i(46, 24)
}

var animals: Array = [
	{
		"id": "bear",
		"name": "小熊阿棕",
		"species": "小熊",
		"trait": "温和",
		"pos": Vector2(22.5 * TILE_SIZE, 34.5 * TILE_SIZE),
		"home": Vector2(22.5 * TILE_SIZE, 34.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#B98761"),
		"ear_col": Color("#8A5B45"),
		"shirt_col": Color("#F5DDA1"),
		"personality": {"social": 0.72, "curiosity": 0.65, "energy": 0.50, "calm": 0.92, "order": 0.75},
		"interests": ["阅读", "料理"],
		"needs": {"social": 0.60, "fun": 0.60, "energy": 0.80, "hunger": 0.70},
		"affinity": 25,
		"relations": {},
		"knowledge": 2,
		"memory": [],
		"action": "read",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 1.2,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "cat",
		"name": "小猫柒柒",
		"species": "猫咪",
		"trait": "独立",
		"pos": Vector2(18.5 * TILE_SIZE, 32.5 * TILE_SIZE),
		"home": Vector2(18.5 * TILE_SIZE, 32.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#F5B06C"),
		"ear_col": Color("#D97A3E"),
		"shirt_col": Color("#74C9ED"),
		"personality": {"social": 0.42, "curiosity": 0.75, "energy": 0.55, "calm": 0.88, "order": 0.68},
		"interests": ["音乐", "阅读"],
		"needs": {"social": 0.65, "fun": 0.58, "energy": 0.82, "hunger": 0.72},
		"affinity": 20,
		"relations": {},
		"knowledge": 1,
		"memory": [],
		"action": "stroll",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 1.8,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "rabbit",
		"name": "小兔露露",
		"species": "兔子",
		"trait": "活泼",
		"pos": Vector2(16.5 * TILE_SIZE, 37.5 * TILE_SIZE),
		"home": Vector2(16.5 * TILE_SIZE, 37.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#FFF9F5"),
		"ear_col": Color("#EE8398"),
		"shirt_col": Color("#EE8398"),
		"personality": {"social": 0.90, "curiosity": 0.70, "energy": 0.85, "calm": 0.55, "order": 0.65},
		"interests": ["花", "园艺"],
		"needs": {"social": 0.55, "fun": 0.55, "energy": 0.85, "hunger": 0.75},
		"affinity": 25,
		"relations": {},
		"knowledge": 1,
		"memory": [],
		"action": "stroll",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 1.0,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "deer",
		"name": "小鹿森森",
		"species": "小鹿",
		"trait": "沉静",
		"pos": Vector2(26.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"home": Vector2(26.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#D89B65"),
		"ear_col": Color("#9A633A"),
		"shirt_col": Color("#39815D"),
		"personality": {"social": 0.60, "curiosity": 0.80, "energy": 0.55, "calm": 0.95, "order": 0.82},
		"interests": ["花", "阅读"],
		"needs": {"social": 0.62, "fun": 0.60, "energy": 0.80, "hunger": 0.74},
		"affinity": 22,
		"relations": {},
		"knowledge": 2,
		"memory": [],
		"action": "read",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 2.2,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "fox",
		"name": "小狐狸阿橙",
		"species": "狐狸",
		"trait": "机灵",
		"pos": Vector2(44.5 * TILE_SIZE, 35.5 * TILE_SIZE),
		"home": Vector2(44.5 * TILE_SIZE, 35.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#F08A61"),
		"ear_col": Color("#544A44"),
		"shirt_col": Color("#39815D"),
		"personality": {"social": 0.58, "curiosity": 0.95, "energy": 0.76, "calm": 0.68, "order": 0.55},
		"interests": ["探索", "收集"],
		"needs": {"social": 0.65, "fun": 0.52, "energy": 0.78, "hunger": 0.70},
		"affinity": 20,
		"relations": {},
		"knowledge": 2,
		"memory": [],
		"action": "stroll",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 2.6,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "frog",
		"name": "小青蛙呱呱",
		"species": "青蛙",
		"trait": "乐观",
		"pos": Vector2(18.5 * TILE_SIZE, 43.5 * TILE_SIZE),
		"home": Vector2(18.5 * TILE_SIZE, 43.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#7BC96F"),
		"ear_col": Color("#499B4A"),
		"shirt_col": Color("#74C9ED"),
		"personality": {"social": 0.82, "curiosity": 0.68, "energy": 0.92, "calm": 0.60, "order": 0.50},
		"interests": ["运动", "海"],
		"needs": {"social": 0.58, "fun": 0.52, "energy": 0.88, "hunger": 0.68},
		"affinity": 22,
		"relations": {},
		"knowledge": 1,
		"memory": [],
		"action": "play",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 1.6,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "otter",
		"name": "小海獭波波",
		"species": "海獭",
		"trait": "随和",
		"pos": Vector2(34.5 * TILE_SIZE, 45.5 * TILE_SIZE),
		"home": Vector2(34.5 * TILE_SIZE, 45.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#9A6B4E"),
		"ear_col": Color("#6D4832"),
		"shirt_col": Color("#379CC9"),
		"personality": {"social": 0.85, "curiosity": 0.72, "energy": 0.74, "calm": 0.80, "order": 0.60},
		"interests": ["海", "料理"],
		"needs": {"social": 0.56, "fun": 0.58, "energy": 0.78, "hunger": 0.66},
		"affinity": 24,
		"relations": {},
		"knowledge": 1,
		"memory": [],
		"action": "play",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 2.1,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	},
	{
		"id": "bird",
		"name": "小鸟小羽",
		"species": "小鸟",
		"trait": "开朗",
		"pos": Vector2(46.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"home": Vector2(46.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"facing": Vector2.DOWN,
		"anim_t": 0.0,
		"body_col": Color("#6EC4E8"),
		"ear_col": Color("#3F93BD"),
		"shirt_col": Color("#F7D460"),
		"personality": {"social": 0.88, "curiosity": 0.82, "energy": 0.84, "calm": 0.65, "order": 0.58},
		"interests": ["音乐", "探索"],
		"needs": {"social": 0.52, "fun": 0.55, "energy": 0.84, "hunger": 0.72},
		"affinity": 22,
		"relations": {},
		"knowledge": 1,
		"memory": [],
		"action": "stroll",
		"action_reason": "",
		"action_timer": 0.0,
		"decision_timer": 1.9,
		"path": [],
		"chat_cd": 0.0,
		"greet_cd": 0.0,
		"player_chat_cd": 0.0
	}
]

# --- 居民 AI 配置 ---
const RESIDENT_SPEED: float = 24.0
const MEMORY_CAP: int = 12
const AI_DECISION_MIN: float = 2.0
const AI_DECISION_MAX: float = 4.0
const AI_DEBUG_LOG: bool = true

# 行动目录：need 表示该行动主要补足的需求，poi 是目标点类型
const RESIDENT_ACTIONS: Dictionary = {
	"rest":   {"label": "回家休息",     "need": "energy", "poi": "home"},
	"eat":    {"label": "去食堂用餐",   "need": "hunger", "poi": "food"},
	"chat":   {"label": "找朋友聊天",   "need": "social", "poi": "friend"},
	"play":   {"label": "去海边码头",   "need": "fun",    "poi": "beach"},
	"read":   {"label": "去图书馆看书", "need": "fun",    "poi": "library"},
	"sports": {"label": "去运动场活动", "need": "fun",    "poi": "sports"},
	"shop":   {"label": "逛商店看家具", "need": "fun",    "poi": "shop"},
	"stroll": {"label": "四处散步",     "need": "fun",    "poi": "nearby"}
}

# --- 环境粒子与交互特效 ---
var ambient_particles: Array = []
var burst_particles: Array = []

# --- 物品数据库（每一项均绑定真实 PNG 图标 key） ---
const ITEM_DB: Dictionary = {
	"shovel":       {"name": "铁铲",     "icon_key": "shovel",       "type": "tool",       "desc": "挖掘泥土、清除杂草与移植花木（无耐久限制）"},
	"axe":          {"name": "伐木斧",   "icon_key": "axe",          "type": "tool",       "desc": "修剪或砍伐树木获得木材与苹果，也可拆卸户外家具"},
	"watering_can": {"name": "浇水壶",   "icon_key": "watering_can", "type": "tool",       "desc": "给鲜花浇水，让花瓣绽放晶莹水珠"},
	"net":          {"name": "捕虫网",   "icon_key": "bug_net",      "type": "tool",       "desc": "在花丛与草地间挥网捕捉蝴蝶"},
	"rod":          {"name": "钓鱼竿",   "icon_key": "fishing_rod",  "type": "tool",       "desc": "面朝河流或大海抛竿垂钓小鱼"},
	"flower_seed":  {"name": "鲜花苗",   "icon_key": "flower",       "type": "placeable",  "obj_id": ObjectType.FLOWER_PINK,    "price": 40,  "desc": "可在草地上直接种植可爱的粉色花朵"},
	"potted_plant": {"name": "精致盆栽", "icon_key": "potted_plant", "type": "placeable",  "obj_id": ObjectType.FLOWER_PLANTER, "price": 120, "desc": "陶盆盛开的绿植白花盆栽，可布置在广场与庭院"},
	"bench_item":   {"name": "木长椅",   "icon_key": "bench",        "type": "placeable",  "obj_id": ObjectType.BENCH,          "price": 180, "desc": "温暖的双人木制长椅，可坐下休息"},
	"lamp_item":    {"name": "复古路灯", "icon_key": "street_lamp",  "type": "placeable",  "obj_id": ObjectType.LAMP,           "price": 220, "desc": "傍晚与夜晚会自动亮起温暖光晕的街灯"},
	"wood":         {"name": "木材",     "icon_key": "wood",         "type": "material",   "sell": 45,  "desc": "散发松木清香的木材，可在商店出售换取铃钱"},
	"shell":        {"name": "海贝壳",   "icon_key": "shell",        "type": "material",   "sell": 65,  "desc": "海浪冲上金沙滩的扇贝，可在商店出售"},
	"fish":         {"name": "小海鱼",   "icon_key": "fish",         "type": "material",   "sell": 120, "desc": "清澈河海里钓起的小鱼，可在商店出售"},
	"bug":          {"name": "黄粉蝶",   "icon_key": "butterfly",    "type": "material",   "sell": 100, "desc": "花丛间翩翩起舞的蝴蝶，可在商店出售"},
	"apple":        {"name": "海岛苹果", "icon_key": "apple",        "type": "consumable", "sell": 50,  "desc": "香甜脆爽的红苹果，可直接使用品尝"},
	"fence_item":   {"name": "木栅栏",   "icon_key": "grass_tile",   "type": "placeable",  "obj_id": ObjectType.FENCE,   "price": 90,  "desc": "围出小院的木栅栏"},
	"fountain_item":{"name": "清泉喷泉", "icon_key": "water_tile",   "type": "placeable",  "obj_id": ObjectType.FOUNTAIN,"price": 800, "desc": "哗啦啦的庭院喷泉"},
	"carrot_seed":    {"name": "胡萝卜种子", "icon_key": "flower", "type": "seed", "crop": "carrot",     "price": 30, "desc": "3 天成熟，需要浇水"},
	"tomato_seed":    {"name": "番茄种子",   "icon_key": "flower", "type": "seed", "crop": "tomato",     "price": 40, "desc": "4 天成熟，需要浇水"},
	"pumpkin_seed":   {"name": "南瓜种子",   "icon_key": "flower", "type": "seed", "crop": "pumpkin",    "price": 60, "desc": "5 天成熟，需要浇水"},
	"strawberry_seed":{"name": "草莓种子",   "icon_key": "flower", "type": "seed", "crop": "strawberry", "price": 80, "desc": "4 天成熟，需要浇水"},
	"carrot":    {"name": "胡萝卜", "icon_key": "carrot",    "type": "crop", "sell": 60,  "desc": "脆生生的胡萝卜"},
	"tomato":    {"name": "番茄",   "icon_key": "tomato",    "type": "crop", "sell": 90,  "desc": "红透的番茄"},
	"pumpkin":   {"name": "南瓜",   "icon_key": "pumpkin",   "type": "crop", "sell": 150, "desc": "沉甸甸的南瓜"},
	"strawberry":{"name": "草莓",   "icon_key": "strawberry","type": "crop", "sell": 120, "desc": "香甜的草莓"},
	"bed_item":       {"name": "温暖木床",   "icon_key": "bed",           "type": "placeable", "obj_id": ObjectType.BED,           "indoor_type": "bed",           "walkable": false, "price": 320, "desc": "铺着柔软蓝白床单的木床，可在室内外放置，躺下可休息并保存进度"},
	"sofa_item":      {"name": "暖心沙发",   "icon_key": "sofa",          "type": "placeable", "obj_id": ObjectType.SOFA,          "indoor_type": "sofa",          "walkable": false, "price": 260, "desc": "宽敞舒适的布艺软垫沙发，适合放在休息区"},
	"table_item":     {"name": "原木书桌",   "icon_key": "table",         "type": "placeable", "obj_id": ObjectType.DINING_TABLE,  "indoor_type": "table",         "walkable": false, "price": 200, "desc": "结实的原木书桌与餐台，适合布置在工作区"},
	"chair_item":     {"name": "木靠背椅",   "icon_key": "chair",         "type": "placeable", "obj_id": ObjectType.CHAIR,         "indoor_type": "chair",         "walkable": false, "price": 120, "desc": "带软垫的轻巧木椅，可搭配书桌使用"},
	"bookshelf_item": {"name": "满载书架",   "icon_key": "bookshelf",     "type": "placeable", "obj_id": ObjectType.BOOKSHELF,     "indoor_type": "bookshelf",     "walkable": false, "price": 280, "desc": "摆满绘本与岛屿百科的木书架，互动可阅读增长知识"},
	"wardrobe_item":  {"name": "双门衣柜",   "icon_key": "wardrobe",      "type": "placeable", "obj_id": ObjectType.WARDROBE,      "indoor_type": "wardrobe",      "walkable": false, "price": 300, "desc": "储物区大衣柜，互动可整理背包与收纳家具"},
	"storage_item":   {"name": "储物木箱",   "icon_key": "storage_box",   "type": "placeable", "obj_id": ObjectType.STORAGE_BOX,   "indoor_type": "storage_box",   "walkable": false, "price": 160, "desc": "带铜扣的木质储物箱，可随时整理随身物品"},
	"rug_item":       {"name": "织花地毯",   "icon_key": "rug",           "type": "placeable", "obj_id": ObjectType.RUG,           "indoor_type": "rug",           "walkable": true,  "price": 140, "desc": "温暖的编织地毯，铺在地面后角色依然可以在上面自由行走"},
	"record_item":    {"name": "复古留声机", "icon_key": "record_player", "type": "placeable", "obj_id": ObjectType.RECORD_PLAYER, "indoor_type": "record_player", "walkable": false, "price": 360, "desc": "缓缓流淌海岛轻音乐的留声机，互动可获得轻快步伐加成"},
	"display_item":   {"name": "收藏展示柜", "icon_key": "display_case",  "type": "placeable", "obj_id": ObjectType.DISPLAY_CASE,  "indoor_type": "display_case",  "walkable": false, "price": 340, "desc": "玻璃木框收藏柜，可展示海岛稀有纪念物"},
	"double_bed_item": {"name": "豪华双人床", "icon_key": "double_bed",   "type": "placeable", "obj_id": ObjectType.BED,           "indoor_type": "double_bed",    "walkable": false, "price": 480, "desc": "宽大柔软的双人木床，带蓬松枕头与暖色绒毯"},
	"fridge_item":     {"name": "双门电冰箱", "icon_key": "fridge",       "type": "placeable", "obj_id": ObjectType.STORAGE_BOX,   "indoor_type": "fridge",        "walkable": false, "price": 380, "desc": "薄荷绿保鲜冰箱，可安全冷藏存放各类水果蔬菜与鱼获"},
	"fish_tank_item":  {"name": "海岛观赏鱼缸","icon_key": "fish_tank",   "type": "placeable", "obj_id": ObjectType.DISPLAY_CASE,  "indoor_type": "fish_tank",     "walkable": false, "price": 360, "desc": "带水草与滤水器的大玻璃鱼缸，可将钓到的鱼放入展示游动"},
	"clock_item":      {"name": "摆锤机械挂钟","icon_key": "clock",       "type": "placeable", "obj_id": ObjectType.LAMP,          "indoor_type": "clock",         "walkable": false, "price": 180, "desc": "复古金摆锤挂钟，互动可查看精准海岛时间、节气与今日运势"},
	"trash_can_item":  {"name": "脚踏垃圾桶", "icon_key": "trash_can",   "type": "placeable", "obj_id": ObjectType.STORAGE_BOX,   "indoor_type": "trash_can",     "walkable": false, "price": 80,  "desc": "清理杂物的实用脚踏桶，可安全丢弃背包中不需要的物品"},
	"telescope_item":  {"name": "黄铜观星镜", "icon_key": "telescope",   "type": "placeable", "obj_id": ObjectType.LAMP,          "indoor_type": "telescope",     "walkable": false, "price": 420, "desc": "三脚架黄铜天文望远镜，可观测夜空星座与明日海岛天气预报"},
	"easel_item":      {"name": "海岛写生画架","icon_key": "easel",       "type": "placeable", "obj_id": ObjectType.DISPLAY_CASE,  "indoor_type": "easel",         "walkable": false, "price": 240, "desc": "摆着画板与调色盘的木画架，互动可作画记录岛屿风光"},
	"piano_item":      {"name": "原木立式钢琴","icon_key": "piano",       "type": "placeable", "obj_id": ObjectType.RECORD_PLAYER, "indoor_type": "piano",         "walkable": false, "price": 680, "desc": "音色温润的立式原木钢琴，互动可演奏欢快的小岛旋律"}
}

var inventory: Dictionary = {}
var hotbar: Array = ["shovel", "axe", "watering_can", "net", "rod", "flower_seed"]
var selected_hotbar_index: int = 0
var selected_bag_item_id: String = ""

# --- 手机虚拟摇杆状态 ---
var joy_center: Vector2 = Vector2(88.0, 276.0)
var joy_radius: float = 46.0
var joy_knob_pos: Vector2 = Vector2(88.0, 276.0)
var joy_vector: Vector2 = Vector2.ZERO
var joy_touch_index: int = -1

# --- 情境互动检测缓存 ---
var nearby_interact_type: String = ""
var nearby_interact_cell: Vector2i = Vector2i(-1, -1)
var nearby_animal_idx: int = -1
var interact_check_accum: float = 0.0

# --- 手机岛建模式状态（含地形、铲平、造高地、水域、道路、植物、建筑、装饰、移动物体、撤销、重做、确认、取消） ---
var current_build_tool: int = BuildTool.GROUND_GRASS
var build_brush_size: int = 1
var build_sub_road: int = GroundType.STONE_PATH
var build_sub_plant: int = ObjectType.FLOWER_PINK
var build_sub_decor: int = ObjectType.FLOWER_PLANTER
var build_sub_cliff: int = 0  # 0=悬崖(抬高) 1=坡道(连接高度)
var is_box_select_mode: bool = false
var is_camera_pan_mode: bool = false

# 移动物体工具状态
var moving_picked_obj: int = ObjectType.NONE
var moving_from_cell: Vector2i = Vector2i(-1, -1)

var build_touch_index: int = -1
var build_drag_start_cell: Vector2i = Vector2i(-1, -1)
var build_drag_curr_cell: Vector2i = Vector2i(-1, -1)
var pending_box_rect: Rect2i = Rect2i(0, 0, 0, 0)
var has_pending_box: bool = false
var current_stroke_changes: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
const MAX_UNDO_STEPS: int = 25
const MAX_BOX_SPAN: int = 14

# --- 设置参数 ---
var setting_camera_zoom: float = 1.0
var setting_move_speed_scale: float = 1.0
var setting_show_grid_in_build: bool = true

# --- UI 节点引用 ---
var canvas_modulate: CanvasModulate
var ui_layer: CanvasLayer
var hud_root: Control
var title_panel: Control
var title_bg_rect: ColorRect
var title_card_panel: Panel
var top_status_panel: Panel
var top_right_bar: HBoxContainer
var top_time_label: Label
var top_coin_label: Label
var toast_panel: Panel
var toast_label: Label
var toast_timer: float = 0.0
var time_refresh_timer: float = 0.0
var cached_day_key: String = ""
var clock_hour: int = 12
var player_knowledge: int = 0
var speed_buff_timer: float = 0.0
var action_menu_modal: Control = null
var crops: Dictionary = {}
var farm_seed_id: String = "carrot_seed"
var build_sub_farm: int = 0  # 0=播种 1=浇水 2=收获

const CROP_DB: Dictionary = {
	"carrot":     {"name": "胡萝卜", "days": 3, "color": Color("#F08A61")},
	"tomato":     {"name": "番茄",   "days": 4, "color": Color("#D9483B")},
	"pumpkin":    {"name": "南瓜",   "days": 5, "color": Color("#E8A33D")},
	"strawberry": {"name": "草莓",   "days": 4, "color": Color("#EE8398")}
}
var day_watch_timer: float = 0.0

var right_action_box: VBoxContainer
var interact_btn: Button
var interact_btn_label: Label
var use_tool_btn: Button
var cancel_btn: Button
var mode_toggle_btn: Button
var mode_toggle_label: Label

var hotbar_panel: Panel
var hotbar_container: HBoxContainer
var hotbar_slots: Array = [] # [{btn, icon_rect, count_lbl, border_style}]

var build_toolbar_panel: Control
var build_bottom_panel: Panel
var build_right_box: VBoxContainer
var build_mode_hint_label: Label
var build_brush_size_btn: Button
var build_brush_mode_btn: Button
var build_pan_mode_btn: Button
var build_undo_btn: Button
var build_redo_btn: Button
var build_confirm_box_btn: Button
var build_cancel_tool_btn: Button
var build_sub_cycle_btn: Button
var build_tool_buttons: Array = []

# 模态弹窗引用
var active_modal: Control = null
var bag_modal: Control
var bag_grid_container: GridContainer
var bag_detail_label: Label
var bag_detail_icon: TextureRect
var map_modal: Control
var map_canvas: Control
var map_zoom: float = 1.0
var map_pan_offset: Vector2 = Vector2.ZERO
var pause_menu_modal: Control
var settings_modal: Control
var dialog_modal: Control
var dialog_title_label: Label
var dialog_body_label: Label
var dialog_portrait_box: Panel
var dialog_portrait_rect: TextureRect
var dialog_expr_label: Label
var dialog_expr_bar: HBoxContainer
var dialog_char_id: String = ""
var dialog_curr_expr: String = "neutral"
var shop_modal: Control
var confirm_modal: Control
var confirm_label: Label
var confirm_yes_callable: Callable

var hud_overlay_draw: Control

func _ready() -> void:
	# 强制将引擎视口底色设为海洋蓝，彻底根除任何超宽屏/全面屏下的灰色背景留白
	RenderingServer.set_default_clear_color(PAL_OCEAN_BLUE)

	_preload_all_icons()
	_init_default_island()
	_init_indoor_rooms()
	_init_residents()
	_init_default_inventory()
	_init_ambient_particles()

	canvas_modulate = CanvasModulate.new()
	add_child(canvas_modulate)

	camera = Camera2D.new()
	camera.position = player_pos
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_update_camera_limits()
	add_child(camera)

	_build_all_mobile_ui()
	_update_time_and_lighting()

	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	_switch_game_state(GameState.TITLE_SCREEN)
	cached_day_key = _get_logical_day_key()

# ==============================================================================
# 图标资源统一加载器（优先 load 工程资源，兼容 Image.load_from_file，零缺失保底）
# ==============================================================================

func _preload_all_icons() -> void:
	for key in ICON_PATHS.keys():
		_get_icon_tex(key)
	for cid in CHAR_WALK_PATHS.keys():
		_get_walk_tex(str(cid))
	for cid in ["bear", "cat", "rabbit", "deer", "fox", "frog", "otter", "bird"]:
		for expr in PORTRAIT_EXPRS:
			_get_portrait_tex(cid, str(expr))

func _get_walk_tex(char_id: String) -> Texture2D:
	var cid: String = char_id if CHAR_WALK_PATHS.has(char_id) else "bear"
	if _walk_tex_cache.has(cid):
		return _walk_tex_cache[cid]
	var candidate_paths: Array[String] = [
		str(CHAR_WALK_PATHS.get(cid, "")),
		"res://characters/%s_walk.png" % cid,
		"res://%s_walk.png" % cid
	]
	var tex: Texture2D = null
	for p in candidate_paths:
		if p != "" and ResourceLoader.exists(p):
			tex = load(p) as Texture2D
			if tex != null:
				break
		if p != "":
			var abs_p: String = ProjectSettings.globalize_path(p)
			if FileAccess.file_exists(abs_p):
				var img := Image.load_from_file(abs_p)
				if img != null and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
					if tex != null:
						break
	if tex != null:
		_walk_tex_cache[cid] = tex
	return tex

func _get_portrait_tex(char_id: String, expr: String = "neutral") -> Texture2D:
	var cid: String = char_id if char_id in ["bear", "cat", "rabbit", "deer", "fox", "frog", "otter", "bird"] else "bear"
	var ex: String = expr if expr in PORTRAIT_EXPRS else "neutral"
	var cache_key: String = "%s_%s" % [cid, ex]
	if _portrait_tex_cache.has(cache_key):
		return _portrait_tex_cache[cache_key]

	# 依次尝试：标准子目录、根目录、portraits目录（防止手机上传时路径扁平化）
	var candidate_paths: Array[String] = [
		"res://sprites/portraits/%s_%s.png" % [cid, ex],
		"res://portraits/%s_%s.png" % [cid, ex],
		"res://%s_%s.png" % [cid, ex]
	]
	var tex: Texture2D = null
	for p in candidate_paths:
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
			if tex != null:
				break
		var abs_p: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				if tex != null:
					break

	# 若用户手机未上传图片素材：内置程序化全量绘制 8 位动物 × 5 种表情纯正像素立绘，绝不显示纯色方块！
	if tex == null:
		tex = _create_pixel_art_portrait(cid, ex)
	_portrait_tex_cache[cache_key] = tex
	return tex

func _create_pixel_art_portrait(cid: String, ex: String) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var head_c := Color("#B98761")
	var ear_c := Color("#8A5B45")
	var muz_c := Color("#F5DDA1")
	var outline := Color("#544A44")
	var blush_c := Color("#EE8398")

	match cid:
		"cat":
			head_c = Color("#F5B06C"); ear_c = Color("#D97A3E"); muz_c = Color("#FFF2D6")
		"rabbit":
			head_c = Color("#FFF9F5"); ear_c = Color("#EE8398"); muz_c = Color("#FFF2D6")
		"deer":
			head_c = Color("#D89B65"); ear_c = Color("#9A633A"); muz_c = Color("#F5DDA1")
		"fox":
			head_c = Color("#F08A61"); ear_c = Color("#544A44"); muz_c = Color("#FFF2D6")
		"frog":
			head_c = Color("#7BC96F"); ear_c = Color("#499B4A"); muz_c = Color("#A3E699")
		"otter":
			head_c = Color("#9A6B4E"); ear_c = Color("#6D4832"); muz_c = Color("#F5DDA1")
		"bird":
			head_c = Color("#6EC4E8"); ear_c = Color("#F7D460"); muz_c = Color("#FFF2D6")

	# 1. 绘制耳朵/顶饰
	if cid == "rabbit":
		for y in range(2, 13):
			for x in range(7, 12):
				var is_edge: bool = (x == 7 or x == 11 or y == 2 or y == 12)
				img.set_pixel(x, y, outline if is_edge else (ear_c if x == 9 and y >= 4 and y <= 10 else head_c))
			for x in range(20, 25):
				var is_edge2: bool = (x == 20 or x == 24 or y == 2 or y == 12)
				img.set_pixel(x, y, outline if is_edge2 else (ear_c if x == 22 and y >= 4 and y <= 10 else head_c))
	elif cid in ["cat", "fox"]:
		for y in range(4, 12):
			for x in range(6, 13):
				if x + y >= 14 and x - y <= 4:
					var is_e: bool = (x == 6 or x == 12 or y == 4 or x + y == 14 or x - y == 4)
					img.set_pixel(x, y, outline if is_e else (ear_c if cid == "fox" else head_c))
			for x in range(19, 26):
				if x - y >= 13 and x + y <= 33:
					var is_e2: bool = (x == 19 or x == 25 or y == 4 or x - y == 13 or x + y == 33)
					img.set_pixel(x, y, outline if is_e2 else (ear_c if cid == "fox" else head_c))
	elif cid == "frog":
		for y in range(4, 12):
			for x in range(6, 14):
				var dx: float = float(x) - 9.5
				var dy: float = float(y) - 7.5
				if dx * dx + dy * dy <= 12.0:
					var is_bo: bool = (dx * dx + dy * dy >= 7.5)
					img.set_pixel(x, y, outline if is_bo else head_c)
			for x in range(18, 26):
				var dx2: float = float(x) - 21.5
				var dy2: float = float(y) - 7.5
				if dx2 * dx2 + dy2 * dy2 <= 12.0:
					var is_bo2: bool = (dx2 * dx2 + dy2 * dy2 >= 7.5)
					img.set_pixel(x, y, outline if is_bo2 else head_c)
	else:
		for y in range(5, 12):
			for x in range(5, 12):
				var de: float = float(x - 8) * float(x - 8) + float(y - 8) * float(y - 8)
				if de <= 10.0:
					img.set_pixel(x, y, outline if de >= 6.5 else ear_c)
			for x in range(20, 27):
				var de2: float = float(x - 23) * float(x - 23) + float(y - 8) * float(y - 8)
				if de2 <= 10.0:
					img.set_pixel(x, y, outline if de2 >= 6.5 else ear_c)

	# 2. 绘制圆润头部外轮廓与面部底色
	for y in range(9, 29):
		for x in range(5, 27):
			var at_corner: bool = (x in [5, 26] and y in [9, 28])
			if at_corner:
				continue
			var is_border: bool = (x in [5, 26] or y in [9, 28] or (x in [6, 25] and y in [9, 28]))
			img.set_pixel(x, y, outline if is_border else head_c)

	# 3. 绘制口鼻区域 (Muzzle)
	for y in range(18, 26):
		for x in range(11, 21):
			img.set_pixel(x, y, muz_c)

	# 4. 鼻子/鸟喙
	if cid == "bird":
		for bx in [14, 15, 16, 17]:
			img.set_pixel(bx, 18, Color("#F7D460"))
		img.set_pixel(15, 19, Color("#F7D460"))
		img.set_pixel(16, 19, Color("#F7D460"))
		img.set_pixel(15, 20, Color("#D97A3E"))
	else:
		img.set_pixel(15, 18, outline)
		img.set_pixel(16, 18, outline)
		img.set_pixel(15, 19, outline)
		img.set_pixel(16, 19, outline)

	# 5. 表情系统（眼睛、嘴部、腮红与细节）
	if ex in ["happy", "shy"]:
		# 笑眯眯的弯月眼 ^^
		for ex_off in [9, 18]:
			img.set_pixel(ex_off, 15, outline)
			img.set_pixel(ex_off + 1, 14, outline)
			img.set_pixel(ex_off + 2, 14, outline)
			img.set_pixel(ex_off + 3, 15, outline)
		# 粉嫩腮红
		for bx in range(7, 10):
			img.set_pixel(bx, 20, blush_c)
			img.set_pixel(bx, 21, blush_c)
		for bx in range(22, 25):
			img.set_pixel(bx, 20, blush_c)
			img.set_pixel(bx, 21, blush_c)
		# 开心露齿微笑
		for mx in [14, 17]: img.set_pixel(mx, 21, outline)
		for mx in [15, 16]:
			img.set_pixel(mx, 22, outline)
			img.set_pixel(mx, 21, Color.WHITE)
	elif ex == "surprised":
		# 惊讶的大圆眼睛与高光
		for ex_off in [9, 18]:
			for y in range(13, 17):
				for x in range(ex_off, ex_off + 4):
					var is_eb: bool = (x in [ex_off, ex_off + 3] or y in [13, 16])
					img.set_pixel(x, y, outline if is_eb else Color.WHITE)
			img.set_pixel(ex_off + 1, 14, outline)
		# 惊讶小圆嘴 "o"
		img.set_pixel(15, 21, outline)
		img.set_pixel(16, 21, outline)
		img.set_pixel(15, 23, outline)
		img.set_pixel(16, 23, outline)
		img.set_pixel(14, 22, outline)
		img.set_pixel(17, 22, outline)
		img.set_pixel(15, 22, Color("#EE8398"))
		img.set_pixel(16, 22, Color("#EE8398"))
	elif ex == "sleepy":
		# 困倦闭眼水平线 --
		for ex_off in [9, 18]:
			for x in range(ex_off, ex_off + 4):
				img.set_pixel(x, 15, outline)
		# 微小呼噜嘴
		img.set_pixel(15, 22, outline)
		img.set_pixel(16, 22, outline)
		# 额角呼噜 "Z"
		for zx in range(23, 27): img.set_pixel(zx, 8, outline)
		img.set_pixel(25, 9, outline)
		img.set_pixel(24, 10, outline)
		for zx in range(23, 27): img.set_pixel(zx, 11, outline)
	elif ex == "angry":
		# 生气皱眉与圆瞪怒目 \ /
		for x in range(8, 13):
			img.set_pixel(x, 12 + int((x - 8) * 0.5), outline)
		for x in range(18, 23):
			img.set_pixel(x, 14 - int((x - 18) * 0.5), outline)
		for ex_off in [10, 19]:
			for y in range(14, 18):
				for x in range(ex_off, ex_off + 3):
					img.set_pixel(x, y, outline)
		# 紧咬的嘟嘴
		for mx in range(14, 18):
			img.set_pixel(mx, 23, outline)
		img.set_pixel(13, 24, outline)
		img.set_pixel(18, 24, outline)
		# 额角怒气符号井字
		img.set_pixel(23, 11, Color("#EE8398"))
		img.set_pixel(24, 10, Color("#EE8398"))
		img.set_pixel(25, 11, Color("#EE8398"))
	elif ex == "confused":
		# 疑惑高低眉与不平视线
		for x in range(9, 13): img.set_pixel(x, 13, outline)
		for x in range(19, 23): img.set_pixel(x, 11, outline)
		for y in range(14, 17):
			for x in range(10, 13): img.set_pixel(x, y, outline)
		for y in range(13, 17):
			for x in range(19, 23): img.set_pixel(x, y, outline)
		img.set_pixel(10, 14, Color.WHITE)
		img.set_pixel(20, 14, Color.WHITE)
		# 歪头撇嘴
		img.set_pixel(14, 22, outline)
		img.set_pixel(15, 23, outline)
		img.set_pixel(16, 23, outline)
		img.set_pixel(17, 23, outline)
		# 头顶金色小问号 "?"
		img.set_pixel(24, 4, Color("#F7D460"))
		img.set_pixel(25, 4, Color("#F7D460"))
		img.set_pixel(26, 5, Color("#F7D460"))
		img.set_pixel(25, 6, Color("#F7D460"))
		img.set_pixel(25, 8, Color("#F7D460"))
	else: # neutral (普通日常温和眼神)
		for ex_off in [10, 19]:
			for y in range(13, 17):
				for x in range(ex_off, ex_off + 3):
					img.set_pixel(x, y, outline)
			# 灵动白色高光
			img.set_pixel(ex_off, 13, Color.WHITE)
			img.set_pixel(ex_off + 1, 14, Color.WHITE)
		# 温和浅浅微笑
		img.set_pixel(14, 21, outline)
		img.set_pixel(15, 22, outline)
		img.set_pixel(16, 22, outline)
		img.set_pixel(17, 21, outline)

	return ImageTexture.create_from_image(img)

func _get_icon_tex(key: String) -> Texture2D:
	if _icon_cache.has(key):
		return _icon_cache[key]
	var path: String = ICON_PATHS.get(key, "")
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and path != "":
		var abs_p: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = _create_fallback_pixel_icon(key)
	_icon_cache[key] = tex
	return tex

func _create_fallback_pixel_icon(key: String) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var main_col: Color = PAL_CORAL
	if "water" in key or "river" in key or "fish" in key: main_col = PAL_SKY_BLUE
	elif "grass" in key or "plant" in key or "tree" in key: main_col = PAL_GRASS
	elif "coin" in key or "weather" in key: main_col = PAL_GOLD
	elif "wood" in key or "bench" in key or "shovel" in key: main_col = PAL_EARTH
	for y in range(4, 28):
		for x in range(4, 28):
			if x == 4 or x == 27 or y == 4 or y == 27:
				img.set_pixel(x, y, PAL_OUTLINE)
			else:
				img.set_pixel(x, y, main_col)
	return ImageTexture.create_from_image(img)

func _update_camera_limits() -> void:
	if camera == null:
		return
	if in_interior:
		camera.limit_left = -TILE_SIZE * 16
		camera.limit_top = -TILE_SIZE * 12
		camera.limit_right = (ROOM_W + 16) * TILE_SIZE
		camera.limit_bottom = (ROOM_H + 12) * TILE_SIZE
	else:
		# 放宽摄像机边界到广阔外海区域，配合无限延伸的海洋绘制，彻底消除屏幕边缘灰色留白
		camera.limit_left = -TILE_SIZE * 16
		camera.limit_top = -TILE_SIZE * 12
		camera.limit_right = (GRID_WIDTH + 16) * TILE_SIZE
		camera.limit_bottom = (GRID_HEIGHT + 12) * TILE_SIZE

# ==============================================================================
# 44x44 完整岛屿生态设计（森林区、瀑布高地、中央喷泉广场、居民区、河畔集市、金沙滩与码头）
# ==============================================================================

func _init_default_island() -> void:
	ground_grid.clear()
	elevation_grid.clear()
	object_grid.clear()

	for x in range(GRID_WIDTH):
		var g_col: Array = []
		var e_col: Array = []
		var o_col: Array = []
		for y in range(GRID_HEIGHT):
			g_col.append(GroundType.DEEP_WATER)
			e_col.append(0)
			o_col.append(ObjectType.NONE)
		ground_grid.append(g_col)
		elevation_grid.append(e_col)
		object_grid.append(o_col)

	# 旧版 44×44 岛屿的核心布局整体平移 (MAP_CORE_OX, MAP_CORE_OY) 放入新地图，
	# 保证原有建筑、广场、河道、桥梁与景观的相对关系不变，新土地在四周自然生长。
	var ox: int = MAP_CORE_OX
	var oy: int = MAP_CORE_OY

	# 1. 更大、更有机的海岸线：西侧海湾 + 南部宽阔金沙滩
	var center := Vector2(GRID_WIDTH * 0.5, GRID_HEIGHT * 0.5)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var nx: float = (float(x) - center.x) / (GRID_WIDTH * 0.44)
			var ny: float = (float(y) - center.y) / (GRID_HEIGHT * 0.45)
			var wave: float = 0.055 * sin(float(x) * 0.33) + 0.05 * cos(float(y) * 0.29) + 0.02 * sin(float(x + y) * 0.21)
			var dist: float = sqrt(nx * nx + ny * ny) + wave
			if dist > 1.04:
				ground_grid[x][y] = GroundType.DEEP_WATER
				elevation_grid[x][y] = 0
			elif dist > 0.93:
				ground_grid[x][y] = GroundType.SHALLOW_WATER
				elevation_grid[x][y] = 0
			elif dist > 0.86 or (y >= int(GRID_HEIGHT * 0.78) and dist <= 0.93):
				ground_grid[x][y] = GroundType.SAND
				elevation_grid[x][y] = 1
			else:
				ground_grid[x][y] = GroundType.GRASS
				elevation_grid[x][y] = 1

	# 2. 中央偏北翠绿高地（原岛东北高地，瀑布落差保留）
	for x in range(11 + ox, 31 + ox):
		for y in range(6 + oy, 13 + oy):
			if ground_grid[x][y] == GroundType.GRASS:
				if not (x > 27 + ox and y > 10 + oy):
					elevation_grid[x][y] = 2

	# 2b. 新增西侧断崖台地：给岛西增加一处可俯瞰海湾的二层高台
	for x in range(7, 14):
		for y in range(20, 28):
			if ground_grid[x][y] != GroundType.GRASS:
				continue
			var edge_hash: int = (x * 7 + y * 13) % 11
			if edge_hash < 8 or (x > 11 and y > 24 and edge_hash < 10):
				elevation_grid[x][y] = 2

	# 3. 河流：自高地瀑布蜿蜒向南入海（原河道走向整体平移）
	for y in range(8 + oy, GRID_HEIGHT):
		var rx: int = _river_center_x(y)
		for dx in range(2):
			if is_valid_cell(rx + dx, y) and ground_grid[rx + dx][y] != GroundType.DEEP_WATER:
				ground_grid[rx + dx][y] = GroundType.RIVER
				elevation_grid[rx + dx][y] = 0
	# 河心小湖（原岛湖泊平移）
	for x in range(24 + ox, 28 + ox):
		for y in range(14 + oy, 17 + oy):
			ground_grid[x][y] = GroundType.RIVER
			elevation_grid[x][y] = 0
	# 3b. 新增西部林间池塘
	for x in range(12, 17):
		for y in range(34, 39):
			if ground_grid[x][y] == GroundType.GRASS:
				ground_grid[x][y] = GroundType.RIVER
				elevation_grid[x][y] = 0

	# 4. 两座跨河木桥 + 南海岸观海木栈桥码头
	for y in [30, 31]:
		for x in [37, 38]:
			ground_grid[x][y] = GroundType.BRIDGE
			elevation_grid[x][y] = 1
	for y in [44, 45]:
		for x in [38, 39]:
			ground_grid[x][y] = GroundType.BRIDGE
			elevation_grid[x][y] = 1
	for x in [30, 31]:
		for y in range(50, 59):
			ground_grid[x][y] = GroundType.BRIDGE
			elevation_grid[x][y] = 1

	# 5. 中央喷泉石板广场 + 全岛道路网络（原布局平移，并向新区域延伸）
	for x in range(18 + ox, 24 + ox):
		for y in range(19 + oy, 24 + oy):
			ground_grid[x][y] = GroundType.STONE_PATH
	# 东西主干道：西侧草原 -> 家园 -> 广场 -> 木桥 -> 东侧果园
	for x in range(10, 53):
		for y in [30, 31]:
			if ground_grid[x][y] != GroundType.BRIDGE:
				ground_grid[x][y] = GroundType.STONE_PATH
	# 南北景观木板大道：广场 -> 南海滩 -> 码头
	for y in range(34, 45):
		for x in [30, 31]:
			if ground_grid[x][y] in [GroundType.GRASS, GroundType.SAND]:
				ground_grid[x][y] = GroundType.WOOD_PATH
	# 广场北侧小径，通向高地脚下
	for y in range(22, 30):
		for x in [31, 32]:
			if ground_grid[x][y] == GroundType.GRASS:
				ground_grid[x][y] = GroundType.STONE_PATH
	# 东侧果园小径
	for x in range(47, 49):
		for y in range(20, 31):
			if ground_grid[x][y] == GroundType.GRASS:
				ground_grid[x][y] = GroundType.STONE_PATH
	# 西侧草原木板小径，连接主路与南岸
	for x in range(6, 30):
		for y in [38, 39]:
			if ground_grid[x][y] == GroundType.GRASS:
				ground_grid[x][y] = GroundType.WOOD_PATH

	# 6. 核心建筑、公共设施与生活叙事细节（原坐标 + 偏移）
	object_grid[15 + ox][18 + oy] = ObjectType.HOUSE
	object_grid[16 + ox][19 + oy] = ObjectType.MAILBOX
	object_grid[12 + ox][23 + oy] = ObjectType.VILLAGER_HOUSE
	object_grid[30 + ox][18 + oy] = ObjectType.SHOP
	object_grid[20 + ox][21 + oy] = ObjectType.FOUNTAIN
	object_grid[18 + ox][19 + oy] = ObjectType.LAMP
	object_grid[23 + ox][19 + oy] = ObjectType.LAMP
	object_grid[18 + ox][23 + oy] = ObjectType.FLOWER_PLANTER
	object_grid[23 + ox][23 + oy] = ObjectType.FLOWER_PLANTER
	object_grid[19 + ox][19 + oy] = ObjectType.BENCH
	object_grid[22 + ox][19 + oy] = ObjectType.BENCH
	object_grid[19 + ox][24 + oy] = ObjectType.SIGNBOARD

	# 6b. 公共设施（阶段3）
	object_grid[20][24] = ObjectType.LIBRARY
	object_grid[38][24] = ObjectType.CANTEEN
	object_grid[20][38] = ObjectType.SPORTS
	object_grid[48][30] = ObjectType.FURNITURE_SHOP
	object_grid[24][42] = ObjectType.SEED_SHOP
	# 6c. 8 位动物居民各自的小屋（熊、猫、兔、鹿、狐、蛙、海獭、小鸟独立房屋入口）
	for vh_id in VILLAGER_HOUSE_CELLS.keys():
		var vhc: Vector2i = VILLAGER_HOUSE_CELLS[vh_id]
		if is_valid_cell(vhc.x, vhc.y):
			ground_grid[vhc.x][vhc.y] = GroundType.GRASS
			elevation_grid[vhc.x][vhc.y] = 1
			object_grid[vhc.x][vhc.y] = ObjectType.VILLAGER_HOUSE
			if is_valid_cell(vhc.x, vhc.y + 1) and ground_grid[vhc.x][vhc.y + 1] == GroundType.GRASS:
				object_grid[vhc.x][vhc.y + 1] = ObjectType.NONE

	# 家园小花园围栏与耕地
	for fx in [13, 14, 17]:
		object_grid[fx + ox][19 + oy] = ObjectType.FENCE
	ground_grid[13 + ox][17 + oy] = GroundType.TILLED_SOIL
	ground_grid[14 + ox][17 + oy] = GroundType.TILLED_SOIL
	object_grid[13 + ox][17 + oy] = ObjectType.FLOWER_PINK
	object_grid[14 + ox][17 + oy] = ObjectType.FLOWER_WATERED

	# 7. 原岛分区植被（坐标整体平移）
	var pine_coords: Array[Vector2i] = [
		Vector2i(10, 11), Vector2i(12, 9), Vector2i(15, 8), Vector2i(18, 8),
		Vector2i(21, 8), Vector2i(28, 9), Vector2i(9, 14), Vector2i(11, 13)
	]
	for c in pine_coords:
		var px: int = c.x + ox
		var py: int = c.y + oy
		if ground_grid[px][py] == GroundType.GRASS:
			object_grid[px][py] = ObjectType.TREE_PINE

	var oak_coords: Array[Vector2i] = [
		Vector2i(14, 11), Vector2i(19, 11), Vector2i(10, 17), Vector2i(10, 21),
		Vector2i(15, 26), Vector2i(17, 28), Vector2i(31, 15), Vector2i(33, 21),
		Vector2i(31, 25), Vector2i(25, 29)
	]
	for c in oak_coords:
		var px2: int = c.x + ox
		var py2: int = c.y + oy
		if ground_grid[px2][py2] == GroundType.GRASS and object_grid[px2][py2] == ObjectType.NONE:
			object_grid[px2][py2] = ObjectType.TREE_OAK

	var palm_coords: Array[Vector2i] = [
		Vector2i(14, 31), Vector2i(17, 32), Vector2i(24, 32), Vector2i(30, 30), Vector2i(12, 29)
	]
	for c in palm_coords:
		var px3: int = c.x + ox
		var py3: int = c.y + oy
		if ground_grid[px3][py3] in [GroundType.SAND, GroundType.GRASS] and object_grid[px3][py3] == ObjectType.NONE:
			object_grid[px3][py3] = ObjectType.TREE_PALM

	object_grid[11 + ox][15 + oy] = ObjectType.STUMP
	object_grid[12 + ox][14 + oy] = ObjectType.MUSHROOM
	object_grid[16 + ox][10 + oy] = ObjectType.MUSHROOM
	object_grid[23 + ox][11 + oy] = ObjectType.ROCK
	object_grid[32 + ox][18 + oy] = ObjectType.ROCK
	object_grid[15 + ox][33 + oy] = ObjectType.SHELL
	object_grid[18 + ox][34 + oy] = ObjectType.SHELL
	object_grid[23 + ox][34 + oy] = ObjectType.SHELL
	object_grid[26 + ox][33 + oy] = ObjectType.SHELL
	object_grid[19 + ox][32 + oy] = ObjectType.BENCH

	# 7b. 新增北部森林：松树与橡树混生，留出若干林间空地作为探索路线
	for x in range(16, 43):
		for y in range(5, 18):
			if ground_grid[x][y] != GroundType.GRASS or object_grid[x][y] != ObjectType.NONE:
				continue
			if elevation_grid[x][y] == 2:
				continue
			var h: int = (x * 17 + y * 31) % 23
			if h == 0 or h == 5:
				object_grid[x][y] = ObjectType.TREE_PINE
			elif h == 9:
				object_grid[x][y] = ObjectType.TREE_OAK
			elif h == 12:
				object_grid[x][y] = ObjectType.BUSH
			elif h == 15:
				object_grid[x][y] = ObjectType.MUSHROOM

	# 7c. 新增东部果园：成排果树 + 少量花丛，提供采集与装饰素材
	for x in range(44, 56):
		for y in range(18, 31):
			if ground_grid[x][y] != GroundType.GRASS or object_grid[x][y] != ObjectType.NONE:
				continue
			if (x - 44) % 3 == 0 and (y - 18) % 3 == 0:
				object_grid[x][y] = ObjectType.TREE_OAK
			elif (x * 3 + y * 5) % 19 == 0:
				object_grid[x][y] = ObjectType.FLOWER_PINK

	# 7d. 新增西部草原：大面积可建造空地，只做极轻点缀
	for x in range(6, 20):
		for y in range(22, 46):
			if ground_grid[x][y] != GroundType.GRASS or object_grid[x][y] != ObjectType.NONE:
				continue
			if elevation_grid[x][y] == 2:
				continue
			var hh: int = (x * 29 + y * 11) % 37
			if hh == 3:
				object_grid[x][y] = ObjectType.FLOWER_YELLOW
			elif hh == 7:
				object_grid[x][y] = ObjectType.BUSH

	# 7e. 新增东南半岛沙滩：椰林与贝壳
	for x in range(34, 58):
		for y in range(44, GRID_HEIGHT - 5):
			if ground_grid[x][y] != GroundType.SAND or object_grid[x][y] != ObjectType.NONE:
				continue
			var hp: int = (x * 13 + y * 7) % 29
			if hp == 0:
				object_grid[x][y] = ObjectType.TREE_PALM
			elif hp == 5:
				object_grid[x][y] = ObjectType.SHELL

	# 8. 全岛花草点缀（避开广场与主要道路）
	for x in range(6, GRID_WIDTH - 6):
		for y in range(6, GRID_HEIGHT - 6):
			if ground_grid[x][y] != GroundType.GRASS or object_grid[x][y] != ObjectType.NONE:
				continue
			if abs(x - (20 + ox)) <= 3 and abs(y - (21 + oy)) <= 3:
				continue
			var hash_v: int = (x * 13 + y * 29) % 47
			if hash_v == 0:
				object_grid[x][y] = ObjectType.FLOWER_PINK
			elif hash_v == 1:
				object_grid[x][y] = ObjectType.FLOWER_YELLOW
			elif hash_v == 2:
				object_grid[x][y] = ObjectType.BUSH
			elif hash_v == 3 and x > 36:
				object_grid[x][y] = ObjectType.WEED

	player_pos = Vector2((21.5 + ox) * TILE_SIZE, (22.5 + oy) * TILE_SIZE)
	player_facing = Vector2.DOWN
	undo_stack.clear()
	redo_stack.clear()
	queue_redraw()

func _river_center_x(y: int) -> int:
	var oy: int = MAP_CORE_OY
	var ox: int = MAP_CORE_OX
	if y < 13 + oy:
		return 25 + ox
	elif y < 20 + oy:
		return 26 + ox
	elif y < 27 + oy:
		return 27 + ox
	return 28 + ox

func _init_default_inventory() -> void:
	coins = 1800
	inventory = {
		"shovel": 1,
		"axe": 1,
		"watering_can": 1,
		"net": 1,
		"rod": 1,
		"flower_seed": 15,
		"potted_plant": 4,
		"bench_item": 2,
		"lamp_item": 2,
		"chair_item": 2,
		"rug_item": 2,
		"bookshelf_item": 1,
		"sofa_item": 1,
		"shell": 3,
		"wood": 8,
		"apple": 4
	}
	hotbar = ["shovel", "axe", "watering_can", "net", "rod", "flower_seed"]
	selected_hotbar_index = 0

func _init_ambient_particles() -> void:
	ambient_particles.clear()
	for i in range(22):
		ambient_particles.append({
			"pos": Vector2(randf_range(64.0, GRID_WIDTH * TILE_SIZE - 64.0), randf_range(64.0, GRID_HEIGHT * TILE_SIZE - 64.0)),
			"vel": Vector2(randf_range(-10.0, 14.0), randf_range(6.0, 15.0)),
			"phase": randf() * TAU,
			"color": PAL_PINK if i % 3 == 0 else (PAL_GRASS if i % 3 == 1 else PAL_GOLD)
		})

func _spawn_burst_effect(world_pt: Vector2, col: Color) -> void:
	for i in range(6):
		var ang: float = float(i) * TAU / 6.0 + randf_range(-0.3, 0.3)
		burst_particles.append({
			"pos": world_pt,
			"vel": Vector2(cos(ang), sin(ang)) * randf_range(16.0, 32.0),
			"life": 0.45,
			"color": col
		})

# ==============================================================================
# 主循环与小动物 AI
# ==============================================================================

func _physics_process(delta: float) -> void:
	env_anim_time += delta
	_update_particles(delta)

	if game_state == GameState.TITLE_SCREEN or active_modal != null:
		queue_redraw()
		return

	if tool_swing_timer > 0.0:
		tool_swing_timer = maxf(0.0, tool_swing_timer - delta)

	var move_dir: Vector2 = Vector2.ZERO
	if game_state == GameState.EXPLORE_MODE:
		var kb_input := Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)
		# 输入优先级：摇杆 > 键盘 > 点击寻路
		if joy_vector.length() > 0.05:
			_cancel_auto_path()
			move_dir = joy_vector.normalized()
		elif kb_input.length() > 0.05:
			_cancel_auto_path()
			move_dir = kb_input.normalized()
		elif not auto_path.is_empty():
			move_dir = _advance_auto_path(delta)

		if move_dir.length() > 0.05:
			player_facing = move_dir
			walk_anim_time += delta * 10.0
			var buff: float = 1.2 if speed_buff_timer > 0.0 else 1.0
			var spd: float = BASE_MOVE_SPEED * setting_move_speed_scale * buff
			_move_player_with_collision(move_dir * spd * delta)
			if hud_overlay_draw != null:
				hud_overlay_draw.queue_redraw()
		elif walk_anim_time != 0.0:
			walk_anim_time = 0.0

	# 摄像机平滑跟随玩家；岛建的“单指移视角”模式下交给玩家自己控制
	if camera != null and not (game_state == GameState.BUILD_MODE and is_camera_pan_mode):
		camera.position = player_pos

	_update_residents(delta)
	queue_redraw()

func _process(delta: float) -> void:
	if speed_buff_timer > 0.0:
		speed_buff_timer = maxf(0.0, speed_buff_timer - delta)

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_panel != null:
			toast_panel.visible = false

	time_refresh_timer += delta
	if time_refresh_timer >= 2.0:
		time_refresh_timer = 0.0
		_update_time_and_lighting()

	# 游戏内跨过 05:00 也要结算施工，不必退出重进
	day_watch_timer += delta
	if day_watch_timer >= 5.0:
		day_watch_timer = 0.0
		_check_day_rollover()

	if game_state == GameState.EXPLORE_MODE and active_modal == null:
		interact_check_accum += delta
		if interact_check_accum >= 0.12:
			interact_check_accum = 0.0
			_refresh_nearby_interaction()

func _update_particles(delta: float) -> void:
	var map_max := Vector2(GRID_WIDTH * TILE_SIZE - 48.0, GRID_HEIGHT * TILE_SIZE - 48.0)
	for p in ambient_particles:
		var pos: Vector2 = p["pos"] + p["vel"] * delta
		pos.x += sin(env_anim_time * 2.0 + float(p["phase"])) * 6.0 * delta
		if pos.x < 48.0: pos.x = map_max.x
		if pos.x > map_max.x: pos.x = 48.0
		if pos.y < 48.0: pos.y = map_max.y
		if pos.y > map_max.y: pos.y = 48.0
		p["pos"] = pos

	for i in range(burst_particles.size() - 1, -1, -1):
		var bp: Dictionary = burst_particles[i]
		bp["pos"] = bp["pos"] + bp["vel"] * delta
		bp["life"] = float(bp["life"]) - delta
		if float(bp["life"]) <= 0.0:
			burst_particles.remove_at(i)

func _init_residents() -> void:
	# 兼容旧存档：补齐 AI 字段
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		if not a.has("personality"):
			a["personality"] = {"social": 0.6, "curiosity": 0.5, "energy": 0.6, "calm": 0.5, "order": 0.5}
		if not a.has("interests"):
			a["interests"] = []
		if not a.has("needs"):
			a["needs"] = {"social": 0.5, "fun": 0.5, "energy": 0.8, "hunger": 0.7}
		if not a.has("relations"):
			a["relations"] = {}
		if not a.has("memory"):
			a["memory"] = []
		if not a.has("knowledge"):
			a["knowledge"] = 0
		if not a.has("affinity"):
			a["affinity"] = int(a.get("friendship", 20))
		if a.has("friendship"):
			a.erase("friendship")
		if a.has("dialogs"):
			a.erase("dialogs")
		if a.has("wait_timer"):
			a.erase("wait_timer")
		a["path"] = []
		a["action"] = "stroll"
		a["action_reason"] = "刚出门，先随便走走"
		a["action_timer"] = 0.0
		a["decision_timer"] = randf_range(AI_DECISION_MIN, AI_DECISION_MAX)
		a["chat_cd"] = 0.0
		a["greet_cd"] = 0.0
		a["stuck_t"] = 0.0
		if not a.has("facing"):
			a["facing"] = Vector2.DOWN
		if not a.has("anim_t"):
			a["anim_t"] = 0.0
		var hc: Vector2i = VILLAGER_HOUSE_CELLS.get(str(a["id"]), Vector2i(22, 33))
		a["house"] = Vector2(hc) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		a["home"] = Vector2(hc.x + 0.5, hc.y + 1.5) * TILE_SIZE
	# 初始化两两关系
	for i in range(animals.size()):
		for j in range(animals.size()):
			if i == j:
				continue
			var other_id: String = str(animals[j]["id"])
			if not animals[i]["relations"].has(other_id):
				animals[i]["relations"][other_id] = 0

func _resident_needs(a: Dictionary) -> Dictionary:
	return a["needs"]

func _resident_personality(a: Dictionary) -> Dictionary:
	return a["personality"]

func _resident_action_label(action_id: String) -> String:
	if RESIDENT_ACTIONS.has(action_id):
		return str(RESIDENT_ACTIONS[action_id]["label"])
	return action_id

func _resident_action_target(idx: int, action_id: String) -> Vector2i:
	var a: Dictionary = animals[idx]
	var poi: String = "nearby"
	if RESIDENT_ACTIONS.has(action_id):
		poi = str(RESIDENT_ACTIONS[action_id]["poi"])
	match poi:
		"home":
			return _nearest_walkable_cell(world_to_grid(a["home"]), 3, false)
		"food":
			return _nearest_walkable_cell(Vector2i(38, 25), 3, false)
		"library", "bench":
			return _nearest_walkable_cell(Vector2i(20, 25), 3, false)
		"sports":
			return _nearest_walkable_cell(Vector2i(20, 39), 3, false)
		"shop":
			var shop_targets: Array[Vector2i] = [Vector2i(40, 28), Vector2i(48, 31), Vector2i(24, 43)]
			return _nearest_walkable_cell(shop_targets[idx % shop_targets.size()], 3, false)
		"beach":
			return _nearest_walkable_cell(Vector2i(30, 52), 4, false)
		"friend":
			var best := Vector2i(-1, -1)
			var best_d := 9999.0
			var my_pos: Vector2 = a["pos"]
			for j in range(animals.size()):
				if j == idx:
					continue
				var op: Vector2 = animals[j]["pos"]
				var d: float = my_pos.distance_to(op)
				if d < best_d:
					best_d = d
					best = _nearest_walkable_cell(world_to_grid(op), 2)
			return best
		_:
			# 以当前位置为中心，找一块 8 格内的随机空地
			var from := world_to_grid(a["pos"])
			for attempt in range(12):
				var rx: int = from.x + randi_range(-8, 8)
				var ry: int = from.y + randi_range(-8, 8)
				if is_cell_walkable(rx, ry, false):
					return Vector2i(rx, ry)
			return _nearest_walkable_cell(from, 4)

func _resident_score_action(idx: int, action_id: String, hour: int) -> float:
	var a: Dictionary = animals[idx]
	var p: Dictionary = a["personality"]
	var n: Dictionary = a["needs"]
	var score: float = 0.0
	match action_id:
		"rest":
			score = (1.0 - float(n["energy"])) * 2.2 + (0.4 if (hour >= 20 or hour < 6) else 0.0) - float(p["energy"]) * 0.4
		"eat":
			score = (1.0 - float(n["hunger"])) * 2.2 + (0.3 if hour in [7, 8, 12, 18] else 0.0)
		"chat":
			score = (1.0 - float(n["social"])) * 2.4 + float(p["social"]) * 1.2
		"play":
			score = (1.0 - float(n["fun"])) * 1.8 + float(p["energy"]) * 0.8 + (0.4 if hour >= 10 and hour < 18 else 0.0)
		"read":
			score = float(p["curiosity"]) * 1.4 + (1.0 - float(n["fun"])) * 0.7 + (0.3 if hour >= 14 else 0.0)
		"sports":
			score = float(p["energy"]) * 1.3 + (1.0 - float(n["fun"])) * 0.8 + (0.35 if hour >= 8 and hour < 18 else 0.0)
		"shop":
			score = float(p["social"]) * 0.7 + (1.0 - float(n["fun"])) * 0.6 + (0.25 if hour >= 10 and hour < 19 else 0.0)
		"stroll":
			score = 0.9 + float(p["energy"]) * 0.4

	var act_interest: Dictionary = {"read": "阅读", "play": "海", "sports": "运动", "shop": "园艺", "eat": "料理", "chat": "音乐", "stroll": "探索"}
	var tag: String = str(act_interest.get(action_id, ""))
	if tag != "" and tag in a["interests"]:
		score += 0.6

	var cell := _resident_action_target(idx, action_id)
	if cell.x < 0:
		return -1.0
	var from := world_to_grid(a["pos"])
	score -= float(absi(from.x - cell.x) + absi(from.y - cell.y)) * 0.02
	score += randf() * 0.25
	return score

func _resident_choose_action(idx: int) -> void:
	var a: Dictionary = animals[idx]
	var hour: int = clock_hour
	var best_id: String = "stroll"
	var best_score: float = -999.0
	var score_log: Array = []
	for action_id in RESIDENT_ACTIONS.keys():
		var s: float = _resident_score_action(idx, str(action_id), hour)
		score_log.append("%s=%.2f" % [str(action_id), s])
		if s > best_score:
			best_score = s
			best_id = str(action_id)

	var target := _resident_action_target(idx, best_id)
	if target.x < 0:
		best_id = "stroll"
		target = _resident_action_target(idx, best_id)

	a["action"] = best_id
	a["action_timer"] = float(_resident_action_duration(best_id))
	a["action_reason"] = "选%s(%.2f) | 社交%.2f 心情%.2f 精力%.2f 饥饿%.2f | %d时" % [
		_resident_action_label(best_id), best_score,
		float(a["needs"]["social"]), float(a["needs"]["fun"]),
		float(a["needs"]["energy"]), float(a["needs"]["hunger"]), hour
	]
	if not _resident_go_to(idx, target):
		a["action_reason"] += " | 目标不可达，改为散步"
		a["action"] = "stroll"
		a["action_timer"] = 6.0
		var alt := _resident_action_target(idx, "stroll")
		_resident_go_to(idx, alt)
	if AI_DEBUG_LOG:
		print("[AI] ", a["name"], " -> ", a["action_reason"], " | ", " ".join(score_log))

func _resident_action_duration(action_id: String) -> float:
	match action_id:
		"rest": return randf_range(14.0, 22.0)
		"read": return randf_range(10.0, 16.0)
		"chat": return randf_range(7.0, 11.0)
		"play": return randf_range(9.0, 14.0)
		"shop": return randf_range(6.0, 10.0)
		"eat": return randf_range(8.0, 12.0)
		_: return randf_range(5.0, 8.0)

func _resident_go_to(idx: int, target_cell: Vector2i) -> bool:
	var a: Dictionary = animals[idx]
	if target_cell.x < 0:
		return false
	var from := world_to_grid(a["pos"])
	if from == target_cell:
		a["path"] = []
		return true
	if in_interior:
		return false
	var p: Array = find_path(from, target_cell)
	if p.is_empty():
		return false
	for c in p:
		if not is_cell_walkable(c.x, c.y, false):
			return false
	a["path"] = p
	a["stuck_t"] = 0.0
	return true

func _resident_blocked_by_other(idx: int, next_pos: Vector2) -> bool:
	for j in range(animals.size()):
		if j == idx:
			continue
		var op: Vector2 = animals[j]["pos"]
		if op.distance_to(next_pos) < 9.0:
			return true
	return false

func _resident_move(idx: int, delta: float) -> void:
	var a: Dictionary = animals[idx]
	var path: Array = a["path"]
	if path.is_empty():
		a["anim_t"] = 0.0
		return
	var pos: Vector2 = a["pos"]

	while not path.is_empty():
		var target: Vector2 = Vector2(path[0]) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		var to_target: Vector2 = target - pos
		if to_target.length() <= 2.5:
			path.pop_front()
			continue
		var dir_norm: Vector2 = to_target.normalized()
		a["facing"] = dir_norm
		a["anim_t"] = float(a.get("anim_t", 0.0)) + delta * 7.5
		var step: float = minf(RESIDENT_SPEED * delta, to_target.length())
		var next_pos: Vector2 = pos + dir_norm * step
		if _resident_blocked_by_other(idx, next_pos) or (not in_interior and next_pos.distance_to(player_pos) < 8.0):
			a["stuck_t"] = float(a.get("stuck_t", 0.0)) + delta
			if float(a["stuck_t"]) > 1.4:
				path.clear()
				a["action_timer"] = 0.0
				a["stuck_t"] = 0.0
			return
		a["stuck_t"] = 0.0
		a["pos"] = next_pos
		return

func _resident_tick_needs(idx: int, delta: float) -> void:
	var a: Dictionary = animals[idx]
	var n: Dictionary = a["needs"]
	n["social"] = clampf(float(n["social"]) - 0.004 * delta, 0.0, 1.0)
	n["fun"] = clampf(float(n["fun"]) - 0.005 * delta, 0.0, 1.0)
	n["hunger"] = clampf(float(n["hunger"]) - 0.003 * delta, 0.0, 1.0)
	if not (a["path"] as Array).is_empty():
		n["energy"] = clampf(float(n["energy"]) - 0.004 * delta, 0.0, 1.0)

func _resident_apply_action(idx: int, delta: float) -> void:
	var a: Dictionary = animals[idx]
	var n: Dictionary = a["needs"]
	match str(a["action"]):
		"rest":
			n["energy"] = clampf(float(n["energy"]) + 0.06 * delta, 0.0, 1.0)
		"eat":
			n["hunger"] = clampf(float(n["hunger"]) + 0.08 * delta, 0.0, 1.0)
			n["fun"] = clampf(float(n["fun"]) + 0.01 * delta, 0.0, 1.0)
		"play":
			n["fun"] = clampf(float(n["fun"]) + 0.06 * delta, 0.0, 1.0)
			n["energy"] = clampf(float(n["energy"]) - 0.01 * delta, 0.0, 1.0)
		"read":
			a["knowledge"] = float(a["knowledge"]) + 0.25 * delta
			n["fun"] = clampf(float(n["fun"]) + 0.02 * delta, 0.0, 1.0)
		"chat":
			n["social"] = clampf(float(n["social"]) + 0.05 * delta, 0.0, 1.0)
		"shop":
			n["fun"] = clampf(float(n["fun"]) + 0.03 * delta, 0.0, 1.0)
		"stroll":
			n["fun"] = clampf(float(n["fun"]) + 0.02 * delta, 0.0, 1.0)

func _resident_add_memory(idx: int, kind: String, who: String, text: String, val: int) -> void:
	var a: Dictionary = animals[idx]
	var mem: Array = a["memory"]
	mem.append({"kind": kind, "who": who, "text": text, "val": val, "at": int(Time.get_unix_time_from_system())})
	# 容量上限 + 容量外的最旧记忆直接遗忘
	while mem.size() > MEMORY_CAP:
		mem.pop_front()

func _resident_player_memory_text(a: Dictionary) -> String:
	var mem: Array = a["memory"]
	for i in range(mem.size() - 1, -1, -1):
		var m: Dictionary = mem[i]
		if str(m.get("kind", "")) == "player":
			return str(m.get("text", ""))
	return ""

func _resident_compat(i: int, j: int) -> float:
	var p1: Dictionary = animals[i]["personality"]
	var p2: Dictionary = animals[j]["personality"]
	var diff: float = 0.0
	for k in ["social", "curiosity", "energy", "calm", "order"]:
		diff += absf(float(p1[k]) - float(p2[k]))
	diff = diff / 5.0
	var overlap: int = 0
	for tag in animals[i]["interests"]:
		if tag in animals[j]["interests"]:
			overlap += 1
	return clampf(1.0 - diff + float(overlap) * 0.12, 0.0, 1.0)

func _resident_social_scan(delta: float) -> void:
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		if float(a["chat_cd"]) > 0.0:
			continue
		for j in range(animals.size()):
			if i == j:
				continue
			var b: Dictionary = animals[j]
			if (a["pos"] as Vector2).distance_to(b["pos"]) > 26.0:
				continue
			if (a["path"] as Array).size() > 0 or (b["path"] as Array).size() > 0:
				continue
			var compat: float = _resident_compat(i, j)
			var change: int = int(round((compat - 0.5) * 8.0))
			change = clampi(change, -4, 5)
			a["relations"][str(b["id"])] = clampi(int(a["relations"].get(str(b["id"]), 0)) + change, -100, 100)
			b["relations"][str(a["id"])] = clampi(int(b["relations"].get(str(a["id"]), 0)) + change, -100, 100)
			if change >= 0:
				_resident_add_memory(i, "friend", str(b["id"]), "和%s聊得很开心" % str(b["name"]), change)
				a["needs"]["social"] = clampf(float(a["needs"]["social"]) + 0.12, 0.0, 1.0)
			else:
				_resident_add_memory(i, "conflict", str(b["id"]), "和%s闹了点小别扭" % str(b["name"]), change)
				a["needs"]["fun"] = clampf(float(a["needs"]["fun"]) - 0.06, 0.0, 1.0)
			a["chat_cd"] = randf_range(10.0, 16.0)
			b["chat_cd"] = randf_range(6.0, 12.0)

func _resident_greet_player(delta: float) -> void:
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		a["greet_cd"] = maxf(0.0, float(a["greet_cd"]) - delta)
		if float(a["greet_cd"]) > 0.0:
			continue
		if (a["pos"] as Vector2).distance_to(player_pos) > 34.0:
			continue
		if str(a["action"]) == "rest":
			continue
		var line: String = _resident_small_talk(i)
		_show_toast("%s：%s" % [str(a["name"]), line])
		a["greet_cd"] = randf_range(40.0, 70.0)
		a["affinity"] = clampi(int(a["affinity"]) + 1, 0, 100)

func _resident_small_talk(i: int) -> String:
	var a: Dictionary = animals[i]
	var n: Dictionary = a["needs"]
	var p: Dictionary = a["personality"]
	if float(n["energy"]) < 0.25:
		return "我有点走不动啦，想回家歇一会儿。"
	if float(n["hunger"]) < 0.25:
		return "肚子咕咕叫，我先去找点吃的。"
	if float(n["social"]) < 0.3 and float(p["social"]) > 0.6:
		return "正想找人聊天呢，你来得正好。"
	if str(a["action"]) == "read":
		return "这本书里讲了好多小岛的故事。"
	if str(a["action"]) == "play":
		return "海边的风今天特别舒服。"
	if str(a["action"]) == "chat":
		return "刚和朋友聊完，心情不错。"
	return "今天的小岛也很安静呢。"

func _resident_greet_line(i: int) -> String:
	var a: Dictionary = animals[i]
	var p: Dictionary = a["personality"]
	var n: Dictionary = a["needs"]
	var aff: int = int(a["affinity"])
	var lines: Array = []

	if float(p["social"]) >= 0.8:
		lines.append(["嗨！见到你真好呀～", "你来得正好，陪我走两步吧！"][randi() % 2])
	elif float(p["social"]) <= 0.45:
		lines.append(["……你好。我自己待会儿也挺好的。", "嗯，是你啊。有事吗？"][randi() % 2])
	else:
		lines.append(["今天的风很舒服呢。", "嗨，慢慢逛呀。"][randi() % 2])

	if float(n["energy"]) < 0.3:
		lines.append("我有点累了，刚想回家躺一会儿。")
	elif float(n["hunger"]) < 0.3:
		lines.append("肚子有点饿，正打算去找点吃的。")

	if float(a["knowledge"]) >= 4.0:
		lines.append("我最近看了不少书，知道了好多岛上的事。")

	var mem_text: String = _resident_player_memory_text(a)
	if mem_text != "" and randf() < 0.55:
		lines.append("我还记得，%s。" % mem_text)

	if aff >= 60:
		lines.append("和你聊天总是很安心。")
	elif aff <= 5:
		lines.append("我们好像还没说过几句话。")

	var friend_line: String = _resident_best_friend_line(i)
	if friend_line != "":
		lines.append(friend_line)

	return "\n".join(lines)

func _resident_best_friend_line(i: int) -> String:
	var a: Dictionary = animals[i]
	var best_id: String = ""
	var best_val: int = -999
	for k in a["relations"].keys():
		var v: int = int(a["relations"][k])
		if v > best_val:
			best_val = v
			best_id = str(k)
	if best_val >= 8:
		for j in range(animals.size()):
			if str(animals[j]["id"]) == best_id:
				return "我和%s最近处得不错。" % str(animals[j]["name"])
	if best_val <= -8:
		for j in range(animals.size()):
			if str(animals[j]["id"]) == best_id:
				return "我和%s最近有点合不来。" % str(animals[j]["name"])
	return ""

func _resident_interact(i: int) -> void:
	var a: Dictionary = animals[i]
	# 手上有贝壳/花苗/苹果时自动送出一份，好感提升更多（阶段4）
	var gift_id: String = ""
	for gid in ["shell", "flower_seed", "apple"]:
		if int(inventory.get(gid, 0)) > 0:
			gift_id = str(gid)
			break
	if gift_id != "" and int(a["affinity"]) < 90:
		_consume_item(gift_id, 1)
		a["affinity"] = clampi(int(a["affinity"]) + 6, 0, 100)
		_resident_add_memory(i, "gift", "player", "收到了你送的%s" % str(ITEM_DB[gift_id]["name"]), 6)
		_show_toast("%s 收下了你的%s，好感 +6" % [str(a["name"]), str(ITEM_DB[gift_id]["name"])])
	a["affinity"] = clampi(int(a["affinity"]) + 3, 0, 100)
	a["needs"]["social"] = clampf(float(a["needs"]["social"]) + 0.15, 0.0, 1.0)
	a["needs"]["fun"] = clampf(float(a["needs"]["fun"]) + 0.05, 0.0, 1.0)
	_resident_add_memory(i, "player", "player", "和你在%s聊过天" % _resident_action_label(str(a["action"])), 3)
	var expr: String = _select_resident_expression(a, gift_id != "")
	_open_dialog_modal(
		"%s · %s · ♥%d · 正在%s" % [str(a["name"]), str(a["trait"]), int(a["affinity"]), _resident_action_label(str(a["action"]))],
		_resident_greet_line(i),
		str(a["id"]),
		expr
	)
	if AI_DEBUG_LOG:
		print("[AI] 玩家与 ", a["name"], " 交互，好感=", a["affinity"], " 记忆=", a["memory"].size())

func _resident_debug_report() -> String:
	var lines: Array = []
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		var n: Dictionary = a["needs"]
		lines.append("%s（%s / %s）♥%d 知识%d" % [str(a["name"]), str(a["species"]), str(a["trait"]), int(a["affinity"]), int(float(a["knowledge"]))])
		lines.append("  当前：%s" % _resident_action_label(str(a["action"])))
		lines.append("  原因：%s" % str(a["action_reason"]))
		lines.append("  需求：社交 %.2f / 心情 %.2f / 精力 %.2f / 饥饿 %.2f" % [
			float(n["social"]), float(n["fun"]), float(n["energy"]), float(n["hunger"])])
		var rel_parts: Array = []
		for k in a["relations"].keys():
			rel_parts.append("%s %+d" % [str(k), int(a["relations"][k])])
		if not rel_parts.is_empty():
			lines.append("  关系：" + "，".join(rel_parts))
		if (a["memory"] as Array).size() > 0:
			var m: Dictionary = a["memory"][a["memory"].size() - 1]
			lines.append("  最近记忆：%s" % str(m.get("text", "")))
		lines.append("")
	return "\n".join(lines)

func _update_residents(delta: float) -> void:
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		_resident_tick_needs(i, delta)
		_resident_move(i, delta)
		if (a["path"] as Array).is_empty():
			_resident_apply_action(i, delta)
			a["action_timer"] = float(a["action_timer"]) - delta
			if float(a["action_timer"]) <= 0.0:
				_resident_choose_action(i)
		else:
			a["action_timer"] = maxf(0.0, float(a["action_timer"]))
	_resident_social_scan(delta)
	_resident_greet_player(delta)

# ==============================================================================
# 网格坐标与碰撞判断
# ==============================================================================

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))

func is_valid_cell(gx: int, gy: int) -> bool:
	if in_interior:
		return gx >= 0 and gx < ROOM_W and gy >= 0 and gy < ROOM_H
	return gx >= 0 and gx < GRID_WIDTH and gy >= 0 and gy < GRID_HEIGHT

func is_cell_walkable(gx: int, gy: int, allow_high: bool = true) -> bool:
	if in_interior:
		return is_indoor_cell_walkable(gx, gy)
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
		return false
	var g_type: int = ground_grid[gx][gy]
	if g_type in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
		return false
	var elev: int = int(elevation_grid[gx][gy])
	# 普通地面(1)永远可走；二层高地(2)需要调用方显式允许（玩家可以，小动物不行）
	if elev != 1 and not (allow_high and elev == 2):
		return false
	var o_type: int = object_grid[gx][gy]
	if o_type in [
		ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM,
		ObjectType.BUSH, ObjectType.BENCH, ObjectType.LAMP, ObjectType.FENCE,
		ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE, ObjectType.SHOP, ObjectType.CONSTRUCTION,
		ObjectType.FOUNTAIN, ObjectType.MAILBOX, ObjectType.FLOWER_PLANTER,
		ObjectType.SIGNBOARD, ObjectType.ROCK, ObjectType.STUMP,
		ObjectType.LIBRARY, ObjectType.CANTEEN, ObjectType.SPORTS,
		ObjectType.FURNITURE_SHOP, ObjectType.SEED_SHOP,
		ObjectType.BOOKSHELF, ObjectType.RECORD_PLAYER, ObjectType.SHELL_SHELF, ObjectType.DINING_TABLE,
		ObjectType.BED, ObjectType.SOFA, ObjectType.CHAIR, ObjectType.WARDROBE, ObjectType.STORAGE_BOX, ObjectType.DISPLAY_CASE
	]:
		return false
	return true

# 单步高度通行规则（坡道系统的核心）：
#   同高度      -> 直接通过
#   高度差 == 1 -> 起点或终点必须是坡道(RAMP)
#   高度差 > 1  -> 禁止
func can_step_between(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if in_interior:
		return is_indoor_cell_walkable(to_cell.x, to_cell.y)
	if not is_cell_walkable(to_cell.x, to_cell.y):
		return false
	if from_cell == to_cell:
		return true
	if not is_valid_cell(from_cell.x, from_cell.y):
		return true
	var h0: int = int(elevation_grid[from_cell.x][from_cell.y])
	var h1: int = int(elevation_grid[to_cell.x][to_cell.y])
	var diff: int = absi(h1 - h0)
	if diff == 0:
		return true
	if diff == 1:
		return int(object_grid[from_cell.x][from_cell.y]) == ObjectType.RAMP \
			or int(object_grid[to_cell.x][to_cell.y]) == ObjectType.RAMP
	return false

func is_rect_walkable(rect: Rect2) -> bool:
	var pts: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		rect.end
	]
	for pt in pts:
		var c: Vector2i = world_to_grid(pt)
		if not is_cell_walkable(c.x, c.y):
			return false
	return true

# 以“起点格 -> 终点格”成对比较来判定碰撞，才能表达坡道的通行方向
func _rect_step_ok(old_rect: Rect2, new_rect: Rect2) -> bool:
	var shift: Vector2 = new_rect.position - old_rect.position
	var pts: Array[Vector2] = [
		new_rect.position,
		Vector2(new_rect.end.x, new_rect.position.y),
		Vector2(new_rect.position.x, new_rect.end.y),
		new_rect.end
	]
	for pt in pts:
		var to_cell: Vector2i = world_to_grid(pt)
		var from_cell: Vector2i = world_to_grid(pt - shift)
		if not can_step_between(from_cell, to_cell):
			return false
	return true

func _move_player_with_collision(motion: Vector2) -> void:
	var old_rect := Rect2(player_pos - COLLISION_HALF_SIZE, COLLISION_HALF_SIZE * 2.0)
	var try_x := Vector2(player_pos.x + motion.x, player_pos.y)
	var rect_x := Rect2(try_x - COLLISION_HALF_SIZE, COLLISION_HALF_SIZE * 2.0)
	if _rect_step_ok(old_rect, rect_x):
		player_pos.x = try_x.x
		old_rect = Rect2(player_pos - COLLISION_HALF_SIZE, COLLISION_HALF_SIZE * 2.0)
	var try_y := Vector2(player_pos.x, player_pos.y + motion.y)
	var rect_y := Rect2(try_y - COLLISION_HALF_SIZE, COLLISION_HALF_SIZE * 2.0)
	if _rect_step_ok(old_rect, rect_y):
		player_pos.y = try_y.y
	if in_interior:
		var pc: Vector2i = world_to_grid(player_pos)
		if pc.y >= ROOM_H - 1 and pc.x in [5, 6] and motion.y > 0.0:
			_exit_house()

func get_front_cell() -> Vector2i:
	var target_pt: Vector2 = player_pos + player_facing.normalized() * float(TILE_SIZE) * 0.95
	return world_to_grid(target_pt)

# ==============================================================================
# 情境互动检测与右侧互动按钮真实响应
# ==============================================================================

func _refresh_nearby_interaction() -> void:
	nearby_interact_type = ""
	nearby_interact_cell = Vector2i(-1, -1)
	nearby_animal_idx = -1

	if interact_btn_label == null:
		return

	if in_interior:
		_refresh_indoor_interaction()
		return

	for i in range(animals.size()):
		var a_pos: Vector2 = animals[i]["pos"]
		if player_pos.distance_to(a_pos) <= 26.0:
			nearby_interact_type = "animal"
			nearby_animal_idx = i
			interact_btn_label.text = "交谈"
			return

	var p_cell: Vector2i = world_to_grid(player_pos)
	var f_cell: Vector2i = get_front_cell()
	var front_key: String = _crop_key(f_cell)
	if crops.has(front_key) and _crop_ready(crops[front_key]):
		nearby_interact_type = "harvest"
		nearby_interact_cell = f_cell
		interact_btn_label.text = "收获"
		return
	var check_cells: Array[Vector2i] = [
		f_cell, p_cell,
		p_cell + Vector2i(0, -1), p_cell + Vector2i(0, 1),
		p_cell + Vector2i(-1, 0), p_cell + Vector2i(1, 0)
	]

	for c in check_cells:
		if not is_valid_cell(c.x, c.y):
			continue
		var obj: int = object_grid[c.x][c.y]
		match obj:
			ObjectType.SHELL, ObjectType.MUSHROOM:
				nearby_interact_type = "pickup"
				nearby_interact_cell = c
				interact_btn_label.text = "拾取"
				return
			ObjectType.SHOP:
				nearby_interact_type = "shop"
				nearby_interact_cell = c
				interact_btn_label.text = "商店"
				return
			ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE:
				nearby_interact_type = "house"
				nearby_interact_cell = c
				interact_btn_label.text = "进入"
				return
			ObjectType.MAILBOX:
				nearby_interact_type = "mailbox"
				nearby_interact_cell = c
				interact_btn_label.text = "信箱"
				return
			ObjectType.FOUNTAIN:
				nearby_interact_type = "fountain"
				nearby_interact_cell = c
				interact_btn_label.text = "许愿"
				return
			ObjectType.SIGNBOARD:
				nearby_interact_type = "signboard"
				nearby_interact_cell = c
				interact_btn_label.text = "路牌"
				return
			ObjectType.CONSTRUCTION:
				nearby_interact_type = "construction"
				nearby_interact_cell = c
				interact_btn_label.text = "施工"
				return
			ObjectType.BENCH:
				nearby_interact_type = "bench"
				nearby_interact_cell = c
				interact_btn_label.text = "休息"
				return
			ObjectType.LIBRARY:
				nearby_interact_type = "library"
				nearby_interact_cell = c
				interact_btn_label.text = "看书"
				return
			ObjectType.CANTEEN:
				nearby_interact_type = "canteen"
				nearby_interact_cell = c
				interact_btn_label.text = "用餐"
				return
			ObjectType.SPORTS:
				nearby_interact_type = "sports"
				nearby_interact_cell = c
				interact_btn_label.text = "运动"
				return
			ObjectType.FURNITURE_SHOP:
				nearby_interact_type = "furniture"
				nearby_interact_cell = c
				interact_btn_label.text = "家具"
				return
			ObjectType.SEED_SHOP:
				nearby_interact_type = "seed_shop"
				nearby_interact_cell = c
				interact_btn_label.text = "种子"
				return

	interact_btn_label.text = "互动"

func _on_interact_pressed() -> void:
	_refresh_nearby_interaction()
	if in_interior:
		_on_indoor_interact_pressed()
		return
	match nearby_interact_type:
		"animal":
			if nearby_animal_idx >= 0 and nearby_animal_idx < animals.size():
				_spawn_burst_effect(animals[nearby_animal_idx]["pos"] + Vector2(0, -14), PAL_PINK)
				_resident_interact(nearby_animal_idx)
		"pickup":
			if is_valid_cell(nearby_interact_cell.x, nearby_interact_cell.y):
				var picked_obj: int = object_grid[nearby_interact_cell.x][nearby_interact_cell.y]
				object_grid[nearby_interact_cell.x][nearby_interact_cell.y] = ObjectType.NONE
				if picked_obj == ObjectType.SHELL:
					_add_item("shell", 1)
					_show_toast("拾取了【海贝壳】×1！已放入背包")
				else:
					_add_item("apple", 1)
					_show_toast("采摘了林间物产！已放入背包")
				_spawn_burst_effect(Vector2(nearby_interact_cell) * TILE_SIZE + Vector2(8, 8), PAL_CREAM)
				_refresh_nearby_interaction()
		"shop":
			_open_shop_modal()
		"house":
			_enter_house(nearby_interact_cell)
		"mailbox":
			_open_dialog_modal("小岛木制信箱", "收到来自动物居民的明信片：\n「在属于自己的小岛上，慢慢生活。今天也去海边或松林走走吧！」")
		"fountain":
			_spawn_burst_effect(Vector2(nearby_interact_cell) * TILE_SIZE + Vector2(8, 8), PAL_SKY_BLUE)
			_show_toast("在中央清泉喷泉旁许下了温暖的心愿~")
		"signboard":
			_open_dialog_modal("小岛木质指示牌", "↖ 西北：静谧松林与高地瀑布\n⬆ 中央：喷泉广场与温馨小屋\n➡ 河东：海岛杂货铺\n⬇ 正南：阳光金沙滩与观海木栈桥")
		"construction":
			_open_dialog_modal("建筑施工围挡", "新建筑正在施工中，将在现实日期进入次日清晨（05:00后）自动完工落成！")
		"harvest":
			_harvest_crop_at(nearby_interact_cell)
		"bench":
			_show_toast("坐在温暖的木长椅上听海浪声，真惬意~")
		"library":
			_open_library()
		"canteen":
			_open_canteen()
		"sports":
			_open_sports()
		"furniture":
			_open_furniture_shop()
		"seed_shop":
			_open_seed_shop()
		_:
			_show_toast("靠近小动物、海滩贝壳、喷泉、信箱或杂货铺即可点击互动！")

# ==============================================================================
# 工具使用与快捷栏真实联动
# ==============================================================================

func _on_use_tool_pressed() -> void:
	if game_state != GameState.EXPLORE_MODE:
		return
	if in_interior:
		_on_indoor_use_tool_pressed()
		return
	var item_id: String = hotbar[selected_hotbar_index]
	if item_id == "" or not ITEM_DB.has(item_id):
		_show_toast("当前快捷栏槽位为空，请在背包中选择物品装入")
		return

	tool_swing_timer = 0.25
	var f_cell: Vector2i = get_front_cell()
	if not is_valid_cell(f_cell.x, f_cell.y):
		_show_toast("前方超出小岛边界")
		return

	var cell_center: Vector2 = Vector2(f_cell.x * TILE_SIZE + 8, f_cell.y * TILE_SIZE + 8)
	var item_info: Dictionary = ITEM_DB[item_id]
	var g_type: int = ground_grid[f_cell.x][f_cell.y]
	var o_type: int = object_grid[f_cell.x][f_cell.y]

	match item_id:
		"shovel":
			if o_type in [ObjectType.WEED, ObjectType.FLOWER_PINK, ObjectType.FLOWER_YELLOW, ObjectType.FLOWER_WATERED, ObjectType.BUSH, ObjectType.STUMP]:
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_spawn_burst_effect(cell_center, PAL_EARTH)
				if o_type in [ObjectType.FLOWER_PINK, ObjectType.FLOWER_YELLOW, ObjectType.FLOWER_WATERED]:
					_add_item("flower_seed", 1)
					_show_toast("用铁铲移植了花朵，回收【鲜花苗】×1")
				else:
					_show_toast("用铁铲清理了前方地面！")
			elif o_type == ObjectType.NONE and g_type == GroundType.GRASS and elevation_grid[f_cell.x][f_cell.y] == 1:
				ground_grid[f_cell.x][f_cell.y] = GroundType.TILLED_SOIL
				_spawn_burst_effect(cell_center, PAL_EARTH)
				_show_toast("翻松了一块温暖的泥土地！")
			elif g_type == GroundType.TILLED_SOIL:
				ground_grid[f_cell.x][f_cell.y] = GroundType.GRASS
				_spawn_burst_effect(cell_center, PAL_GRASS)
				_show_toast("将泥土地恢复成了翠绿草地！")
			else:
				_show_toast("铁铲可除草、移花或翻土（大面积改造请点顶部【岛建】）")
		"axe":
			if o_type in [ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM]:
				object_grid[f_cell.x][f_cell.y] = ObjectType.STUMP
				_spawn_burst_effect(cell_center, PAL_WOOD)
				_add_item("wood", 3)
				_add_item("apple", 1)
				_show_toast("收获【木材】×3 与【海岛苹果】×1！（留下树桩可用铁铲挖除）")
			elif o_type in [ObjectType.BENCH, ObjectType.LAMP, ObjectType.FENCE, ObjectType.FLOWER_PLANTER]:
				if o_type == ObjectType.BENCH: _add_item("bench_item", 1)
				elif o_type == ObjectType.LAMP: _add_item("lamp_item", 1)
				elif o_type == ObjectType.FLOWER_PLANTER: _add_item("potted_plant", 1)
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_spawn_burst_effect(cell_center, PAL_CREAM)
				_show_toast("已拆卸并回收前方的户外家具！")
			else:
				_show_toast("请面朝树木或户外家具再使用伐木斧")
		"watering_can":
			_spawn_burst_effect(cell_center, PAL_SKY_BLUE)
			if _water_crop_at(f_cell):
				_show_toast("给作物浇了水，明天就会长大一点")
				_refresh_hotbar_ui()
				_refresh_nearby_interaction()
				return
			if o_type in [ObjectType.FLOWER_PINK, ObjectType.FLOWER_YELLOW]:
				object_grid[f_cell.x][f_cell.y] = ObjectType.FLOWER_WATERED
				_show_toast("给花丛浇了清泉水，花瓣闪着晶莹的光芒！")
			else:
				_show_toast("洒出了一串清凉的水珠~")
		"net":
			_spawn_burst_effect(cell_center, PAL_CREAM)
			if o_type in [ObjectType.FLOWER_PINK, ObjectType.FLOWER_YELLOW, ObjectType.FLOWER_WATERED, ObjectType.BUSH, ObjectType.FLOWER_PLANTER] or g_type == GroundType.GRASS:
				_add_item("bug", 1)
				_show_toast("轻巧挥网！捕捉到了【黄粉蝶】×1！")
			else:
				_show_toast("在草地或花丛旁挥网更容易遇到蝴蝶哦")
		"rod":
			_fishing_action()
		_:
			if item_info.get("type", "") == "placeable":
				var count: int = int(inventory.get(item_id, 0))
				if count <= 0:
					_show_toast("该物品数量不足")
					return
				if o_type == ObjectType.NONE and g_type in [GroundType.GRASS, GroundType.SAND, GroundType.STONE_PATH, GroundType.WOOD_PATH, GroundType.TILLED_SOIL] and elevation_grid[f_cell.x][f_cell.y] == 1:
					object_grid[f_cell.x][f_cell.y] = int(item_info["obj_id"])
					_consume_item(item_id, 1)
					_spawn_burst_effect(cell_center, PAL_PINK)
					_show_toast("成功放置了【" + str(item_info["name"]) + "】！")
				else:
					_show_toast("前方格子已有物体或是水面，无法放置")
			elif item_info.get("type", "") == "seed":
				if _plant_seed_at(f_cell, item_id):
					_show_toast("播下了%s，记得每天浇水" % str(item_info["name"]))
			elif item_info.get("type", "") == "consumable":
				_consume_item(item_id, 1)
				_spawn_burst_effect(player_pos, PAL_CORAL)
				_show_toast("品尝了香甜的【" + str(item_info["name"]) + "】，神清气爽！")
			else:
				_show_toast("当前手持：【" + str(item_info["name"]) + "】，可在杂货铺出售换取铃钱")

	_refresh_hotbar_ui()
	_refresh_nearby_interaction()

func _add_item(item_id: String, amount: int) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	if not (item_id in hotbar):
		for i in range(hotbar.size()):
			if hotbar[i] == "":
				hotbar[i] = item_id
				break
	_refresh_hotbar_ui()

func _consume_item(item_id: String, amount: int) -> void:
	var cur: int = int(inventory.get(item_id, 0)) - amount
	if cur <= 0:
		inventory.erase(item_id)
		for i in range(hotbar.size()):
			if hotbar[i] == item_id:
				hotbar[i] = ""
	else:
		inventory[item_id] = cur
	_refresh_hotbar_ui()

# ==============================================================================
# 手机岛建模式（支持 9 大图标化工具：草地、铲平、造高地、水域、道路、植物、建筑、装饰、移动物体 + 撤销/重做/确认/取消）
# ==============================================================================

func _switch_game_state(new_state: int) -> void:
	_reset_touch_states()
	_cancel_auto_path()
	game_state = new_state

	if title_panel != null:
		title_panel.visible = (game_state == GameState.TITLE_SCREEN)
	if hud_root != null:
		hud_root.visible = (game_state != GameState.TITLE_SCREEN)

	if game_state == GameState.EXPLORE_MODE:
		moving_picked_obj = ObjectType.NONE
		if build_toolbar_panel != null: build_toolbar_panel.visible = false
		if hotbar_panel != null: hotbar_panel.visible = true
		if right_action_box != null: right_action_box.visible = true
		if mode_toggle_label != null: mode_toggle_label.text = "岛建"
		if camera != null:
			camera.zoom = Vector2(setting_camera_zoom, setting_camera_zoom)
			camera.position = player_pos
	elif game_state == GameState.BUILD_MODE:
		if build_toolbar_panel != null: build_toolbar_panel.visible = true
		if hotbar_panel != null: hotbar_panel.visible = false
		if right_action_box != null: right_action_box.visible = false
		if mode_toggle_label != null: mode_toggle_label.text = "漫步"
		if camera != null:
			var bz: float = maxf(0.85, setting_camera_zoom * 0.92)
			camera.zoom = Vector2(bz, bz)
		_update_build_ui_labels()

	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

func _reset_touch_states() -> void:
	joy_touch_index = -1
	joy_vector = Vector2.ZERO
	joy_knob_pos = joy_center
	build_touch_index = -1
	build_drag_start_cell = Vector2i(-1, -1)
	build_drag_curr_cell = Vector2i(-1, -1)
	has_pending_box = false
	current_stroke_changes.clear()
	if build_confirm_box_btn != null:
		build_confirm_box_btn.visible = false
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

func is_cell_editable_for_tool(gx: int, gy: int, tool_id: int) -> bool:
	if gx <= 2 or gx >= GRID_WIDTH - 3 or gy <= 2 or gy >= GRID_HEIGHT - 3:
		return false
	var obj: int = object_grid[gx][gy]
	if obj in [ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE, ObjectType.SHOP] and tool_id != BuildTool.MOVE_OBJECT:
		return false
	# 水面（elev==0）只能先用【铲平】填土造陆，其它工具一律红框拦截，避免“水上造岛”
	if int(elevation_grid[gx][gy]) == 0 and tool_id in [
		BuildTool.ROAD_PAVE, BuildTool.PLANT_PUT, BuildTool.BUILDING_PUT,
		BuildTool.DECOR_PUT, BuildTool.CLIFF_RAISE, BuildTool.GROUND_GRASS
	]:
		return false
	if tool_id in [BuildTool.RIVER_DIG, BuildTool.CLIFF_RAISE, BuildTool.BUILDING_PUT]:
		var p_cell: Vector2i = world_to_grid(player_pos)
		if p_cell.x == gx and p_cell.y == gy:
			return false
		for a in animals:
			var a_cell: Vector2i = world_to_grid(a["pos"])
			if a_cell.x == gx and a_cell.y == gy:
				return false
	return true

func _handle_move_object_tool(cell: Vector2i) -> void:
	if not is_valid_cell(cell.x, cell.y):
		return
	if moving_picked_obj == ObjectType.NONE:
		var obj: int = object_grid[cell.x][cell.y]
		if obj == ObjectType.NONE:
			_show_toast("【移动工具】请先点击岛上已有的家具、植物或建筑将其拿起")
			return
		moving_picked_obj = obj
		moving_from_cell = cell
		object_grid[cell.x][cell.y] = ObjectType.NONE
		_show_toast("已拿起物体！请点击新的空地格子完成移动（或点取消放回原处）")
		_update_build_ui_labels()
	else:
		if object_grid[cell.x][cell.y] != ObjectType.NONE or ground_grid[cell.x][cell.y] in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
			_show_toast("目标位置已有物体或是水面，请选择平整陆地放置")
			return
		var move_changes: Array = [
			{"x": moving_from_cell.x, "y": moving_from_cell.y, "old_g": ground_grid[moving_from_cell.x][moving_from_cell.y], "old_e": elevation_grid[moving_from_cell.x][moving_from_cell.y], "old_o": moving_picked_obj},
			{"x": cell.x, "y": cell.y, "old_g": ground_grid[cell.x][cell.y], "old_e": elevation_grid[cell.x][cell.y], "old_o": ObjectType.NONE}
		]
		object_grid[cell.x][cell.y] = moving_picked_obj
		_commit_stroke_to_undo(move_changes)
		_spawn_burst_effect(Vector2(cell) * TILE_SIZE + Vector2(8, 8), PAL_CREAM)
		moving_picked_obj = ObjectType.NONE
		moving_from_cell = Vector2i(-1, -1)
		_show_toast("已成功移动物体位置！")
		_update_build_ui_labels()

func _apply_brush_at_cell(center_cell: Vector2i, tool_id: int, stroke_changes: Array) -> bool:
	if tool_id == BuildTool.MOVE_OBJECT:
		_handle_move_object_tool(center_cell)
		return true
	var any_changed: bool = false
	var offset: int = -int((build_brush_size - 1) / 2)   # 画笔以手指位置为中心，而不是左上角
	for dx in range(build_brush_size):
		for dy in range(build_brush_size):
			if _apply_build_tool_to_cell(center_cell.x + offset + dx, center_cell.y + offset + dy, tool_id, stroke_changes):
				any_changed = true
	if any_changed:
		_spawn_burst_effect(Vector2(center_cell) * TILE_SIZE + Vector2(8, 8), PAL_CREAM)
	return any_changed

func _apply_build_tool_to_cell(gx: int, gy: int, tool_id: int, stroke_changes: Array) -> bool:
	if not is_cell_editable_for_tool(gx, gy, tool_id):
		return false

	if tool_id == BuildTool.FARM:
		return _farm_action_at_cell(gx, gy)

	var old_g: int = ground_grid[gx][gy]
	var old_e: int = elevation_grid[gx][gy]
	var old_o: int = object_grid[gx][gy]

	var new_g: int = old_g
	var new_e: int = old_e
	var new_o: int = old_o

	match tool_id:
		BuildTool.GROUND_GRASS:
			new_g = GroundType.GRASS
			new_e = 1
		BuildTool.FLATTEN:
			# 铲平同时承担“填土造陆”：任何水域都会被填成草地，高度回到 1
			if new_g in [GroundType.RIVER, GroundType.SHALLOW_WATER, GroundType.DEEP_WATER, GroundType.TILLED_SOIL]:
				new_g = GroundType.GRASS
			new_e = 1
			if new_o not in [ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE, ObjectType.SHOP]:
				new_o = ObjectType.NONE
		BuildTool.CLIFF_RAISE:
			if build_sub_cliff == 1:
				# 坡道：不改变地形高度，只在地面放一块连接台阶
				new_o = ObjectType.RAMP
			else:
				new_g = GroundType.GRASS
				new_e = 2
				new_o = ObjectType.NONE
		BuildTool.RIVER_DIG:
			new_g = GroundType.RIVER
			new_e = 0
			new_o = ObjectType.NONE
		BuildTool.ROAD_PAVE:
			# 保留原有高度：在高地上铺路不会再被压平成平地
			new_g = build_sub_road
			if new_o in [ObjectType.WEED, ObjectType.TREE_OAK, ObjectType.TREE_PINE]:
				new_o = ObjectType.NONE
		BuildTool.PLANT_PUT:
			new_o = build_sub_plant
		BuildTool.DECOR_PUT:
			new_o = build_sub_decor
		BuildTool.BUILDING_PUT:
			new_o = ObjectType.CONSTRUCTION

	if new_g == old_g and new_e == old_e and new_o == old_o:
		return false

	var already_recorded: bool = false
	for item in stroke_changes:
		if item["x"] == gx and item["y"] == gy:
			already_recorded = true
			break
	if not already_recorded:
		stroke_changes.append({
			"x": gx, "y": gy,
			"old_g": old_g, "old_e": old_e, "old_o": old_o,
			"new_g": new_g, "new_e": new_e, "new_o": new_o
		})
	else:
		for item in stroke_changes:
			if item["x"] == gx and item["y"] == gy:
				item["new_g"] = new_g
				item["new_e"] = new_e
				item["new_o"] = new_o
				break

	ground_grid[gx][gy] = new_g
	elevation_grid[gx][gy] = new_e
	object_grid[gx][gy] = new_o
	return true

func _commit_stroke_to_undo(stroke_changes: Array) -> void:
	if stroke_changes.is_empty():
		return
	for ch in stroke_changes:
		var gx: int = int(ch["x"])
		var gy: int = int(ch["y"])
		ch["new_g"] = ground_grid[gx][gy]
		ch["new_e"] = elevation_grid[gx][gy]
		ch["new_o"] = object_grid[gx][gy]
	undo_stack.append(stroke_changes.duplicate(true))
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
	redo_stack.clear()
	_update_build_ui_labels()

func _on_build_undo_pressed() -> void:
	if undo_stack.is_empty():
		_show_toast("当前没有可撤销的岛建操作")
		return
	var last_changes: Array = undo_stack.pop_back()
	for ch in last_changes:
		var gx: int = int(ch["x"])
		var gy: int = int(ch["y"])
		if is_valid_cell(gx, gy):
			ground_grid[gx][gy] = int(ch["old_g"])
			elevation_grid[gx][gy] = int(ch["old_e"])
			object_grid[gx][gy] = int(ch["old_o"])
	redo_stack.append(last_changes)
	has_pending_box = false
	if build_confirm_box_btn != null:
		build_confirm_box_btn.visible = false
	_update_build_ui_labels()
	_show_toast("已撤销上一步操作（恢复 %d 格）" % last_changes.size())

func _on_build_redo_pressed() -> void:
	if redo_stack.is_empty():
		_show_toast("当前没有可重做的操作")
		return
	var next_changes: Array = redo_stack.pop_back()
	for ch in next_changes:
		var gx: int = int(ch["x"])
		var gy: int = int(ch["y"])
		if is_valid_cell(gx, gy):
			ground_grid[gx][gy] = int(ch.get("new_g", ground_grid[gx][gy]))
			elevation_grid[gx][gy] = int(ch.get("new_e", elevation_grid[gx][gy]))
			object_grid[gx][gy] = int(ch.get("new_o", object_grid[gx][gy]))
	undo_stack.append(next_changes)
	_update_build_ui_labels()
	_show_toast("已重做岛建操作（应用 %d 格）" % next_changes.size())

func _execute_pending_box_selection() -> void:
	if not has_pending_box:
		return
	var batch_changes: Array = []
	var modified_count: int = 0
	for gx in range(pending_box_rect.position.x, pending_box_rect.end.x):
		for gy in range(pending_box_rect.position.y, pending_box_rect.end.y):
			if _apply_build_tool_to_cell(gx, gy, current_build_tool, batch_changes):
				modified_count += 1
	_commit_stroke_to_undo(batch_changes)
	has_pending_box = false
	if build_confirm_box_btn != null:
		build_confirm_box_btn.visible = false
	if modified_count > 0:
		_show_toast("已完成区域批量改造（共修改 %d 格）" % modified_count)
	else:
		_show_toast("所选区域无需修改或处于保护范围")

# ==============================================================================
# 钓鱼与图鉴（阶段8）
# ==============================================================================

const FISH_DB: Dictionary = {
	"crucian":        {"name": "小鲫鱼",   "water": "river", "rarity": 0, "price": 60},
	"carp":           {"name": "鲤鱼",     "water": "river", "rarity": 0, "price": 80},
	"loach":          {"name": "泥鳅",     "water": "river", "rarity": 1, "price": 110},
	"bass":           {"name": "河鲈",     "water": "river", "rarity": 1, "price": 140},
	"eel":            {"name": "夜鳗",     "water": "river", "rarity": 2, "price": 260, "night": true},
	"sardine":        {"name": "沙丁鱼",   "water": "sea",   "rarity": 0, "price": 70},
	"mackerel":       {"name": "竹荚鱼",   "water": "sea",   "rarity": 0, "price": 95},
	"sea_bream":      {"name": "鲷鱼",     "water": "sea",   "rarity": 1, "price": 180},
	"flatfish":       {"name": "比目鱼",   "water": "sea",   "rarity": 1, "price": 200},
	"squid":          {"name": "乌贼",     "water": "sea",   "rarity": 2, "price": 300, "night": true},
	"tuna":           {"name": "金枪鱼",   "water": "sea",   "rarity": 3, "price": 600},
	"moonfish":       {"name": "月光鱼",   "water": "sea",   "rarity": 3, "price": 900, "night": true}
}

var fishing_state: String = "idle"
var fishing_timer: float = 0.0
var fishing_cell: Vector2i = Vector2i(-1, -1)
var fishing_water: String = "sea"
var fishing_species: String = ""
var caught_fish: Dictionary = {}

func _fish_rarity_label(r: int) -> String:
	return ["常见", "少见", "稀有", "传说"][clampi(r, 0, 3)]

func _pick_fish(water: String) -> String:
	var pool: Array = []
	for id in FISH_DB.keys():
		var f: Dictionary = FISH_DB[id]
		if str(f["water"]) != water:
			continue
		if bool(f.get("night", false)) and not (clock_hour >= 20 or clock_hour < 6):
			continue
		var weight: int = [60, 25, 10, 4][clampi(int(f["rarity"]), 0, 3)]
		for k in range(weight):
			pool.append(str(id))
	if pool.is_empty():
		return "crucian" if water == "river" else "sardine"
	return str(pool[randi() % pool.size()])

func _fishing_action() -> void:
	if fishing_state == "bite":
		_success_fishing()
		return
	if fishing_state == "cast":
		fishing_state = "idle"
		_show_toast("收竿太早了，鱼还没上钩")
		return
	var f_cell: Vector2i = get_front_cell()
	if not is_valid_cell(f_cell.x, f_cell.y):
		_show_toast("面朝水面再抛竿")
		return
	var g: int = int(ground_grid[f_cell.x][f_cell.y])
	if g not in [GroundType.RIVER, GroundType.SHALLOW_WATER, GroundType.DEEP_WATER]:
		_show_toast("要面朝河流或大海才能抛竿")
		return
	fishing_cell = f_cell
	fishing_water = "river" if g == GroundType.RIVER else "sea"
	fishing_state = "cast"
	fishing_timer = randf_range(1.4, 3.8)
	_show_toast("抛竿了，安静等浮漂动…")

func _update_fishing(delta: float) -> void:
	if fishing_state == "cast":
		fishing_timer -= delta
		if fishing_timer <= 0.0:
			fishing_species = _pick_fish(fishing_water)
			fishing_state = "bite"
			fishing_timer = 1.3
			_show_toast("浮漂猛地一沉！快点「使用」收竿！")
	elif fishing_state == "bite":
		fishing_timer -= delta
		if fishing_timer <= 0.0:
			fishing_state = "idle"
			_show_toast("犹豫了一下，鱼跑掉了…")

func _success_fishing() -> void:
	var f: Dictionary = FISH_DB.get(fishing_species, {})
	var nm: String = str(f.get("name", "小鱼"))
	var rarity: int = int(f.get("rarity", 0))
	caught_fish[fishing_species] = int(caught_fish.get(fishing_species, 0)) + 1
	_add_item("fish", 1)
	fishing_state = "idle"
	_spawn_burst_effect(Vector2(fishing_cell) * TILE_SIZE + Vector2(8, 8), PAL_SKY_BLUE)
	_show_toast("钓到了【%s】！%s，可在杂货铺出售" % [nm, _fish_rarity_label(rarity)])

func _open_fish_codex() -> void:
	var lines: Array = []
	var total: int = 0
	var kinds: int = 0
	for id in FISH_DB.keys():
		var f: Dictionary = FISH_DB[id]
		var c: int = int(caught_fish.get(str(id), 0))
		total += c
		if c > 0:
			kinds += 1
		lines.append("%s  %s  ×%d" % [str(f["name"]), _fish_rarity_label(int(f["rarity"])), c])
	lines.append("")
	lines.append("已收集 %d/%d 种，共 %d 条" % [kinds, FISH_DB.size(), total])
	_open_dialog_modal("鱼类图鉴", "\n".join(lines))

# ==============================================================================
# 房屋与室内（阶段7）：每个房间有独立布局数据，进出保留室外位置
# ==============================================================================

const ROOM_W: int = 12
const ROOM_H: int = 10

var in_interior: bool = false
var current_room_id: String = ""
var player_floor: int = 1
var outdoor_pos: Vector2 = Vector2.ZERO
var outdoor_facing: Vector2 = Vector2.DOWN
var indoor_rooms: Dictionary = {}
var indoor_edit_mode: bool = false
var is_player_sitting: bool = false
var sitting_furniture_pos: Vector2 = Vector2.ZERO
var storage_box_items: Dictionary = {}
var fridge_items: Dictionary = {}
var player_shirt_idx: int = 0
var player_hat_idx: int = 0
const SHIRT_COLORS: Array[Color] = [Color("#379CC9"), Color("#EE8398"), Color("#39815D"), Color("#F7D460"), Color("#A288E3"), Color("#FFF2D6")]
const SHIRT_NAMES: Array[String] = ["海洋天蓝", "珊瑚粉樱", "静谧森林", "暖阳明黄", "薰衣草紫", "清爽纯白"]
const HAT_NAMES: Array[String] = ["探险草帽", "红色贝雷帽", "海岛花环", "不戴帽子"]

# 语言 AI 适配层（离线高品质本地人格库 + 可选云端自定义代理）
var ai_enabled: bool = false
var ai_api_url: String = "https://api.openai.com/v1"
var ai_api_key: String = ""
var ai_model_name: String = "gpt-4o-mini"
var ai_request_in_progress: bool = false
var _ai_dialog_cache: Dictionary = {}
var indoor_preview_cell: Vector2i = Vector2i(-1, -1)
var indoor_moving_item: Dictionary = {}
var indoor_hud_bar: Panel = null
var indoor_title_lbl: Label = null
var indoor_edit_btn: Button = null
var indoor_store_btn: Button = null
var indoor_exit_btn: Button = null

const INDOOR_FURNITURE_META: Dictionary = {
	"bed":           {"name": "温暖木床",   "icon": "bed",           "walkable": false, "item_id": "bed_item",       "act": "sleep",         "btn": "休息"},
	"double_bed":    {"name": "豪华双人床", "icon": "double_bed",    "walkable": false, "item_id": "double_bed_item","act": "sleep",         "btn": "就寝"},
	"sofa":          {"name": "暖心沙发",   "icon": "sofa",          "walkable": false, "item_id": "sofa_item",      "act": "sit",           "btn": "小憩"},
	"chair":         {"name": "木靠背椅",   "icon": "chair",         "walkable": false, "item_id": "chair_item",     "act": "sit",           "btn": "落座"},
	"table":         {"name": "原木书桌",   "icon": "table",         "walkable": false, "item_id": "table_item",     "act": "work",          "btn": "工作"},
	"bookshelf":     {"name": "满载书架",   "icon": "bookshelf",     "walkable": false, "item_id": "bookshelf_item", "act": "read",          "btn": "阅读"},
	"lamp":          {"name": "温馨台灯",   "icon": "lamp",          "walkable": false, "item_id": "lamp_item",      "act": "lamp",          "btn": "开关"},
	"rug":           {"name": "织花地毯",   "icon": "rug",           "walkable": true,  "item_id": "rug_item",       "act": "",              "btn": "互动"},
	"wardrobe":      {"name": "双门衣柜",   "icon": "wardrobe",      "walkable": false, "item_id": "wardrobe_item",  "act": "wardrobe",      "btn": "衣柜"},
	"storage_box":   {"name": "储物木箱",   "icon": "storage_box",   "walkable": false, "item_id": "storage_item",   "act": "storage",       "btn": "存取"},
	"fridge":        {"name": "双门电冰箱", "icon": "fridge",        "walkable": false, "item_id": "fridge_item",    "act": "fridge",        "btn": "冰箱"},
	"fish_tank":     {"name": "海岛观赏鱼缸","icon": "fish_tank",    "walkable": false, "item_id": "fish_tank_item", "act": "fish_tank",     "btn": "鱼缸"},
	"clock":         {"name": "摆锤机械挂钟","icon": "clock",        "walkable": false, "item_id": "clock_item",     "act": "clock",         "btn": "时钟"},
	"trash_can":     {"name": "脚踏垃圾桶", "icon": "trash_can",     "walkable": false, "item_id": "trash_can_item", "act": "trash_can",     "btn": "丢弃"},
	"record_player": {"name": "复古留声机", "icon": "record_player", "walkable": false, "item_id": "record_item",    "act": "music",         "btn": "点歌"},
	"telescope":     {"name": "黄铜观星镜", "icon": "telescope",     "walkable": false, "item_id": "telescope_item", "act": "telescope",     "btn": "观星"},
	"easel":         {"name": "写生画架",   "icon": "easel",         "walkable": false, "item_id": "easel_item",     "act": "easel",         "btn": "作画"},
	"piano":         {"name": "原木立式钢琴","icon": "piano",         "walkable": false, "item_id": "piano_item",     "act": "piano",         "btn": "弹琴"},
	"counter_desk":  {"name": "设施服务台", "icon": "counter_desk",  "walkable": false, "item_id": "table_item",     "act": "counter",       "btn": "问询"},
	"display_case":  {"name": "收藏展示柜", "icon": "display_case",  "walkable": false, "item_id": "display_item",   "act": "display",       "btn": "观赏"},
	"seed_rack":     {"name": "花艺种子架", "icon": "seed_rack",     "walkable": false, "item_id": "potted_plant",   "act": "seeds",         "btn": "花架"},
	"shell_rack":    {"name": "海洋贝壳架", "icon": "shell_rack",    "walkable": false, "item_id": "shell",          "act": "shells",        "btn": "贝壳"},
	"sports_gear":   {"name": "运动器材架", "icon": "sports_gear",   "walkable": false, "item_id": "bench_item",     "act": "sports",        "btn": "锻炼"},
	"map_wall":      {"name": "航海探索图", "icon": "map_wall",      "walkable": false, "item_id": "display_item",   "act": "map",           "btn": "看图"},
	"stove_counter": {"name": "暖香料理台", "icon": "stove_counter", "walkable": false, "item_id": "table_item",     "act": "eat",           "btn": "品尝"},
	"potted_plant":  {"name": "精致盆栽",   "icon": "potted_plant",  "walkable": false, "item_id": "potted_plant",   "act": "plant",         "btn": "赏花"},
	"stairs_up":     {"name": "阁楼木楼梯", "icon": "stairs_up",     "walkable": false, "item_id": "",               "act": "stairs_up",     "btn": "上楼"},
	"stairs_down":   {"name": "下楼木楼梯", "icon": "stairs_down",   "walkable": false, "item_id": "",               "act": "stairs_down",   "btn": "下楼"}
}

func _init_indoor_rooms() -> void:
	indoor_rooms = {
		"player": {
			"name": "我的温馨小屋·一楼大厅（生活·储物·工作·上楼）",
			"floor_col": Color("#F7EBD4"),
			"floor_alt": Color("#EFE0C4"),
			"wall_col": Color("#D9C3A3"),
			"trim_col": Color("#8A5B45"),
			"furniture": [
				# 休息区 (左上)
				{"x": 2, "y": 2, "type": "bed"},
				{"x": 3, "y": 2, "type": "lamp", "lamp_on": true},
				{"x": 2, "y": 3, "type": "rug"},
				{"x": 3, "y": 3, "type": "rug"},
				# 储物与厨膳区 (右上)
				{"x": 7, "y": 1, "type": "fridge"},
				{"x": 8, "y": 1, "type": "wardrobe"},
				{"x": 9, "y": 1, "type": "storage_box"},
				# 通往二楼阁楼木楼梯 (右上侧，位置清晰可通行)
				{"x": 10, "y": 2, "type": "stairs_up"},
				# 工作与生活区 (左下)
				{"x": 2, "y": 6, "type": "table"},
				{"x": 3, "y": 6, "type": "chair"},
				{"x": 1, "y": 5, "type": "bookshelf"},
				{"x": 1, "y": 2, "type": "trash_can"},
				# 自由装修与观赏区
				{"x": 9, "y": 5, "type": "fish_tank"},
				{"x": 5, "y": 5, "type": "rug"},
				{"x": 6, "y": 5, "type": "rug"}
			]
		},
		"player_2f": {
			"name": "我的温馨小屋·二楼阁楼（星空天窗·观星·艺术工作室）",
			"floor_col": Color("#EFE2CF"),
			"floor_alt": Color("#E4D4BE"),
			"wall_col": Color("#8A5B45"),
			"trim_col": Color("#544A44"),
			"furniture": [
				# 通往一楼楼梯口
				{"x": 10, "y": 2, "type": "stairs_down"},
				# 阁楼大双人床
				{"x": 2, "y": 2, "type": "double_bed"},
				# 星空天窗观星镜
				{"x": 6, "y": 2, "type": "telescope"},
				# 音乐与艺术角
				{"x": 3, "y": 1, "type": "piano"},
				{"x": 2, "y": 6, "type": "easel"},
				# 阁楼挂钟与储物
				{"x": 8, "y": 1, "type": "clock"},
				{"x": 9, "y": 6, "type": "storage_box"},
				# 书写角
				{"x": 7, "y": 5, "type": "table"},
				{"x": 8, "y": 5, "type": "chair"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"}
			]
		},
		"bear": {
			"name": "小熊阿棕的木香书屋（温和·爱阅读）",
			"floor_col": Color("#EEDBC0"),
			"floor_alt": Color("#E4CFAF"),
			"wall_col": Color("#B98761"),
			"trim_col": Color("#6E4735"),
			"furniture": [
				{"x": 2, "y": 1, "type": "bookshelf"},
				{"x": 3, "y": 1, "type": "bookshelf"},
				{"x": 4, "y": 1, "type": "bookshelf"},
				{"x": 2, "y": 3, "type": "sofa"},
				{"x": 3, "y": 3, "type": "lamp"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"},
				{"x": 8, "y": 2, "type": "stove_counter"},
				{"x": 8, "y": 5, "type": "table"},
				{"x": 9, "y": 5, "type": "chair"},
				{"x": 2, "y": 7, "type": "bed"}
			]
		},
		"cat": {
			"name": "小猫柒柒的临窗观察屋（独立·爱安静）",
			"floor_col": Color("#F6E9E2"),
			"floor_alt": Color("#EDDCD3"),
			"wall_col": Color("#E6B89C"),
			"trim_col": Color("#7A5448"),
			"furniture": [
				# 靠窗座位与观察点
				{"x": 4, "y": 1, "type": "sofa"},
				{"x": 7, "y": 1, "type": "chair"},
				{"x": 8, "y": 1, "type": "lamp"},
				{"x": 2, "y": 2, "type": "record_player"},
				{"x": 5, "y": 3, "type": "rug"},
				{"x": 6, "y": 3, "type": "rug"},
				{"x": 9, "y": 4, "type": "bookshelf"},
				{"x": 2, "y": 6, "type": "bed"},
				{"x": 9, "y": 7, "type": "potted_plant"}
			]
		},
		"rabbit": {
			"name": "小兔露露的花艺园丁屋（活泼·园艺兴趣）",
			"floor_col": Color("#FBF3E6"),
			"floor_alt": Color("#F4E7D4"),
			"wall_col": Color("#F2C6CF"),
			"trim_col": Color("#9A5B6B"),
			"furniture": [
				{"x": 2, "y": 1, "type": "seed_rack"},
				{"x": 3, "y": 1, "type": "seed_rack"},
				{"x": 8, "y": 1, "type": "potted_plant"},
				{"x": 9, "y": 1, "type": "potted_plant"},
				{"x": 2, "y": 3, "type": "potted_plant"},
				{"x": 9, "y": 3, "type": "potted_plant"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"},
				{"x": 8, "y": 5, "type": "table"},
				{"x": 9, "y": 5, "type": "chair"},
				{"x": 2, "y": 6, "type": "bed"}
			]
		},
		"deer": {
			"name": "小鹿森森的自然木屋（沉静·热爱自然）",
			"floor_col": Color("#EFE5D2"),
			"floor_alt": Color("#E4D8C1"),
			"wall_col": Color("#9CC49E"),
			"trim_col": Color("#4A6B4E"),
			"furniture": [
				{"x": 2, "y": 1, "type": "bookshelf"},
				{"x": 3, "y": 1, "type": "potted_plant"},
				{"x": 8, "y": 1, "type": "potted_plant"},
				{"x": 9, "y": 1, "type": "bookshelf"},
				{"x": 3, "y": 3, "type": "table"},
				{"x": 4, "y": 3, "type": "chair"},
				{"x": 2, "y": 3, "type": "lamp"},
				{"x": 5, "y": 5, "type": "rug"},
				{"x": 6, "y": 5, "type": "rug"},
				{"x": 8, "y": 6, "type": "bed"},
				{"x": 2, "y": 7, "type": "potted_plant"}
			]
		},
		"fox": {
			"name": "小狐狸阿橙的收藏探险屋（机灵·爱收集）",
			"floor_col": Color("#EFE4D4"),
			"floor_alt": Color("#E4D6C3"),
			"wall_col": Color("#D99B72"),
			"trim_col": Color("#5C4338"),
			"furniture": [
				{"x": 2, "y": 1, "type": "display_case"},
				{"x": 3, "y": 1, "type": "display_case"},
				{"x": 6, "y": 1, "type": "map_wall"},
				{"x": 9, "y": 1, "type": "storage_box"},
				{"x": 8, "y": 3, "type": "table"},
				{"x": 9, "y": 3, "type": "chair"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"},
				{"x": 2, "y": 6, "type": "bed"},
				{"x": 3, "y": 6, "type": "lamp"}
			]
		},
		"frog": {
			"name": "小青蛙呱呱的碧波运动屋（蓝绿水生·爱运动）",
			"floor_col": Color("#E2F2EA"),
			"floor_alt": Color("#D3E8DD"),
			"wall_col": Color("#7BC9A6"),
			"trim_col": Color("#39735B"),
			"furniture": [
				{"x": 2, "y": 1, "type": "sports_gear"},
				{"x": 3, "y": 1, "type": "sports_gear"},
				{"x": 8, "y": 1, "type": "potted_plant"},
				{"x": 9, "y": 1, "type": "potted_plant"},
				{"x": 2, "y": 4, "type": "potted_plant"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"},
				{"x": 8, "y": 4, "type": "sofa"},
				{"x": 2, "y": 6, "type": "bed"},
				{"x": 9, "y": 6, "type": "storage_box"}
			]
		},
		"otter": {
			"name": "小海獭波波的贝壳海景屋（海洋装饰·爱垂钓）",
			"floor_col": Color("#E4F2F8"),
			"floor_alt": Color("#D5E7F0"),
			"wall_col": Color("#74C9ED"),
			"trim_col": Color("#2E6F8E"),
			"furniture": [
				{"x": 2, "y": 1, "type": "shell_rack"},
				{"x": 3, "y": 1, "type": "shell_rack"},
				{"x": 8, "y": 1, "type": "display_case"},
				{"x": 9, "y": 1, "type": "storage_box"},
				{"x": 2, "y": 4, "type": "table"},
				{"x": 3, "y": 4, "type": "chair"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"},
				{"x": 8, "y": 6, "type": "bed"},
				{"x": 9, "y": 6, "type": "lamp"}
			]
		},
		"bird": {
			"name": "小鸟小羽的唱机音乐屋（音乐书本·舒适座椅）",
			"floor_col": Color("#FBF2DF"),
			"floor_alt": Color("#F2E5CB"),
			"wall_col": Color("#88CBE8"),
			"trim_col": Color("#466D85"),
			"furniture": [
				{"x": 2, "y": 1, "type": "record_player"},
				{"x": 3, "y": 1, "type": "bookshelf"},
				{"x": 8, "y": 1, "type": "bookshelf"},
				{"x": 3, "y": 3, "type": "sofa"},
				{"x": 4, "y": 3, "type": "chair"},
				{"x": 8, "y": 3, "type": "lamp"},
				{"x": 5, "y": 4, "type": "rug"},
				{"x": 6, "y": 4, "type": "rug"},
				{"x": 2, "y": 6, "type": "bed"},
				{"x": 9, "y": 6, "type": "potted_plant"}
			]
		},
		"library": {
			"name": "海岛公共图书馆（全岛书库·安静自修）",
			"floor_col": Color("#EFE6D5"),
			"floor_alt": Color("#E4D9C4"),
			"wall_col": Color("#379CC9"),
			"trim_col": Color("#205A75"),
			"furniture": [
				{"x": 2, "y": 1, "type": "bookshelf"},
				{"x": 3, "y": 1, "type": "bookshelf"},
				{"x": 4, "y": 1, "type": "bookshelf"},
				{"x": 7, "y": 1, "type": "bookshelf"},
				{"x": 8, "y": 1, "type": "bookshelf"},
				{"x": 9, "y": 1, "type": "clock"},
				{"x": 2, "y": 4, "type": "counter_desk"},
				{"x": 5, "y": 4, "type": "table"},
				{"x": 6, "y": 4, "type": "chair"},
				{"x": 8, "y": 4, "type": "table"},
				{"x": 9, "y": 4, "type": "chair"},
				{"x": 5, "y": 6, "type": "rug"},
				{"x": 6, "y": 6, "type": "rug"},
				{"x": 2, "y": 7, "type": "sofa"}
			]
		},
		"canteen": {
			"name": "海岛阳光食堂（热汤便当·临海餐座）",
			"floor_col": Color("#FDF4E7"),
			"floor_alt": Color("#F4E7D4"),
			"wall_col": Color("#F08A61"),
			"trim_col": Color("#8A5B45"),
			"furniture": [
				{"x": 2, "y": 1, "type": "stove_counter"},
				{"x": 3, "y": 1, "type": "stove_counter"},
				{"x": 4, "y": 1, "type": "fridge"},
				{"x": 7, "y": 1, "type": "counter_desk"},
				{"x": 8, "y": 1, "type": "clock"},
				{"x": 2, "y": 4, "type": "table"},
				{"x": 3, "y": 4, "type": "chair"},
				{"x": 6, "y": 4, "type": "table"},
				{"x": 7, "y": 4, "type": "chair"},
				{"x": 9, "y": 5, "type": "trash_can"},
				{"x": 5, "y": 5, "type": "rug"},
				{"x": 6, "y": 5, "type": "rug"},
				{"x": 2, "y": 7, "type": "sofa"}
			]
		},
		"shop": {
			"name": "海岛杂货铺（特产货架·杂货商台）",
			"floor_col": Color("#F4EDE1"),
			"floor_alt": Color("#E9E0D1"),
			"wall_col": Color("#379CC9"),
			"trim_col": Color("#8A5B45"),
			"furniture": [
				{"x": 2, "y": 1, "type": "display_case"},
				{"x": 3, "y": 1, "type": "display_case"},
				{"x": 7, "y": 1, "type": "storage_box"},
				{"x": 8, "y": 1, "type": "storage_box"},
				{"x": 2, "y": 4, "type": "counter_desk"},
				{"x": 6, "y": 4, "type": "table"},
				{"x": 7, "y": 4, "type": "chair"},
				{"x": 9, "y": 4, "type": "potted_plant"},
				{"x": 5, "y": 5, "type": "rug"},
				{"x": 6, "y": 5, "type": "rug"}
			]
		},
		"furniture_shop": {
			"name": "海岛家具店展厅（样板陈设·室内选购）",
			"floor_col": Color("#F6EFE3"),
			"floor_alt": Color("#ECE2D2"),
			"wall_col": Color("#8A5B45"),
			"trim_col": Color("#544A44"),
			"furniture": [
				{"x": 2, "y": 1, "type": "piano"},
				{"x": 4, "y": 1, "type": "double_bed"},
				{"x": 7, "y": 1, "type": "wardrobe"},
				{"x": 8, "y": 1, "type": "counter_desk"},
				{"x": 2, "y": 5, "type": "sofa"},
				{"x": 3, "y": 5, "type": "lamp"},
				{"x": 5, "y": 4, "type": "easel"},
				{"x": 8, "y": 5, "type": "table"},
				{"x": 9, "y": 5, "type": "chair"}
			]
		},
		"seed_shop": {
			"name": "海岛温室花坊（花艺育苗·种子选购）",
			"floor_col": Color("#EBF6EC"),
			"floor_alt": Color("#DDF0DE"),
			"wall_col": Color("#39815D"),
			"trim_col": Color("#22553B"),
			"furniture": [
				{"x": 2, "y": 1, "type": "seed_rack"},
				{"x": 3, "y": 1, "type": "seed_rack"},
				{"x": 4, "y": 1, "type": "potted_plant"},
				{"x": 7, "y": 1, "type": "counter_desk"},
				{"x": 8, "y": 1, "type": "potted_plant"},
				{"x": 2, "y": 4, "type": "table"},
				{"x": 3, "y": 4, "type": "chair"},
				{"x": 7, "y": 4, "type": "potted_plant"},
				{"x": 8, "y": 4, "type": "seed_rack"}
			]
		},
		"sports": {
			"name": "海岛体育馆与运动中心（器械体能·健身更衣）",
			"floor_col": Color("#EAF6EE"),
			"floor_alt": Color("#DBEFE1"),
			"wall_col": Color("#8CCB74"),
			"trim_col": Color("#39735B"),
			"furniture": [
				{"x": 2, "y": 1, "type": "sports_gear"},
				{"x": 3, "y": 1, "type": "sports_gear"},
				{"x": 4, "y": 1, "type": "clock"},
				{"x": 7, "y": 1, "type": "storage_box"},
				{"x": 8, "y": 1, "type": "storage_box"},
				{"x": 2, "y": 4, "type": "chair"},
				{"x": 3, "y": 4, "type": "chair"},
				{"x": 7, "y": 4, "type": "sofa"},
				{"x": 8, "y": 4, "type": "sofa"}
			]
		},
		"workshop": {
			"name": "海岛工坊与修造工作室（工具台架·材料储运）",
			"floor_col": Color("#EFE5D7"),
			"floor_alt": Color("#E5D7C5"),
			"wall_col": Color("#8A5B45"),
			"trim_col": Color("#544A44"),
			"furniture": [
				{"x": 2, "y": 1, "type": "map_wall"},
				{"x": 3, "y": 1, "type": "table"},
				{"x": 4, "y": 1, "type": "chair"},
				{"x": 7, "y": 1, "type": "storage_box"},
				{"x": 8, "y": 1, "type": "storage_box"},
				{"x": 2, "y": 4, "type": "easel"},
				{"x": 7, "y": 4, "type": "trash_can"}
			]
		}
	}

func is_indoor_door_clearance(gx: int, gy: int) -> bool:
	return (gx in [5, 6]) and (gy in [8, 9])

func _indoor_furniture_at(room_id: String, gx: int, gy: int, ignore_walkable: bool = false) -> Dictionary:
	if not indoor_rooms.has(room_id):
		return {}
	var furn_list: Array = indoor_rooms[room_id].get("furniture", [])
	for f in furn_list:
		if int(f.get("x", -1)) == gx and int(f.get("y", -1)) == gy:
			var ftype: String = str(f.get("type", ""))
			var w: bool = bool(INDOOR_FURNITURE_META.get(ftype, {}).get("walkable", false))
			if ignore_walkable and w:
				continue
			return f
	return {}

func is_indoor_cell_walkable(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= ROOM_W or gy < 0 or gy >= ROOM_H:
		return false
	# 南侧房门通道 (5,9) 与 (6,9) 允许通行（走到即出门）
	if gy == ROOM_H - 1 and gx in [5, 6]:
		return true
	# 四周墙体不可穿行
	if gx == 0 or gx == ROOM_W - 1 or gy == 0 or gy == ROOM_H - 1:
		return false
	# 非地毯类家具阻挡碰撞
	var f: Dictionary = _indoor_furniture_at(current_room_id, gx, gy, true)
	if not f.is_empty():
		return false
	return true

func _resident_id_for_house(cell: Vector2i) -> String:
	for vh_id in VILLAGER_HOUSE_CELLS.keys():
		if VILLAGER_HOUSE_CELLS[vh_id] == cell:
			return str(vh_id)
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		var hc: Vector2i = world_to_grid(a["house"])
		if hc == cell:
			return str(a["id"])
	return "bear"

func _enter_house(cell: Vector2i) -> void:
	var house_id: String = "player"
	if int(object_grid[cell.x][cell.y]) == ObjectType.HOUSE:
		house_id = "player"
	else:
		house_id = _resident_id_for_house(cell)
	if indoor_rooms.is_empty():
		_init_indoor_rooms()
	if not indoor_rooms.has(house_id):
		house_id = "bear"

	_cancel_auto_path()
	_reset_touch_states()
	if not in_interior:
		outdoor_pos = player_pos
		outdoor_facing = player_facing
	in_interior = true
	current_room_id = house_id
	indoor_edit_mode = false
	indoor_moving_item = {}
	indoor_preview_cell = Vector2i(-1, -1)

	# 将玩家放置在房间南门内侧中央，面朝室内北方
	player_pos = Vector2(5.5 * TILE_SIZE, 8.1 * TILE_SIZE)
	player_facing = Vector2.UP
	_update_camera_limits()
	if camera != null:
		camera.position = Vector2(6.0 * TILE_SIZE, 5.0 * TILE_SIZE)
	if mode_toggle_label != null:
		mode_toggle_label.text = "装修" if current_room_id == "player" else "出门"
	_update_indoor_hud()
	_refresh_nearby_interaction()
	var rname: String = str(indoor_rooms[house_id].get("name", "温馨小屋"))
	if house_id == "player":
		_show_toast("进入【%s】：可自由行走、互动，或点右上【装修】布置/收纳家具" % rname)
	else:
		_show_toast("进入【%s】：走近家具可互动，往下走出房门即可返回室外" % rname)
	queue_redraw()

func _exit_house() -> void:
	if not in_interior:
		return
	if not indoor_moving_item.is_empty() and current_room_id == "player":
		indoor_rooms[current_room_id]["furniture"].append(indoor_moving_item)
		indoor_moving_item = {}
	in_interior = false
	indoor_edit_mode = false
	current_room_id = ""
	_cancel_auto_path()
	_reset_touch_states()
	player_pos = outdoor_pos
	player_facing = Vector2.DOWN
	_update_camera_limits()
	if camera != null:
		camera.position = player_pos
	if mode_toggle_label != null:
		mode_toggle_label.text = "岛建"
	_update_indoor_hud()
	_refresh_nearby_interaction()
	_show_toast("已走出房间回到小岛，室外位置、时间与背包状态完全保留")
	queue_redraw()

func _toggle_indoor_edit_mode() -> void:
	if not in_interior:
		return
	if current_room_id != "player":
		_exit_house()
		return
	indoor_edit_mode = not indoor_edit_mode
	if not indoor_edit_mode and not indoor_moving_item.is_empty():
		indoor_rooms[current_room_id]["furniture"].append(indoor_moving_item)
		indoor_moving_item = {}
	indoor_preview_cell = get_front_cell()
	_update_indoor_hud()
	if indoor_edit_mode:
		_show_toast("【室内装修模式】点地面可预览并放置快捷栏家具，或点击已有家具进行移动/收纳")
	else:
		_show_toast("已退出室内装修模式")
	queue_redraw()

func _update_indoor_hud() -> void:
	if hud_root == null:
		return
	if indoor_hud_bar == null:
		indoor_hud_bar = Panel.new()
		indoor_hud_bar.position = Vector2(12, 48)
		indoor_hud_bar.size = Vector2(460, 34)
		indoor_hud_bar.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 8))
		hud_root.add_child(indoor_hud_bar)

		var hbox := HBoxContainer.new()
		hbox.position = Vector2(8, 3)
		hbox.add_theme_constant_override("separation", 6)
		indoor_hud_bar.add_child(hbox)

		indoor_title_lbl = Label.new()
		indoor_title_lbl.custom_minimum_size = Vector2(228, 26)
		indoor_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		indoor_title_lbl.add_theme_font_size_override("font_size", 11)
		indoor_title_lbl.add_theme_color_override("font_color", PAL_WOOD)
		hbox.add_child(indoor_title_lbl)

		indoor_edit_btn = _make_touch_btn("装修: 关", Vector2(68, 26), PAL_SKY_BLUE, PAL_OUTLINE)
		indoor_edit_btn.pressed.connect(_toggle_indoor_edit_mode)
		hbox.add_child(indoor_edit_btn)

		indoor_store_btn = _make_touch_btn("收纳家具", Vector2(68, 26), PAL_SAND, PAL_OUTLINE)
		indoor_store_btn.pressed.connect(_store_front_indoor_furniture)
		hbox.add_child(indoor_store_btn)

		indoor_exit_btn = _make_touch_btn("出门返回", Vector2(68, 26), PAL_CORAL, PAL_OUTLINE)
		indoor_exit_btn.pressed.connect(_exit_house)
		hbox.add_child(indoor_exit_btn)

	indoor_hud_bar.visible = in_interior
	if not in_interior:
		return
	var rinfo: Dictionary = indoor_rooms.get(current_room_id, {})
	indoor_title_lbl.text = str(rinfo.get("name", "室内房间"))
	var is_player_room: bool = (current_room_id in ["player", "player_2f"])
	indoor_edit_btn.visible = is_player_room
	indoor_store_btn.visible = is_player_room
	indoor_edit_btn.text = "装修: 开" if indoor_edit_mode else "装修: 关"

func _indoor_host_resident_idx() -> int:
	if not in_interior or (current_room_id in ["player", "player_2f"]):
		return -1
	for i in range(animals.size()):
		if str(animals[i]["id"]) == current_room_id:
			return i
	return -1

func _indoor_host_pos() -> Vector2:
	return Vector2(6.5 * TILE_SIZE, 3.5 * TILE_SIZE)

func _refresh_indoor_interaction() -> void:
	var host_idx: int = _indoor_host_resident_idx()
	if host_idx >= 0 and player_pos.distance_to(_indoor_host_pos()) <= 26.0:
		nearby_interact_type = "indoor_animal"
		nearby_animal_idx = host_idx
		interact_btn_label.text = "交谈"
		return

	var p_cell: Vector2i = world_to_grid(player_pos)
	var f_cell: Vector2i = get_front_cell()
	if p_cell.y >= ROOM_H - 2 and p_cell.x in [5, 6] and f_cell.y >= ROOM_H - 1:
		nearby_interact_type = "exit_door"
		nearby_interact_cell = f_cell
		interact_btn_label.text = "出门"
		return

	var check_cells: Array[Vector2i] = [
		f_cell, p_cell,
		p_cell + Vector2i(0, -1), p_cell + Vector2i(0, 1),
		p_cell + Vector2i(-1, 0), p_cell + Vector2i(1, 0)
	]
	for c in check_cells:
		var f: Dictionary = _indoor_furniture_at(current_room_id, c.x, c.y, true)
		if not f.is_empty():
			var ftype: String = str(f.get("type", ""))
			var meta: Dictionary = INDOOR_FURNITURE_META.get(ftype, {})
			nearby_interact_type = "indoor_furn"
			nearby_interact_cell = c
			interact_btn_label.text = str(meta.get("btn", "互动"))
			return
	interact_btn_label.text = "出门" if (p_cell.y >= ROOM_H - 2 and p_cell.x in [5, 6]) else "互动"

func _on_indoor_interact_pressed() -> void:
	if nearby_interact_type == "indoor_animal" and nearby_animal_idx >= 0:
		_spawn_burst_effect(_indoor_host_pos() + Vector2(0, -12), PAL_PINK)
		_resident_interact(nearby_animal_idx)
		return
	if nearby_interact_type == "exit_door":
		_exit_house()
		return
	if nearby_interact_type == "indoor_furn":
		var f: Dictionary = _indoor_furniture_at(current_room_id, nearby_interact_cell.x, nearby_interact_cell.y, true)
		if not f.is_empty():
			var ftype: String = str(f.get("type", ""))
			var meta: Dictionary = INDOOR_FURNITURE_META.get(ftype, {})
			_do_interior_action(str(meta.get("act", "")), ftype)
			return
	var p_cell: Vector2i = world_to_grid(player_pos)
	if p_cell.y >= ROOM_H - 2 and p_cell.x in [5, 6]:
		_exit_house()
	else:
		_show_toast("走近床铺、书架、衣柜、留声机或居民即可点击互动；走到底部房门可出门")

func _do_interior_action(act_id: String, ftype: String = "") -> void:
	match act_id:
		"sleep":
			_save_game()
			_spawn_burst_effect(player_pos, PAL_SKY_BLUE)
			_show_toast("在温暖的木床上休息片刻，精神饱满，日记进度已自动保存！")
		"storage":
			_open_bag_modal()
		"work":
			_open_dialog_modal("工作区书桌笔记", "【小岛生活手记】\n• 休息区：木床可随时睡眠存档\n• 储物区：衣柜与木箱可整理背包\n• 自由装修区：选中底部家具点「使用」或开启「装修」即可摆放、移动与收纳家具！")
		"read":
			player_knowledge += 1
			_show_toast("翻阅了书架上的绘本笔记，知识 +1（当前知识：%d）" % player_knowledge)
		"music":
			speed_buff_timer = maxf(speed_buff_timer, 90.0)
			_spawn_burst_effect(player_pos, PAL_GOLD)
			_show_toast("留声机流淌出轻柔的海岛旋律，心情愉悦（移速+20%，90秒）")
		"eat":
			speed_buff_timer = maxf(speed_buff_timer, 90.0)
			_spawn_burst_effect(player_pos, PAL_CORAL)
			_show_toast("品尝了香气扑鼻的暖胃热汤，浑身充满干劲（移速+20%，90秒）")
		"map":
			_open_dialog_modal("阿橙的航海探索地图", "地图上用红笔圈出了小岛秘境：\n• 北部高地瀑布下适合垂钓河鲈与夜鳗\n• 南岸木栈桥码头夜晚会出现稀有月光鱼\n• 东侧果园与西侧花田适合挥网捕蝶")
		"display":
			player_knowledge += 1
			_show_toast("仔细观赏了收藏柜里的海岛奇珍，眼界大开（知识 %d）" % player_knowledge)
		"seeds":
			_show_toast("花艺架上整齐摆放着露露培育的鲜花与种子标本，真香呀~")
		"shells":
			player_knowledge += 1
			_show_toast("欣赏了波波从海滩收集的五彩扇贝与海螺（知识 %d）" % player_knowledge)
		"sports":
			speed_buff_timer = maxf(speed_buff_timer, 60.0)
			_show_toast("借用呱呱的运动器材热了热身，步伐更轻快了（移速+20%，60秒）")
		"sit":
			_show_toast("坐在柔软舒适的座椅上歇了口气，窗外海风轻拂~")
		"lamp":
			_show_toast("温暖的台灯散发着柔和的奶油色光芒")
		_:
			_show_toast("仔细打量了这件精致的室内陈设")

func _can_place_indoor_furniture_at(gx: int, gy: int, ftype: String) -> bool:
	if not (current_room_id in ["player", "player_2f"]):
		return false
	if gx <= 0 or gx >= ROOM_W - 1 or gy <= 0 or gy >= ROOM_H - 1:
		return false
	if is_indoor_door_clearance(gx, gy):
		return false
	var is_rug: bool = (ftype == "rug")
	var existing: Dictionary = _indoor_furniture_at(current_room_id, gx, gy, not is_rug)
	if not existing.is_empty():
		return false
	if not is_rug:
		var p_cell: Vector2i = world_to_grid(player_pos)
		if p_cell == Vector2i(gx, gy):
			return false
	return true

func _store_front_indoor_furniture() -> void:
	if not in_interior or current_room_id != "player":
		_show_toast("只有自己的小屋可以收纳或装修家具哦")
		return
	var f_cell: Vector2i = indoor_preview_cell if (indoor_edit_mode and indoor_preview_cell.x >= 0) else get_front_cell()
	var furn_list: Array = indoor_rooms[current_room_id]["furniture"]
	for idx in range(furn_list.size() - 1, -1, -1):
		var f: Dictionary = furn_list[idx]
		if int(f.get("x", -1)) == f_cell.x and int(f.get("y", -1)) == f_cell.y:
			var ftype: String = str(f.get("type", ""))
			var meta: Dictionary = INDOOR_FURNITURE_META.get(ftype, {})
			var item_id: String = str(meta.get("item_id", "chair_item"))
			furn_list.remove_at(idx)
			_add_item(item_id, 1)
			_spawn_burst_effect(Vector2(f_cell) * TILE_SIZE + Vector2(8, 8), PAL_CREAM)
			_show_toast("已将【%s】收纳回背包！" % str(meta.get("name", "家具")))
			_refresh_nearby_interaction()
			queue_redraw()
			return
	_show_toast("请面朝或点选一件室内家具再点击【收纳家具】")

func _on_indoor_use_tool_pressed() -> void:
	if current_room_id != "player":
		_show_toast("在居民家里做客时请爱护主人的家具哦~")
		return
	var item_id: String = hotbar[selected_hotbar_index]
	var f_cell: Vector2i = indoor_preview_cell if (indoor_edit_mode and indoor_preview_cell.x >= 0) else get_front_cell()
	indoor_preview_cell = f_cell

	# 用铁铲或斧头在自己屋里可直接收纳前方家具
	if item_id in ["shovel", "axe"]:
		_store_front_indoor_furniture()
		return

	if item_id == "" or not ITEM_DB.has(item_id):
		_show_toast("请在底部快捷栏或背包中选择一件家具再放置")
		return
	var info: Dictionary = ITEM_DB[item_id]
	var indoor_type: String = str(info.get("indoor_type", ""))
	if indoor_type == "":
		if item_id == "potted_plant":
			indoor_type = "potted_plant"
		elif item_id == "lamp_item":
			indoor_type = "lamp"
		elif item_id == "bench_item":
			indoor_type = "sofa"
	if indoor_type == "":
		_show_toast("【%s】适合在户外使用，室内请选择家具或盆栽布置" % str(info["name"]))
		return
	if int(inventory.get(item_id, 0)) <= 0:
		_show_toast("背包中该家具数量不足")
		return
	if is_indoor_door_clearance(f_cell.x, f_cell.y):
		_show_toast("这里靠近房门出口，家具不能堵门哦！")
		queue_redraw()
		return
	if not _can_place_indoor_furniture_at(f_cell.x, f_cell.y, indoor_type):
		_show_toast("目标位置已有家具或墙壁，请换一个空格放置")
		queue_redraw()
		return

	indoor_rooms[current_room_id]["furniture"].append({
		"x": f_cell.x,
		"y": f_cell.y,
		"type": indoor_type
	})
	_consume_item(item_id, 1)
	_spawn_burst_effect(Vector2(f_cell) * TILE_SIZE + Vector2(8, 8), PAL_PINK)
	_show_toast("已在室内放置【%s】！" % str(info["name"]))
	_refresh_hotbar_ui()
	_refresh_nearby_interaction()
	queue_redraw()

func _handle_indoor_edit_tap(screen_pos: Vector2) -> void:
	var world_pt: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var cell: Vector2i = world_to_grid(world_pt)
	if not is_valid_cell(cell.x, cell.y):
		return
	indoor_preview_cell = cell
	# 如果正在移动某件家具：点击合法空格即放下
	if not indoor_moving_item.is_empty():
		var mtype: String = str(indoor_moving_item.get("type", "chair"))
		if is_indoor_door_clearance(cell.x, cell.y):
			_show_toast("不能把家具放在房门通道上堵门哦！")
			queue_redraw()
			return
		if _can_place_indoor_furniture_at(cell.x, cell.y, mtype):
			indoor_moving_item["x"] = cell.x
			indoor_moving_item["y"] = cell.y
			indoor_rooms[current_room_id]["furniture"].append(indoor_moving_item)
			var nm: String = str(INDOOR_FURNITURE_META.get(mtype, {}).get("name", "家具"))
			indoor_moving_item = {}
			_spawn_burst_effect(Vector2(cell) * TILE_SIZE + Vector2(8, 8), PAL_GRASS)
			_show_toast("已将【%s】移动到新位置！" % nm)
		else:
			_show_toast("该格已有物体或为墙体，请点击绿色预览格放置")
		queue_redraw()
		return

	# 如果点击了已有的家具：拿起它准备移动
	var furn_list: Array = indoor_rooms[current_room_id]["furniture"]
	for idx in range(furn_list.size() - 1, -1, -1):
		var f: Dictionary = furn_list[idx]
		if int(f.get("x", -1)) == cell.x and int(f.get("y", -1)) == cell.y:
			indoor_moving_item = f.duplicate(true)
			furn_list.remove_at(idx)
			var nm2: String = str(INDOOR_FURNITURE_META.get(str(f.get("type", "")), {}).get("name", "家具"))
			_show_toast("已拿起【%s】：点击室内空地即可移动，或点「取消」放回原处" % nm2)
			queue_redraw()
			return

	# 如果点击了空地：尝试放置当前快捷栏选中的家具
	_on_indoor_use_tool_pressed()

# ==============================================================================
# 种植系统（阶段6）：翻土 -> 播种 -> 浇水 -> 成熟 -> 收获
# ==============================================================================

func _crop_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _crop_ready(c: Dictionary) -> bool:
	var cid: String = str(c.get("id", "carrot"))
	var need_days: int = int(CROP_DB.get(cid, {}).get("days", 3))
	return int(c.get("stage", 0)) >= need_days

func _plant_seed_at(cell: Vector2i, seed_id: String) -> bool:
	if not is_valid_cell(cell.x, cell.y):
		return false
	if not ITEM_DB.has(seed_id) or str(ITEM_DB[seed_id].get("type", "")) != "seed":
		return false
	if int(inventory.get(seed_id, 0)) <= 0:
		_show_toast("没有%s了，去种子店买一些吧" % str(ITEM_DB[seed_id]["name"]))
		return false
	if int(ground_grid[cell.x][cell.y]) != GroundType.TILLED_SOIL:
		_show_toast("要先用铁铲把草地翻成泥土地才能播种")
		return false
	if int(object_grid[cell.x][cell.y]) != ObjectType.NONE:
		_show_toast("这块地已经有东西了")
		return false
	if crops.has(_crop_key(cell)):
		_show_toast("这里已经种过作物了")
		return false
	crops[_crop_key(cell)] = {
		"id": str(ITEM_DB[seed_id].get("crop", "carrot")),
		"stage": 0,
		"watered": false,
		"day": _get_logical_day_key()
	}
	_consume_item(seed_id, 1)
	_spawn_burst_effect(Vector2(cell) * TILE_SIZE + Vector2(8, 8), PAL_GRASS)
	return true

func _water_crop_at(cell: Vector2i) -> bool:
	var key: String = _crop_key(cell)
	if not crops.has(key):
		return false
	var c: Dictionary = crops[key]
	if bool(c.get("watered", false)):
		_show_toast("这块地今天已经浇过水了")
		return true
	c["watered"] = true
	crops[key] = c
	_spawn_burst_effect(Vector2(cell) * TILE_SIZE + Vector2(8, 8), PAL_SKY_BLUE)
	return true

func _harvest_crop_at(cell: Vector2i) -> bool:
	var key: String = _crop_key(cell)
	if not crops.has(key):
		return false
	var c: Dictionary = crops[key]
	if not _crop_ready(c):
		var left: int = int(CROP_DB.get(str(c["id"]), {}).get("days", 3)) - int(c["stage"])
		_show_toast("还没成熟，再等 %d 天（记得每天浇水）" % maxi(1, left))
		return false
	var cid: String = str(c["id"])
	crops.erase(key)
	var amount: int = randi_range(1, 2)
	_add_item(cid, amount)
	_add_item(str(cid) + "_seed", 1)
	_spawn_burst_effect(Vector2(cell) * TILE_SIZE + Vector2(8, 8), PAL_GOLD)
	_show_toast("收获了【%s】×%d，还留了 1 颗种子" % [str(CROP_DB.get(cid, {}).get("name", cid)), amount])
	return true

func _farm_action_at_cell(gx: int, gy: int) -> bool:
	var cell := Vector2i(gx, gy)
	match build_sub_farm:
		0:
			return _plant_seed_at(cell, farm_seed_id)
		1:
			if _water_crop_at(cell):
				return true
			return false
		_:
			return _harvest_crop_at(cell)

func _grow_crops_on_new_day() -> void:
	var grown: int = 0
	for key in crops.keys():
		var c: Dictionary = crops[key]
		if bool(c.get("watered", false)):
			c["stage"] = int(c["stage"]) + 1
			c["watered"] = false
			c["day"] = _get_logical_day_key()
			crops[key] = c
			grown += 1
	if grown > 0:
		_show_toast("清晨的阳光里，%d 株作物长大了一点" % grown)

func _draw_crop(p: Vector2, c: Dictionary) -> void:
	var stage: int = int(c.get("stage", 0))
	var cid: String = str(c.get("id", "carrot"))
	var fruit_col: Color = CROP_DB.get(cid, {}).get("color", PAL_CORAL)
	var need_days: int = int(CROP_DB.get(cid, {}).get("days", 3))
	draw_rect(Rect2(p.x + 3, p.y + 12, 10, 2), PAL_EARTH.darkened(0.2), true)
	if stage <= 0:
		draw_rect(Rect2(p.x + 7, p.y + 8, 2, 4), PAL_FOREST, true)
		draw_rect(Rect2(p.x + 6, p.y + 7, 2, 2), PAL_GRASS, true)
	elif stage == 1:
		draw_rect(Rect2(p.x + 7, p.y + 6, 2, 6), PAL_FOREST, true)
		draw_rect(Rect2(p.x + 4, p.y + 6, 3, 3), PAL_GRASS, true)
		draw_rect(Rect2(p.x + 9, p.y + 5, 3, 3), PAL_GRASS, true)
	else:
		draw_rect(Rect2(p.x + 7, p.y + 5, 2, 7), PAL_FOREST, true)
		draw_rect(Rect2(p.x + 4, p.y + 4, 8, 4), PAL_GRASS, true)
		if stage >= need_days:
			draw_rect(Rect2(p.x + 6, p.y + 7, 4, 4), fruit_col, true)
			draw_rect(Rect2(p.x + 7, p.y + 8, 2, 2), PAL_CREAM, true)
	if bool(c.get("watered", false)):
		draw_rect(Rect2(p.x + 11, p.y + 9, 2, 2), PAL_SKY_BLUE, true)

# ==============================================================================
# 岛屿公共设施（阶段3）与关系面板（阶段4）
# ==============================================================================

func _open_action_menu(title_str: String, icon_key: String, entries: Array, body: String = "") -> void:
	if action_menu_modal != null and is_instance_valid(action_menu_modal):
		action_menu_modal.queue_free()
		action_menu_modal = null
	var res: Array = _create_modal_base(title_str, icon_key, Vector2(430, 330))
	var modal: Control = res[0]
	var panel: Panel = res[1]
	var y: float = 46.0
	if body != "":
		var lbl := Label.new()
		lbl.text = body
		lbl.position = Vector2(20, y)
		lbl.size = Vector2(390, 54)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", PAL_OUTLINE)
		panel.add_child(lbl)
		y += 58.0
	for e in entries:
		var b := _make_touch_btn(str(e.get("text", "确定")), Vector2(390, 38), PAL_CREAM_DARK, PAL_OUTLINE)
		b.position = Vector2(20, y)
		var cb: Callable = e.get("cb", Callable())
		b.pressed.connect(func():
			_close_active_modal()
			if cb.is_valid():
				cb.call()
		)
		panel.add_child(b)
		y += 44.0
	action_menu_modal = modal
	_open_modal(modal)

func _open_library() -> void:
	var body := "安静的小岛图书馆。\n你已读 %d 本，居民们也会来这里看书。" % player_knowledge
	var entries: Array = [
		{"text": "读《岛屿地形学》 +1 知识", "cb": func(): _player_read(0)},
		{"text": "读《潮汐与鱼群》 +1 知识", "cb": func(): _player_read(1)},
		{"text": "读《小动物的心事》 +1 知识", "cb": func(): _player_read(2)},
		{"text": "翻翻鱼类图鉴", "cb": func(): _open_fish_codex()},
		{"text": "关闭", "cb": func(): pass}
	]
	_open_action_menu("小岛图书馆", "island_map", entries, body)

func _player_read(book: int) -> void:
	player_knowledge += 1
	if book == 0:
		_show_toast("读完《岛屿地形学》：对地形改造更熟悉了（知识 %d）" % player_knowledge)
	elif book == 1:
		_show_toast("读完《潮汐与鱼群》：更懂鱼群的习性了（知识 %d）" % player_knowledge)
	else:
		_show_toast("读完《小动物的心事》：更懂居民们了（知识 %d）" % player_knowledge)

func _open_canteen() -> void:
	var body := "今日供应：海藻饭团 30 铃钱、暖胃热汤 15 铃钱。\n吃过之后脚步会轻快一阵子。\n当前铃钱：%d" % coins
	var entries: Array = [
		{"text": "海藻饭团 -30 铃钱（移速+20%，90秒）", "cb": func(): _player_eat(30, 90.0)},
		{"text": "暖胃热汤 -15 铃钱（移速+20%，45秒）", "cb": func(): _player_eat(15, 45.0)},
		{"text": "关闭", "cb": func(): pass}
	]
	_open_action_menu("海岛食堂", "shop_ui", entries, body)

func _player_eat(cost: int, buff: float) -> void:
	if coins < cost:
		_show_toast("铃钱不足：需要 %d，现有 %d" % [cost, coins])
		return
	coins -= cost
	speed_buff_timer = maxf(speed_buff_timer, buff)
	_update_time_and_lighting()
	_show_toast("吃饱了！%.0f 秒内走得更快" % buff)

func _open_sports() -> void:
	var entries: Array = [
		{"text": "跑两圈（移速+20%，60秒）", "cb": func(): _player_exercise()},
		{"text": "看看大家的相处", "cb": func(): _open_relations()},
		{"text": "关闭", "cb": func(): pass}
	]
	_open_action_menu("海岛运动场", "use_tool_ui", entries, "平整的草场，居民们常来这里活动。")

func _player_exercise() -> void:
	speed_buff_timer = maxf(speed_buff_timer, 60.0)
	_show_toast("跑了两圈，身体热起来了（移速+20%，60秒）")

func _open_furniture_shop(page: int = 0) -> void:
	var all_ids: Array = [
		"bed_item", "sofa_item", "table_item", "chair_item",
		"bookshelf_item", "wardrobe_item", "storage_item", "rug_item",
		"record_item", "display_item", "potted_plant", "lamp_item",
		"bench_item", "fence_item", "fountain_item"
	]
	var page_size: int = 4
	var total_pages: int = int(ceil(float(all_ids.size()) / float(page_size)))
	var cur_page: int = clampi(page, 0, total_pages - 1)
	var start_i: int = cur_page * page_size
	var end_i: int = mini(start_i + page_size, all_ids.size())
	var entries: Array = []
	for idx in range(start_i, end_i):
		var id: String = str(all_ids[idx])
		if not ITEM_DB.has(id):
			continue
		var info: Dictionary = ITEM_DB[id]
		var price: int = int(info.get("price", 100))
		var iid := str(id)
		var nm := str(info["name"])
		entries.append({"text": "购买【%s】 - %d 铃钱" % [nm, price], "cb": func(): _buy_item(iid, 1)})
	var next_p: int = (cur_page + 1) % total_pages
	entries.append({"text": "下一页家具 (%d/%d)" % [cur_page + 1, total_pages], "cb": func(): _open_furniture_shop(next_p)})
	entries.append({"text": "关闭", "cb": func(): pass})
	_open_action_menu("海岛家具店（室内外通用家具）", "shop_ui", entries, "当前铃钱：%d · 购买后可在小屋内或庭院自由摆放" % coins)

func _open_seed_shop() -> void:
	var entries: Array = []
	for id in ["carrot_seed", "tomato_seed", "pumpkin_seed", "strawberry_seed"]:
		if not ITEM_DB.has(id):
			continue
		var iid := str(id)
		var nm := str(ITEM_DB[id]["name"])
		entries.append({"text": nm, "cb": func(): _open_seed_quantity(iid)})
	entries.append({"text": "关闭", "cb": func(): pass})
	_open_action_menu("海岛种子店", "flower", entries, "当前铃钱：%d\n买到的种子可以播在翻好的土地上" % coins)

func _open_seed_quantity(id: String) -> void:
	var info: Dictionary = ITEM_DB[id]
	var price: int = int(info.get("price", 30))
	var entries: Array = [
		{"text": "买 1 份 - %d 铃钱" % price, "cb": func(): _buy_item(id, 1)},
		{"text": "买 5 份 - %d 铃钱（批量）" % (price * 5), "cb": func(): _buy_item(id, 5)},
		{"text": "返回", "cb": func(): _open_seed_shop()}
	]
	_open_action_menu(str(info["name"]), "flower", entries, "每份 3 颗种子，买得越多越省事。")

func _buy_item(id: String, qty: int) -> void:
	if not ITEM_DB.has(id):
		return
	var info: Dictionary = ITEM_DB[id]
	var price: int = int(info.get("price", 100))
	var total: int = price * qty
	if coins < total:
		_show_toast("铃钱不足：需要 %d，现有 %d" % [total, coins])
		return
	coins -= total
	var give: int = qty
	if str(info.get("type", "")) == "seed":
		give = qty * 3
	_add_item(id, give)
	_update_time_and_lighting()
	_show_toast("购买成功：%s ×%d，花费 %d 铃钱" % [str(info["name"]), give, total])

func _affinity_tier(v: int) -> String:
	if v >= 80:
		return "挚友"
	elif v >= 55:
		return "好朋友"
	elif v >= 30:
		return "熟人"
	elif v >= 10:
		return "点头之交"
	return "陌生"

func _open_relations() -> void:
	var lines: Array = []
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		lines.append("%s（%s）· 与玩家：%s ♥%d" % [str(a["name"]), str(a["trait"]), _affinity_tier(int(a["affinity"])), int(a["affinity"])])
		var best_id := ""
		var best_v := -999
		var worst_id := ""
		var worst_v := 999
		for k in a["relations"].keys():
			var v: int = int(a["relations"][k])
			if v > best_v:
				best_v = v
				best_id = str(k)
			if v < worst_v:
				worst_v = v
				worst_id = str(k)
		if best_id != "":
			lines.append("   最亲近 %s %+d ／ 最疏远 %s %+d" % [best_id, best_v, worst_id, worst_v])
		lines.append("")
	_open_dialog_modal("小岛关系", "\n".join(lines))

# ==============================================================================
# 统一触屏输入处理
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.TITLE_SCREEN or active_modal != null:
		return

	var vp_size: Vector2 = get_viewport_rect().size

	if game_state == GameState.EXPLORE_MODE:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				# 摇杆热区：以摇杆底座为中心的圆形区域，其余地面点击一律走寻路
				if joy_touch_index == -1 and touch.position.distance_to(joy_center) <= joy_radius * 2.0:
					joy_touch_index = touch.index
					_cancel_auto_path()
					_update_joystick(touch.position)
				elif joy_touch_index == -1:
					if in_interior and touch.position.y < 86.0:
						return
					if in_interior and indoor_edit_mode and touch.position.x < vp_size.x - 106.0 and touch.position.y < vp_size.y - 70.0:
						_handle_indoor_edit_tap(touch.position)
					else:
						_handle_ground_click(touch.position)
			else:
				if touch.index == joy_touch_index:
					joy_touch_index = -1
					joy_knob_pos = joy_center
					joy_vector = Vector2.ZERO
					if hud_overlay_draw != null:
						hud_overlay_draw.queue_redraw()
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == joy_touch_index:
				_update_joystick(drag.position)
		return

	if game_state == GameState.BUILD_MODE:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				# 避开顶部栏、底部岛建工具栏与右侧控制区
				if touch.position.y < 46.0 or touch.position.y > vp_size.y - 82.0 or touch.position.x > vp_size.x - 106.0:
					return
				if build_touch_index == -1:
					build_touch_index = touch.index
					var world_pt: Vector2 = get_canvas_transform().affine_inverse() * touch.position
					var cell: Vector2i = world_to_grid(world_pt)

					if is_camera_pan_mode:
						build_drag_start_cell = cell
					elif current_build_tool == BuildTool.MOVE_OBJECT:
						build_drag_curr_cell = cell
						_handle_move_object_tool(cell)
					elif is_box_select_mode:
						if has_pending_box and pending_box_rect.has_point(cell):
							_execute_pending_box_selection()
							build_touch_index = -1
							return
						build_drag_start_cell = cell
						build_drag_curr_cell = cell
						_update_pending_box_from_drag()
					else:
						current_stroke_changes.clear()
						build_drag_curr_cell = cell
						_apply_brush_at_cell(cell, current_build_tool, current_stroke_changes)
			else:
				if touch.index == build_touch_index:
					build_touch_index = -1
					if not is_camera_pan_mode and not is_box_select_mode and current_build_tool != BuildTool.MOVE_OBJECT:
						if not current_stroke_changes.is_empty():
							_commit_stroke_to_undo(current_stroke_changes)
							current_stroke_changes.clear()

		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == build_touch_index:
				if is_camera_pan_mode:
					camera.position -= drag.relative / camera.zoom.x
					var map_px := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
					camera.position.x = clampf(camera.position.x, 48.0, map_px.x - 48.0)
					camera.position.y = clampf(camera.position.y, 48.0, map_px.y - 48.0)
				elif current_build_tool != BuildTool.MOVE_OBJECT:
					var world_pt: Vector2 = get_canvas_transform().affine_inverse() * drag.position
					var cell: Vector2i = world_to_grid(world_pt)
					if cell != build_drag_curr_cell:
						build_drag_curr_cell = cell
						if is_box_select_mode:
							_update_pending_box_from_drag()
						else:
							_apply_brush_at_cell(cell, current_build_tool, current_stroke_changes)

func _update_pending_box_from_drag() -> void:
	if not is_valid_cell(build_drag_start_cell.x, build_drag_start_cell.y):
		return
	var x1: int = clampi(mini(build_drag_start_cell.x, build_drag_curr_cell.x), 2, GRID_WIDTH - 3)
	var y1: int = clampi(mini(build_drag_start_cell.y, build_drag_curr_cell.y), 2, GRID_HEIGHT - 3)
	var x2: int = clampi(maxi(build_drag_start_cell.x, build_drag_curr_cell.x), 2, GRID_WIDTH - 3)
	var y2: int = clampi(maxi(build_drag_start_cell.y, build_drag_curr_cell.y), 2, GRID_HEIGHT - 3)

	if x2 - x1 + 1 > MAX_BOX_SPAN: x2 = x1 + MAX_BOX_SPAN - 1
	if y2 - y1 + 1 > MAX_BOX_SPAN: y2 = y1 + MAX_BOX_SPAN - 1

	pending_box_rect = Rect2i(x1, y1, x2 - x1 + 1, y2 - y1 + 1)
	has_pending_box = true
	if build_confirm_box_btn != null:
		build_confirm_box_btn.visible = true

# ==============================================================================
# 点击地面自动寻路（A*，64×64 网格，八方向，禁止贴角穿墙，支持坡道高度）
# ==============================================================================
const PATH_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

func _cancel_auto_path() -> void:
	if auto_path.is_empty() and path_target_cell == Vector2i(-1, -1):
		return
	auto_path.clear()
	path_target_cell = Vector2i(-1, -1)
	path_stuck_time = 0.0
	queue_redraw()

func _advance_auto_path(delta: float) -> Vector2:
	# 卡住检测：连续 0.8 秒没有位移就放弃本次寻路，避免原地抖动
	if player_pos.distance_to(path_last_pos) < 0.35:
		path_stuck_time += delta
		if path_stuck_time > 0.8:
			_cancel_auto_path()
			_show_toast("前面被挡住了，换个位置试试")
			return Vector2.ZERO
	else:
		path_stuck_time = 0.0
		path_last_pos = player_pos

	while not auto_path.is_empty():
		var target := Vector2(auto_path[0]) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		var to_target: Vector2 = target - player_pos
		if to_target.length() <= 2.5:
			auto_path.pop_front()
			continue
		return to_target.normalized()

	if path_target_cell != Vector2i(-1, -1):
		path_target_cell = Vector2i(-1, -1)
		queue_redraw()
	return Vector2.ZERO

func _handle_ground_click(screen_pos: Vector2) -> void:
	var world_pt: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var clicked: Vector2i = world_to_grid(world_pt)
	var start: Vector2i = world_to_grid(player_pos)
	var goal: Vector2i = clicked

	if not is_cell_walkable(goal.x, goal.y):
		goal = _nearest_walkable_cell(clicked, 5)
		if goal.x < 0:
			_show_toast("那里过不去，换一块地面试试")
			return

	if goal == start:
		_cancel_auto_path()
		return

	var path: Array[Vector2i] = find_path(start, goal)
	if path.is_empty():
		_show_toast("这里走不过去哦～")
		return

	auto_path = path
	path_target_cell = goal
	path_stuck_time = 0.0
	path_last_pos = player_pos
	queue_redraw()

func _nearest_walkable_cell(from_cell: Vector2i, max_radius: int, allow_high: bool = true) -> Vector2i:
	for r in range(0, max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nx: int = from_cell.x + dx
				var ny: int = from_cell.y + dy
				if is_cell_walkable(nx, ny, allow_high):
					return Vector2i(nx, ny)
	return Vector2i(-1, -1)

func _path_heap_push(heap: Array, f: float, idx: int) -> void:
	heap.append([f, idx])
	var i: int = heap.size() - 1
	while i > 0:
		var parent: int = (i - 1) / 2
		if float(heap[parent][0]) <= float(heap[i][0]):
			break
		var tmp: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent

func _path_heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		var i: int = 0
		var n: int = heap.size()
		while true:
			var l: int = i * 2 + 1
			var r: int = l + 1
			var m: int = i
			if l < n and float(heap[l][0]) < float(heap[m][0]):
				m = l
			if r < n and float(heap[r][0]) < float(heap[m][0]):
				m = r
			if m == i:
				break
			var tmp: Array = heap[m]
			heap[m] = heap[i]
			heap[i] = tmp
			i = m
	return top

func _path_heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return 1.4142 * float(mini(dx, dy)) + float(maxi(dx, dy) - mini(dx, dy))

func find_path(start_cell: Vector2i, goal_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_valid_cell(start_cell.x, start_cell.y):
		return result
	if not is_cell_walkable(goal_cell.x, goal_cell.y):
		return result
	if start_cell == goal_cell:
		return result

	var gw: int = ROOM_W if in_interior else GRID_WIDTH
	var gh: int = ROOM_H if in_interior else GRID_HEIGHT
	var total: int = gw * gh
	var g_cost := PackedFloat32Array()
	g_cost.resize(total)
	g_cost.fill(INF)
	var came := PackedInt32Array()
	came.resize(total)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(total)

	var start_idx: int = start_cell.y * gw + start_cell.x
	var goal_idx: int = goal_cell.y * gw + goal_cell.x
	g_cost[start_idx] = 0.0

	var heap: Array = []
	_path_heap_push(heap, _path_heuristic(start_cell, goal_cell), start_idx)
	var found: bool = false

	while not heap.is_empty():
		var cur: Array = _path_heap_pop(heap)
		var ci: int = int(cur[1])
		if closed[ci] == 1:
			continue
		closed[ci] = 1
		if ci == goal_idx:
			found = true
			break

		var cx: int = ci % gw
		var cy: int = ci / gw
		for d in PATH_DIRS:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if not is_valid_cell(nx, ny):
				continue
			var ni: int = ny * gw + nx
			if closed[ni] == 1:
				continue
			if not can_step_between(Vector2i(cx, cy), Vector2i(nx, ny)):
				continue
			var diagonal: bool = d.x != 0 and d.y != 0
			if diagonal:
				# 禁止从两堵墙的夹角对角穿过去
				if not is_cell_walkable(cx + d.x, cy) or not is_cell_walkable(cx, cy + d.y):
					continue
			var step_cost: float = 1.4142 if diagonal else 1.0
			var ng: float = g_cost[ci] + step_cost
			if ng < g_cost[ni] - 0.0001:
				g_cost[ni] = ng
				came[ni] = ci
				_path_heap_push(heap, ng + _path_heuristic(Vector2i(nx, ny), goal_cell), ni)

	if not found:
		return result

	var rev: Array[Vector2i] = []
	var walk: int = goal_idx
	while walk != -1 and walk != start_idx:
		rev.append(Vector2i(walk % gw, walk / gw))
		walk = came[walk]
	rev.reverse()
	for c in rev:
		result.append(c)
	return result

func _update_joystick(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joy_center
	if offset.length() > joy_radius:
		offset = offset.normalized() * joy_radius
	joy_knob_pos = joy_center + offset
	# 死区 + 八方向吸附：斜向和直向速度一致，也不会出现手指微抖导致角色乱走
	if offset.length() < joy_radius * 0.28:
		joy_vector = Vector2.ZERO
	else:
		var ang: float = atan2(offset.y, offset.x)
		var snapped: float = round(ang / (PI / 4.0)) * (PI / 4.0)
		joy_vector = Vector2(cos(snapped), sin(snapped))
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

# ==============================================================================
# 《小岛日记》多层 Y-Sort 绘本渲染引擎（彻底消除边缘灰块、支持树冠遮挡与地形自动衔接）
# ==============================================================================

# 只绘制摄像机可视范围（含 2 格安全边），避免大地图每帧遍历全部格子
func _visible_world_rect() -> Rect2:
	var inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * get_viewport_rect().size
	var top_left: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var bottom_right: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(top_left, bottom_right - top_left)

func _visible_cell_rect(margin: int = 2) -> Rect2i:
	var wr: Rect2 = _visible_world_rect()
	var x0: int = clampi(int(floor(wr.position.x / TILE_SIZE)) - margin, 0, GRID_WIDTH)
	var y0: int = clampi(int(floor(wr.position.y / TILE_SIZE)) - margin, 0, GRID_HEIGHT)
	var x1: int = clampi(int(ceil(wr.end.x / TILE_SIZE)) + margin, 0, GRID_WIDTH)
	var y1: int = clampi(int(ceil(wr.end.y / TILE_SIZE)) + margin, 0, GRID_HEIGHT)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))

func _draw() -> void:
	if in_interior:
		_draw_indoor_room()
		return
	var vis: Rect2i = _visible_cell_rect(2)
	var view_world: Rect2 = _visible_world_rect()

	# 0. 海洋背景：只铺满当前可视区域，边缘随镜头自然延伸
	draw_rect(view_world.grow(32.0), PAL_OCEAN_BLUE, true)
	var usea_x0: int = int(floor(view_world.position.x / TILE_SIZE)) - 3
	var usea_y0: int = int(floor(view_world.position.y / TILE_SIZE)) - 3
	var usea_x1: int = int(ceil(view_world.end.x / TILE_SIZE)) + 3
	var usea_y1: int = int(ceil(view_world.end.y / TILE_SIZE)) + 3
	for wx in range(usea_x0, usea_x1, 3):
		for wy in range(usea_y0, usea_y1, 3):
			if wx >= 2 and wx < GRID_WIDTH - 2 and wy >= 2 and wy < GRID_HEIGHT - 2:
				continue
			var w_shift: float = sin(env_anim_time * 2.0 + float(wx + wy)) * 2.5
			draw_rect(Rect2(wx * TILE_SIZE + 3 + w_shift, wy * TILE_SIZE + 6, 7, 2), Color(1.0, 1.0, 1.0, 0.28), true)

	# 1. 绘制岛屿网格地形、岸线过渡、河岸、高地瀑布与道路连接（仅可视区域）
	for x in range(vis.position.x, vis.position.x + vis.size.x):
		for y in range(vis.position.y, vis.position.y + vis.size.y):
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var g_type: int = ground_grid[x][y]
			var elev: int = elevation_grid[x][y]
			var is_alt: bool = ((x + y) % 2 == 0)

			draw_rect(rect, _get_ground_color(g_type, elev, is_alt), true)

			# (a) 草地自然纹理变化：三叶草、嫩芽与微小地面高光
			if g_type == GroundType.GRASS:
				var h_seed: int = (x * 19 + y * 31) % 17
				if h_seed == 0:
					draw_rect(Rect2(rect.position.x + 3, rect.position.y + 4, 2, 2), PAL_FOREST.lightened(0.22), true)
					draw_rect(Rect2(rect.position.x + 5, rect.position.y + 3, 2, 3), PAL_FOREST.lightened(0.22), true)
				elif h_seed == 1:
					draw_rect(Rect2(rect.position.x + 9, rect.position.y + 10, 3, 2), PAL_HIGH_GRASS, true)
				elif h_seed == 2:
					draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, 2, 2), PAL_CREAM, true)

			# (b) 草地与沙滩的四向自然圆角齿边过渡 + 湿沙海岸线
			if g_type == GroundType.SAND:
				if y > 0 and ground_grid[x][y - 1] == GroundType.GRASS:
					draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, 3), PAL_GRASS, true)
					draw_rect(Rect2(rect.position.x + 2, rect.position.y + 3, 4, 1), PAL_GRASS_ALT, true)
					draw_rect(Rect2(rect.position.x + 10, rect.position.y + 3, 4, 1), PAL_GRASS_ALT, true)
				if y + 1 < GRID_HEIGHT and ground_grid[x][y + 1] == GroundType.GRASS:
					draw_rect(Rect2(rect.position.x, rect.position.y + 13, TILE_SIZE, 3), PAL_GRASS, true)
				if x > 0 and ground_grid[x - 1][y] == GroundType.GRASS:
					draw_rect(Rect2(rect.position.x, rect.position.y, 3, TILE_SIZE), PAL_GRASS, true)
				if x + 1 < GRID_WIDTH and ground_grid[x + 1][y] == GroundType.GRASS:
					draw_rect(Rect2(rect.position.x + 13, rect.position.y, 3, TILE_SIZE), PAL_GRASS, true)
				# 靠近浅水的湿沙带
				if (y + 1 < GRID_HEIGHT and ground_grid[x][y + 1] == GroundType.SHALLOW_WATER) or (y > 0 and ground_grid[x][y - 1] == GroundType.SHALLOW_WATER):
					draw_rect(Rect2(rect.position.x, rect.position.y + 11, TILE_SIZE, 5), PAL_WET_SAND, true)

			# (c) 浅水与河流的泥土岸壁、白色浪花与高地瀑布动态水流
			if g_type in [GroundType.SHALLOW_WATER, GroundType.RIVER]:
				if y > 0 and ground_grid[x][y - 1] not in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
					draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, 2), PAL_EARTH, true)
					draw_rect(Rect2(rect.position.x, rect.position.y + 2, TILE_SIZE, 1), Color(1.0, 0.98, 0.92, 0.72), true)
				if x > 0 and ground_grid[x - 1][y] not in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
					draw_rect(Rect2(rect.position.x, rect.position.y, 2, TILE_SIZE), PAL_EARTH, true)
				if x + 1 < GRID_WIDTH and ground_grid[x + 1][y] not in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
					draw_rect(Rect2(rect.position.x + 14, rect.position.y, 2, TILE_SIZE), PAL_EARTH, true)

				var wave_shift: float = sin(env_anim_time * 2.6 + float(x + y)) * 2.0
				if (x + y) % 2 == 0:
					draw_rect(Rect2(rect.position.x + 4 + wave_shift, rect.position.y + 7, 6, 2), Color(1.0, 1.0, 1.0, 0.58), true)
				# 北部高地交界处绘制飞流直下的白色瀑布水花 (y == 12)
				if g_type == GroundType.RIVER and y >= 11 + MAP_CORE_OY and y <= 13 + MAP_CORE_OY:
					var wf_off: float = fmod(env_anim_time * 18.0, 6.0)
					draw_rect(Rect2(rect.position.x + 2, rect.position.y, TILE_SIZE - 4, TILE_SIZE), Color(0.85, 0.96, 1.0, 0.85), true)
					draw_rect(Rect2(rect.position.x + 4, rect.position.y + wf_off, 8, 3), Color.WHITE, true)

			# (d) 二层高地立体悬崖岩壁与顶缘高光
			if elev == 2:
				if y + 1 < GRID_HEIGHT and elevation_grid[x][y + 1] < 2:
					draw_rect(Rect2(rect.position.x, rect.position.y + 10, TILE_SIZE, 6), PAL_EARTH, true)
					draw_rect(Rect2(rect.position.x, rect.position.y + 14, TILE_SIZE, 2), PAL_WOOD, true)
					draw_rect(Rect2(rect.position.x, rect.position.y + 9, TILE_SIZE, 1), PAL_CREAM, true)
					draw_rect(Rect2(rect.position.x + 4, rect.position.y + 11, 2, 3), PAL_WOOD, true)
					draw_rect(Rect2(rect.position.x + 11, rect.position.y + 12, 2, 2), PAL_WOOD, true)
				if x > 0 and elevation_grid[x - 1][y] < 2:
					draw_rect(Rect2(rect.position.x, rect.position.y, 2, TILE_SIZE), PAL_WOOD, true)
				if x + 1 < GRID_WIDTH and elevation_grid[x + 1][y] < 2:
					draw_rect(Rect2(rect.position.x + 14, rect.position.y, 2, TILE_SIZE), PAL_WOOD, true)

			# (e) 石板路、木板路与木桥精致拼接
			if g_type == GroundType.BRIDGE:
				draw_rect(Rect2(rect.position.x, rect.position.y + 1, TILE_SIZE, 2), PAL_OUTLINE, true)
				draw_rect(Rect2(rect.position.x, rect.position.y + 13, TILE_SIZE, 2), PAL_OUTLINE, true)
				for bx in [4, 8, 12]:
					draw_rect(Rect2(rect.position.x + bx, rect.position.y + 3, 1, 10), PAL_WOOD.darkened(0.18), true)
			elif g_type == GroundType.STONE_PATH:
				draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, 5, 5), Color("#E3DDD3"), true)
				draw_rect(Rect2(rect.position.x + 8, rect.position.y + 2, 6, 4), Color("#D6CFC2"), true)
				draw_rect(Rect2(rect.position.x + 2, rect.position.y + 8, 6, 5), Color("#D6CFC2"), true)
				draw_rect(Rect2(rect.position.x + 9, rect.position.y + 8, 5, 6), Color("#E3DDD3"), true)
			elif g_type == GroundType.WOOD_PATH:
				draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, TILE_SIZE - 2, TILE_SIZE - 2), PAL_EARTH, true)
				draw_rect(Rect2(rect.position.x + 1, rect.position.y + 7, TILE_SIZE - 2, 1), PAL_WOOD, true)
				draw_rect(Rect2(rect.position.x + 1, rect.position.y + 12, TILE_SIZE - 2, 1), PAL_WOOD, true)

			if game_state == GameState.BUILD_MODE and setting_show_grid_in_build and x >= 3 and x < GRID_WIDTH - 3 and y >= 3 and y < GRID_HEIGHT - 3:
				draw_rect(rect, Color(1, 1, 1, 0.14), false, 1.0)

	# 2. 漫步模式下高亮显示玩家面朝交互格
	if game_state == GameState.EXPLORE_MODE:
		var fc: Vector2i = get_front_cell()
		if is_valid_cell(fc.x, fc.y):
			draw_rect(Rect2(fc.x * TILE_SIZE + 1, fc.y * TILE_SIZE + 1, TILE_SIZE - 2, TILE_SIZE - 2), Color(1.0, 0.95, 0.80, 0.58), false, 1.2)

	# 3. 严格按 Y 轴深度排序（Y-Sorting）：逐行绘制地面物件、树干、建筑、小动物与玩家角色
	var p_row: int = clampi(int(floor(player_pos.y / TILE_SIZE)), 0, GRID_HEIGHT - 1)
	for y in range(vis.position.y, vis.position.y + vis.size.y):
		for x in range(vis.position.x, vis.position.x + vis.size.x):
			var o_type: int = object_grid[x][y]
			if o_type != ObjectType.NONE:
				_draw_storybook_object_base(Vector2(x * TILE_SIZE, y * TILE_SIZE), o_type)
			var crop_key: String = "%d,%d" % [x, y]
			if crops.has(crop_key):
				_draw_crop(Vector2(x * TILE_SIZE, y * TILE_SIZE), crops[crop_key])

		for a in animals:
			var ay_row: int = clampi(int(floor(float(a["pos"].y) / TILE_SIZE)), 0, GRID_HEIGHT - 1)
			if ay_row == y:
				_draw_storybook_animal(a)

		if p_row == y:
			_draw_storybook_player()

	# 4. 顶层树冠与屋顶遮挡层（Tree Canopy Overlay Layer）：让角色走在树后时呈现真实空间层次
	for y in range(vis.position.y, vis.position.y + vis.size.y):
		for x in range(vis.position.x, vis.position.x + vis.size.x):
			var o_type: int = object_grid[x][y]
			if o_type in [ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM]:
				_draw_tree_canopy_layer(Vector2(x * TILE_SIZE, y * TILE_SIZE), o_type)

	# 4.4 钓鱼浮漂
	if fishing_state != "idle" and is_valid_cell(fishing_cell.x, fishing_cell.y):
		var bob_pt := Vector2(fishing_cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		var bob_off: float = sin(env_anim_time * 4.0) * 1.5
		draw_circle(bob_pt + Vector2(0, bob_off), 2.6, Color.WHITE)
		draw_circle(bob_pt + Vector2(0, bob_off), 1.2, PAL_CORAL)
		if fishing_state == "bite":
			draw_circle(bob_pt + Vector2(0, -10), 3.2, PAL_GOLD)

	# 4.5 点击寻路的路径预览与目标点脉冲
	if game_state == GameState.EXPLORE_MODE and path_target_cell != Vector2i(-1, -1):
		var pulse: float = 0.5 + 0.5 * sin(env_anim_time * 4.0)
		for i in range(auto_path.size()):
			var dot := Vector2(auto_path[i]) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
			if i % 2 == 0:
				draw_circle(dot, 1.2, Color(1.0, 1.0, 1.0, 0.28))
		var target_px := Vector2(path_target_cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		draw_arc(target_px, 5.5 + pulse * 3.0, 0.0, TAU, 20, Color(1.0, 0.98, 0.86, 0.85), 1.6)
		draw_circle(target_px, 1.8, Color(1.0, 0.98, 0.86, 0.9))

	# 5. 绘制飘落花瓣/树叶、夜晚萤火虫与操作爆发粒子
	_draw_environment_particles()

	# 6. 岛建模式下绘制红绿合法性预览框（含 1x1 / 2x2 / 3x3 画笔与移动工具预览）
	if game_state == GameState.BUILD_MODE:
		if has_pending_box:
			for gx in range(pending_box_rect.position.x, pending_box_rect.end.x):
				for gy in range(pending_box_rect.position.y, pending_box_rect.end.y):
					var cell_rect := Rect2(gx * TILE_SIZE, gy * TILE_SIZE, TILE_SIZE, TILE_SIZE)
					var ok: bool = is_cell_editable_for_tool(gx, gy, current_build_tool)
					draw_rect(cell_rect, Color(0.25, 0.92, 0.40, 0.38) if ok else Color(0.95, 0.30, 0.30, 0.45), true)
			var box_px := Rect2(pending_box_rect.position * TILE_SIZE, pending_box_rect.size * TILE_SIZE)
			draw_rect(box_px, PAL_CREAM, false, 2.0)
		elif is_valid_cell(build_drag_curr_cell.x, build_drag_curr_cell.y):
			var span: int = 1 if current_build_tool == BuildTool.MOVE_OBJECT else build_brush_size
			var pv_off: int = -int((span - 1) / 2)
			for dx in range(span):
				for dy in range(span):
					var tx: int = build_drag_curr_cell.x + pv_off + dx
					var ty: int = build_drag_curr_cell.y + pv_off + dy
					if is_valid_cell(tx, ty):
						var c_rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)
						var ok: bool = is_cell_editable_for_tool(tx, ty, current_build_tool)
						draw_rect(c_rect, Color(0.25, 0.92, 0.40, 0.42) if ok else Color(0.95, 0.30, 0.30, 0.45), true)
						draw_rect(c_rect, PAL_CREAM, false, 1.2)

func _get_ground_color(g_type: int, elev: int, is_alt: bool) -> Color:
	if elev == 2 and g_type == GroundType.GRASS:
		return PAL_HIGH_GRASS if is_alt else PAL_GRASS
	match g_type:
		GroundType.DEEP_WATER: return PAL_OCEAN_BLUE if is_alt else PAL_DEEP_OCEAN
		GroundType.SHALLOW_WATER: return PAL_SKY_BLUE if is_alt else PAL_SKY_BLUE.darkened(0.04)
		GroundType.SAND: return PAL_SAND if is_alt else PAL_SAND_ALT
		GroundType.GRASS: return PAL_GRASS if is_alt else PAL_GRASS_ALT
		GroundType.RIVER: return PAL_SKY_BLUE.darkened(0.06) if is_alt else PAL_SKY_BLUE
		GroundType.BRIDGE: return PAL_EARTH if is_alt else PAL_EARTH.darkened(0.06)
		GroundType.STONE_PATH: return Color("#CFC8B8") if is_alt else Color("#C5BEB0")
		GroundType.WOOD_PATH: return PAL_WOOD if is_alt else PAL_WOOD.lightened(0.06)
		GroundType.TILLED_SOIL: return PAL_WOOD.darkened(0.12) if is_alt else PAL_WOOD.darkened(0.18)
	return PAL_CREAM

func _draw_storybook_object_base(p: Vector2, o_type: int) -> void:
	match o_type:
		ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM:
			# 底层仅画树影与树干（树冠在顶层绘制以实现角色穿行遮挡层次）
			draw_rect(Rect2(p.x + 1, p.y + 11, 14, 4), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x + 5, p.y + 6, 6, 9), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 6, p.y + 6, 4, 8), PAL_WOOD, true)
		ObjectType.FLOWER_PINK, ObjectType.FLOWER_WATERED:
			var sway: float = sin(env_anim_time * 3.0 + p.x) * 0.6
			draw_rect(Rect2(p.x + 3, p.y + 9, 10, 5), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 2 + sway, p.y + 5, 5, 5), PAL_PINK, true)
			draw_rect(Rect2(p.x + 8 + sway, p.y + 6, 5, 5), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 4 + sway, p.y + 7, 2, 2), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 10 + sway, p.y + 8, 2, 2), PAL_CREAM, true)
			if o_type == ObjectType.FLOWER_WATERED:
				draw_rect(Rect2(p.x + 7, p.y + 2, 2, 2), PAL_SKY_BLUE.lightened(0.3), true)
		ObjectType.FLOWER_YELLOW:
			var sway2: float = cos(env_anim_time * 2.8 + p.y) * 0.6
			draw_rect(Rect2(p.x + 3, p.y + 9, 10, 5), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 3 + sway2, p.y + 5, 5, 5), PAL_GOLD, true)
			draw_rect(Rect2(p.x + 9 + sway2, p.y + 6, 4, 4), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 5 + sway2, p.y + 7, 2, 2), PAL_CORAL, true)
		ObjectType.WEED:
			draw_rect(Rect2(p.x + 4, p.y + 9, 2, 4), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 7, p.y + 7, 2, 6), PAL_GRASS.darkened(0.15), true)
			draw_rect(Rect2(p.x + 10, p.y + 9, 2, 4), PAL_FOREST, true)
		ObjectType.SHELL:
			draw_rect(Rect2(p.x + 4, p.y + 6, 8, 6), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 5, p.y + 7, 6, 4), PAL_PINK, true)
			draw_rect(Rect2(p.x + 6, p.y + 7, 4, 2), PAL_CREAM, true)
		ObjectType.ROCK:
			draw_rect(Rect2(p.x + 2, p.y + 5, 12, 9), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 3, p.y + 6, 10, 7), Color("#9BA2A8"), true)
			draw_rect(Rect2(p.x + 4, p.y + 6, 6, 3), Color("#BCC2C7"), true)
		ObjectType.STUMP:
			draw_rect(Rect2(p.x + 3, p.y + 7, 10, 7), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 4, p.y + 9, 8, 4), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 4, p.y + 7, 8, 3), PAL_SAND, true)
		ObjectType.MUSHROOM:
			draw_rect(Rect2(p.x + 6, p.y + 9, 4, 5), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 3, p.y + 5, 10, 5), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 5, p.y + 6, 2, 2), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 9, p.y + 7, 2, 2), PAL_CREAM, true)
		ObjectType.BUSH:
			draw_rect(Rect2(p.x + 1, p.y + 3, 14, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 4, 12, 9), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 3, p.y + 4, 10, 6), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 5, p.y + 6, 2, 2), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 10, p.y + 7, 2, 2), PAL_PINK, true)
		ObjectType.FLOWER_PLANTER:
			draw_rect(Rect2(p.x + 1, p.y + 5, 14, 10), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 8, 12, 6), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 3, p.y + 4, 10, 5), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 4, p.y + 3, 3, 3), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 9, p.y + 3, 3, 3), PAL_PINK, true)
		ObjectType.BENCH:
			draw_rect(Rect2(p.x + 1, p.y + 4, 14, 10), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 5, 12, 4), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 2, p.y + 9, 12, 3), PAL_WOOD, true)
		ObjectType.LAMP:
			var h: int = int(Time.get_datetime_dict_from_system().get("hour", 12))
			if h >= 17 or h < 7:
				draw_circle(Vector2(p.x + 8, p.y + 4), 15.0, Color(1.0, 0.90, 0.55, 0.30))
			draw_rect(Rect2(p.x + 6, p.y + 4, 4, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 7, p.y + 5, 2, 9), Color("#4A525A"), true)
			draw_rect(Rect2(p.x + 4, p.y, 8, 6), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 5, p.y + 1, 6, 4), PAL_GOLD, true)
		ObjectType.FENCE:
			draw_rect(Rect2(p.x + 1, p.y + 3, 4, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 11, p.y + 3, 4, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 4, 2, 9), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 12, p.y + 4, 2, 9), PAL_EARTH, true)
			draw_rect(Rect2(p.x, p.y + 6, 16, 3), PAL_WOOD, true)
		ObjectType.FOUNTAIN:
			draw_rect(Rect2(p.x - 5, p.y - 3, 26, 22), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 4, p.y - 2, 24, 20), Color("#E6DFD3"), true)
			draw_rect(Rect2(p.x - 2, p.y, 20, 16), PAL_SKY_BLUE, true)
			var splash: float = abs(sin(env_anim_time * 4.2)) * 2.5
			draw_rect(Rect2(p.x + 5, p.y + 2 - splash, 6, 9), Color(1.0, 1.0, 1.0, 0.88), true)
		ObjectType.MAILBOX:
			draw_rect(Rect2(p.x + 6, p.y + 7, 4, 8), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 3, p.y + 1, 10, 7), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 4, p.y + 2, 8, 5), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 5, p.y + 3, 6, 2), PAL_CREAM, true)
		ObjectType.SIGNBOARD:
			draw_rect(Rect2(p.x + 6, p.y + 8, 4, 7), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 2, 12, 8), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 3, p.y + 3, 10, 6), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 5, p.y + 5, 6, 1), PAL_CREAM, true)
		ObjectType.HOUSE:
			draw_rect(Rect2(p.x - 8, p.y + 12, 32, 5), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 7, p.y - 14, 30, 30), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 13, 28, 10), PAL_CORAL, true)
			draw_rect(Rect2(p.x - 4, p.y - 11, 24, 3), PAL_PINK, true)
			draw_rect(Rect2(p.x + 14, p.y - 17, 5, 6), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 4, p.y + 4, 7, 11), PAL_WOOD, true)
			draw_rect(Rect2(p.x - 2, p.y + 3, 4, 5), PAL_SKY_BLUE, true)
			draw_rect(Rect2(p.x + 14, p.y + 3, 4, 5), PAL_SKY_BLUE, true)
		ObjectType.VILLAGER_HOUSE:
			draw_rect(Rect2(p.x - 7, p.y + 12, 30, 4), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 6, p.y - 12, 28, 28), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 4, p.y - 4, 24, 19), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 5, p.y - 11, 26, 9), PAL_FOREST, true)
			draw_rect(Rect2(p.x - 3, p.y - 9, 22, 3), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 4, p.y + 4, 6, 11), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 13, p.y + 3, 4, 5), PAL_GOLD, true)
		ObjectType.SHOP:
			draw_rect(Rect2(p.x - 8, p.y + 12, 32, 5), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 7, p.y - 14, 30, 30), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 13, 28, 10), PAL_OCEAN_BLUE, true)
			# 经典红白遮阳篷条纹
			for sx in range(-4, 20, 6):
				draw_rect(Rect2(p.x + sx, p.y - 7, 3, 4), PAL_CREAM, true)
				draw_rect(Rect2(p.x + sx + 3, p.y - 7, 3, 4), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 4, p.y + 4, 7, 11), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 13, p.y + 3, 6, 5), PAL_GOLD, true)
		ObjectType.LIBRARY:
			draw_rect(Rect2(p.x - 8, p.y + 12, 32, 5), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 7, p.y - 14, 30, 30), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 13, 28, 10), PAL_OCEAN_BLUE, true)
			draw_rect(Rect2(p.x - 2, p.y + 2, 6, 9), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 8, p.y + 2, 6, 9), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 12, p.y - 16, 4, 6), PAL_GOLD, true)
		ObjectType.CANTEEN:
			draw_rect(Rect2(p.x - 8, p.y + 12, 32, 5), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 7, p.y - 14, 30, 30), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 13, 28, 10), PAL_CORAL, true)
			for sx in range(-4, 20, 7):
				draw_rect(Rect2(p.x + sx, p.y - 6, 4, 3), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 5, p.y + 3, 8, 9), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 15, p.y + 1, 5, 5), PAL_GOLD, true)
		ObjectType.SPORTS:
			draw_rect(Rect2(p.x - 18, p.y - 14, 52, 42), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 16, p.y - 12, 48, 38), Color("#8CCB74"), true)
			draw_rect(Rect2(p.x - 16, p.y + 6, 48, 1.5), Color(1, 1, 1, 0.75), true)
			draw_arc(Vector2(p.x + 8, p.y + 7), 9.0, 0, TAU, 18, Color(1, 1, 1, 0.75), 1.2)
			draw_rect(Rect2(p.x - 2, p.y - 20, 14, 7), PAL_SAND, true)
			draw_rect(Rect2(p.x - 2, p.y - 20, 14, 2), PAL_WOOD, true)
		ObjectType.FURNITURE_SHOP:
			draw_rect(Rect2(p.x - 8, p.y + 12, 32, 5), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 7, p.y - 14, 30, 30), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM_DARK, true)
			draw_rect(Rect2(p.x - 6, p.y - 13, 28, 10), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 4, p.y + 3, 8, 10), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 15, p.y + 2, 5, 4), PAL_GOLD, true)
		ObjectType.SEED_SHOP:
			draw_rect(Rect2(p.x - 8, p.y + 12, 32, 5), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x - 7, p.y - 14, 30, 30), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 13, 28, 10), PAL_FOREST, true)
			draw_rect(Rect2(p.x - 3, p.y - 10, 22, 3), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 5, p.y + 3, 8, 10), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 15, p.y + 1, 4, 4), PAL_PINK, true)
		ObjectType.RAMP:
			# 木台阶坡道：四道台阶 + 朝向相邻高地的一侧画一个小亮块作为提示
			var rgx: int = int(round(p.x / float(TILE_SIZE)))
			var rgy: int = int(round(p.y / float(TILE_SIZE)))
			draw_rect(Rect2(p.x + 1, p.y + 1, 14, 14), PAL_EARTH, true)
			for i in range(4):
				draw_rect(Rect2(p.x + 2, p.y + 2 + i * 3, 12, 2), PAL_WOOD.lightened(0.06 * float(i)), true)
			if is_valid_cell(rgx, rgy):
				var my_h: int = int(elevation_grid[rgx][rgy])
				for dvec in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx: int = rgx + dvec.x
					var ny: int = rgy + dvec.y
					if is_valid_cell(nx, ny) and int(elevation_grid[nx][ny]) > my_h:
						draw_rect(Rect2(p.x + 7 + dvec.x * 6 - 1, p.y + 7 + dvec.y * 6 - 1, 3, 3), PAL_CREAM, true)
						break
		ObjectType.CONSTRUCTION:
			draw_rect(Rect2(p.x - 3, p.y - 3, 22, 20), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 2, p.y - 2, 20, 18), PAL_SAND, true)
			draw_rect(Rect2(p.x, p.y, 16, 14), PAL_WOOD, false, 2.0)
		ObjectType.BOOKSHELF:
			draw_texture_rect(_get_icon_tex("bookshelf"), Rect2(p.x - 2, p.y - 6, 20, 20), false)
		ObjectType.RECORD_PLAYER:
			draw_texture_rect(_get_icon_tex("record_player"), Rect2(p.x - 2, p.y - 4, 20, 20), false)
		ObjectType.SHELL_SHELF:
			draw_texture_rect(_get_icon_tex("shell_rack"), Rect2(p.x - 2, p.y - 6, 20, 20), false)
		ObjectType.DINING_TABLE:
			draw_texture_rect(_get_icon_tex("table"), Rect2(p.x - 2, p.y - 4, 20, 20), false)
		ObjectType.BED:
			draw_texture_rect(_get_icon_tex("bed"), Rect2(p.x - 2, p.y - 4, 20, 20), false)
		ObjectType.SOFA:
			draw_texture_rect(_get_icon_tex("sofa"), Rect2(p.x - 2, p.y - 4, 20, 20), false)
		ObjectType.CHAIR:
			draw_texture_rect(_get_icon_tex("chair"), Rect2(p.x - 1, p.y - 3, 18, 18), false)
		ObjectType.WARDROBE:
			draw_texture_rect(_get_icon_tex("wardrobe"), Rect2(p.x - 2, p.y - 6, 20, 20), false)
		ObjectType.STORAGE_BOX:
			draw_texture_rect(_get_icon_tex("storage_box"), Rect2(p.x - 1, p.y - 3, 18, 18), false)
		ObjectType.RUG:
			draw_texture_rect(_get_icon_tex("rug"), Rect2(p.x - 2, p.y - 2, 20, 20), false)
		ObjectType.DISPLAY_CASE:
			draw_texture_rect(_get_icon_tex("display_case"), Rect2(p.x - 2, p.y - 6, 20, 20), false)

func _draw_tree_canopy_layer(p: Vector2, o_type: int) -> void:
	match o_type:
		ObjectType.TREE_OAK:
			draw_rect(Rect2(p.x - 1, p.y - 6, 18, 15), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x, p.y - 5, 16, 13), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 2, p.y - 7, 12, 10), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 4, p.y - 6, 8, 5), PAL_HIGH_GRASS, true)
			draw_rect(Rect2(p.x + 3, p.y + 1, 3, 3), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 11, p.y, 3, 3), PAL_CORAL, true)
		ObjectType.TREE_PINE:
			# 塔状针叶松树
			draw_rect(Rect2(p.x + 1, p.y, 14, 8), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 1, 12, 6), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 3, p.y - 5, 10, 7), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 4, p.y - 4, 8, 5), PAL_FOREST.lightened(0.10), true)
			draw_rect(Rect2(p.x + 5, p.y - 9, 6, 5), PAL_GRASS, true)
		ObjectType.TREE_PALM:
			# 海滨椰子树羽状树冠与椰果
			draw_rect(Rect2(p.x - 2, p.y - 5, 20, 9), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 1, p.y - 4, 18, 7), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 3, p.y - 7, 10, 5), PAL_HIGH_GRASS, true)
			draw_rect(Rect2(p.x + 5, p.y + 2, 3, 3), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 9, p.y + 2, 3, 3), PAL_WOOD, true)

func _facing_to_row(f: Vector2) -> int:
	# 0: 下 (DOWN), 1: 左 (LEFT), 2: 右 (RIGHT), 3: 上 (UP)
	if absf(f.x) > absf(f.y):
		return 1 if f.x < 0.0 else 2
	return 3 if f.y < -0.05 else 0

func _draw_storybook_animal(a: Dictionary, override_pos: Vector2 = Vector2(-9999, -9999)) -> void:
	var p: Vector2 = a["pos"] if override_pos.x < -1000.0 else override_pos
	var id_str: String = str(a.get("id", "bear"))
	var facing: Vector2 = a.get("facing", Vector2.DOWN)
	var anim_t: float = float(a.get("anim_t", 0.0))
	var is_moving: bool = not (a.get("path", []) as Array).is_empty() and override_pos.x < -1000.0
	var row: int = _facing_to_row(facing)
	var col: int = (int(floor(anim_t)) % 4) if is_moving else 0

	draw_rect(Rect2(p.x - 6, p.y + 1, 12, 3), Color(0, 0, 0, 0.22), true)
	var walk_tex: Texture2D = _get_walk_tex(id_str)
	if walk_tex != null:
		draw_texture_rect_region(
			walk_tex,
			Rect2(round(p.x - 10.0), round(p.y - 19.0), 20.0, 20.0),
			Rect2(float(col * 24), float(row * 24), 24.0, 24.0)
		)
		return

	# 保底像素绘制
	var body_col: Color = a.get("body_col", PAL_EARTH)
	var shirt_col: Color = a.get("shirt_col", PAL_SAND)
	draw_rect(Rect2(p.x - 5, p.y - 14, 10, 17), PAL_OUTLINE, true)
	draw_rect(Rect2(p.x - 4, p.y - 5, 8, 7), shirt_col, true)
	draw_rect(Rect2(p.x - 4, p.y - 13, 8, 8), body_col, true)

func _draw_storybook_player() -> void:
	var px: float = player_pos.x
	var py: float = player_pos.y
	var row: int = _facing_to_row(player_facing)
	var col: int = (int(floor(walk_anim_time * 0.8)) % 4) if walk_anim_time > 0.01 else 0

	draw_rect(Rect2(px - 6, py + 1, 12, 3), Color(0, 0, 0, 0.26), true)
	var p_tex: Texture2D = _get_walk_tex("player")
	if p_tex != null:
		draw_texture_rect_region(
			p_tex,
			Rect2(round(px - 10.0), round(py - 19.0), 20.0, 20.0),
			Rect2(float(col * 24), float(row * 24), 24.0, 24.0)
		)
	else:
		draw_rect(Rect2(px - 5, py - 14, 10, 17), PAL_OUTLINE, true)
		draw_rect(Rect2(px - 4, py - 5, 8, 7), PAL_OCEAN_BLUE, true)
		draw_rect(Rect2(px - 4, py - 13, 8, 7), PAL_CREAM, true)

	if tool_swing_timer > 0.0:
		var swing_pos: Vector2 = player_pos + player_facing.normalized() * 11.0
		draw_circle(swing_pos, 5.0, PAL_CREAM)
		draw_circle(swing_pos, 3.0, PAL_CORAL)

func _draw_indoor_room() -> void:
	var view_world: Rect2 = _visible_world_rect()
	# 室内暖棕背景衬底
	draw_rect(view_world.grow(64.0), Color("#261F1B"), true)

	var room: Dictionary = indoor_rooms.get(current_room_id, indoor_rooms.get("player", {}))
	var floor_col: Color = room.get("floor_col", PAL_CREAM)
	var floor_alt: Color = room.get("floor_alt", PAL_CREAM_DARK)
	var wall_col: Color = room.get("wall_col", PAL_SAND)
	var trim_col: Color = room.get("trim_col", PAL_WOOD)

	# 外框阴影与木质外框
	draw_rect(Rect2(-4, -4, ROOM_W * TILE_SIZE + 8, ROOM_H * TILE_SIZE + 10), PAL_OUTLINE, true)
	draw_rect(Rect2(-2, -2, ROOM_W * TILE_SIZE + 4, ROOM_H * TILE_SIZE + 6), trim_col, true)

	# 逐格绘制墙体与木地板
	for x in range(ROOM_W):
		for y in range(ROOM_H):
			var r := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var is_door: bool = (y == ROOM_H - 1 and x in [5, 6])
			var is_wall: bool = (x == 0 or x == ROOM_W - 1 or y == 0 or y == ROOM_H - 1) and not is_door
			if is_wall:
				draw_rect(r, wall_col if y == 0 else trim_col, true)
				if y == 0:
					draw_rect(Rect2(r.position.x, r.position.y + 12, TILE_SIZE, 4), trim_col, true)
					# 北墙窗户与日光/夜色
					if x in [4, 7]:
						var win_col: Color = Color("#466289") if (clock_hour >= 19 or clock_hour < 6) else PAL_SKY_BLUE
						draw_rect(Rect2(r.position.x + 2, r.position.y + 2, 12, 9), PAL_OUTLINE, true)
						draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 10, 7), win_col, true)
						draw_rect(Rect2(r.position.x + 7, r.position.y + 3, 1, 7), PAL_CREAM, true)
						draw_rect(Rect2(r.position.x + 3, r.position.y + 6, 10, 1), PAL_CREAM, true)
			else:
				var c_fl: Color = floor_col if ((x + y) % 2 == 0) else floor_alt
				draw_rect(r, c_fl, true)
				draw_rect(Rect2(r.position.x, r.position.y + 15, TILE_SIZE, 1), c_fl.darkened(0.06), true)
				if is_door:
					draw_rect(Rect2(r.position.x + 1, r.position.y + 2, TILE_SIZE - 2, TILE_SIZE - 3), PAL_CORAL, true)
					draw_rect(Rect2(r.position.x + 2, r.position.y + 4, TILE_SIZE - 4, TILE_SIZE - 7), PAL_SAND, true)

	# 玩家房屋绘制四大功能区柔和地面边线标识（休息区、储物区、工作区、自由装修区）
	if current_room_id == "player":
		draw_rect(Rect2(1 * TILE_SIZE + 1, 1 * TILE_SIZE + 1, 4 * TILE_SIZE - 2, 3 * TILE_SIZE - 2), Color(0.45, 0.78, 0.93, 0.14), false, 1.0)
		draw_rect(Rect2(7 * TILE_SIZE + 1, 1 * TILE_SIZE + 1, 4 * TILE_SIZE - 2, 2 * TILE_SIZE - 2), Color(0.95, 0.83, 0.38, 0.16), false, 1.0)
		draw_rect(Rect2(1 * TILE_SIZE + 1, 5 * TILE_SIZE + 1, 3 * TILE_SIZE - 2, 3 * TILE_SIZE - 2), Color(0.51, 0.79, 0.43, 0.16), false, 1.0)
		if indoor_edit_mode:
			for gx in range(1, ROOM_W - 1):
				for gy in range(1, ROOM_H - 1):
					var gr := Rect2(gx * TILE_SIZE, gy * TILE_SIZE, TILE_SIZE, TILE_SIZE)
					draw_rect(gr, Color(1, 1, 1, 0.16), false, 1.0)

	# 1. 先绘制地面地毯层 (walkable == true)
	var furn_list: Array = room.get("furniture", [])
	for f in furn_list:
		var ftype: String = str(f.get("type", ""))
		if ftype == "rug":
			var fp := Vector2(int(f["x"]) * TILE_SIZE, int(f["y"]) * TILE_SIZE)
			draw_texture_rect(_get_icon_tex("rug"), Rect2(fp.x - 1, fp.y - 1, 18, 18), false)

	# 2. Y-Sort 逐行绘制室内立体家具、房间主人与玩家角色
	var p_row: int = clampi(int(floor(player_pos.y / TILE_SIZE)), 0, ROOM_H - 1)
	var host_idx: int = _indoor_host_resident_idx()
	var host_pos: Vector2 = _indoor_host_pos()
	var host_row: int = clampi(int(floor(host_pos.y / TILE_SIZE)), 0, ROOM_H - 1)

	for y in range(ROOM_H):
		for f in furn_list:
			if int(f.get("y", -1)) != y:
				continue
			var ftype2: String = str(f.get("type", ""))
			if ftype2 == "rug":
				continue
			var fx: int = int(f.get("x", 0))
			var fp2 := Vector2(fx * TILE_SIZE, y * TILE_SIZE)
			var icon_k: String = str(INDOOR_FURNITURE_META.get(ftype2, {}).get("icon", "chair"))
			draw_rect(Rect2(fp2.x + 1, fp2.y + 13, 14, 3), Color(0, 0, 0, 0.18), true)
			draw_texture_rect(_get_icon_tex(icon_k), Rect2(fp2.x - 2, fp2.y - 4, 20, 20), false)

		if host_idx >= 0 and host_row == y:
			_draw_storybook_animal(animals[host_idx], host_pos)

		if p_row == y:
			_draw_storybook_player()

	# 3. 漫步正面高亮框或室内装修红绿预览框
	var fc: Vector2i = indoor_preview_cell if (indoor_edit_mode and indoor_preview_cell.x >= 0) else get_front_cell()
	if is_valid_cell(fc.x, fc.y):
		if indoor_edit_mode and current_room_id == "player":
			var test_type: String = str(indoor_moving_item.get("type", "chair")) if not indoor_moving_item.is_empty() else "chair"
			var can_put: bool = _can_place_indoor_furniture_at(fc.x, fc.y, test_type)
			var p_col: Color = Color(0.25, 0.92, 0.40, 0.42) if can_put else Color(0.95, 0.30, 0.30, 0.48)
			draw_rect(Rect2(fc.x * TILE_SIZE, fc.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), p_col, true)
			draw_rect(Rect2(fc.x * TILE_SIZE, fc.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), PAL_CREAM, false, 1.4)
		else:
			draw_rect(Rect2(fc.x * TILE_SIZE + 1, fc.y * TILE_SIZE + 1, TILE_SIZE - 2, TILE_SIZE - 2), Color(1.0, 0.95, 0.80, 0.58), false, 1.2)

	_draw_environment_particles()

func _draw_environment_particles() -> void:
	var h: int = int(Time.get_datetime_dict_from_system().get("hour", 12))
	var is_night: bool = (h >= 19 or h < 6)

	for p in ambient_particles:
		var pos: Vector2 = p["pos"]
		if is_night:
			var glow_alpha: float = 0.4 + 0.55 * abs(sin(env_anim_time * 3.0 + float(p["phase"])))
			draw_rect(Rect2(pos.x, pos.y, 2, 2), Color(0.95, 1.0, 0.55, glow_alpha), true)
		else:
			draw_rect(Rect2(pos.x, pos.y, 2, 2), p["color"], true)

	for bp in burst_particles:
		var bpos: Vector2 = bp["pos"]
		draw_rect(Rect2(bpos.x - 1.5, bpos.y - 1.5, 3, 3), bp["color"], true)

# ==============================================================================
# 《小岛日记》真实图标化 UI 构建（顶部栏、快捷栏、右侧按钮、岛建栏、背包与商店）
# ==============================================================================

func _make_storybook_panel_style(bg_col: Color = PAL_CREAM, border_col: Color = PAL_OUTLINE, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

func _make_touch_btn(txt: String, min_size: Vector2, bg_col: Color = PAL_CREAM, text_col: Color = PAL_OUTLINE) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = min_size
	btn.size = min_size
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)

	var sb := _make_storybook_panel_style(bg_col, PAL_OUTLINE, 7)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_pressed := _make_storybook_panel_style(bg_col.darkened(0.08), PAL_OUTLINE, 7)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_pressed)
	return btn

## 创建带真实 PNG 图标 + 中文短标签的绘本风触控按钮（图标与文字清晰分离，严禁挤成一团）
func _make_icon_label_btn(icon_key: String, label_txt: String, btn_size: Vector2, bg_col: Color = PAL_CREAM, vertical: bool = false, icon_px: int = 22) -> Array:
	var btn := _make_touch_btn("", btn_size, bg_col, PAL_OUTLINE)
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2 if vertical else 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var tex_rect := TextureRect.new()
	tex_rect.texture = _get_icon_tex(icon_key)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(icon_px, icon_px)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11 if vertical else 12)
	lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	return [btn, lbl, tex_rect]

func _make_small_icon_rect(icon_key: String, px: int = 20) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _get_icon_tex(icon_key)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _build_all_mobile_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# ---------------- 1. 手机启动主界面 ----------------
	title_panel = Control.new()
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(title_panel)

	title_bg_rect = ColorRect.new()
	title_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bg_rect.color = Color(0.10, 0.22, 0.32, 0.42)
	title_panel.add_child(title_bg_rect)

	title_card_panel = Panel.new()
	title_card_panel.size = Vector2(360, 276)
	title_card_panel.position = Vector2(140, 42)
	title_card_panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 12))
	title_panel.add_child(title_card_panel)

	var title_header_box := HBoxContainer.new()
	title_header_box.position = Vector2(56, 14)
	title_header_box.add_theme_constant_override("separation", 8)
	title_card_panel.add_child(title_header_box)
	title_header_box.add_child(_make_small_icon_rect("home_ui", 32))

	var game_title_lbl := Label.new()
	game_title_lbl.text = "小岛日记"
	game_title_lbl.add_theme_font_size_override("font_size", 24)
	game_title_lbl.add_theme_color_override("font_color", PAL_WOOD)
	title_header_box.add_child(game_title_lbl)
	title_header_box.add_child(_make_small_icon_rect("flower", 30))

	var sub_lbl := Label.new()
	sub_lbl.text = "在属于自己的小岛上，慢慢生活"
	sub_lbl.position = Vector2(78, 50)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	title_card_panel.add_child(sub_lbl)

	var btn_continue: Button = _make_icon_label_btn("confirm_ui", "继续日记 (读取本地存档)", Vector2(260, 42), PAL_GRASS, false, 22)[0]
	btn_continue.position = Vector2(50, 82)
	btn_continue.pressed.connect(func():
		if FileAccess.file_exists(SAVE_PATH):
			_load_game()
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("欢迎回到《小岛日记》！小动物们都在等你呢~")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_save_game()
			_show_toast("欢迎登岛！按住左下角摇杆即可在小岛漫步")
	)
	title_card_panel.add_child(btn_continue)

	var btn_new_game: Button = _make_icon_label_btn("grass_ui", "开启新岛屿生活", Vector2(260, 42), PAL_SKY_BLUE, false, 22)[0]
	btn_new_game.position = Vector2(50, 132)
	btn_new_game.pressed.connect(func():
		if FileAccess.file_exists(SAVE_PATH):
			_ask_confirm("开启新游戏将覆盖当前本地存档，确定要重新生成初始小岛吗？", func():
				in_interior = false
				_init_default_island()
				_init_indoor_rooms()
				_init_default_inventory()
				_save_game()
				_refresh_hotbar_ui()
				_switch_game_state(GameState.EXPLORE_MODE)
				_show_toast("全新的《小岛日记》已开启！")
			)
		else:
			_init_default_island()
			_init_default_inventory()
			_save_game()
			_refresh_hotbar_ui()
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("欢迎来到属于你的温暖小岛！")
	)
	title_card_panel.add_child(btn_new_game)

	var btn_title_settings: Button = _make_icon_label_btn("settings_ui", "设置", Vector2(124, 42), PAL_SAND, false, 22)[0]
	btn_title_settings.position = Vector2(50, 184)
	btn_title_settings.pressed.connect(func(): _open_modal(settings_modal))
	title_card_panel.add_child(btn_title_settings)

	var btn_title_quit: Button = _make_icon_label_btn("cancel_ui", "退出", Vector2(124, 42), PAL_CORAL, false, 22)[0]
	btn_title_quit.position = Vector2(186, 184)
	btn_title_quit.pressed.connect(func():
		_ask_confirm("确定要保存并退出《小岛日记》吗？", func():
			_save_game()
			get_tree().quit()
		)
	)
	title_card_panel.add_child(btn_title_quit)

	# ---------------- 2. 游戏内主 HUD ----------------
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_root)

	hud_overlay_draw = Control.new()
	hud_overlay_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_overlay_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_overlay_draw.draw.connect(_on_draw_hud_overlay)
	hud_root.add_child(hud_overlay_draw)

	# 2.1 顶部左侧状态栏（真实接入 calendar_ui.png + weather_ui.png + coins_ui.png）
	top_status_panel = Panel.new()
	top_status_panel.position = Vector2(12, 8)
	top_status_panel.size = Vector2(328, 36)
	top_status_panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 9))
	hud_root.add_child(top_status_panel)

	var status_hbox := HBoxContainer.new()
	status_hbox.position = Vector2(8, 5)
	status_hbox.add_theme_constant_override("separation", 5)
	top_status_panel.add_child(status_hbox)

	status_hbox.add_child(_make_small_icon_rect("calendar_ui", 22))
	status_hbox.add_child(_make_small_icon_rect("weather_ui", 22))

	top_time_label = Label.new()
	top_time_label.add_theme_font_size_override("font_size", 12)
	top_time_label.add_theme_color_override("font_color", PAL_OUTLINE)
	status_hbox.add_child(top_time_label)

	var sep_spacer := Control.new()
	sep_spacer.custom_minimum_size = Vector2(6, 1)
	status_hbox.add_child(sep_spacer)

	status_hbox.add_child(_make_small_icon_rect("coins_ui", 22))

	top_coin_label = Label.new()
	top_coin_label.add_theme_font_size_override("font_size", 12)
	top_coin_label.add_theme_color_override("font_color", PAL_WOOD)
	status_hbox.add_child(top_coin_label)

	# 2.2 顶部右侧统一图标化功能入口（岛建、背包、地图、菜单，统一尺寸 66x36、间距 5）
	top_right_bar = HBoxContainer.new()
	top_right_bar.position = Vector2(348, 8)
	top_right_bar.add_theme_constant_override("separation", 5)
	hud_root.add_child(top_right_bar)

	var mode_res: Array = _make_icon_label_btn("hammer", "岛建", Vector2(68, 36), PAL_CORAL, false, 20)
	mode_toggle_btn = mode_res[0]
	mode_toggle_label = mode_res[1]
	mode_toggle_btn.pressed.connect(func():
		if in_interior:
			_toggle_indoor_edit_mode()
			return
		if game_state == GameState.EXPLORE_MODE:
			_switch_game_state(GameState.BUILD_MODE)
			_show_toast("已进入【岛建模式】：点击底部图标切换工具，右侧可改画笔/撤销")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("已返回【日常漫步模式】")
	)
	top_right_bar.add_child(mode_toggle_btn)

	var bag_top_btn: Button = _make_icon_label_btn("backpack_ui", "背包", Vector2(68, 36), PAL_SAND, false, 20)[0]
	bag_top_btn.pressed.connect(func(): _open_bag_modal())
	top_right_bar.add_child(bag_top_btn)

	var map_top_btn: Button = _make_icon_label_btn("map_ui", "地图", Vector2(68, 36), PAL_SKY_BLUE, false, 20)[0]
	map_top_btn.pressed.connect(func(): _open_map_modal())
	top_right_bar.add_child(map_top_btn)

	var menu_top_btn: Button = _make_icon_label_btn("settings_ui", "菜单", Vector2(68, 36), PAL_CREAM, false, 20)[0]
	menu_top_btn.pressed.connect(func(): _open_modal(pause_menu_modal))
	top_right_bar.add_child(menu_top_btn)

	# 顶部柔和气泡提示条
	toast_panel = Panel.new()
	toast_panel.position = Vector2(130, 48)
	toast_panel.size = Vector2(380, 26)
	toast_panel.visible = false
	toast_panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 6))
	hud_root.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.position = Vector2(10, 3)
	toast_label.add_theme_font_size_override("font_size", 12)
	toast_label.add_theme_color_override("font_color", PAL_OUTLINE)
	toast_panel.add_child(toast_label)

	# 2.3 右侧大拇指操作按钮（真实接入 interact_hand.png、use_tool.png、cancel.png + 中文短标签）
	right_action_box = VBoxContainer.new()
	right_action_box.position = Vector2(544, 152)
	right_action_box.add_theme_constant_override("separation", 6)
	hud_root.add_child(right_action_box)

	var act_res: Array = _make_icon_label_btn("interact_hand", "互动", Vector2(82, 46), PAL_GRASS, false, 24)
	interact_btn = act_res[0]
	interact_btn_label = act_res[1]
	interact_btn.pressed.connect(_on_interact_pressed)
	right_action_box.add_child(interact_btn)

	var use_res: Array = _make_icon_label_btn("use_tool", "使用", Vector2(82, 46), PAL_SKY_BLUE, false, 24)
	use_tool_btn = use_res[0]
	use_tool_btn.pressed.connect(_on_use_tool_pressed)
	right_action_box.add_child(use_tool_btn)

	var can_res: Array = _make_icon_label_btn("cancel", "取消", Vector2(82, 40), PAL_CORAL, false, 20)
	cancel_btn = can_res[0]
	cancel_btn.pressed.connect(_on_cancel_button_pressed)
	right_action_box.add_child(cancel_btn)

	# 2.4 底部 6 槽位纯图标快捷栏（接入 shovel/axe/watering_can/bug_net/fishing_rod/flower 真实 PNG + 数量角标 + 选中高亮框）
	hotbar_panel = Panel.new()
	hotbar_panel.position = Vector2(152, 296)
	hotbar_panel.size = Vector2(336, 56)
	hotbar_panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 10))
	hud_root.add_child(hotbar_panel)

	hotbar_container = HBoxContainer.new()
	hotbar_container.position = Vector2(8, 5)
	hotbar_container.add_theme_constant_override("separation", 5)
	hotbar_panel.add_child(hotbar_container)

	hotbar_slots.clear()
	for i in range(6):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(49, 46)
		slot_btn.size = Vector2(49, 46)
		var idx: int = i
		slot_btn.pressed.connect(func():
			selected_hotbar_index = idx
			_refresh_hotbar_ui()
			var id_str: String = hotbar[idx]
			if id_str != "" and ITEM_DB.has(id_str):
				_show_toast("已装备：【" + str(ITEM_DB[id_str]["name"]) + "】")
			else:
				_show_toast("选中了空槽位 #" + str(idx + 1))
		)

		var icon_rect := TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(7, 4)
		icon_rect.size = Vector2(35, 35)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(icon_rect)

		var count_lbl := Label.new()
		count_lbl.position = Vector2(2, 28)
		count_lbl.size = Vector2(44, 16)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
		count_lbl.add_theme_color_override("font_outline_color", PAL_CREAM)
		count_lbl.add_theme_constant_override("outline_size", 3)
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(count_lbl)

		hotbar_container.add_child(slot_btn)
		hotbar_slots.append({
			"btn": slot_btn,
			"icon_rect": icon_rect,
			"count_lbl": count_lbl
		})

	# ---------------- 3. 手机岛建模式专属图标工具栏 ----------------
	_build_terraforming_toolbar()

	# ---------------- 4. 构建所有绘本风弹窗（背包、商店、地图、菜单、设置） ----------------
	_build_all_modals()
	_refresh_hotbar_ui()

func _build_terraforming_toolbar() -> void:
	build_toolbar_panel = Control.new()
	build_toolbar_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_toolbar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_toolbar_panel.visible = false
	hud_root.add_child(build_toolbar_panel)

	# 右侧岛建辅助图标按钮组（撤销、重做、画笔尺寸、连续/框选、移视角、换样式、确认、取消）
	build_right_box = VBoxContainer.new()
	build_right_box.position = Vector2(534, 48)
	build_right_box.add_theme_constant_override("separation", 4)
	build_toolbar_panel.add_child(build_right_box)

	var undo_redo_row := HBoxContainer.new()
	undo_redo_row.add_theme_constant_override("separation", 4)
	build_right_box.add_child(undo_redo_row)

	build_undo_btn = _make_icon_label_btn("undo_ui", "撤销", Vector2(44, 38), PAL_SAND, true, 16)[0]
	build_undo_btn.pressed.connect(_on_build_undo_pressed)
	undo_redo_row.add_child(build_undo_btn)

	build_redo_btn = _make_icon_label_btn("redo_ui", "重做", Vector2(44, 38), PAL_SAND, true, 16)[0]
	build_redo_btn.pressed.connect(_on_build_redo_pressed)
	undo_redo_row.add_child(build_redo_btn)

	build_brush_size_btn = _make_touch_btn("画笔: 1×1", Vector2(92, 32), PAL_CREAM, PAL_OUTLINE)
	build_brush_size_btn.pressed.connect(func():
		build_brush_size = (build_brush_size % 3) + 1
		is_box_select_mode = false
		_update_build_ui_labels()
		_show_toast("画笔尺寸切换为：%d×%d 格" % [build_brush_size, build_brush_size])
	)
	build_right_box.add_child(build_brush_size_btn)

	build_brush_mode_btn = _make_touch_btn("模式: 涂抹", Vector2(92, 32), PAL_SKY_BLUE, PAL_OUTLINE)
	build_brush_mode_btn.pressed.connect(func():
		is_camera_pan_mode = false
		is_box_select_mode = not is_box_select_mode
		has_pending_box = false
		build_confirm_box_btn.visible = false
		_update_build_ui_labels()
	)
	build_right_box.add_child(build_brush_mode_btn)

	build_pan_mode_btn = _make_touch_btn("移视角: 关", Vector2(92, 32), PAL_CREAM_DARK, PAL_OUTLINE)
	build_pan_mode_btn.pressed.connect(func():
		is_camera_pan_mode = not is_camera_pan_mode
		_update_build_ui_labels()
	)
	build_right_box.add_child(build_pan_mode_btn)

	build_sub_cycle_btn = _make_touch_btn("切换子样式", Vector2(92, 32), PAL_PINK, PAL_OUTLINE)
	build_sub_cycle_btn.pressed.connect(_on_cycle_build_subtype)
	build_right_box.add_child(build_sub_cycle_btn)

	var confirm_cancel_row := HBoxContainer.new()
	confirm_cancel_row.add_theme_constant_override("separation", 4)
	build_right_box.add_child(confirm_cancel_row)

	build_confirm_box_btn = _make_icon_label_btn("confirm", "确定", Vector2(44, 40), PAL_GRASS, true, 16)[0]
	build_confirm_box_btn.visible = false
	build_confirm_box_btn.pressed.connect(_execute_pending_box_selection)
	confirm_cancel_row.add_child(build_confirm_box_btn)

	build_cancel_tool_btn = _make_icon_label_btn("cancel", "取消", Vector2(44, 40), PAL_CORAL, true, 16)[0]
	build_cancel_tool_btn.pressed.connect(_on_cancel_button_pressed)
	confirm_cancel_row.add_child(build_cancel_tool_btn)

	# 底部 9 大核心图标化岛建工具栏（草地、铲平、造高地、水域、道路、植物、建筑、装饰、移动）
	build_bottom_panel = Panel.new()
	build_bottom_panel.position = Vector2(10, 278)
	build_bottom_panel.size = Vector2(518, 76)
	build_bottom_panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 10))
	build_toolbar_panel.add_child(build_bottom_panel)

	build_mode_hint_label = Label.new()
	build_mode_hint_label.position = Vector2(12, 4)
	build_mode_hint_label.add_theme_font_size_override("font_size", 11)
	build_mode_hint_label.add_theme_color_override("font_color", PAL_WOOD)
	build_bottom_panel.add_child(build_mode_hint_label)

	var tool_hbox := HBoxContainer.new()
	tool_hbox.position = Vector2(8, 22)
	tool_hbox.add_theme_constant_override("separation", 4)
	build_bottom_panel.add_child(tool_hbox)

	var tool_defs: Array = [
		{"id": BuildTool.GROUND_GRASS, "name": "地形", "icon": "grass_tile"},
		{"id": BuildTool.FLATTEN,      "name": "铲平", "icon": "dirt_tile"},
		{"id": BuildTool.CLIFF_RAISE,  "name": "高地", "icon": "raised_terrain"},
		{"id": BuildTool.RIVER_DIG,    "name": "水域", "icon": "water_tile"},
		{"id": BuildTool.ROAD_PAVE,    "name": "道路", "icon": "stone_path"},
		{"id": BuildTool.PLANT_PUT,    "name": "植物", "icon": "flower"},
		{"id": BuildTool.BUILDING_PUT, "name": "建筑", "icon": "house"},
		{"id": BuildTool.DECOR_PUT,    "name": "装饰", "icon": "potted_plant"},
		{"id": BuildTool.MOVE_OBJECT,  "name": "移动", "icon": "move_ui"},
		{"id": BuildTool.FARM,         "name": "农事", "icon": "flower"}
	]

	build_tool_buttons.clear()
	for td in tool_defs:
		var res_arr: Array = _make_icon_label_btn(td["icon"], td["name"], Vector2(46, 48), PAL_CREAM_DARK, true, 20)
		var t_btn: Button = res_arr[0]
		var tid: int = int(td["id"])
		t_btn.pressed.connect(func():
			current_build_tool = tid
			is_camera_pan_mode = false
			has_pending_box = false
			build_confirm_box_btn.visible = false
			_update_build_ui_labels()
		)
		tool_hbox.add_child(t_btn)
		build_tool_buttons.append({"id": tid, "btn": t_btn})

func _on_cycle_build_subtype() -> void:
	if current_build_tool == BuildTool.ROAD_PAVE:
		if build_sub_road == GroundType.STONE_PATH:
			build_sub_road = GroundType.WOOD_PATH
			_show_toast("道路样式切换为：【温暖木板路】")
		elif build_sub_road == GroundType.WOOD_PATH:
			build_sub_road = GroundType.BRIDGE
			_show_toast("道路样式切换为：【水上木桥】")
		else:
			build_sub_road = GroundType.STONE_PATH
			_show_toast("道路样式切换为：【村庄石板路】")
	elif current_build_tool == BuildTool.FARM:
		if build_sub_farm == 0:
			var seeds: Array = ["carrot_seed", "tomato_seed", "pumpkin_seed", "strawberry_seed"]
			var idx: int = seeds.find(farm_seed_id)
			farm_seed_id = str(seeds[(idx + 1) % seeds.size()])
			_show_toast("农事种子切换为：【%s】" % str(ITEM_DB[farm_seed_id]["name"]))
		else:
			build_sub_farm = (build_sub_farm + 1) % 3
			_show_toast("农事动作切换为：【%s】" % ["播种", "浇水", "收获"][build_sub_farm])
	elif current_build_tool == BuildTool.CLIFF_RAISE:
		if build_sub_cliff == 0:
			build_sub_cliff = 1
			_show_toast("高地样式切换为：【木台阶坡道】—— 放在悬崖脚下就能走上高地")
		else:
			build_sub_cliff = 0
			_show_toast("高地样式切换为：【二层悬崖】—— 可作为挡土墙与观景台基座")
	elif current_build_tool == BuildTool.PLANT_PUT:
		if build_sub_plant == ObjectType.FLOWER_PINK:
			build_sub_plant = ObjectType.FLOWER_YELLOW
			_show_toast("植物样式切换为：【向阳黄花】")
		elif build_sub_plant == ObjectType.FLOWER_YELLOW:
			build_sub_plant = ObjectType.BUSH
			_show_toast("植物样式切换为：【常青灌木】")
		elif build_sub_plant == ObjectType.BUSH:
			build_sub_plant = ObjectType.TREE_OAK
			_show_toast("植物样式切换为：【海岛果树】")
		elif build_sub_plant == ObjectType.TREE_OAK:
			build_sub_plant = ObjectType.TREE_PINE
			_show_toast("植物样式切换为：【森林松树】")
		else:
			build_sub_plant = ObjectType.FLOWER_PINK
			_show_toast("植物样式切换为：【粉色花朵】")
	elif current_build_tool == BuildTool.DECOR_PUT:
		if build_sub_decor == ObjectType.FLOWER_PLANTER:
			build_sub_decor = ObjectType.BENCH
			_show_toast("装饰切换为：【木长椅】")
		elif build_sub_decor == ObjectType.BENCH:
			build_sub_decor = ObjectType.LAMP
			_show_toast("装饰切换为：【复古街灯】")
		elif build_sub_decor == ObjectType.LAMP:
			build_sub_decor = ObjectType.FOUNTAIN
			_show_toast("装饰切换为：【清泉喷泉】")
		elif build_sub_decor == ObjectType.FOUNTAIN:
			build_sub_decor = ObjectType.FENCE
			_show_toast("装饰切换为：【木质栅栏】")
		else:
			build_sub_decor = ObjectType.FLOWER_PLANTER
			_show_toast("装饰切换为：【精致花坛盆栽】")
	else:
		_show_toast("提示：选择【道路】【植物】【装饰】工具时可点此切换子样式！")
	_update_build_ui_labels()

func _update_build_ui_labels() -> void:
	if build_brush_size_btn == null:
		return
	build_brush_size_btn.text = "画笔: %d×%d" % [build_brush_size, build_brush_size]
	build_brush_mode_btn.text = "模式: 框选" if is_box_select_mode else "模式: 涂抹"
	build_pan_mode_btn.text = "移视角: 开" if is_camera_pan_mode else "移视角: 关"

	var tool_desc: String = ""
	match current_build_tool:
		BuildTool.GROUND_GRASS: tool_desc = "【地形】铺设自然草坪"
		BuildTool.FLATTEN:      tool_desc = "【铲平】铲平高地/填河/清杂物"
		BuildTool.CLIFF_RAISE:
			if build_sub_cliff == 1:
				tool_desc = "【坡道】放在悬崖脚下，可徒步上下高地"
			else:
				tool_desc = "【高地】堆筑二层悬崖（点“切换子样式”可改为坡道）"
		BuildTool.RIVER_DIG:    tool_desc = "【水域】挖掘河流与湖泊"
		BuildTool.ROAD_PAVE:    tool_desc = "【道路】铺设石路/木路/木桥"
		BuildTool.PLANT_PUT:    tool_desc = "【植物】种植花草/灌木/树木"
		BuildTool.BUILDING_PUT: tool_desc = "【建筑】选址建造新房屋"
		BuildTool.DECOR_PUT:    tool_desc = "【装饰】布置盆栽/长椅/路灯/喷泉"
		BuildTool.FARM:
			tool_desc = "【农事】%s（%s）" % [["播种", "浇水", "收获"][build_sub_farm], str(ITEM_DB[farm_seed_id]["name"])]
		BuildTool.MOVE_OBJECT:
			if moving_picked_obj == ObjectType.NONE:
				tool_desc = "【移动】第1步：点击要搬运的物体"
			else:
				tool_desc = "【移动】第2步：点击空地放置物体"

	var mode_str: String = "单指移视角" if is_camera_pan_mode else ("拉框预览->点确认" if is_box_select_mode else ("%d×%d连续涂抹 (可撤销:%d)" % [build_brush_size, build_brush_size, undo_stack.size()]))
	build_mode_hint_label.text = "%s | %s" % [tool_desc, mode_str]

	for item in build_tool_buttons:
		var b: Button = item["btn"]
		var active: bool = (int(item["id"]) == current_build_tool)
		b.add_theme_stylebox_override("normal", _make_storybook_panel_style(PAL_GOLD if active else PAL_CREAM_DARK, PAL_OUTLINE, 7))

func _on_cancel_button_pressed() -> void:
	if active_modal != null:
		_close_active_modal()
		return
	if in_interior:
		if not indoor_moving_item.is_empty() and current_room_id == "player":
			indoor_rooms[current_room_id]["furniture"].append(indoor_moving_item)
			indoor_moving_item = {}
			_show_toast("已取消移动，家具已放回原位置")
			queue_redraw()
			return
		if indoor_edit_mode:
			indoor_edit_mode = false
			_update_indoor_hud()
			_show_toast("已退出室内装修模式")
			queue_redraw()
			return
		_reset_touch_states()
		_cancel_auto_path()
		_show_toast("已取消当前动作（走到底部房门或点「出门返回」可离开房间）")
		return
	if game_state == GameState.BUILD_MODE:
		if moving_picked_obj != ObjectType.NONE and is_valid_cell(moving_from_cell.x, moving_from_cell.y):
			object_grid[moving_from_cell.x][moving_from_cell.y] = moving_picked_obj
			moving_picked_obj = ObjectType.NONE
			moving_from_cell = Vector2i(-1, -1)
			_update_build_ui_labels()
			_show_toast("已取消移动，物体已放回原位置")
		elif has_pending_box:
			has_pending_box = false
			build_confirm_box_btn.visible = false
			_show_toast("已取消当前框选预览")
		elif is_camera_pan_mode:
			is_camera_pan_mode = false
			_update_build_ui_labels()
			_show_toast("已退出视角移动模式")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("已退出岛建模式，回到漫步状态")
	else:
		_reset_touch_states()
		_show_toast("已取消当前动作状态")

func _refresh_hotbar_ui() -> void:
	if hotbar_slots.is_empty():
		return
	for i in range(6):
		var slot: Dictionary = hotbar_slots[i]
		var btn: Button = slot["btn"]
		var icon_rect: TextureRect = slot["icon_rect"]
		var count_lbl: Label = slot["count_lbl"]
		var item_id: String = hotbar[i]
		var is_sel: bool = (i == selected_hotbar_index)

		var bg_col: Color = PAL_GOLD if is_sel else PAL_CREAM_DARK
		var border_col: Color = PAL_CORAL if is_sel else PAL_OUTLINE
		btn.add_theme_stylebox_override("normal", _make_storybook_panel_style(bg_col, border_col, 7))
		btn.add_theme_stylebox_override("pressed", _make_storybook_panel_style(bg_col.darkened(0.06), border_col, 7))
		btn.add_theme_stylebox_override("hover", _make_storybook_panel_style(bg_col, border_col, 7))

		if item_id != "" and ITEM_DB.has(item_id):
			var info: Dictionary = ITEM_DB[item_id]
			var cnt: int = int(inventory.get(item_id, 0))
			icon_rect.texture = _get_icon_tex(str(info["icon_key"]))
			icon_rect.visible = true
			if info.get("type", "") == "tool":
				count_lbl.text = ""
			else:
				count_lbl.text = str(cnt)
		else:
			icon_rect.texture = null
			icon_rect.visible = false
			count_lbl.text = ""

func _on_draw_hud_overlay() -> void:
	if game_state != GameState.EXPLORE_MODE or active_modal != null:
		return
	hud_overlay_draw.draw_circle(joy_center, joy_radius, Color(0.20, 0.18, 0.16, 0.38))
	hud_overlay_draw.draw_arc(joy_center, joy_radius, 0.0, TAU, 36, PAL_CREAM, 2.5)
	hud_overlay_draw.draw_circle(joy_knob_pos, 20.0, PAL_CREAM)
	hud_overlay_draw.draw_arc(joy_knob_pos, 20.0, 0.0, TAU, 24, PAL_OUTLINE, 2.0)

# ==============================================================================
# 模态弹窗系统（全部接入真实 PNG 图标，消除简陋文本按钮）
# ==============================================================================

func _create_modal_base(title_str: String, icon_key: String, panel_size: Vector2) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	ui_layer.add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.12, 0.10, 0.08, 0.52)
	root.add_child(dimmer)

	var panel := Panel.new()
	panel.size = panel_size
	panel.position = (get_viewport_rect().size - panel_size) * 0.5
	panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 12))
	root.add_child(panel)

	var header_box := HBoxContainer.new()
	header_box.position = Vector2(16, 10)
	header_box.add_theme_constant_override("separation", 6)
	panel.add_child(header_box)
	header_box.add_child(_make_small_icon_rect(icon_key, 24))

	var title_lbl := Label.new()
	title_lbl.text = title_str
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", PAL_WOOD)
	header_box.add_child(title_lbl)

	var close_btn: Button = _make_icon_label_btn("cancel_ui", "关闭", Vector2(74, 34), PAL_CORAL, false, 18)[0]
	close_btn.position = Vector2(panel_size.x - 84, 8)
	close_btn.pressed.connect(_close_active_modal)
	panel.add_child(close_btn)

	return [root, panel, title_lbl]

func _open_modal(modal: Control) -> void:
	_reset_touch_states()
	_cancel_auto_path()
	if active_modal != null:
		active_modal.visible = false
	active_modal = modal
	if active_modal != null:
		active_modal.visible = true
		_on_viewport_size_changed()
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

func _close_active_modal() -> void:
	if active_modal != null:
		active_modal.visible = false
		active_modal = null
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

func _build_all_modals() -> void:
	# 1. 背包弹窗（每个格子显示真实 PNG 物品图标 + 名称 + 数量）
	var bag_res: Array = _create_modal_base("小岛背包与快捷栏整理", "backpack_ui", Vector2(540, 304))
	bag_modal = bag_res[0]
	var bag_panel: Panel = bag_res[1]

	bag_grid_container = GridContainer.new()
	bag_grid_container.columns = 5
	bag_grid_container.position = Vector2(18, 48)
	bag_grid_container.add_theme_constant_override("h_separation", 8)
	bag_grid_container.add_theme_constant_override("v_separation", 8)
	bag_panel.add_child(bag_grid_container)

	var detail_box := HBoxContainer.new()
	detail_box.position = Vector2(18, 206)
	detail_box.add_theme_constant_override("separation", 8)
	bag_panel.add_child(detail_box)

	bag_detail_icon = _make_small_icon_rect("flower", 32)
	detail_box.add_child(bag_detail_icon)

	bag_detail_label = Label.new()
	bag_detail_label.custom_minimum_size = Vector2(460, 34)
	bag_detail_label.add_theme_font_size_override("font_size", 12)
	bag_detail_label.add_theme_color_override("font_color", PAL_OUTLINE)
	detail_box.add_child(bag_detail_label)

	var bag_assign_bar := HBoxContainer.new()
	bag_assign_bar.position = Vector2(18, 248)
	bag_assign_bar.add_theme_constant_override("separation", 6)
	bag_panel.add_child(bag_assign_bar)

	var use_in_bag_btn: Button = _make_icon_label_btn("use_tool_ui", "立即使用", Vector2(114, 38), PAL_GRASS, false, 18)[0]
	use_in_bag_btn.pressed.connect(func():
		if selected_bag_item_id == "":
			return
		hotbar[selected_hotbar_index] = selected_bag_item_id
		_refresh_hotbar_ui()
		_close_active_modal()
		if game_state != GameState.EXPLORE_MODE:
			_switch_game_state(GameState.EXPLORE_MODE)
		_on_use_tool_pressed()
	)
	bag_assign_bar.add_child(use_in_bag_btn)

	for s in range(6):
		var slot_idx: int = s
		var assign_btn := _make_touch_btn("放入槽" + str(s + 1), Vector2(58, 38), PAL_SAND, PAL_OUTLINE)
		assign_btn.pressed.connect(func():
			if selected_bag_item_id == "":
				_show_toast("请先点击上方网格中的一件物品")
				return
			hotbar[slot_idx] = selected_bag_item_id
			selected_hotbar_index = slot_idx
			_refresh_hotbar_ui()
			_show_toast("已将【" + str(ITEM_DB[selected_bag_item_id]["name"]) + "】放入快捷栏槽位 #" + str(slot_idx + 1))
		)
		bag_assign_bar.add_child(assign_btn)

	# 2. 完整岛屿地图弹窗
	var map_res: Array = _create_modal_base("小岛日记全景地图 (单指拖动查看)", "map_ui", Vector2(540, 310))
	map_modal = map_res[0]
	var map_panel: Panel = map_res[1]

	map_canvas = Control.new()
	map_canvas.position = Vector2(20, 48)
	map_canvas.size = Vector2(360, 246)
	map_canvas.clip_contents = true
	map_canvas.draw.connect(_on_draw_realtime_minimap)
	map_canvas.gui_input.connect(_on_minimap_gui_input)
	map_panel.add_child(map_canvas)

	var legend_lbl := Label.new()
	legend_lbl.position = Vector2(392, 52)
	legend_lbl.text = "【小岛区域图例】\n• 红点：你的当前位置\n• 黄点：8位动物居民\n• 红顶：温馨岛民小屋\n• 蓝顶：河畔杂货铺\n• 白圈：中央喷泉广场\n• 棕色：木桥与观海码头"
	legend_lbl.add_theme_font_size_override("font_size", 12)
	legend_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	map_panel.add_child(legend_lbl)

	var zoom_in_btn := _make_touch_btn("放大地图 (+)", Vector2(125, 38), PAL_SKY_BLUE, PAL_OUTLINE)
	zoom_in_btn.position = Vector2(392, 205)
	zoom_in_btn.pressed.connect(func():
		map_zoom = clampf(map_zoom + 0.35, 1.0, 2.4)
		map_canvas.queue_redraw()
	)
	map_panel.add_child(zoom_in_btn)

	var zoom_out_btn := _make_touch_btn("缩小/复位 (-)", Vector2(125, 38), PAL_SAND, PAL_OUTLINE)
	zoom_out_btn.position = Vector2(392, 250)
	zoom_out_btn.pressed.connect(func():
		map_zoom = 1.0
		map_pan_offset = Vector2.ZERO
		map_canvas.queue_redraw()
	)
	map_panel.add_child(zoom_out_btn)

	# 3. 综合菜单弹窗（全部接入真实 PNG 图标）
	var menu_res: Array = _create_modal_base("小岛日记系统菜单", "settings_ui", Vector2(340, 284))
	pause_menu_modal = menu_res[0]
	var menu_panel: Panel = menu_res[1]

	var m_bag: Button = _make_icon_label_btn("backpack_ui", "打开背包整理", Vector2(260, 38), PAL_SAND, false, 20)[0]
	m_bag.position = Vector2(40, 52)
	m_bag.pressed.connect(func(): _open_bag_modal())
	menu_panel.add_child(m_bag)

	var m_map: Button = _make_icon_label_btn("map_ui", "查看小岛全景地图", Vector2(260, 38), PAL_SKY_BLUE, false, 20)[0]
	m_map.position = Vector2(40, 96)
	m_map.pressed.connect(func(): _open_map_modal())
	menu_panel.add_child(m_map)

	var m_set: Button = _make_icon_label_btn("settings_ui", "画面与触控设置", Vector2(260, 38), PAL_CREAM_DARK, false, 20)[0]
	m_set.position = Vector2(40, 140)
	m_set.pressed.connect(func(): _open_modal(settings_modal))
	menu_panel.add_child(m_set)

	var m_save: Button = _make_icon_label_btn("confirm_ui", "立即保存日记进度", Vector2(260, 38), PAL_GRASS, false, 20)[0]
	m_save.position = Vector2(40, 184)
	m_save.pressed.connect(func():
		if _save_game():
			_close_active_modal()
			_show_toast("已安全保存全部岛屿地形、装饰与背包进度！")
	)
	menu_panel.add_child(m_save)

	var m_title: Button = _make_icon_label_btn("home_ui", "保存并返回标题画面", Vector2(260, 38), PAL_CORAL, false, 20)[0]
	m_title.position = Vector2(40, 228)
	m_title.pressed.connect(func():
		_ask_confirm("返回主菜单前会自动保存当前进度，确定返回吗？", func():
			_save_game()
			_close_active_modal()
			_switch_game_state(GameState.TITLE_SCREEN)
		)
	)
	menu_panel.add_child(m_title)

	# 4. 设置弹窗
	var set_res: Array = _create_modal_base("手机触控与画面设置", "settings", Vector2(440, 260))
	settings_modal = set_res[0]
	var set_panel: Panel = set_res[1]

	var zoom_lbl := Label.new()
	zoom_lbl.text = "镜头视野缩放:"
	zoom_lbl.position = Vector2(24, 62)
	zoom_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	set_panel.add_child(zoom_lbl)

	var zoom_slider := HSlider.new()
	zoom_slider.min_value = 0.85
	zoom_slider.max_value = 1.35
	zoom_slider.step = 0.05
	zoom_slider.value = setting_camera_zoom
	zoom_slider.position = Vector2(150, 64)
	zoom_slider.size = Vector2(240, 28)
	zoom_slider.value_changed.connect(func(val: float):
		setting_camera_zoom = val
		if camera != null and game_state == GameState.EXPLORE_MODE:
			camera.zoom = Vector2(val, val)
	)
	set_panel.add_child(zoom_slider)

	var spd_lbl := Label.new()
	spd_lbl.text = "角色漫步速度:"
	spd_lbl.position = Vector2(24, 112)
	spd_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	set_panel.add_child(spd_lbl)

	var spd_slider := HSlider.new()
	spd_slider.min_value = 0.8
	spd_slider.max_value = 1.5
	spd_slider.step = 0.1
	spd_slider.value = setting_move_speed_scale
	spd_slider.position = Vector2(150, 114)
	spd_slider.size = Vector2(240, 28)
	spd_slider.value_changed.connect(func(val: float): setting_move_speed_scale = val)
	set_panel.add_child(spd_slider)

	var grid_toggle_btn := _make_touch_btn("岛建辅助网格线：开启", Vector2(240, 40), PAL_SAND, PAL_OUTLINE)
	grid_toggle_btn.position = Vector2(100, 162)
	grid_toggle_btn.pressed.connect(func():
		setting_show_grid_in_build = not setting_show_grid_in_build
		grid_toggle_btn.text = "岛建辅助网格线：" + ("开启" if setting_show_grid_in_build else "关闭")
	)
	set_panel.add_child(grid_toggle_btn)

	var ai_btn := _make_touch_btn("查看居民 AI 状态", Vector2(240, 36), PAL_SKY_BLUE, PAL_OUTLINE)
	ai_btn.position = Vector2(100, 208)
	ai_btn.pressed.connect(func():
		_close_active_modal()
		_open_dialog_modal("居民状态（本地 AI）", _resident_debug_report())
	)
	set_panel.add_child(ai_btn)

	# 5. 商店弹窗（每个商品卡片均带有对应的真实 PNG 图标）
	var shop_res: Array = _create_modal_base("小岛温馨杂货铺", "shop_ui", Vector2(490, 286))
	shop_modal = shop_res[0]
	var shop_panel: Panel = shop_res[1]

	var shop_items: Array = ["flower_seed", "potted_plant", "bench_item", "lamp_item"]
	for idx in range(shop_items.size()):
		var sid: String = shop_items[idx]
		var sinfo: Dictionary = ITEM_DB[sid]
		var price: int = int(sinfo.get("price", 100))
		var buy_btn: Button = _make_icon_label_btn(str(sinfo["icon_key"]), "%s (-%d铃钱)" % [sinfo["name"], price], Vector2(214, 46), PAL_GRASS, false, 28)[0]
		buy_btn.position = Vector2(22 + (idx % 2) * 226, 58 + int(idx / 2) * 56)
		buy_btn.pressed.connect(func():
			if coins < price:
				_show_toast("铃钱不足，去海滩捡贝壳或钓鱼出售吧！")
				return
			coins -= price
			_add_item(sid, 1)
			_update_time_and_lighting()
			_show_toast("购买成功！获得【" + str(sinfo["name"]) + "】×1")
		)
		shop_panel.add_child(buy_btn)

	var sell_btn: Button = _make_icon_label_btn("coins_ui", "一键出售背包收集品 (贝壳/鱼/蝴蝶/木材)", Vector2(440, 48), PAL_SAND, false, 26)[0]
	sell_btn.position = Vector2(24, 186)
	sell_btn.pressed.connect(func():
		var earned: int = 0
		for sell_id in ["shell", "fish", "bug", "wood"]:
			var c: int = int(inventory.get(sell_id, 0))
			if c > 0:
				earned += c * int(ITEM_DB[sell_id].get("sell", 50))
				inventory.erase(sell_id)
		if earned > 0:
			coins += earned
			_refresh_hotbar_ui()
			_update_time_and_lighting()
			_show_toast("成功出售收集品，获得 %d 铃钱！" % earned)
		else:
			_show_toast("背包里暂时没有可出售的收集品哦")
	)
	shop_panel.add_child(sell_btn)

	# 6. 对话框弹窗（支持 8 位动物居民 5 种表情立绘展示与切换）
	var dlg_res: Array = _create_modal_base("岛民交谈", "mail_ui", Vector2(500, 236))
	dialog_modal = dlg_res[0]
	var dlg_panel: Panel = dlg_res[1]
	dialog_title_label = dlg_res[2]

	dialog_portrait_box = Panel.new()
	dialog_portrait_box.position = Vector2(18, 48)
	dialog_portrait_box.size = Vector2(92, 114)
	dialog_portrait_box.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM_DARK, PAL_OUTLINE, 8))
	dlg_panel.add_child(dialog_portrait_box)

	dialog_portrait_rect = TextureRect.new()
	dialog_portrait_rect.position = Vector2(8, 6)
	dialog_portrait_rect.size = Vector2(76, 76)
	dialog_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog_portrait_box.add_child(dialog_portrait_rect)

	dialog_expr_label = Label.new()
	dialog_expr_label.position = Vector2(4, 86)
	dialog_expr_label.size = Vector2(84, 22)
	dialog_expr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_expr_label.add_theme_font_size_override("font_size", 11)
	dialog_expr_label.add_theme_color_override("font_color", PAL_WOOD)
	dialog_portrait_box.add_child(dialog_expr_label)

	dialog_body_label = Label.new()
	dialog_body_label.position = Vector2(122, 50)
	dialog_body_label.size = Vector2(358, 108)
	dialog_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_body_label.add_theme_font_size_override("font_size", 13)
	dialog_body_label.add_theme_color_override("font_color", PAL_OUTLINE)
	dlg_panel.add_child(dialog_body_label)

	dialog_expr_bar = HBoxContainer.new()
	dialog_expr_bar.position = Vector2(18, 174)
	dialog_expr_bar.add_theme_constant_override("separation", 4)
	dlg_panel.add_child(dialog_expr_bar)
	for ex in PORTRAIT_EXPRS:
		var ex_str: String = str(ex)
		var ex_btn := _make_touch_btn(str(EXPR_CN_NAMES.get(ex_str, ex_str)), Vector2(54, 34), PAL_SAND, PAL_OUTLINE)
		ex_btn.pressed.connect(func():
			if dialog_char_id != "":
				_set_dialog_portrait(dialog_char_id, ex_str)
		)
		dialog_expr_bar.add_child(ex_btn)

	var dlg_ok: Button = _make_icon_label_btn("confirm_ui", "确定", Vector2(140, 38), PAL_GRASS, false, 20)[0]
	dlg_ok.position = Vector2(340, 172)
	dlg_ok.pressed.connect(_close_active_modal)
	dlg_panel.add_child(dlg_ok)

	# 7. 二次确认弹窗
	var cfm_res: Array = _create_modal_base("请确认操作", "settings_ui", Vector2(400, 190))
	confirm_modal = cfm_res[0]
	var cfm_panel: Panel = cfm_res[1]

	confirm_label = Label.new()
	confirm_label.position = Vector2(22, 54)
	confirm_label.size = Vector2(356, 68)
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.add_theme_font_size_override("font_size", 14)
	confirm_label.add_theme_color_override("font_color", PAL_OUTLINE)
	cfm_panel.add_child(confirm_label)

	var cfm_yes: Button = _make_icon_label_btn("confirm_ui", "确定", Vector2(140, 40), PAL_CORAL, false, 20)[0]
	cfm_yes.position = Vector2(48, 132)
	cfm_yes.pressed.connect(func():
		_close_active_modal()
		if confirm_yes_callable.is_valid():
			confirm_yes_callable.call()
	)
	cfm_panel.add_child(cfm_yes)

	var cfm_no: Button = _make_icon_label_btn("cancel_ui", "取消", Vector2(140, 40), PAL_SAND, false, 20)[0]
	cfm_no.position = Vector2(212, 132)
	cfm_no.pressed.connect(_close_active_modal)
	cfm_panel.add_child(cfm_no)

func _open_bag_modal() -> void:
	for child in bag_grid_container.get_children():
		child.queue_free()

	var keys: Array = inventory.keys()
	if selected_bag_item_id == "" and not keys.is_empty():
		selected_bag_item_id = str(keys[0])

	for item_id in keys:
		var cnt: int = int(inventory[item_id])
		if cnt <= 0 or not ITEM_DB.has(item_id):
			continue
		var info: Dictionary = ITEM_DB[item_id]
		var id_copy: String = str(item_id)
		var is_sel: bool = (id_copy == selected_bag_item_id)
		var btn_arr: Array = _make_icon_label_btn(str(info["icon_key"]), "%s x%d" % [info["name"], cnt], Vector2(96, 48), PAL_GOLD if is_sel else PAL_CREAM_DARK, true, 22)
		var item_btn: Button = btn_arr[0]
		item_btn.pressed.connect(func():
			selected_bag_item_id = id_copy
			_open_bag_modal()
		)
		bag_grid_container.add_child(item_btn)

	if selected_bag_item_id != "" and ITEM_DB.has(selected_bag_item_id):
		var d_info: Dictionary = ITEM_DB[selected_bag_item_id]
		bag_detail_icon.texture = _get_icon_tex(str(d_info["icon_key"]))
		bag_detail_label.text = "【%s】 — %s" % [d_info["name"], d_info["desc"]]
	else:
		bag_detail_label.text = "点击上方物品查看说明并放入底部快捷栏"

	_open_modal(bag_modal)

func _open_map_modal() -> void:
	_open_modal(map_modal)
	map_canvas.queue_redraw()

func _open_shop_modal() -> void:
	_open_modal(shop_modal)

func _select_resident_expression(a: Dictionary, received_gift: bool = false) -> String:
	if received_gift:
		return "shy" if int(a.get("affinity", 20)) >= 50 else "happy"
	var n: Dictionary = a.get("needs", {})
	if float(n.get("energy", 0.8)) < 0.32 or str(a.get("action", "")) == "rest":
		return "sleepy"
	if int(a.get("affinity", 20)) >= 65:
		return "happy" if (randi() % 2 == 0) else "shy"
	if float(n.get("fun", 0.6)) > 0.68:
		return "happy"
	if float(a.get("personality", {}).get("curiosity", 0.5)) >= 0.80 and randf() < 0.45:
		return "surprised"
	return "neutral"

func _set_dialog_portrait(char_id: String, expr: String) -> void:
	dialog_char_id = char_id
	dialog_curr_expr = expr if expr in PORTRAIT_EXPRS else "neutral"
	if dialog_portrait_rect != null:
		dialog_portrait_rect.texture = _get_portrait_tex(dialog_char_id, dialog_curr_expr)
	if dialog_expr_label != null:
		dialog_expr_label.text = "表情·%s" % str(EXPR_CN_NAMES.get(dialog_curr_expr, "普通"))

func _open_dialog_modal(title_str: String, body_str: String, char_id: String = "", expr: String = "neutral") -> void:
	dialog_title_label.text = title_str
	dialog_body_label.text = body_str
	var has_portrait: bool = (char_id != "")
	if dialog_portrait_box != null:
		dialog_portrait_box.visible = has_portrait
	if dialog_expr_bar != null:
		dialog_expr_bar.visible = has_portrait
	if has_portrait:
		_set_dialog_portrait(char_id, expr)
		dialog_body_label.position = Vector2(122, 50)
		dialog_body_label.size = Vector2(358, 108)
	else:
		dialog_char_id = ""
		dialog_body_label.position = Vector2(22, 50)
		dialog_body_label.size = Vector2(456, 112)
	_open_modal(dialog_modal)

func _ask_confirm(prompt_str: String, on_yes: Callable) -> void:
	confirm_label.text = prompt_str
	confirm_yes_callable = on_yes
	_open_modal(confirm_modal)

# ==============================================================================
# 实时同步岛屿大地图绘制与触屏拖动缩放
# ==============================================================================

func _on_minimap_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		map_pan_offset += drag.relative
		var max_pan: float = 160.0 * map_zoom
		map_pan_offset.x = clampf(map_pan_offset.x, -max_pan, max_pan)
		map_pan_offset.y = clampf(map_pan_offset.y, -max_pan, max_pan)
		map_canvas.queue_redraw()

func _on_draw_realtime_minimap() -> void:
	var fit_px: float = minf(map_canvas.size.x / float(GRID_WIDTH), map_canvas.size.y / float(GRID_HEIGHT))
	var cell_px: float = fit_px * map_zoom
	var total_w: float = GRID_WIDTH * cell_px
	var total_h: float = GRID_HEIGHT * cell_px
	var start_origin: Vector2 = (map_canvas.size - Vector2(total_w, total_h)) * 0.5 + map_pan_offset

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var r := Rect2(start_origin.x + x * cell_px, start_origin.y + y * cell_px, cell_px + 0.5, cell_px + 0.5)
			var g_col: Color = _get_ground_color(ground_grid[x][y], elevation_grid[x][y], false)
			map_canvas.draw_rect(r, g_col, true)

			var obj: int = object_grid[x][y]
			if obj in [ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE]:
				map_canvas.draw_rect(r.grow(1.5), PAL_CORAL, true)
			elif obj == ObjectType.SHOP:
				map_canvas.draw_rect(r.grow(1.5), PAL_OCEAN_BLUE, true)
			elif obj == ObjectType.FOUNTAIN:
				map_canvas.draw_rect(r.grow(1.2), PAL_CREAM, true)
			elif obj in [ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM]:
				map_canvas.draw_rect(r, PAL_FOREST, true)

	for a in animals:
		var ac: Vector2i = world_to_grid(a["pos"])
		var ap := Vector2(start_origin.x + (ac.x + 0.5) * cell_px, start_origin.y + (ac.y + 0.5) * cell_px)
		map_canvas.draw_circle(ap, 3.0 * map_zoom, PAL_GOLD)

	var pc: Vector2i = world_to_grid(player_pos)
	var pp := Vector2(start_origin.x + (pc.x + 0.5) * cell_px, start_origin.y + (pc.y + 0.5) * cell_px)
	map_canvas.draw_circle(pp, 4.0 * map_zoom, PAL_CORAL)
	map_canvas.draw_arc(pp, 5.0 * map_zoom, 0, TAU, 16, PAL_CREAM, 1.5)

# ==============================================================================
# 现实时间、四季、昼夜光影与全面屏无留白自适应布局
# ==============================================================================

func _update_time_and_lighting() -> void:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var month: int = int(dt.get("month", 10))
	var h: int = int(dt.get("hour", 12))
	clock_hour = h
	var mi: int = int(dt.get("minute", 0))

	var season: String = "秋"
	if month in [3, 4, 5]: season = "春"
	elif month in [6, 7, 8]: season = "夏"
	elif month in [9, 10, 11]: season = "秋"
	else: season = "冬"

	var period: String = "夜晚"
	if h >= 5 and h < 8: period = "清晨"
	elif h >= 8 and h < 17: period = "白天"
	elif h >= 17 and h < 20: period = "黄昏"

	if top_time_label != null:
		top_time_label.text = "%02d月%02d日 %02d:%02d (%s·%s)" % [month, int(dt.get("day", 1)), h, mi, season, period]
	if top_coin_label != null:
		top_coin_label.text = "%d" % coins

	var t: float = float(h) + float(mi) / 60.0
	if t >= 5.0 and t < 8.0:
		canvas_modulate.color = Color(0.98, 0.91, 0.84).lerp(Color.WHITE, (t - 5.0) / 3.0)
	elif t >= 8.0 and t < 17.0:
		canvas_modulate.color = Color.WHITE
	elif t >= 17.0 and t < 19.5:
		canvas_modulate.color = Color.WHITE.lerp(Color(0.98, 0.80, 0.68), (t - 17.0) / 2.5)
	elif t >= 19.5 and t < 21.0:
		canvas_modulate.color = Color(0.98, 0.80, 0.68).lerp(Color(0.60, 0.66, 0.86), (t - 19.5) / 1.5)
	else:
		canvas_modulate.color = Color(0.60, 0.66, 0.86)

func _on_viewport_size_changed() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var w: float = maxf(640.0, vp_size.x)
	var h: float = maxf(360.0, vp_size.y)

	if title_panel != null:
		title_panel.size = vp_size
	if title_bg_rect != null:
		title_bg_rect.size = vp_size
	if title_card_panel != null:
		title_card_panel.position = (vp_size - title_card_panel.size) * 0.5

	if hud_root != null:
		hud_root.size = vp_size
	if hud_overlay_draw != null:
		hud_overlay_draw.size = vp_size

	# 左下角摇杆始终锚定在屏幕左下安全区
	joy_center = Vector2(88.0, h - 84.0)
	if joy_touch_index == -1:
		joy_knob_pos = joy_center

	# 顶部右侧图标按钮栏贴靠屏幕右上安全区
	if top_right_bar != null:
		top_right_bar.position = Vector2(w - 298.0, 8.0)

	# 底部 6 槽快捷栏水平居中
	if hotbar_panel != null:
		hotbar_panel.position = Vector2((w - hotbar_panel.size.x) * 0.5, h - 62.0)

	# 右侧操作按钮贴靠右缘安全区
	if right_action_box != null:
		right_action_box.position = Vector2(w - 98.0, h - 208.0)

	# 岛建工具栏自适应居中与右对齐
	if build_bottom_panel != null:
		build_bottom_panel.position = Vector2((w - 110.0 - build_bottom_panel.size.x) * 0.5, h - 80.0)
	if build_right_box != null:
		build_right_box.position = Vector2(w - 104.0, 48.0)

	if toast_panel != null:
		toast_panel.position = Vector2((w - toast_panel.size.x) * 0.5, 48.0)

	# 居中当前打开的模态弹窗
	if active_modal != null:
		active_modal.size = vp_size
		for child in active_modal.get_children():
			if child is ColorRect:
				child.size = vp_size
			elif child is Panel:
				child.position = (vp_size - child.size) * 0.5

func _show_toast(msg: String) -> void:
	if toast_label != null and toast_panel != null:
		toast_label.text = msg
		toast_panel.visible = true
	toast_timer = 3.2

# ==============================================================================
# 本地安全存档系统
# ==============================================================================

func _get_logical_day_key() -> String:
	var unix_sec: int = int(Time.get_unix_time_from_system())
	var tz: Dictionary = Time.get_time_zone_from_system()
	var local_sec: int = unix_sec + int(tz.get("bias", 0)) * 60
	var shifted_dt: Dictionary = Time.get_datetime_dict_from_unix_time(local_sec - 18000)
	return "%04d-%02d-%02d" % [
		int(shifted_dt.get("year", 2026)),
		int(shifted_dt.get("month", 1)),
		int(shifted_dt.get("day", 1))
	]

func _check_day_rollover() -> void:
	var k: String = _get_logical_day_key()
	if cached_day_key == "":
		cached_day_key = k
		return
	if k > cached_day_key:
		cached_day_key = k
		var done: int = _finish_all_constructions()
		if done > 0:
			_show_toast("新的一天开始了！%d 座建筑已经落成" % done)
			_save_game()
		_grow_crops_on_new_day()

func _save_game() -> bool:
	var residents_state: Array = []
	for a in animals:
		residents_state.append({
			"id": str(a["id"]),
			"pos": {"x": snappedf((a["pos"] as Vector2).x, 0.1), "y": snappedf((a["pos"] as Vector2).y, 0.1)},
			"affinity": int(a["affinity"]),
			"knowledge": float(a["knowledge"]),
			"needs": a["needs"],
			"relations": a["relations"],
			"memory": a["memory"]
		})
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"logical_day_key": _get_logical_day_key(),
		"coins": coins,
		"player": {"x": snappedf((outdoor_pos if in_interior else player_pos).x, 0.1), "y": snappedf((outdoor_pos if in_interior else player_pos).y, 0.1)},
		"inventory": inventory,
		"hotbar": hotbar,
		"selected_hotbar_index": selected_hotbar_index,
		"player_knowledge": player_knowledge,
		"crops": crops,
		"caught_fish": caught_fish,
		"indoor_rooms": indoor_rooms,
		"residents": residents_state,
		"settings": {
			"camera_zoom": setting_camera_zoom,
			"move_speed_scale": setting_move_speed_scale,
			"show_grid_in_build": setting_show_grid_in_build
		},
		"ground_grid": ground_grid,
		"elevation_grid": elevation_grid,
		"object_grid": object_grid
	}
	var payload: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[存档] 无法写入临时文件，本次保存失败")
		return false
	file.store_string(payload)
	file.flush()
	file.close()

	# 回读校验：写进去的内容必须能被重新解析，且三层网格形状完整，否则不覆盖正式存档
	var verify: String = FileAccess.get_file_as_string(TEMP_SAVE_PATH)
	if verify != payload:
		push_warning("[存档] 回读内容与写入不一致，放弃本次保存")
		return false
	var check: Variant = JSON.parse_string(verify)
	if typeof(check) != TYPE_DICTIONARY:
		push_warning("[存档] 回读 JSON 解析失败，放弃本次保存")
		return false
	var ck: Dictionary = check
	if not _grid_shape_ok(ck.get("ground_grid", null)) \
		or not _grid_shape_ok(ck.get("elevation_grid", null)) \
		or not _grid_shape_ok(ck.get("object_grid", null)):
		push_warning("[存档] 回读网格形状不合法，放弃本次保存")
		return false

	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	# 正式存档先降级为 .bak，再把临时文件扶正，任何一步失败都回滚到上一次可用存档
	if dir.file_exists(SAVE_PATH):
		if dir.file_exists(BAK_SAVE_PATH):
			dir.remove(BAK_SAVE_PATH)
		if dir.rename(SAVE_PATH, BAK_SAVE_PATH) != OK:
			push_warning("[存档] 备份旧存档失败，放弃本次保存")
			return false
	if dir.rename(TEMP_SAVE_PATH, SAVE_PATH) != OK:
		push_warning("[存档] 临时文件转正失败，回滚到旧存档")
		if dir.file_exists(BAK_SAVE_PATH) and not dir.file_exists(SAVE_PATH):
			dir.rename(BAK_SAVE_PATH, SAVE_PATH)
		return false
	return true

func _grid_shape_ok(grid: Variant) -> bool:
	if typeof(grid) != TYPE_ARRAY or grid.size() != GRID_WIDTH:
		return false
	for x in range(GRID_WIDTH):
		var col: Variant = grid[x]
		if typeof(col) != TYPE_ARRAY or col.size() != GRID_HEIGHT:
			return false
	return true

func _read_save_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return null
	return JSON.parse_string(text)

func _finish_all_constructions() -> int:
	var finished: int = 0
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if int(object_grid[x][y]) == ObjectType.CONSTRUCTION:
				object_grid[x][y] = ObjectType.VILLAGER_HOUSE
				finished += 1
	return finished

func _load_game() -> void:
	# 主存档坏了就退到 .bak，避免一次写坏就永久开不了游戏
	var parsed: Variant = _read_save_file(SAVE_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = _read_save_file(BAK_SAVE_PATH)
		if typeof(parsed) == TYPE_DICTIONARY:
			_show_toast("主存档损坏，已自动读取上一次的备份存档")
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	# v4 及更早的存档没有友谊/设置字段：按默认值补齐，不做破坏性迁移
	coins = maxi(0, int(data.get("coins", 1800)))

	if data.has("inventory") and typeof(data["inventory"]) == TYPE_DICTIONARY:
		var inv: Dictionary = data["inventory"]
		for k in inv.keys():
			if ITEM_DB.has(str(k)):
				inventory[str(k)] = maxi(0, int(inv[k]))

	if data.has("hotbar") and typeof(data["hotbar"]) == TYPE_ARRAY and data["hotbar"].size() == 6:
		var hb: Array = data["hotbar"]
		for i in range(6):
			hotbar[i] = str(hb[i])

	player_knowledge = maxi(0, int(data.get("player_knowledge", 0)))
	if data.has("caught_fish") and typeof(data["caught_fish"]) == TYPE_DICTIONARY:
		caught_fish.clear()
		var cf: Dictionary = data["caught_fish"]
		for k in cf.keys():
			if FISH_DB.has(str(k)):
				caught_fish[str(k)] = maxi(0, int(cf[k]))

	if data.has("crops") and typeof(data["crops"]) == TYPE_DICTIONARY:
		crops.clear()
		var cds: Dictionary = data["crops"]
		for k in cds.keys():
			if typeof(cds[k]) == TYPE_DICTIONARY:
				var cd: Dictionary = cds[k]
				crops[str(k)] = {
					"id": str(cd.get("id", "carrot")),
					"stage": maxi(0, int(cd.get("stage", 0))),
					"watered": bool(cd.get("watered", false)),
					"day": str(cd.get("day", ""))
				}
		var today_key: String = _get_logical_day_key()
		for k in crops.keys():
			var c2: Dictionary = crops[k]
			if str(c2.get("day", "")) != "" and today_key > str(c2.get("day", "")) and bool(c2.get("watered", false)):
				c2["stage"] = int(c2["stage"]) + 1
				c2["watered"] = false
				c2["day"] = today_key
				crops[k] = c2

	if data.has("selected_hotbar_index"):
		selected_hotbar_index = clampi(int(data["selected_hotbar_index"]), 0, 5)

	_init_residents()
	# v6 及更早只有 friendship 数组：迁移成与玩家的好感度
	if data.has("friendship") and typeof(data["friendship"]) == TYPE_ARRAY:
		var fs: Array = data["friendship"]
		for i in range(animals.size()):
			if i < fs.size():
				animals[i]["affinity"] = clampi(20 + int(fs[i]) * 6, 0, 100)
	if data.has("residents") and typeof(data["residents"]) == TYPE_ARRAY:
		for item in data["residents"]:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var rid: String = str(item.get("id", ""))
			if rid == "penguin":
				rid = "otter"
			for j in range(animals.size()):
				if str(animals[j]["id"]) != rid:
					continue
				var a2: Dictionary = animals[j]
				a2["affinity"] = clampi(int(item.get("affinity", 20)), 0, 100)
				a2["knowledge"] = float(item.get("knowledge", 0.0))
				if item.has("needs") and typeof(item["needs"]) == TYPE_DICTIONARY:
					var nd: Dictionary = item["needs"]
					for k in ["social", "fun", "energy", "hunger"]:
						a2["needs"][k] = clampf(float(nd.get(k, a2["needs"][k])), 0.0, 1.0)
				if item.has("relations") and typeof(item["relations"]) == TYPE_DICTIONARY:
					a2["relations"] = item["relations"]
				if item.has("memory") and typeof(item["memory"]) == TYPE_ARRAY:
					a2["memory"] = item["memory"]
				if item.has("pos") and typeof(item["pos"]) == TYPE_DICTIONARY:
					var pp: Dictionary = item["pos"]
					var pt := Vector2(float(pp.get("x", a2["pos"].x)), float(pp.get("y", a2["pos"].y)))
					var ptc: Vector2i = world_to_grid(pt)
					if is_cell_walkable(ptc.x, ptc.y, false):
						a2["pos"] = pt

	if data.has("settings") and typeof(data["settings"]) == TYPE_DICTIONARY:
		var st: Dictionary = data["settings"]
		setting_camera_zoom = clampf(float(st.get("camera_zoom", 1.0)), 0.7, 2.0)
		setting_move_speed_scale = clampf(float(st.get("move_speed_scale", 1.0)), 0.6, 1.6)
		setting_show_grid_in_build = bool(st.get("show_grid_in_build", true))

	# 旧版 44×44 地图存档：地图结构变了，保留进度（金币/背包/好感/设置），岛屿按新版本重建
	var legacy_map: bool = false
	if data.has("ground_grid") and typeof(data["ground_grid"]) == TYPE_ARRAY:
		if (data["ground_grid"] as Array).size() == LEGACY_GRID_SIZE:
			legacy_map = true
	if legacy_map:
		var legacy_copy: String = "user://little_island_diary_save_legacy44.json"
		if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(legacy_copy):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(legacy_copy))
		_init_default_island()
		_show_toast("旧版 44×44 地图存档：进度已保留，岛屿已扩建为 64×64（旧档另存为 legacy44）")

	if _grid_shape_ok(data.get("ground_grid", null)) \
		and _grid_shape_ok(data.get("elevation_grid", null)) \
		and _grid_shape_ok(data.get("object_grid", null)):
		var gg: Array = data["ground_grid"]
		var eg: Array = data["elevation_grid"]
		var og: Array = data["object_grid"]
		for x in range(GRID_WIDTH):
			for y in range(GRID_HEIGHT):
				# 逐格 clamp，坏档最多表现为局部默认地形，不会数组越界崩溃
				ground_grid[x][y] = clampi(int(gg[x][y]), 0, GroundType.TILLED_SOIL)
				elevation_grid[x][y] = clampi(int(eg[x][y]), 0, 2)
				object_grid[x][y] = clampi(int(og[x][y]), 0, ObjectType.DISPLAY_CASE)
		# 确保 8 位居民的小屋在旧存档升级后同样存在于岛上
		for vh_id in VILLAGER_HOUSE_CELLS.keys():
			var vhc: Vector2i = VILLAGER_HOUSE_CELLS[vh_id]
			if is_valid_cell(vhc.x, vhc.y) and object_grid[vhc.x][vhc.y] == ObjectType.NONE:
				ground_grid[vhc.x][vhc.y] = GroundType.GRASS
				elevation_grid[vhc.x][vhc.y] = 1
				object_grid[vhc.x][vhc.y] = ObjectType.VILLAGER_HOUSE

	var saved_day: String = str(data.get("logical_day_key", ""))
	if saved_day != "" and _get_logical_day_key() > saved_day:
		var done: int = _finish_all_constructions()
		if done > 0:
			_show_toast("施工完成！%d 座新建筑在清晨落成" % done)

	_init_indoor_rooms()
	player_floor = clampi(int(data.get("player_floor", 1)), 1, 2)
	player_shirt_idx = clampi(int(data.get("player_shirt_idx", 0)), 0, SHIRT_COLORS.size() - 1)
	player_hat_idx = clampi(int(data.get("player_hat_idx", 0)), 0, HAT_NAMES.size() - 1)
	ai_enabled = bool(data.get("ai_enabled", false))

	if data.has("storage_box_items") and typeof(data["storage_box_items"]) == TYPE_DICTIONARY:
		storage_box_items = data["storage_box_items"]
	if data.has("fridge_items") and typeof(data["fridge_items"]) == TYPE_DICTIONARY:
		fridge_items = data["fridge_items"]

	if data.has("indoor_rooms") and typeof(data["indoor_rooms"]) == TYPE_DICTIONARY:
		var saved_rooms: Dictionary = data["indoor_rooms"]
		for rk in ["player", "player_2f"]:
			if saved_rooms.has(rk) and typeof(saved_rooms[rk]) == TYPE_DICTIONARY:
				var pr: Dictionary = saved_rooms[rk]
				if pr.has("furniture") and typeof(pr["furniture"]) == TYPE_ARRAY:
					indoor_rooms[rk]["furniture"] = pr["furniture"]

	if data.has("player") and typeof(data["player"]) == TYPE_DICTIONARY:
		var p: Dictionary = data["player"]
		var saved_pt := Vector2(float(p.get("x", player_pos.x)), float(p.get("y", player_pos.y)))
		var c: Vector2i = world_to_grid(saved_pt)
		if is_cell_walkable(c.x, c.y):
			player_pos = saved_pt

	cached_day_key = _get_logical_day_key()
	_refresh_hotbar_ui()
	_update_time_and_lighting()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_reset_touch_states()
		if game_state != GameState.TITLE_SCREEN:
			_save_game()
