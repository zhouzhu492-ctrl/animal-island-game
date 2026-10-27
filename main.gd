extends Node2D

# ==============================================================================
# 《小岛日记 (Little Island Diary)》 —— Cozy Storybook Pixel Art 手机触屏升级版
# 视觉与核心系统全面贯彻《小岛日记》设定集 V1.0：
# 1. 官方锁定色板：暖奶油色 #FFF2D6、天空蓝 #74C9ED、海洋蓝 #379CC9、草地绿 #83C96D、
#    森林绿 #39815D、沙滩黄 #F5DDA1、泥土棕 #B98761、木棕 #8A5B45、花卉粉 #EE8398、
#    珊瑚橙 #F08A61、暖深棕描边 #544A44
# 2. 地形自动过渡边缘：草地->沙滩自然圆角/锯齿过渡、浅水白沫岸线、二层高地岩壁与顶缘高光
# 3. 精细绘本像素物体：中央喷泉、信箱、木质指示牌、花坛、圆润多层果树、红顶小屋、蓝顶杂货铺
# 4. 5 位原创小动物邻居（兔子莉莉、猫咪奈奈、狐狸阿洛、小熊布朗、企鹅波波），带暖棕轮廓与呼吸步态
# 5. 环境动态特效：水面微光波纹、微风落叶、夜晚萤火虫、挖掘/浇水/放置闪烁粒子
# 6. 100% 手机横屏绘本风 UI：奶油色圆角面板、深棕文字、左下虚拟摇杆、底部 6 槽手绘像素图标快捷栏、
#    右侧大拇指交互按钮、支持画笔大小(1x1/2x2/3x3)+矩形框选+一键撤销的岛建工具栏
# ==============================================================================

const GRID_WIDTH: int = 36
const GRID_HEIGHT: int = 36
const TILE_SIZE: int = 16
const SAVE_PATH: String = "user://little_island_diary_save_v1.json"
const TEMP_SAVE_PATH: String = "user://little_island_diary_save_v1.tmp"

# --- 《小岛日记》V1.0 核心锁定色板 ---
const PAL_CREAM      := Color("#FFF2D6")
const PAL_CREAM_DARK := Color("#F2DEC0")
const PAL_SKY_BLUE   := Color("#74C9ED")
const PAL_OCEAN_BLUE := Color("#379CC9")
const PAL_GRASS      := Color("#83C96D")
const PAL_GRASS_ALT  := Color("#78BE62")
const PAL_HIGH_GRASS := Color("#91D47A")
const PAL_FOREST     := Color("#39815D")
const PAL_SAND       := Color("#F5DDA1")
const PAL_SAND_ALT   := Color("#EBD193")
const PAL_EARTH      := Color("#B98761")
const PAL_WOOD       := Color("#8A5B45")
const PAL_PINK       := Color("#EE8398")
const PAL_CORAL      := Color("#F08A61")
const PAL_OUTLINE    := Color("#544A44")

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
	TREE = 1,
	FLOWER_RED = 2,
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
	SIGNBOARD = 16
}

enum BuildTool {
	GROUND_GRASS = 0,
	FLATTEN = 1,
	CLIFF_RAISE = 2,
	RIVER_DIG = 3,
	ROAD_PAVE = 4,
	PLANT_PUT = 5,
	DECOR_PUT = 6,
	BUILDING_PUT = 7
}

# --- 核心游戏状态 ---
var game_state: int = GameState.TITLE_SCREEN
var coins: int = 1500
var env_anim_time: float = 0.0

# --- 地图与地形三维状态 ---
var ground_grid: Array = []     # [x][y] -> GroundType
var elevation_grid: Array = []  # [x][y] -> 0:水面, 1:平地, 2:二层高地
var object_grid: Array = []     # [x][y] -> ObjectType

# --- 玩家角色与摄像机 ---
var player_pos: Vector2 = Vector2(18.5 * TILE_SIZE, 19.5 * TILE_SIZE)
var player_facing: Vector2 = Vector2.DOWN
var walk_anim_time: float = 0.0
var tool_swing_timer: float = 0.0
const BASE_MOVE_SPEED: float = 88.0
const COLLISION_HALF_SIZE: Vector2 = Vector2(4.2, 4.2)
var camera: Camera2D

# --- 《小岛日记》5 位原创小动物居民（造型、耳朵、尾巴、性格与台词各不相同） ---
var animals: Array = [
	{
		"id": "rabbit",
		"name": "兔子莉莉",
		"trait": "温柔",
		"pos": Vector2(15.5 * TILE_SIZE, 17.5 * TILE_SIZE),
		"home": Vector2(15.5 * TILE_SIZE, 17.5 * TILE_SIZE),
		"target": Vector2(15.5 * TILE_SIZE, 17.5 * TILE_SIZE),
		"body_col": Color("#FFF9F5"),
		"ear_col": Color("#EE8398"),
		"shirt_col": Color("#EE8398"),
		"wait_timer": 2.0,
		"friendship": 1,
		"dialogs": [
			"欢迎来到《小岛日记》！看到广场中央的喷泉了吗？水花在阳光下一闪一闪的真好看~",
			"我最喜欢在花坛旁边散步啦，如果你用【浇水壶】给花朵浇水，它们会开得更灿烂哦！",
			"在【岛建模式】里不仅能切换1格、2格、3格画笔，还能用【框选】一次性铺满整座花园呢！"
		]
	},
	{
		"id": "cat",
		"name": "猫咪奈奈",
		"trait": "活泼",
		"pos": Vector2(21.5 * TILE_SIZE, 18.5 * TILE_SIZE),
		"home": Vector2(21.5 * TILE_SIZE, 18.5 * TILE_SIZE),
		"target": Vector2(21.5 * TILE_SIZE, 18.5 * TILE_SIZE),
		"body_col": Color("#F5B06C"),
		"ear_col": Color("#D97A3E"),
		"shirt_col": Color("#74C9ED"),
		"wait_timer": 3.2,
		"friendship": 1,
		"dialogs": [
			"喵呜~ 海滩上冲上来了好多粉色的【海贝壳】，靠近点右侧的【拾取】就能收进背包啦！",
			"听说河里有许多【小海鱼】，拿着底部快捷栏里的【钓鱼竿】去河边试试手气吧！",
			"哪怕你忙得隔好几天才上线，我们也都在岛上开心地生活，随时欢迎你回来！"
		]
	},
	{
		"id": "fox",
		"name": "狐狸阿洛",
		"trait": "独立",
		"pos": Vector2(13.5 * TILE_SIZE, 22.5 * TILE_SIZE),
		"home": Vector2(13.5 * TILE_SIZE, 22.5 * TILE_SIZE),
		"target": Vector2(13.5 * TILE_SIZE, 22.5 * TILE_SIZE),
		"body_col": Color("#F08A61"),
		"ear_col": Color("#544A44"),
		"shirt_col": Color("#39815D"),
		"wait_timer": 4.0,
		"friendship": 1,
		"dialogs": [
			"黄昏和夜晚的时候，岛上的复古路灯会亮起暖光，草丛间还会飞起萤火虫呢。",
			"点击顶部【地图】可以随时查看全岛地形，还能用手指拖动和放大观察每一个角落。",
			"想改造河道或堆高悬崖的话，随时点右上角的【岛建】，不满意点【撤销】就能一键恢复。"
		]
	},
	{
		"id": "bear",
		"name": "小熊布朗",
		"trait": "憨厚",
		"pos": Vector2(24.5 * TILE_SIZE, 16.5 * TILE_SIZE),
		"home": Vector2(24.5 * TILE_SIZE, 16.5 * TILE_SIZE),
		"target": Vector2(24.5 * TILE_SIZE, 16.5 * TILE_SIZE),
		"body_col": Color("#B98761"),
		"ear_col": Color("#8A5B45"),
		"shirt_col": Color("#F5DDA1"),
		"wait_timer": 2.8,
		"friendship": 1,
		"dialogs": [
			"呼呼~ 我最喜欢坐在长椅上吃甜甜的【海岛苹果】了，用斧头摇树就能收获木材和苹果哦！",
			"北边的【杂货铺】里新进了花坛、喷泉、街灯和木长椅，卖掉贝壳或小鱼就能换好多铃钱！",
			"在属于自己的小岛上，慢慢生活，这才是最舒服的日子呀。"
		]
	},
	{
		"id": "penguin",
		"name": "企鹅波波",
		"trait": "开朗",
		"pos": Vector2(19.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"home": Vector2(19.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"target": Vector2(19.5 * TILE_SIZE, 25.5 * TILE_SIZE),
		"body_col": Color("#5B9BD5"),
		"ear_col": Color("#379CC9"),
		"shirt_col": Color("#F08A61"),
		"wait_timer": 3.6,
		"friendship": 1,
		"dialogs": [
			"噗噗！南边的海滩浅水区踩上去凉丝丝的，海浪拍岸的声音特别治愈！",
			"你可以在沙滩旁摆上木长椅和指示牌，打造属于你的海滨度假角！",
			"要是建错了地方完全别慌，岛建模式右上角的【撤销】按钮超级好用！"
		]
	}
]

# --- 环境粒子与交互特效 ---
var ambient_particles: Array = [] # 飘落树叶 / 夜晚萤火虫
var burst_particles: Array = []   # 挖掘泥土 / 浇水 / 放置星星反馈

# --- 物品数据库与真实背包/快捷栏 ---
const ITEM_DB: Dictionary = {
	"shovel": {"name": "铁铲", "icon": "铲", "type": "tool", "color": PAL_EARTH, "desc": "挖掘泥土、清除杂草与移植花木（无耐久限制）"},
	"axe": {"name": "伐木斧", "icon": "斧", "type": "tool", "color": PAL_CORAL, "desc": "砍伐或修剪树木获得木材与苹果（无耐久限制）"},
	"watering_can": {"name": "浇水壶", "icon": "壶", "type": "tool", "color": PAL_SKY_BLUE, "desc": "给鲜花浇水，让花朵绽放晶莹光泽"},
	"net": {"name": "捕虫网", "icon": "网", "type": "tool", "color": PAL_GRASS, "desc": "在花丛与草地间挥网捕捉蝴蝶"},
	"rod": {"name": "钓鱼竿", "icon": "竿", "type": "tool", "color": PAL_OCEAN_BLUE, "desc": "面朝河流或大海抛竿垂钓"},
	"flower_seed": {"name": "鲜花苗", "icon": "花", "type": "placeable", "obj_id": ObjectType.FLOWER_RED, "color": PAL_PINK, "desc": "可在草地上直接种植缤纷花丛", "price": 40},
	"bush_seed": {"name": "灌木苗", "icon": "灌", "type": "placeable", "obj_id": ObjectType.BUSH, "color": PAL_FOREST, "desc": "圆润饱满的四季常青灌木", "price": 60},
	"planter_item": {"name": "精致花坛", "icon": "坛", "type": "placeable", "obj_id": ObjectType.FLOWER_PLANTER, "color": PAL_CORAL, "desc": "木框装点的盛开花坛，适合装扮广场", "price": 150},
	"bench_item": {"name": "木长椅", "icon": "椅", "type": "placeable", "obj_id": ObjectType.BENCH, "color": PAL_WOOD, "desc": "温暖的双人木制长椅，可坐下小憩", "price": 180},
	"lamp_item": {"name": "复古街灯", "icon": "灯", "type": "placeable", "obj_id": ObjectType.LAMP, "color": Color("#F7D460"), "desc": "傍晚与夜晚会自动亮起温暖光晕的路灯", "price": 220},
	"wood": {"name": "木材", "icon": "木", "type": "material", "color": PAL_WOOD, "desc": "散发松木清香的木材，可出售换取铃钱", "sell": 45},
	"shell": {"name": "海贝壳", "icon": "贝", "type": "material", "color": PAL_PINK, "desc": "海浪冲上沙滩的粉色扇贝，可在商店出售", "sell": 65},
	"fish": {"name": "小海鱼", "icon": "鱼", "type": "material", "color": PAL_SKY_BLUE, "desc": "清澈河海里钓起的小鱼，可在商店出售", "sell": 120},
	"bug": {"name": "黄粉蝶", "icon": "蝶", "type": "material", "color": Color("#F7D460"), "desc": "花丛间翩翩起舞的蝴蝶，可在商店出售", "sell": 100},
	"apple": {"name": "海岛苹果", "icon": "果", "type": "consumable", "color": Color("#E8524A"), "desc": "香甜脆爽的红苹果，可直接使用品尝", "sell": 50}
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

# --- 手机岛建模式状态（支持 1x1 / 2x2 / 3x3 画笔大小与矩形框选） ---
var current_build_tool: int = BuildTool.GROUND_GRASS
var build_brush_size: int = 1 # 1: 小(1x1), 2: 中(2x2), 3: 大(3x3)
var build_sub_road: int = GroundType.STONE_PATH
var build_sub_plant: int = ObjectType.FLOWER_RED
var build_sub_decor: int = ObjectType.BENCH
var is_box_select_mode: bool = false
var is_camera_pan_mode: bool = false

var build_touch_index: int = -1
var build_drag_start_cell: Vector2i = Vector2i(-1, -1)
var build_drag_curr_cell: Vector2i = Vector2i(-1, -1)
var pending_box_rect: Rect2i = Rect2i(0, 0, 0, 0)
var has_pending_box: bool = false
var current_stroke_changes: Array = []
var undo_stack: Array = []
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
var top_time_label: Label
var top_coin_label: Label
var toast_panel: Panel
var toast_label: Label
var toast_timer: float = 0.0
var time_refresh_timer: float = 0.0

var interact_btn: Button
var use_tool_btn: Button
var cancel_btn: Button
var mode_toggle_btn: Button
var hotbar_container: HBoxContainer
var hotbar_buttons: Array = []

var build_toolbar_panel: Control
var build_mode_hint_label: Label
var build_brush_size_btn: Button
var build_brush_mode_btn: Button
var build_pan_mode_btn: Button
var build_undo_btn: Button
var build_confirm_box_btn: Button
var build_sub_cycle_btn: Button
var build_tool_buttons: Array = []

# 模态弹窗引用
var active_modal: Control = null
var bag_modal: Control
var bag_grid_container: GridContainer
var bag_detail_label: Label
var map_modal: Control
var map_canvas: Control
var map_zoom: float = 1.0
var map_pan_offset: Vector2 = Vector2.ZERO
var pause_menu_modal: Control
var settings_modal: Control
var dialog_modal: Control
var dialog_title_label: Label
var dialog_body_label: Label
var shop_modal: Control
var confirm_modal: Control
var confirm_label: Label
var confirm_yes_callable: Callable

var hud_overlay_draw: Control

func _ready() -> void:
	_init_default_island()
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

func _update_camera_limits() -> void:
	if camera == null:
		return
	camera.limit_left = -TILE_SIZE * 2
	camera.limit_top = -TILE_SIZE * 2
	camera.limit_right = (GRID_WIDTH + 2) * TILE_SIZE
	camera.limit_bottom = (GRID_HEIGHT + 2) * TILE_SIZE

# ==============================================================================
# 《小岛日记》初始岛屿构建（含中央喷泉广场、信箱、木牌、花坛、二层高地与蜿蜒小河）
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
			var g_type: int = GroundType.DEEP_WATER
			var elev: int = 0
			var o_type: int = ObjectType.NONE
			var edge_dist: int = mini(mini(x, GRID_WIDTH - 1 - x), mini(y, GRID_HEIGHT - 1 - y))

			# 自然圆润的岛屿海岸线轮廓
			var corner_cut: int = 0
			if (x < 6 and y < 6) or (x > GRID_WIDTH - 7 and y < 6) or (x < 6 and y > GRID_HEIGHT - 7) or (x > GRID_WIDTH - 7 and y > GRID_HEIGHT - 7):
				corner_cut = 1

			var eff_dist: int = edge_dist - corner_cut
			if eff_dist <= 1:
				g_type = GroundType.DEEP_WATER
				elev = 0
			elif eff_dist == 2:
				g_type = GroundType.SHALLOW_WATER
				elev = 0
			elif eff_dist <= 4:
				g_type = GroundType.SAND
				elev = 1
			else:
				g_type = GroundType.GRASS
				elev = 1

			# 北部二层翠绿高地悬崖 (x 在 9..17, y 在 6..10)
			if x >= 9 and x <= 17 and y >= 6 and y <= 10:
				elev = 2

			# 蜿蜒穿过小岛东侧的清澈小河
			var river_x: int = 22 if y < 18 else 23
			if eff_dist >= 3 and (x == river_x or x == river_x + 1):
				g_type = GroundType.RIVER
				elev = 0

			# 河上的温暖木桥 (y = 17, 18)
			if (x == river_x or x == river_x + 1) and (y == 17 or y == 18):
				g_type = GroundType.BRIDGE
				elev = 1

			# 中央村庄石板广场 (x 在 15..20, y 在 16..20) 与延伸小径
			if x >= 15 and x <= 20 and y >= 16 and y <= 20:
				g_type = GroundType.STONE_PATH
			elif (y == 17 or y == 18) and x >= 13 and x <= 25 and g_type != GroundType.BRIDGE:
				g_type = GroundType.STONE_PATH
			elif x == 18 and y >= 21 and y <= 27:
				g_type = GroundType.WOOD_PATH

			# 布置《小岛日记》标志性建筑与环境叙事细节
			if x == 14 and y == 14:
				o_type = ObjectType.HOUSE
			elif x == 15 and y == 15:
				o_type = ObjectType.MAILBOX
			elif x == 25 and y == 14:
				o_type = ObjectType.SHOP
			elif x == 18 and y == 18:
				o_type = ObjectType.FOUNTAIN
			elif x == 15 and y == 16:
				o_type = ObjectType.LAMP
			elif x == 20 and y == 16:
				o_type = ObjectType.LAMP
			elif x == 16 and y == 20:
				o_type = ObjectType.BENCH
			elif x == 20 and y == 20:
				o_type = ObjectType.FLOWER_PLANTER
			elif x == 17 and y == 22:
				o_type = ObjectType.SIGNBOARD
			elif g_type == GroundType.SAND and ((x * 3 + y * 5) % 19 == 0):
				o_type = ObjectType.SHELL
			elif g_type == GroundType.GRASS and elev >= 1:
				if (x in [8, 11, 16, 27, 29]) and (y in [8, 12, 24, 21, 26]):
					o_type = ObjectType.TREE
				elif (x in [10, 11, 12]) and y == 15:
					o_type = ObjectType.FENCE
				elif (x + y * 3) % 13 == 0 and abs(x - 18) > 3:
					o_type = ObjectType.FLOWER_RED
				elif (x * 5 + y) % 19 == 0 and abs(x - 18) > 3:
					o_type = ObjectType.BUSH
				elif (x * 7 + y * 3) % 29 == 0 and abs(x - 18) > 4:
					o_type = ObjectType.WEED

			g_col.append(g_type)
			e_col.append(elev)
			o_col.append(o_type)

		ground_grid.append(g_col)
		elevation_grid.append(e_col)
		object_grid.append(o_col)

	player_pos = Vector2(18.5 * TILE_SIZE, 19.5 * TILE_SIZE)
	player_facing = Vector2.DOWN
	undo_stack.clear()
	queue_redraw()

func _init_default_inventory() -> void:
	coins = 1500
	inventory = {
		"shovel": 1,
		"axe": 1,
		"watering_can": 1,
		"net": 1,
		"rod": 1,
		"flower_seed": 15,
		"bush_seed": 8,
		"planter_item": 3,
		"bench_item": 2,
		"lamp_item": 2,
		"shell": 3,
		"wood": 8,
		"apple": 4
	}
	hotbar = ["shovel", "axe", "watering_can", "net", "rod", "flower_seed"]
	selected_hotbar_index = 0

func _init_ambient_particles() -> void:
	ambient_particles.clear()
	for i in range(18):
		ambient_particles.append({
			"pos": Vector2(randf_range(64.0, GRID_WIDTH * TILE_SIZE - 64.0), randf_range(64.0, GRID_HEIGHT * TILE_SIZE - 64.0)),
			"vel": Vector2(randf_range(-10.0, 14.0), randf_range(6.0, 16.0)),
			"phase": randf() * TAU,
			"color": PAL_PINK if i % 3 == 0 else (PAL_GRASS if i % 3 == 1 else Color("#F7D460"))
		})

func _spawn_burst_effect(world_pt: Vector2, col: Color) -> void:
	for i in range(6):
		var ang: float = float(i) * TAU / 6.0 + randf_range(-0.3, 0.3)
		burst_particles.append({
			"pos": world_pt,
			"vel": Vector2(cos(ang), sin(ang)) * randf_range(16.0, 32.0),
			"life": 0.45,
			"max_life": 0.45,
			"color": col
		})

# ==============================================================================
# 主循环：角色移动、小动物漫步、环境波纹/落叶/萤火虫动画更新
# ==============================================================================

func _physics_process(delta: float) -> void:
	env_anim_time += delta
	_update_particles(delta)

	if game_state == GameState.TITLE_SCREEN or active_modal != null:
		queue_redraw()
		return

	if tool_swing_timer > 0.0:
		tool_swing_timer = maxf(0.0, tool_swing_timer - delta)

	if game_state == GameState.EXPLORE_MODE:
		var kb_input := Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)
		var move_dir: Vector2 = joy_vector if joy_vector.length() > 0.05 else kb_input.limit_length(1.0)

		if move_dir.length() > 0.05:
			player_facing = move_dir.normalized()
			walk_anim_time += delta * 10.0
			var spd: float = BASE_MOVE_SPEED * setting_move_speed_scale
			_move_player_with_collision(move_dir * spd * delta)
			camera.position = player_pos
			if hud_overlay_draw != null:
				hud_overlay_draw.queue_redraw()
		elif walk_anim_time != 0.0:
			walk_anim_time = 0.0

	_update_animals(delta)
	queue_redraw()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_panel != null:
			toast_panel.visible = false

	time_refresh_timer += delta
	if time_refresh_timer >= 2.0:
		time_refresh_timer = 0.0
		_update_time_and_lighting()

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

func _update_animals(delta: float) -> void:
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		var pos: Vector2 = a["pos"]
		var target: Vector2 = a["target"]
		if pos.distance_to(target) > 2.0:
			var dir: Vector2 = (target - pos).normalized()
			var next_pos: Vector2 = pos + dir * 22.0 * delta
			var cell: Vector2i = world_to_grid(next_pos)
			if is_cell_walkable(cell.x, cell.y) and next_pos.distance_to(player_pos) > 14.0:
				a["pos"] = next_pos
			else:
				a["target"] = pos
		else:
			var wt: float = float(a["wait_timer"]) - delta
			if wt <= 0.0:
				wt = randf_range(2.8, 6.0)
				var home: Vector2 = a["home"]
				var candidate: Vector2 = home + Vector2(randf_range(-44.0, 44.0), randf_range(-44.0, 44.0))
				var c_cell: Vector2i = world_to_grid(candidate)
				if is_cell_walkable(c_cell.x, c_cell.y):
					a["target"] = candidate
			a["wait_timer"] = wt

# ==============================================================================
# 网格坐标与碰撞判断
# ==============================================================================

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))

func is_valid_cell(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < GRID_WIDTH and gy >= 0 and gy < GRID_HEIGHT

func is_cell_walkable(gx: int, gy: int) -> bool:
	if not is_valid_cell(gx, gy):
		return false
	var g_type: int = ground_grid[gx][gy]
	if g_type in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
		return false
	if elevation_grid[gx][gy] != 1:
		return false
	var o_type: int = object_grid[gx][gy]
	if o_type in [
		ObjectType.TREE, ObjectType.BUSH, ObjectType.BENCH, ObjectType.LAMP,
		ObjectType.FENCE, ObjectType.HOUSE, ObjectType.SHOP, ObjectType.CONSTRUCTION,
		ObjectType.FOUNTAIN, ObjectType.MAILBOX, ObjectType.FLOWER_PLANTER, ObjectType.SIGNBOARD
	]:
		return false
	return true

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

func _move_player_with_collision(motion: Vector2) -> void:
	var next_x := Vector2(player_pos.x + motion.x, player_pos.y)
	if is_rect_walkable(Rect2(next_x - COLLISION_HALF_SIZE, COLLISION_HALF_SIZE * 2.0)):
		player_pos.x = next_x.x
	var next_y := Vector2(player_pos.x, player_pos.y + motion.y)
	if is_rect_walkable(Rect2(next_y - COLLISION_HALF_SIZE, COLLISION_HALF_SIZE * 2.0)):
		player_pos.y = next_y.y

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

	for i in range(animals.size()):
		var a_pos: Vector2 = animals[i]["pos"]
		if player_pos.distance_to(a_pos) <= 26.0:
			nearby_interact_type = "animal"
			nearby_animal_idx = i
			interact_btn.text = "💬 交谈"
			return

	var p_cell: Vector2i = world_to_grid(player_pos)
	var f_cell: Vector2i = get_front_cell()
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
			ObjectType.SHELL:
				nearby_interact_type = "pickup_shell"
				nearby_interact_cell = c
				interact_btn.text = "🐚 拾取"
				return
			ObjectType.SHOP:
				nearby_interact_type = "shop"
				nearby_interact_cell = c
				interact_btn.text = "🏪 商店"
				return
			ObjectType.HOUSE:
				nearby_interact_type = "house"
				nearby_interact_cell = c
				interact_btn.text = "🏠 进入"
				return
			ObjectType.MAILBOX:
				nearby_interact_type = "mailbox"
				nearby_interact_cell = c
				interact_btn.text = "✉ 信箱"
				return
			ObjectType.FOUNTAIN:
				nearby_interact_type = "fountain"
				nearby_interact_cell = c
				interact_btn.text = "⛲ 许愿"
				return
			ObjectType.SIGNBOARD:
				nearby_interact_type = "signboard"
				nearby_interact_cell = c
				interact_btn.text = "🪧 路牌"
				return
			ObjectType.CONSTRUCTION:
				nearby_interact_type = "construction"
				nearby_interact_cell = c
				interact_btn.text = "🚧 施工"
				return
			ObjectType.BENCH:
				nearby_interact_type = "bench"
				nearby_interact_cell = c
				interact_btn.text = "🪑 休息"
				return

	interact_btn.text = "👋 互动"

func _on_interact_pressed() -> void:
	_refresh_nearby_interaction()
	match nearby_interact_type:
		"animal":
			if nearby_animal_idx >= 0 and nearby_animal_idx < animals.size():
				var a: Dictionary = animals[nearby_animal_idx]
				var d_list: Array = a["dialogs"]
				var msg: String = d_list[int(a["friendship"] - 1) % d_list.size()]
				a["friendship"] = int(a["friendship"]) + 1
				_spawn_burst_effect(a["pos"] + Vector2(0, -14), PAL_PINK)
				_open_dialog_modal("%s · 性格:%s (友好度 ♥%d)" % [a["name"], a["trait"], int(a["friendship"])], msg)
		"pickup_shell":
			if is_valid_cell(nearby_interact_cell.x, nearby_interact_cell.y):
				object_grid[nearby_interact_cell.x][nearby_interact_cell.y] = ObjectType.NONE
				_add_item("shell", 1)
				_spawn_burst_effect(Vector2(nearby_interact_cell) * TILE_SIZE + Vector2(8, 8), Color("#FFF2D6"))
				_refresh_nearby_interaction()
				_show_toast("拾取了海浪冲上来的【海贝壳】×1！")
		"shop":
			_open_shop_modal()
		"house":
			_open_dialog_modal("温馨的岛民小屋", "推开木门回到温暖的小屋，阳光洒在奶油色地毯上。\n（已自动为你保存最新《小岛日记》存档）")
			_save_game()
		"mailbox":
			_open_dialog_modal("岛屿木制信箱", "收到一封来自小动物邻居们的欢迎信：\n「在属于自己的小岛上，慢慢生活。愿你每天都有好心情！」")
		"fountain":
			_spawn_burst_effect(Vector2(nearby_interact_cell) * TILE_SIZE + Vector2(8, 8), PAL_SKY_BLUE)
			_show_toast("在中央清泉喷泉旁许下了温暖的心愿~")
		"signboard":
			_open_dialog_modal("小岛木质指示牌", "⬆ 北：中央喷泉广场、温馨小屋与杂货铺\n⬇ 南：阳光金沙滩与浅海拾贝区\n➡ 东：清澈小河与木桥")
		"construction":
			_open_dialog_modal("建筑施工围挡", "大型设施正在建设中，将在现实日期进入次日清晨（05:00后）自动完工落成！")
		"bench":
			_show_toast("坐在温暖的木长椅上听海浪声，真惬意~")
		_:
			_show_toast("靠近小动物、海滩贝壳、喷泉、信箱或建筑即可互动哦！")

# ==============================================================================
# 工具使用与快捷栏真实联动（带绘本粒子反馈）
# ==============================================================================

func _on_use_tool_pressed() -> void:
	if game_state != GameState.EXPLORE_MODE:
		return
	var item_id: String = hotbar[selected_hotbar_index]
	if item_id == "" or not ITEM_DB.has(item_id):
		_show_toast("当前快捷栏槽位为空，请先点击其他槽位或在背包中装备")
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
			if o_type in [ObjectType.WEED, ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED, ObjectType.BUSH]:
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_spawn_burst_effect(cell_center, PAL_EARTH)
				if o_type in [ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED]:
					_add_item("flower_seed", 1)
					_show_toast("用铁铲移植了花朵，回收【鲜花苗】×1")
				elif o_type == ObjectType.BUSH:
					_add_item("bush_seed", 1)
					_show_toast("回收了【灌木苗】×1")
				else:
					_show_toast("用铁铲清理了杂草！")
			elif o_type == ObjectType.NONE and g_type == GroundType.GRASS and elevation_grid[f_cell.x][f_cell.y] == 1:
				ground_grid[f_cell.x][f_cell.y] = GroundType.TILLED_SOIL
				_spawn_burst_effect(cell_center, PAL_EARTH)
				_show_toast("翻松了一块温暖的泥土地！")
			elif g_type == GroundType.TILLED_SOIL:
				ground_grid[f_cell.x][f_cell.y] = GroundType.GRASS
				_spawn_burst_effect(cell_center, PAL_GRASS)
				_show_toast("将泥土地恢复成了翠绿草地！")
			else:
				_show_toast("铁铲可除草、移花或翻土（大面积改造请点右上角【岛建】）")
		"axe":
			if o_type == ObjectType.TREE:
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_spawn_burst_effect(cell_center, PAL_WOOD)
				_add_item("wood", 3)
				_add_item("apple", 1)
				_show_toast("收获【木材】×3 与香甜的【海岛苹果】×1！")
			elif o_type in [ObjectType.BENCH, ObjectType.LAMP, ObjectType.FENCE, ObjectType.FLOWER_PLANTER]:
				if o_type == ObjectType.BENCH: _add_item("bench_item", 1)
				elif o_type == ObjectType.LAMP: _add_item("lamp_item", 1)
				elif o_type == ObjectType.FLOWER_PLANTER: _add_item("planter_item", 1)
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_spawn_burst_effect(cell_center, PAL_CREAM)
				_show_toast("已回收前方的户外家具装饰！")
			else:
				_show_toast("请面朝树木或户外家具再使用伐木斧")
		"watering_can":
			_spawn_burst_effect(cell_center, PAL_SKY_BLUE)
			if o_type == ObjectType.FLOWER_RED:
				object_grid[f_cell.x][f_cell.y] = ObjectType.FLOWER_WATERED
				_show_toast("给花丛浇了清泉水，花瓣闪着晶莹的光芒！")
			else:
				_show_toast("洒出了一串清凉的水珠~")
		"net":
			_spawn_burst_effect(cell_center, Color("#FFF2D6"))
			if o_type in [ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED, ObjectType.BUSH, ObjectType.FLOWER_PLANTER] or g_type == GroundType.GRASS:
				_add_item("bug", 1)
				_show_toast("轻巧挥网！捕捉到了可爱的【黄粉蝶】×1！")
			else:
				_show_toast("在草地或花丛旁挥网更容易遇到蝴蝶哦")
		"rod":
			if g_type in [GroundType.RIVER, GroundType.SHALLOW_WATER, GroundType.DEEP_WATER]:
				_spawn_burst_effect(cell_center, PAL_SKY_BLUE)
				_add_item("fish", 1)
				_show_toast("水花一溅！钓上了一条活蹦乱跳的【小海鱼】×1！")
			else:
				_show_toast("请面朝河流或大海再抛竿钓鱼哦")
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
					_show_toast("成功布置了【" + str(item_info["name"]) + "】！")
				else:
					_show_toast("前方格子已有物体或是水面，无法放置")
			elif item_info.get("type", "") == "consumable":
				_consume_item(item_id, 1)
				_spawn_burst_effect(player_pos, PAL_CORAL)
				_show_toast("品尝了香甜的【" + str(item_info["name"]) + "】，心情大好！")
			else:
				_show_toast("当前手持：【" + str(item_info["name"]) + "】，可在商店出售换取铃钱")

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
# 手机岛建模式（支持 1格/2格/3格 画笔大小、连续拖动、矩形框选与一键撤销）
# ==============================================================================

func _switch_game_state(new_state: int) -> void:
	_reset_touch_states()
	game_state = new_state

	if title_panel != null:
		title_panel.visible = (game_state == GameState.TITLE_SCREEN)
	if hud_root != null:
		hud_root.visible = (game_state != GameState.TITLE_SCREEN)

	if game_state == GameState.EXPLORE_MODE:
		if build_toolbar_panel != null: build_toolbar_panel.visible = false
		if hotbar_container != null: hotbar_container.visible = true
		if interact_btn != null: interact_btn.visible = true
		if use_tool_btn != null: use_tool_btn.visible = true
		if mode_toggle_btn != null: mode_toggle_btn.text = "🛠 岛建"
		if camera != null:
			camera.zoom = Vector2(setting_camera_zoom, setting_camera_zoom)
			camera.position = player_pos
	elif game_state == GameState.BUILD_MODE:
		if build_toolbar_panel != null: build_toolbar_panel.visible = true
		if hotbar_container != null: hotbar_container.visible = false
		if interact_btn != null: interact_btn.visible = false
		if use_tool_btn != null: use_tool_btn.visible = false
		if mode_toggle_btn != null: mode_toggle_btn.text = "🚶 漫步"
		if camera != null:
			var bz: float = maxf(0.85, setting_camera_zoom * 0.9)
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
	if obj in [ObjectType.HOUSE, ObjectType.SHOP]:
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

func _apply_brush_at_cell(center_cell: Vector2i, tool_id: int, stroke_changes: Array) -> bool:
	var any_changed: bool = false
	for dx in range(build_brush_size):
		for dy in range(build_brush_size):
			if _apply_build_tool_to_cell(center_cell.x + dx, center_cell.y + dy, tool_id, stroke_changes):
				any_changed = true
	if any_changed:
		_spawn_burst_effect(Vector2(center_cell) * TILE_SIZE + Vector2(8, 8), PAL_CREAM)
	return any_changed

func _apply_build_tool_to_cell(gx: int, gy: int, tool_id: int, stroke_changes: Array) -> bool:
	if not is_cell_editable_for_tool(gx, gy, tool_id):
		return false

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
			if new_g in [GroundType.RIVER, GroundType.SHALLOW_WATER, GroundType.TILLED_SOIL]:
				new_g = GroundType.GRASS
			new_e = 1
			if new_o != ObjectType.HOUSE and new_o != ObjectType.SHOP:
				new_o = ObjectType.NONE
		BuildTool.CLIFF_RAISE:
			new_g = GroundType.GRASS
			new_e = 2
			new_o = ObjectType.NONE
		BuildTool.RIVER_DIG:
			new_g = GroundType.RIVER
			new_e = 0
			new_o = ObjectType.NONE
		BuildTool.ROAD_PAVE:
			new_g = build_sub_road
			new_e = 1
			if new_o in [ObjectType.WEED, ObjectType.TREE]:
				new_o = ObjectType.NONE
		BuildTool.PLANT_PUT:
			if new_e == 0:
				new_g = GroundType.GRASS
				new_e = 1
			new_o = build_sub_plant
		BuildTool.DECOR_PUT:
			if new_e == 0:
				new_g = GroundType.GRASS
				new_e = 1
			new_o = build_sub_decor
		BuildTool.BUILDING_PUT:
			if new_e == 0:
				new_g = GroundType.GRASS
				new_e = 1
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
			"old_g": old_g, "old_e": old_e, "old_o": old_o
		})

	ground_grid[gx][gy] = new_g
	elevation_grid[gx][gy] = new_e
	object_grid[gx][gy] = new_o
	return true

func _commit_stroke_to_undo(stroke_changes: Array) -> void:
	if stroke_changes.is_empty():
		return
	undo_stack.append(stroke_changes.duplicate(true))
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
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
	has_pending_box = false
	if build_confirm_box_btn != null:
		build_confirm_box_btn.visible = false
	_update_build_ui_labels()
	_show_toast("已撤销上一步岛建修改（恢复 %d 格）" % last_changes.size())

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
# 统一触屏输入处理
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.TITLE_SCREEN or active_modal != null:
		return

	if game_state == GameState.EXPLORE_MODE:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				if joy_touch_index == -1 and touch.position.x < 220.0 and touch.position.y > 120.0 and touch.position.y < 330.0:
					joy_touch_index = touch.index
					_update_joystick(touch.position)
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
				if touch.position.y < 44.0 or touch.position.y > 282.0 or touch.position.x > 530.0:
					return
				if build_touch_index == -1:
					build_touch_index = touch.index
					var world_pt: Vector2 = get_canvas_transform().affine_inverse() * touch.position
					var cell: Vector2i = world_to_grid(world_pt)

					if is_camera_pan_mode:
						build_drag_start_cell = cell
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
					if not is_camera_pan_mode and not is_box_select_mode:
						if not current_stroke_changes.is_empty():
							_commit_stroke_to_undo(current_stroke_changes)
							current_stroke_changes.clear()

		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == build_touch_index:
				if is_camera_pan_mode:
					camera.position -= drag.relative / camera.zoom.x
					var map_px := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
					camera.position.x = clampf(camera.position.x, 64.0, map_px.x - 64.0)
					camera.position.y = clampf(camera.position.y, 64.0, map_px.y - 64.0)
				else:
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
		build_confirm_box_btn.text = "✅ 确认(%d×%d)" % [pending_box_rect.size.x, pending_box_rect.size.y]

func _update_joystick(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joy_center
	if offset.length() > joy_radius:
		offset = offset.normalized() * joy_radius
	joy_knob_pos = joy_center + offset
	joy_vector = offset / joy_radius
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

# ==============================================================================
# 《小岛日记》Cozy Storybook Pixel Art 精细画面渲染引擎
# ==============================================================================

func _draw() -> void:
	# 1. 绘制底层地形、自动过渡边缘（草地/沙滩/浅水岸线/石板路）与二层立体高地
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var g_type: int = ground_grid[x][y]
			var elev: int = elevation_grid[x][y]
			var is_alt: bool = ((x + y) % 2 == 0)

			draw_rect(rect, _get_ground_color(g_type, elev, is_alt), true)

			# 草地自然小草簇细节
			if g_type == GroundType.GRASS and ((x * 7 + y * 13) % 11 == 0):
				draw_rect(Rect2(rect.position.x + 3, rect.position.y + 4, 2, 2), PAL_FOREST.lightened(0.25), true)
				draw_rect(Rect2(rect.position.x + 5, rect.position.y + 3, 2, 3), PAL_FOREST.lightened(0.25), true)

			# 草地向沙滩的柔和圆角边缘过渡
			if g_type == GroundType.SAND:
				if y > 0 and ground_grid[x][y - 1] == GroundType.GRASS:
					draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, 3), PAL_GRASS, true)
					draw_rect(Rect2(rect.position.x + 2, rect.position.y + 3, 4, 1), PAL_GRASS_ALT, true)
					draw_rect(Rect2(rect.position.x + 10, rect.position.y + 3, 4, 1), PAL_GRASS_ALT, true)
				if y + 1 < GRID_HEIGHT and ground_grid[x][y + 1] == GroundType.GRASS:
					draw_rect(Rect2(rect.position.x, rect.position.y + 13, TILE_SIZE, 3), PAL_GRASS, true)

			# 浅水与河流的柔和白色浪花岸线 + 动态水波纹
			if g_type in [GroundType.SHALLOW_WATER, GroundType.RIVER]:
				if y > 0 and ground_grid[x][y - 1] not in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
					draw_rect(Rect2(rect.position.x, rect.position.y, TILE_SIZE, 2), Color(1.0, 0.98, 0.92, 0.65), true)
				var wave_shift: float = sin(env_anim_time * 2.5 + float(x + y)) * 2.0
				if (x + y) % 2 == 0:
					draw_rect(Rect2(rect.position.x + 4 + wave_shift, rect.position.y + 7, 6, 2), Color(1.0, 1.0, 1.0, 0.55), true)

			# 二层高地立体悬崖岩壁与顶缘高光
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

			# 石板路、木板路与木桥精致纹理
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

	# 2. 绘制所有自然植物、装饰物与建筑
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var o_type: int = object_grid[x][y]
			if o_type != ObjectType.NONE:
				_draw_storybook_object(Vector2(x * TILE_SIZE, y * TILE_SIZE), o_type)

	# 3. 漫步模式下高亮显示玩家面朝交互格
	if game_state == GameState.EXPLORE_MODE:
		var fc: Vector2i = get_front_cell()
		if is_valid_cell(fc.x, fc.y):
			draw_rect(Rect2(fc.x * TILE_SIZE + 1, fc.y * TILE_SIZE + 1, TILE_SIZE - 2, TILE_SIZE - 2), Color(1.0, 0.95, 0.80, 0.55), false, 1.2)

	# 4. 绘制 5 位原创小动物居民
	for a in animals:
		_draw_storybook_animal(a)

	# 5. 绘制玩家角色
	_draw_storybook_player()

	# 6. 绘制飘落花瓣/树叶、夜晚萤火虫与操作爆发粒子
	_draw_environment_particles()

	# 7. 岛建模式下绘制红绿合法性预览框（含 1x1 / 2x2 / 3x3 画笔大小预览）
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
			for dx in range(build_brush_size):
				for dy in range(build_brush_size):
					var tx: int = build_drag_curr_cell.x + dx
					var ty: int = build_drag_curr_cell.y + dy
					if is_valid_cell(tx, ty):
						var c_rect := Rect2(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)
						var ok: bool = is_cell_editable_for_tool(tx, ty, current_build_tool)
						draw_rect(c_rect, Color(0.25, 0.92, 0.40, 0.42) if ok else Color(0.95, 0.30, 0.30, 0.45), true)
						draw_rect(c_rect, PAL_CREAM, false, 1.2)

func _get_ground_color(g_type: int, elev: int, is_alt: bool) -> Color:
	if elev == 2 and g_type == GroundType.GRASS:
		return PAL_HIGH_GRASS if is_alt else PAL_GRASS
	match g_type:
		GroundType.DEEP_WATER: return PAL_OCEAN_BLUE if is_alt else PAL_OCEAN_BLUE.darkened(0.05)
		GroundType.SHALLOW_WATER: return PAL_SKY_BLUE if is_alt else PAL_SKY_BLUE.darkened(0.04)
		GroundType.SAND: return PAL_SAND if is_alt else PAL_SAND_ALT
		GroundType.GRASS: return PAL_GRASS if is_alt else PAL_GRASS_ALT
		GroundType.RIVER: return PAL_SKY_BLUE.darkened(0.06) if is_alt else PAL_SKY_BLUE
		GroundType.BRIDGE: return PAL_EARTH if is_alt else PAL_EARTH.darkened(0.06)
		GroundType.STONE_PATH: return Color("#CFC8B8") if is_alt else Color("#C5BEB0")
		GroundType.WOOD_PATH: return PAL_WOOD if is_alt else PAL_WOOD.lightened(0.06)
		GroundType.TILLED_SOIL: return PAL_WOOD.darkened(0.12) if is_alt else PAL_WOOD.darkened(0.18)
	return PAL_CREAM

func _draw_storybook_object(p: Vector2, o_type: int) -> void:
	match o_type:
		ObjectType.TREE:
			# 柔和椭圆树影 + 暖棕描边树干 + 三层饱满圆润树冠 + 红苹果点缀
			draw_rect(Rect2(p.x + 2, p.y + 12, 12, 3), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x + 5, p.y + 8, 6, 7), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 6, p.y + 8, 4, 6), PAL_WOOD, true)
			draw_rect(Rect2(p.x + 1, p.y - 3, 14, 12), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y - 2, 12, 10), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 3, p.y - 4, 10, 8), PAL_GRASS, true)
			draw_rect(Rect2(p.x + 5, p.y - 3, 6, 4), PAL_HIGH_GRASS, true)
			draw_rect(Rect2(p.x + 4, p.y + 2, 2, 2), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 10, p.y + 1, 2, 2), PAL_CORAL, true)
		ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED:
			var sway: float = sin(env_anim_time * 3.0 + p.x) * 0.6
			draw_rect(Rect2(p.x + 4, p.y + 9, 8, 5), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 3 + sway, p.y + 5, 5, 5), PAL_PINK, true)
			draw_rect(Rect2(p.x + 8 + sway, p.y + 6, 5, 5), PAL_CORAL, true)
			draw_rect(Rect2(p.x + 5 + sway, p.y + 7, 2, 2), PAL_CREAM, true)
			draw_rect(Rect2(p.x + 10 + sway, p.y + 8, 2, 2), PAL_CREAM, true)
			if o_type == ObjectType.FLOWER_WATERED:
				draw_rect(Rect2(p.x + 7, p.y + 2, 2, 2), PAL_SKY_BLUE.lightened(0.3), true)
		ObjectType.WEED:
			draw_rect(Rect2(p.x + 4, p.y + 9, 2, 4), PAL_FOREST, true)
			draw_rect(Rect2(p.x + 7, p.y + 7, 2, 6), PAL_GRASS.darkened(0.15), true)
			draw_rect(Rect2(p.x + 10, p.y + 9, 2, 4), PAL_FOREST, true)
		ObjectType.SHELL:
			draw_rect(Rect2(p.x + 4, p.y + 6, 8, 6), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 5, p.y + 7, 6, 4), PAL_PINK, true)
			draw_rect(Rect2(p.x + 6, p.y + 7, 4, 2), PAL_CREAM, true)
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
			draw_rect(Rect2(p.x + 4, p.y + 3, 3, 3), PAL_PINK, true)
			draw_rect(Rect2(p.x + 9, p.y + 3, 3, 3), PAL_CORAL, true)
		ObjectType.BENCH:
			draw_rect(Rect2(p.x + 1, p.y + 4, 14, 10), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 5, 12, 4), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 2, p.y + 9, 12, 3), PAL_WOOD, true)
		ObjectType.LAMP:
			# 夜晚自动发出温暖金色光晕
			var h: int = int(Time.get_datetime_dict_from_system().get("hour", 12))
			if h >= 17 or h < 7:
				draw_circle(Vector2(p.x + 8, p.y + 4), 14.0, Color(1.0, 0.90, 0.55, 0.28))
			draw_rect(Rect2(p.x + 6, p.y + 4, 4, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 7, p.y + 5, 2, 9), Color("#4A525A"), true)
			draw_rect(Rect2(p.x + 4, p.y, 8, 6), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 5, p.y + 1, 6, 4), Color("#FFE875"), true)
		ObjectType.FENCE:
			draw_rect(Rect2(p.x + 1, p.y + 3, 4, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 11, p.y + 3, 4, 11), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x + 2, p.y + 4, 2, 9), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 12, p.y + 4, 2, 9), PAL_EARTH, true)
			draw_rect(Rect2(p.x, p.y + 6, 16, 3), PAL_WOOD, true)
		ObjectType.FOUNTAIN:
			draw_rect(Rect2(p.x - 4, p.y - 2, 24, 20), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 3, p.y - 1, 22, 18), Color("#E6DFD3"), true)
			draw_rect(Rect2(p.x - 1, p.y + 1, 18, 14), PAL_SKY_BLUE, true)
			var splash: float = abs(sin(env_anim_time * 4.0)) * 2.0
			draw_rect(Rect2(p.x + 5, p.y + 3 - splash, 6, 8), Color(1.0, 1.0, 1.0, 0.85), true)
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
			# 珊瑚红暖顶 + 奶油白墙 + 木门与亮窗
			draw_rect(Rect2(p.x - 7, p.y - 13, 30, 29), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 12, 28, 9), PAL_CORAL, true)
			draw_rect(Rect2(p.x - 4, p.y - 10, 24, 3), PAL_PINK, true)
			draw_rect(Rect2(p.x + 4, p.y + 4, 7, 11), PAL_WOOD, true)
			draw_rect(Rect2(p.x - 2, p.y + 3, 4, 5), PAL_SKY_BLUE, true)
			draw_rect(Rect2(p.x + 14, p.y + 3, 4, 5), PAL_SKY_BLUE, true)
		ObjectType.SHOP:
			# 海洋蓝遮阳篷杂货店
			draw_rect(Rect2(p.x - 7, p.y - 13, 30, 29), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 5, p.y - 5, 26, 20), PAL_CREAM, true)
			draw_rect(Rect2(p.x - 6, p.y - 12, 28, 9), PAL_OCEAN_BLUE, true)
			draw_rect(Rect2(p.x - 4, p.y - 7, 24, 3), PAL_SKY_BLUE, true)
			draw_rect(Rect2(p.x + 4, p.y + 4, 7, 11), PAL_EARTH, true)
			draw_rect(Rect2(p.x + 13, p.y + 3, 6, 5), Color("#FFE875"), true)
		ObjectType.CONSTRUCTION:
			draw_rect(Rect2(p.x - 3, p.y - 3, 22, 20), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 2, p.y - 2, 20, 18), PAL_SAND, true)
			draw_rect(Rect2(p.x, p.y, 16, 14), PAL_WOOD, false, 2.0)

func _draw_storybook_animal(a: Dictionary) -> void:
	var p: Vector2 = a["pos"]
	var body_col: Color = a["body_col"]
	var ear_col: Color = a["ear_col"]
	var shirt_col: Color = a["shirt_col"]
	var id_str: String = str(a["id"])
	var step_bob: float = abs(sin(env_anim_time * 3.5 + p.x)) * 1.0

	# 脚下柔和投影
	draw_rect(Rect2(p.x - 6, p.y + 2, 12, 3), Color(0, 0, 0, 0.22), true)
	# 暖深棕描边轮廓 (#544A44)
	draw_rect(Rect2(p.x - 5, p.y - 14 - step_bob, 10, 17), PAL_OUTLINE, true)
	# 小衣服与头部
	draw_rect(Rect2(p.x - 4, p.y - 5 - step_bob, 8, 7), shirt_col, true)
	draw_rect(Rect2(p.x - 4, p.y - 13 - step_bob, 8, 8), body_col, true)

	# 物种专属特征耳朵/嘴喙
	if id_str == "rabbit":
		draw_rect(Rect2(p.x - 4, p.y - 19 - step_bob, 3, 6), PAL_OUTLINE, true)
		draw_rect(Rect2(p.x + 1, p.y - 19 - step_bob, 3, 6), PAL_OUTLINE, true)
		draw_rect(Rect2(p.x - 3, p.y - 18 - step_bob, 2, 5), ear_col, true)
		draw_rect(Rect2(p.x + 1, p.y - 18 - step_bob, 2, 5), ear_col, true)
	elif id_str in ["cat", "fox"]:
		draw_rect(Rect2(p.x - 5, p.y - 16 - step_bob, 3, 3), ear_col, true)
		draw_rect(Rect2(p.x + 2, p.y - 16 - step_bob, 3, 3), ear_col, true)
	elif id_str == "bear":
		draw_rect(Rect2(p.x - 5, p.y - 15 - step_bob, 3, 3), ear_col, true)
		draw_rect(Rect2(p.x + 2, p.y - 15 - step_bob, 3, 3), ear_col, true)
	elif id_str == "penguin":
		draw_rect(Rect2(p.x - 2, p.y - 11 - step_bob, 4, 4), PAL_CREAM, true)
		draw_rect(Rect2(p.x - 1, p.y - 9 - step_bob, 2, 2), PAL_CORAL, true)

	# 豆豆眼与红润脸颊
	draw_rect(Rect2(p.x - 3, p.y - 10 - step_bob, 1.5, 2), PAL_OUTLINE, true)
	draw_rect(Rect2(p.x + 1.5, p.y - 10 - step_bob, 1.5, 2), PAL_OUTLINE, true)
	draw_rect(Rect2(p.x - 4, p.y - 8 - step_bob, 1.5, 1), PAL_PINK, true)
	draw_rect(Rect2(p.x + 2.5, p.y - 8 - step_bob, 1.5, 1), PAL_PINK, true)

func _draw_storybook_player() -> void:
	var bob: float = abs(sin(walk_anim_time)) * 1.5
	var px: float = player_pos.x
	var py: float = player_pos.y

	draw_rect(Rect2(px - 6, py + 2, 12, 3), Color(0, 0, 0, 0.26), true)
	# 暖深棕描边底框
	draw_rect(Rect2(px - 5, py - 14 - bob, 10, 17), PAL_OUTLINE, true)
	# 背带裤与T恤
	draw_rect(Rect2(px - 4, py - 5 - bob, 8, 7), PAL_OCEAN_BLUE, true)
	draw_rect(Rect2(px - 3, py - 6 - bob, 6, 2), PAL_CORAL, true)
	# 脸庞
	draw_rect(Rect2(px - 4, py - 13 - bob, 8, 7), PAL_CREAM, true)
	# 绘本风草帽与红缎带
	draw_rect(Rect2(px - 7, py - 15 - bob, 14, 3), PAL_OUTLINE, true)
	draw_rect(Rect2(px - 6, py - 15 - bob, 12, 2), PAL_SAND, true)
	draw_rect(Rect2(px - 4, py - 18 - bob, 8, 3), PAL_CORAL, true)

	var eye_x: float = clampf(player_facing.x * 1.5, -1.5, 1.5)
	draw_rect(Rect2(px - 2.5 + eye_x, py - 10 - bob, 1.5, 2), PAL_OUTLINE, true)
	draw_rect(Rect2(px + 1.0 + eye_x, py - 10 - bob, 1.5, 2), PAL_OUTLINE, true)

	if tool_swing_timer > 0.0:
		var swing_pos: Vector2 = player_pos + player_facing.normalized() * 11.0
		draw_circle(swing_pos, 5.0, PAL_CREAM)
		draw_circle(swing_pos, 3.0, PAL_CORAL)

func _draw_environment_particles() -> void:
	var h: int = int(Time.get_datetime_dict_from_system().get("hour", 12))
	var is_night: bool = (h >= 19 or h < 6)

	for p in ambient_particles:
		var pos: Vector2 = p["pos"]
		if is_night:
			# 夜晚闪烁的萤火虫
			var glow_alpha: float = 0.4 + 0.55 * abs(sin(env_anim_time * 3.0 + float(p["phase"])))
			draw_rect(Rect2(pos.x, pos.y, 2, 2), Color(0.95, 1.0, 0.55, glow_alpha), true)
		else:
			# 白天随风飘落的花瓣与绿叶
			draw_rect(Rect2(pos.x, pos.y, 2, 2), p["color"], true)

	for bp in burst_particles:
		var bpos: Vector2 = bp["pos"]
		draw_rect(Rect2(bpos.x - 1.5, bpos.y - 1.5, 3, 3), bp["color"], true)

# ==============================================================================
# 《小岛日记》温暖奶油风 UI 系统（#FFF2D6 圆角面板 + #544A44 描边与文字）
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
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)

	var sb := _make_storybook_panel_style(bg_col, PAL_OUTLINE, 7)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_pressed := _make_storybook_panel_style(bg_col.darkened(0.08), PAL_OUTLINE, 7)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_pressed)
	return btn

func _build_all_mobile_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# ---------------- 1. 《小岛日记》正式手机启动画面 ----------------
	title_panel = Control.new()
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(title_panel)

	var title_bg := ColorRect.new()
	title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bg.color = Color(0.12, 0.24, 0.34, 0.45)
	title_panel.add_child(title_bg)

	var title_card := Panel.new()
	title_card.size = Vector2(360, 276)
	title_card.position = Vector2(140, 42)
	title_card.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 12))
	title_panel.add_child(title_card)

	var game_title_lbl := Label.new()
	game_title_lbl.text = "🌴 小岛日记 🌴"
	game_title_lbl.position = Vector2(92, 16)
	game_title_lbl.add_theme_font_size_override("font_size", 24)
	game_title_lbl.add_theme_color_override("font_color", PAL_WOOD)
	title_card.add_child(game_title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "在属于自己的小岛上，慢慢生活"
	sub_lbl.position = Vector2(78, 48)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	title_card.add_child(sub_lbl)

	var btn_continue := _make_touch_btn("▶ 继续日记 (读取本地存档)", Vector2(260, 42), PAL_GRASS, PAL_OUTLINE)
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
	title_card.add_child(btn_continue)

	var btn_new_game := _make_touch_btn("✨ 开启新岛屿生活", Vector2(260, 42), PAL_SKY_BLUE, PAL_OUTLINE)
	btn_new_game.position = Vector2(50, 132)
	btn_new_game.pressed.connect(func():
		if FileAccess.file_exists(SAVE_PATH):
			_ask_confirm("开启新游戏将覆盖当前本地存档，确定要重新生成初始小岛吗？", func():
				_init_default_island()
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
	title_card.add_child(btn_new_game)

	var btn_title_settings := _make_touch_btn("⚙ 游戏设置", Vector2(124, 42), PAL_SAND, PAL_OUTLINE)
	btn_title_settings.position = Vector2(50, 184)
	btn_title_settings.pressed.connect(func(): _open_modal(settings_modal))
	title_card.add_child(btn_title_settings)

	var btn_title_quit := _make_touch_btn("🚪 退出游戏", Vector2(124, 42), PAL_CORAL, PAL_CREAM)
	btn_title_quit.position = Vector2(186, 184)
	btn_title_quit.pressed.connect(func():
		_ask_confirm("确定要保存并退出《小岛日记》吗？", func():
			_save_game()
			get_tree().quit()
		)
	)
	title_card.add_child(btn_title_quit)

	# ---------------- 2. 手机横屏主 HUD ----------------
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_root)

	hud_overlay_draw = Control.new()
	hud_overlay_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_overlay_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_overlay_draw.draw.connect(_on_draw_hud_overlay)
	hud_root.add_child(hud_overlay_draw)

	# 2.1 左上角绘本风胶囊信息栏（日期、季节、时间、铃钱）
	var top_bar := Panel.new()
	top_bar.position = Vector2(12, 8)
	top_bar.size = Vector2(316, 34)
	top_bar.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 8))
	hud_root.add_child(top_bar)

	top_time_label = Label.new()
	top_time_label.position = Vector2(10, 7)
	top_time_label.add_theme_font_size_override("font_size", 12)
	top_time_label.add_theme_color_override("font_color", PAL_OUTLINE)
	top_bar.add_child(top_time_label)

	top_coin_label = Label.new()
	top_coin_label.position = Vector2(216, 7)
	top_coin_label.add_theme_font_size_override("font_size", 12)
	top_coin_label.add_theme_color_override("font_color", PAL_WOOD)
	top_bar.add_child(top_coin_label)

	# 2.2 右上角绘本风快捷功能按钮组（岛建、背包、地图、菜单）
	mode_toggle_btn = _make_touch_btn("🛠 岛建", Vector2(78, 34), PAL_CORAL, PAL_CREAM)
	mode_toggle_btn.position = Vector2(336, 8)
	mode_toggle_btn.pressed.connect(func():
		if game_state == GameState.EXPLORE_MODE:
			_switch_game_state(GameState.BUILD_MODE)
			_show_toast("已进入【岛建模式】：支持1/2/3格画笔与矩形框选，右上角可撤销")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("已返回【日常漫步模式】")
	)
	hud_root.add_child(mode_toggle_btn)

	var bag_top_btn := _make_touch_btn("🎒 背包", Vector2(68, 34), PAL_SAND, PAL_OUTLINE)
	bag_top_btn.position = Vector2(418, 8)
	bag_top_btn.pressed.connect(func(): _open_bag_modal())
	hud_root.add_child(bag_top_btn)

	var map_top_btn := _make_touch_btn("🗺 地图", Vector2(68, 34), PAL_SKY_BLUE, PAL_OUTLINE)
	map_top_btn.position = Vector2(490, 8)
	map_top_btn.pressed.connect(func(): _open_map_modal())
	hud_root.add_child(map_top_btn)

	var menu_top_btn := _make_touch_btn("☰ 菜单", Vector2(64, 34), PAL_CREAM, PAL_OUTLINE)
	menu_top_btn.position = Vector2(562, 8)
	menu_top_btn.pressed.connect(func(): _open_modal(pause_menu_modal))
	hud_root.add_child(menu_top_btn)

	# 顶部柔和气泡提示条
	toast_panel = Panel.new()
	toast_panel.position = Vector2(130, 46)
	toast_panel.size = Vector2(380, 26)
	toast_panel.visible = false
	toast_panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 6))
	hud_root.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.position = Vector2(10, 3)
	toast_label.add_theme_font_size_override("font_size", 12)
	toast_label.add_theme_color_override("font_color", PAL_OUTLINE)
	toast_panel.add_child(toast_label)

	# 2.3 右侧大拇指操作按钮（互动、使用工具、取消）
	interact_btn = _make_touch_btn("👋 互动", Vector2(84, 48), PAL_GRASS, PAL_OUTLINE)
	interact_btn.position = Vector2(540, 165)
	interact_btn.pressed.connect(_on_interact_pressed)
	hud_root.add_child(interact_btn)

	use_tool_btn = _make_touch_btn("✨ 使用", Vector2(84, 48), PAL_SKY_BLUE, PAL_OUTLINE)
	use_tool_btn.position = Vector2(540, 221)
	use_tool_btn.pressed.connect(_on_use_tool_pressed)
	hud_root.add_child(use_tool_btn)

	cancel_btn = _make_touch_btn("✖ 取消", Vector2(84, 40), PAL_CORAL, PAL_CREAM)
	cancel_btn.position = Vector2(540, 277)
	cancel_btn.pressed.connect(_on_cancel_button_pressed)
	hud_root.add_child(cancel_btn)

	# 2.4 底部 6 槽位绘本风快捷物品栏
	var hotbar_bg := Panel.new()
	hotbar_bg.position = Vector2(158, 298)
	hotbar_bg.size = Vector2(344, 56)
	hotbar_bg.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 10))
	hud_root.add_child(hotbar_bg)

	hotbar_container = HBoxContainer.new()
	hotbar_container.position = Vector2(166, 303)
	hotbar_container.add_theme_constant_override("separation", 5)
	hud_root.add_child(hotbar_container)

	hotbar_buttons.clear()
	for i in range(6):
		var slot_btn := _make_touch_btn("", Vector2(50, 46), PAL_CREAM_DARK, PAL_OUTLINE)
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
		hotbar_container.add_child(slot_btn)
		hotbar_buttons.append(slot_btn)

	# ---------------- 3. 手机岛建模式专属工具栏 ----------------
	_build_terraforming_toolbar()

	# ---------------- 4. 构建所有绘本风弹窗 ----------------
	_build_all_modals()
	_refresh_hotbar_ui()

func _build_terraforming_toolbar() -> void:
	build_toolbar_panel = Control.new()
	build_toolbar_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_toolbar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_toolbar_panel.visible = false
	hud_root.add_child(build_toolbar_panel)

	# 右侧岛建控制面板（撤销、画笔尺寸 1/2/3格、连续/框选切换、移视角开关、子样式切换）
	build_undo_btn = _make_touch_btn("↩ 撤销(0)", Vector2(90, 38), PAL_SAND, PAL_OUTLINE)
	build_undo_btn.position = Vector2(534, 48)
	build_undo_btn.pressed.connect(_on_build_undo_pressed)
	build_toolbar_panel.add_child(build_undo_btn)

	build_brush_size_btn = _make_touch_btn("画笔:1格", Vector2(90, 38), PAL_CREAM, PAL_OUTLINE)
	build_brush_size_btn.position = Vector2(534, 90)
	build_brush_size_btn.pressed.connect(func():
		build_brush_size = (build_brush_size % 3) + 1
		is_box_select_mode = false
		_update_build_ui_labels()
		_show_toast("画笔大小已切换为：%d×%d 格" % [build_brush_size, build_brush_size])
	)
	build_toolbar_panel.add_child(build_brush_size_btn)

	build_brush_mode_btn = _make_touch_btn("🖌 连续涂抹", Vector2(90, 38), PAL_SKY_BLUE, PAL_OUTLINE)
	build_brush_mode_btn.position = Vector2(534, 132)
	build_brush_mode_btn.pressed.connect(func():
		is_camera_pan_mode = false
		is_box_select_mode = not is_box_select_mode
		has_pending_box = false
		build_confirm_box_btn.visible = false
		_update_build_ui_labels()
	)
	build_toolbar_panel.add_child(build_brush_mode_btn)

	build_pan_mode_btn = _make_touch_btn("✋ 移视角:关", Vector2(90, 38), PAL_CREAM_DARK, PAL_OUTLINE)
	build_pan_mode_btn.position = Vector2(534, 174)
	build_pan_mode_btn.pressed.connect(func():
		is_camera_pan_mode = not is_camera_pan_mode
		_update_build_ui_labels()
	)
	build_toolbar_panel.add_child(build_pan_mode_btn)

	build_sub_cycle_btn = _make_touch_btn("🎨 换样式", Vector2(90, 38), PAL_PINK, PAL_OUTLINE)
	build_sub_cycle_btn.position = Vector2(534, 216)
	build_sub_cycle_btn.pressed.connect(_on_cycle_build_subtype)
	build_toolbar_panel.add_child(build_sub_cycle_btn)

	build_confirm_box_btn = _make_touch_btn("✅ 确认框选", Vector2(128, 40), PAL_GRASS, PAL_OUTLINE)
	build_confirm_box_btn.position = Vector2(398, 236)
	build_confirm_box_btn.visible = false
	build_confirm_box_btn.pressed.connect(_execute_pending_box_selection)
	build_toolbar_panel.add_child(build_confirm_box_btn)

	# 底部奶油色岛建工具栏
	var bottom_bg := Panel.new()
	bottom_bg.position = Vector2(10, 284)
	bottom_bg.size = Vector2(518, 68)
	bottom_bg.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 10))
	build_toolbar_panel.add_child(bottom_bg)

	build_mode_hint_label = Label.new()
	build_mode_hint_label.position = Vector2(18, 288)
	build_mode_hint_label.add_theme_font_size_override("font_size", 11)
	build_mode_hint_label.add_theme_color_override("font_color", PAL_WOOD)
	build_toolbar_panel.add_child(build_mode_hint_label)

	var tool_hbox := HBoxContainer.new()
	tool_hbox.position = Vector2(16, 306)
	tool_hbox.add_theme_constant_override("separation", 4)
	build_toolbar_panel.add_child(tool_hbox)

	var tool_defs: Array = [
		{"id": BuildTool.GROUND_GRASS, "name": "草地"},
		{"id": BuildTool.FLATTEN, "name": "铲平"},
		{"id": BuildTool.CLIFF_RAISE, "name": "造高地"},
		{"id": BuildTool.RIVER_DIG, "name": "挖河道"},
		{"id": BuildTool.ROAD_PAVE, "name": "铺道路"},
		{"id": BuildTool.PLANT_PUT, "name": "种植物"},
		{"id": BuildTool.DECOR_PUT, "name": "放装饰"},
		{"id": BuildTool.BUILDING_PUT, "name": "建建筑"}
	]

	build_tool_buttons.clear()
	for td in tool_defs:
		var t_btn := _make_touch_btn(td["name"], Vector2(59, 40), PAL_CREAM_DARK, PAL_OUTLINE)
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
			_show_toast("道路切换为：【温暖木板路】")
		elif build_sub_road == GroundType.WOOD_PATH:
			build_sub_road = GroundType.BRIDGE
			_show_toast("道路切换为：【水上木桥】")
		else:
			build_sub_road = GroundType.STONE_PATH
			_show_toast("道路切换为：【村庄石板路】")
	elif current_build_tool == BuildTool.PLANT_PUT:
		if build_sub_plant == ObjectType.FLOWER_RED:
			build_sub_plant = ObjectType.BUSH
			_show_toast("植物切换为：【常青灌木】")
		elif build_sub_plant == ObjectType.BUSH:
			build_sub_plant = ObjectType.TREE
			_show_toast("植物切换为：【海岛果树】")
		else:
			build_sub_plant = ObjectType.FLOWER_RED
			_show_toast("植物切换为：【缤纷花丛】")
	elif current_build_tool == BuildTool.DECOR_PUT:
		if build_sub_decor == ObjectType.BENCH:
			build_sub_decor = ObjectType.LAMP
			_show_toast("装饰切换为：【复古街灯】")
		elif build_sub_decor == ObjectType.LAMP:
			build_sub_decor = ObjectType.FLOWER_PLANTER
			_show_toast("装饰切换为：【精致花坛】")
		elif build_sub_decor == ObjectType.FLOWER_PLANTER:
			build_sub_decor = ObjectType.FOUNTAIN
			_show_toast("装饰切换为：【清泉喷泉】")
		elif build_sub_decor == ObjectType.FOUNTAIN:
			build_sub_decor = ObjectType.FENCE
			_show_toast("装饰切换为：【木质栅栏】")
		else:
			build_sub_decor = ObjectType.BENCH
			_show_toast("装饰切换为：【木长椅】")
	else:
		_show_toast("提示：铺道路、种植物、放装饰可点此按钮切换丰富样式！")
	_update_build_ui_labels()

func _update_build_ui_labels() -> void:
	if build_undo_btn == null:
		return
	build_undo_btn.text = "↩ 撤销(%d)" % undo_stack.size()
	build_brush_size_btn.text = "画笔:%d格" % build_brush_size
	build_brush_mode_btn.text = "🔲 矩形框选" if is_box_select_mode else "🖌 连续涂抹"
	build_pan_mode_btn.text = "✋ 移视角:开" if is_camera_pan_mode else "✋ 移视角:关"

	var tool_desc: String = ""
	match current_build_tool:
		BuildTool.GROUND_GRASS: tool_desc = "【草地】铺设翠绿草坪"
		BuildTool.FLATTEN: tool_desc = "【铲平】铲平高地/填河/清杂草"
		BuildTool.CLIFF_RAISE: tool_desc = "【造高地】堆筑二层悬崖"
		BuildTool.RIVER_DIG: tool_desc = "【挖河道】开凿清澈河流与湖泊"
		BuildTool.ROAD_PAVE: tool_desc = "【铺道路】可点右侧[换样式]切石路/木路/桥"
		BuildTool.PLANT_PUT: tool_desc = "【种植物】可点[换样式]切花丛/灌木/果树"
		BuildTool.DECOR_PUT: tool_desc = "【放装饰】可点[换样式]切长椅/路灯/花坛/喷泉"
		BuildTool.BUILDING_PUT: tool_desc = "【建建筑】放置施工围挡（次日清晨完工）"

	var mode_str: String = "单指移视角" if is_camera_pan_mode else ("拉框预览->点确认" if is_box_select_mode else ("%d×%d画笔连续涂抹" % [build_brush_size, build_brush_size]))
	build_mode_hint_label.text = "%s | %s" % [tool_desc, mode_str]

	for item in build_tool_buttons:
		var b: Button = item["btn"]
		b.modulate = Color(1.0, 0.88, 0.65) if int(item["id"]) == current_build_tool else Color.WHITE

func _on_cancel_button_pressed() -> void:
	if active_modal != null:
		_close_active_modal()
		return
	if game_state == GameState.BUILD_MODE:
		if has_pending_box:
			has_pending_box = false
			build_confirm_box_btn.visible = false
			_show_toast("已取消当前框选范围")
		elif is_camera_pan_mode:
			is_camera_pan_mode = false
			_update_build_ui_labels()
			_show_toast("已退出视角移动模式")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("已退出岛建模式，回到漫步状态")
	else:
		_reset_touch_states()
		_show_toast("已重置当前动作状态")

func _refresh_hotbar_ui() -> void:
	if hotbar_buttons.is_empty():
		return
	for i in range(6):
		var btn: Button = hotbar_buttons[i]
		var item_id: String = hotbar[i]
		var prefix: String = "▶" if i == selected_hotbar_index else ""
		if item_id != "" and ITEM_DB.has(item_id):
			var info: Dictionary = ITEM_DB[item_id]
			var cnt: int = int(inventory.get(item_id, 0))
			if info.get("type", "") == "tool":
				btn.text = "%s%s" % [prefix, info["icon"]]
			else:
				btn.text = "%s%s\nx%d" % [prefix, info["icon"], cnt]
		else:
			btn.text = "%s空" % prefix
		btn.modulate = Color(1.0, 0.90, 0.62) if i == selected_hotbar_index else Color.WHITE

func _on_draw_hud_overlay() -> void:
	if game_state != GameState.EXPLORE_MODE or active_modal != null:
		return
	# 绘制《小岛日记》绘本风圆环虚拟摇杆
	hud_overlay_draw.draw_circle(joy_center, joy_radius, Color(0.20, 0.18, 0.16, 0.38))
	hud_overlay_draw.draw_arc(joy_center, joy_radius, 0.0, TAU, 36, PAL_CREAM, 2.5)
	hud_overlay_draw.draw_circle(joy_knob_pos, 20.0, PAL_CREAM)
	hud_overlay_draw.draw_arc(joy_knob_pos, 20.0, 0.0, TAU, 24, PAL_OUTLINE, 2.0)

# ==============================================================================
# 绘本风模态弹窗系统（背包、岛屿全图、菜单、设置、商店、对话、确认框）
# ==============================================================================

func _create_modal_base(title_str: String, panel_size: Vector2) -> Array:
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
	panel.position = (Vector2(640, 360) - panel_size) * 0.5
	panel.add_theme_stylebox_override("panel", _make_storybook_panel_style(PAL_CREAM, PAL_OUTLINE, 12))
	root.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = title_str
	title_lbl.position = Vector2(18, 12)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", PAL_WOOD)
	panel.add_child(title_lbl)

	var close_btn := _make_touch_btn("✖ 关闭", Vector2(72, 34), PAL_CORAL, PAL_CREAM)
	close_btn.position = Vector2(panel_size.x - 84, 8)
	close_btn.pressed.connect(_close_active_modal)
	panel.add_child(close_btn)

	return [root, panel, title_lbl]

func _open_modal(modal: Control) -> void:
	_reset_touch_states()
	if active_modal != null:
		active_modal.visible = false
	active_modal = modal
	if active_modal != null:
		active_modal.visible = true
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

func _close_active_modal() -> void:
	if active_modal != null:
		active_modal.visible = false
		active_modal = null
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

func _build_all_modals() -> void:
	# 1. 背包弹窗
	var bag_res: Array = _create_modal_base("🎒 小岛背包与快捷栏整理", Vector2(540, 300))
	bag_modal = bag_res[0]
	var bag_panel: Panel = bag_res[1]

	bag_grid_container = GridContainer.new()
	bag_grid_container.columns = 5
	bag_grid_container.position = Vector2(18, 50)
	bag_grid_container.add_theme_constant_override("h_separation", 8)
	bag_grid_container.add_theme_constant_override("v_separation", 8)
	bag_panel.add_child(bag_grid_container)

	bag_detail_label = Label.new()
	bag_detail_label.position = Vector2(18, 206)
	bag_detail_label.size = Vector2(500, 36)
	bag_detail_label.add_theme_font_size_override("font_size", 12)
	bag_detail_label.add_theme_color_override("font_color", PAL_OUTLINE)
	bag_panel.add_child(bag_detail_label)

	var bag_assign_bar := HBoxContainer.new()
	bag_assign_bar.position = Vector2(18, 246)
	bag_assign_bar.add_theme_constant_override("separation", 6)
	bag_panel.add_child(bag_assign_bar)

	var use_in_bag_btn := _make_touch_btn("✨ 立即使用/放置", Vector2(116, 38), PAL_GRASS, PAL_OUTLINE)
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
	var map_res: Array = _create_modal_base("🗺 小岛日记全景地图 (单指拖动查看)", Vector2(540, 310))
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
	legend_lbl.text = "【小岛图例】\n🔴 你的当前位置\n🟡 5位小动物邻居\n🏠 温馨岛民小屋\n🏪 海岛杂货铺\n⛲ 中央喷泉广场\n🟫 木桥与小径"
	legend_lbl.add_theme_font_size_override("font_size", 12)
	legend_lbl.add_theme_color_override("font_color", PAL_OUTLINE)
	map_panel.add_child(legend_lbl)

	var zoom_in_btn := _make_touch_btn("🔍 放大地图", Vector2(125, 38), PAL_SKY_BLUE, PAL_OUTLINE)
	zoom_in_btn.position = Vector2(392, 205)
	zoom_in_btn.pressed.connect(func():
		map_zoom = clampf(map_zoom + 0.35, 1.0, 2.4)
		map_canvas.queue_redraw()
	)
	map_panel.add_child(zoom_in_btn)

	var zoom_out_btn := _make_touch_btn("🔎 缩小/复位", Vector2(125, 38), PAL_SAND, PAL_OUTLINE)
	zoom_out_btn.position = Vector2(392, 250)
	zoom_out_btn.pressed.connect(func():
		map_zoom = 1.0
		map_pan_offset = Vector2.ZERO
		map_canvas.queue_redraw()
	)
	map_panel.add_child(zoom_out_btn)

	# 3. 综合菜单弹窗
	var menu_res: Array = _create_modal_base("☰ 小岛日记菜单", Vector2(340, 280))
	pause_menu_modal = menu_res[0]
	var menu_panel: Panel = menu_res[1]

	var m_bag := _make_touch_btn("🎒 打开背包", Vector2(260, 38), PAL_SAND, PAL_OUTLINE)
	m_bag.position = Vector2(40, 52)
	m_bag.pressed.connect(func(): _open_bag_modal())
	menu_panel.add_child(m_bag)

	var m_map := _make_touch_btn("🗺 查看小岛地图", Vector2(260, 38), PAL_SKY_BLUE, PAL_OUTLINE)
	m_map.position = Vector2(40, 96)
	m_map.pressed.connect(func(): _open_map_modal())
	menu_panel.add_child(m_map)

	var m_set := _make_touch_btn("⚙ 游戏设置", Vector2(260, 38), PAL_CREAM_DARK, PAL_OUTLINE)
	m_set.position = Vector2(40, 140)
	m_set.pressed.connect(func(): _open_modal(settings_modal))
	menu_panel.add_child(m_set)

	var m_save := _make_touch_btn("💾 立即保存日记进度", Vector2(260, 38), PAL_GRASS, PAL_OUTLINE)
	m_save.position = Vector2(40, 184)
	m_save.pressed.connect(func():
		if _save_game():
			_close_active_modal()
			_show_toast("已安全保存全部岛屿地形、装饰与背包进度！")
	)
	menu_panel.add_child(m_save)

	var m_title := _make_touch_btn("🏠 保存并返回标题画面", Vector2(260, 38), PAL_CORAL, PAL_CREAM)
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
	var set_res: Array = _create_modal_base("⚙ 手机触控与画面设置", Vector2(440, 260))
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

	# 5. 商店弹窗
	var shop_res: Array = _create_modal_base("🏪 小岛温馨杂货铺", Vector2(480, 280))
	shop_modal = shop_res[0]
	var shop_panel: Panel = shop_res[1]

	var shop_items: Array = ["flower_seed", "planter_item", "bench_item", "lamp_item"]
	for idx in range(shop_items.size()):
		var sid: String = shop_items[idx]
		var sinfo: Dictionary = ITEM_DB[sid]
		var price: int = int(sinfo.get("price", 100))
		var buy_btn := _make_touch_btn("购买【%s】(-%d铃钱)" % [sinfo["name"], price], Vector2(210, 42), PAL_GRASS, PAL_OUTLINE)
		buy_btn.position = Vector2(22 + (idx % 2) * 224, 60 + int(idx / 2) * 54)
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

	var sell_btn := _make_touch_btn("💰 一键出售收集品 (贝壳/小鱼/蝴蝶/木材)", Vector2(430, 46), PAL_SAND, PAL_OUTLINE)
	sell_btn.position = Vector2(24, 185)
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

	# 6. 对话框弹窗
	var dlg_res: Array = _create_modal_base("💬 岛民交谈", Vector2(450, 200))
	dialog_modal = dlg_res[0]
	var dlg_panel: Panel = dlg_res[1]
	dialog_title_label = dlg_res[2]

	dialog_body_label = Label.new()
	dialog_body_label.position = Vector2(22, 54)
	dialog_body_label.size = Vector2(406, 86)
	dialog_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_body_label.add_theme_font_size_override("font_size", 14)
	dialog_body_label.add_theme_color_override("font_color", PAL_OUTLINE)
	dlg_panel.add_child(dialog_body_label)

	var dlg_ok := _make_touch_btn("真温暖，我知道啦~", Vector2(180, 40), PAL_GRASS, PAL_OUTLINE)
	dlg_ok.position = Vector2(135, 144)
	dlg_ok.pressed.connect(_close_active_modal)
	dlg_panel.add_child(dlg_ok)

	# 7. 二次确认弹窗
	var cfm_res: Array = _create_modal_base("⚠ 请确认操作", Vector2(400, 190))
	confirm_modal = cfm_res[0]
	var cfm_panel: Panel = cfm_res[1]

	confirm_label = Label.new()
	confirm_label.position = Vector2(22, 54)
	confirm_label.size = Vector2(356, 68)
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.add_theme_font_size_override("font_size", 14)
	confirm_label.add_theme_color_override("font_color", PAL_OUTLINE)
	cfm_panel.add_child(confirm_label)

	var cfm_yes := _make_touch_btn("✅ 确认执行", Vector2(140, 40), PAL_CORAL, PAL_CREAM)
	cfm_yes.position = Vector2(48, 132)
	cfm_yes.pressed.connect(func():
		_close_active_modal()
		if confirm_yes_callable.is_valid():
			confirm_yes_callable.call()
	)
	cfm_panel.add_child(cfm_yes)

	var cfm_no := _make_touch_btn("取消返回", Vector2(140, 40), PAL_SAND, PAL_OUTLINE)
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
		var btn_txt: String = "%s %s\n数量:%d" % [info["icon"], info["name"], cnt]
		var item_btn := _make_touch_btn(btn_txt, Vector2(94, 44), PAL_CREAM_DARK, PAL_OUTLINE)
		var id_copy: String = str(item_id)
		if id_copy == selected_bag_item_id:
			item_btn.modulate = Color(1.0, 0.88, 0.62)
		item_btn.pressed.connect(func():
			selected_bag_item_id = id_copy
			_open_bag_modal()
		)
		bag_grid_container.add_child(item_btn)

	if selected_bag_item_id != "" and ITEM_DB.has(selected_bag_item_id):
		var d_info: Dictionary = ITEM_DB[selected_bag_item_id]
		bag_detail_label.text = "【%s】 — %s" % [d_info["name"], d_info["desc"]]
	else:
		bag_detail_label.text = "点击上方物品查看说明并放入底部快捷栏"

	_open_modal(bag_modal)

func _open_map_modal() -> void:
	_open_modal(map_modal)
	map_canvas.queue_redraw()

func _open_shop_modal() -> void:
	_open_modal(shop_modal)

func _open_dialog_modal(title_str: String, body_str: String) -> void:
	dialog_title_label.text = "💬 " + title_str
	dialog_body_label.text = body_str
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
		var max_pan: float = 120.0 * map_zoom
		map_pan_offset.x = clampf(map_pan_offset.x, -max_pan, max_pan)
		map_pan_offset.y = clampf(map_pan_offset.y, -max_pan, max_pan)
		map_canvas.queue_redraw()

func _on_draw_realtime_minimap() -> void:
	var cell_px: float = 6.2 * map_zoom
	var total_w: float = GRID_WIDTH * cell_px
	var total_h: float = GRID_HEIGHT * cell_px
	var start_origin: Vector2 = (map_canvas.size - Vector2(total_w, total_h)) * 0.5 + map_pan_offset

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var r := Rect2(start_origin.x + x * cell_px, start_origin.y + y * cell_px, cell_px + 0.5, cell_px + 0.5)
			var g_col: Color = _get_ground_color(ground_grid[x][y], elevation_grid[x][y], false)
			map_canvas.draw_rect(r, g_col, true)

			var obj: int = object_grid[x][y]
			if obj == ObjectType.HOUSE:
				map_canvas.draw_rect(r.grow(1.5), PAL_CORAL, true)
			elif obj == ObjectType.SHOP:
				map_canvas.draw_rect(r.grow(1.5), PAL_OCEAN_BLUE, true)
			elif obj == ObjectType.FOUNTAIN:
				map_canvas.draw_rect(r.grow(1.2), PAL_CREAM, true)
			elif obj == ObjectType.TREE:
				map_canvas.draw_rect(r, PAL_FOREST, true)

	for a in animals:
		var ac: Vector2i = world_to_grid(a["pos"])
		var ap := Vector2(start_origin.x + (ac.x + 0.5) * cell_px, start_origin.y + (ac.y + 0.5) * cell_px)
		map_canvas.draw_circle(ap, 3.2 * map_zoom, Color("#FFE875"))

	var pc: Vector2i = world_to_grid(player_pos)
	var pp := Vector2(start_origin.x + (pc.x + 0.5) * cell_px, start_origin.y + (pc.y + 0.5) * cell_px)
	map_canvas.draw_circle(pp, 4.2 * map_zoom, PAL_CORAL)
	map_canvas.draw_arc(pp, 5.2 * map_zoom, 0, TAU, 16, PAL_CREAM, 1.5)

# ==============================================================================
# 现实时间、四季、昼夜光影与全面屏安全区自适应
# ==============================================================================

func _update_time_and_lighting() -> void:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var month: int = int(dt.get("month", 10))
	var h: int = int(dt.get("hour", 12))
	var mi: int = int(dt.get("minute", 0))

	var season: String = "秋季"
	if month in [3, 4, 5]: season = "春季"
	elif month in [6, 7, 8]: season = "夏季"
	elif month in [9, 10, 11]: season = "秋季"
	else: season = "冬季"

	var period: String = "夜晚"
	if h >= 5 and h < 8: period = "清晨"
	elif h >= 8 and h < 17: period = "白天"
	elif h >= 17 and h < 20: period = "黄昏"

	if top_time_label != null:
		top_time_label.text = "☀ %02d月%02d日 %02d:%02d (%s·%s)" % [month, int(dt.get("day", 1)), h, mi, season, period]
	if top_coin_label != null:
		top_coin_label.text = "🪙 %d 铃钱" % coins

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
	if hud_root == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var right_x: float = maxf(640.0, vp_size.x) - 18.0

	if interact_btn != null: interact_btn.position.x = right_x - 86.0
	if use_tool_btn != null: use_tool_btn.position.x = right_x - 86.0
	if cancel_btn != null: cancel_btn.position.x = right_x - 86.0
	if build_undo_btn != null: build_undo_btn.position.x = right_x - 92.0
	if build_brush_size_btn != null: build_brush_size_btn.position.x = right_x - 92.0
	if build_brush_mode_btn != null: build_brush_mode_btn.position.x = right_x - 92.0
	if build_pan_mode_btn != null: build_pan_mode_btn.position.x = right_x - 92.0
	if build_sub_cycle_btn != null: build_sub_cycle_btn.position.x = right_x - 92.0

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

func _save_game() -> bool:
	var data: Dictionary = {
		"version": 3,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"logical_day_key": _get_logical_day_key(),
		"coins": coins,
		"player": {"x": snappedf(player_pos.x, 0.1), "y": snappedf(player_pos.y, 0.1)},
		"inventory": inventory,
		"hotbar": hotbar,
		"ground_grid": ground_grid,
		"elevation_grid": elevation_grid,
		"object_grid": object_grid
	}
	var file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		dir.rename(TEMP_SAVE_PATH, SAVE_PATH)
	return true

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	coins = int(data.get("coins", 1500))
	if data.has("inventory") and typeof(data["inventory"]) == TYPE_DICTIONARY:
		inventory = data["inventory"]
	if data.has("hotbar") and typeof(data["hotbar"]) == TYPE_ARRAY and data["hotbar"].size() == 6:
		hotbar = data["hotbar"]

	if data.has("ground_grid") and data.has("elevation_grid") and data.has("object_grid"):
		var gg: Array = data["ground_grid"]
		var eg: Array = data["elevation_grid"]
		var og: Array = data["object_grid"]
		if gg.size() == GRID_WIDTH and eg.size() == GRID_WIDTH and og.size() == GRID_WIDTH:
			for x in range(GRID_WIDTH):
				for y in range(GRID_HEIGHT):
					ground_grid[x][y] = int(gg[x][y])
					elevation_grid[x][y] = int(eg[x][y])
					object_grid[x][y] = int(og[x][y])

	var saved_day: String = str(data.get("logical_day_key", ""))
	var curr_day: String = _get_logical_day_key()
	if saved_day != "" and curr_day > saved_day:
		for x in range(GRID_WIDTH):
			for y in range(GRID_HEIGHT):
				if int(object_grid[x][y]) == ObjectType.CONSTRUCTION:
					object_grid[x][y] = ObjectType.HOUSE

	if data.has("player") and typeof(data["player"]) == TYPE_DICTIONARY:
		var p: Dictionary = data["player"]
		var saved_pt := Vector2(float(p.get("x", player_pos.x)), float(p.get("y", player_pos.y)))
		var c: Vector2i = world_to_grid(saved_pt)
		if is_cell_walkable(c.x, c.y):
			player_pos = saved_pt

	_refresh_hotbar_ui()
	_update_time_and_lighting()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_reset_touch_states()
		if game_state != GameState.TITLE_SCREEN:
			_save_game()
