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

const GRID_WIDTH: int = 44
const GRID_HEIGHT: int = 44
const TILE_SIZE: int = 16
const SAVE_PATH: String = "user://little_island_diary_save_v2.json"
const TEMP_SAVE_PATH: String = "user://little_island_diary_save_v2.tmp"

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
	"move_ui":        "res://sprites/ui/move_ui.png"
}

var _icon_cache: Dictionary = {}

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
	VILLAGER_HOUSE = 23
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
	MOVE_OBJECT = 8
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
const BASE_MOVE_SPEED: float = 90.0
const COLLISION_HALF_SIZE: Vector2 = Vector2(4.2, 4.2)
var camera: Camera2D

# --- 5 位原创小动物居民 ---
var animals: Array = [
	{
		"id": "rabbit",
		"name": "兔子莉莉",
		"trait": "温柔",
		"pos": Vector2(18.5 * TILE_SIZE, 20.5 * TILE_SIZE),
		"home": Vector2(18.5 * TILE_SIZE, 20.5 * TILE_SIZE),
		"target": Vector2(18.5 * TILE_SIZE, 20.5 * TILE_SIZE),
		"body_col": Color("#FFF9F5"),
		"ear_col": Color("#EE8398"),
		"shirt_col": Color("#EE8398"),
		"wait_timer": 2.0,
		"friendship": 1,
		"dialogs": [
			"欢迎来到《小岛日记》！你看底部快捷栏和右上角都换上了精致的绘本像素图标呢~",
			"我最喜欢在中央喷泉和花坛附近散步啦，用【浇水壶】给花朵浇水会让它们闪闪发光哦！",
			"进入【岛建】后，不仅能铺路、挖河、造高地，还能用【移动】工具调整岛上的家具和植物位置！"
		]
	},
	{
		"id": "cat",
		"name": "猫咪奈奈",
		"trait": "活泼",
		"pos": Vector2(24.5 * TILE_SIZE, 21.5 * TILE_SIZE),
		"home": Vector2(24.5 * TILE_SIZE, 21.5 * TILE_SIZE),
		"target": Vector2(24.5 * TILE_SIZE, 21.5 * TILE_SIZE),
		"body_col": Color("#F5B06C"),
		"ear_col": Color("#D97A3E"),
		"shirt_col": Color("#74C9ED"),
		"wait_timer": 3.2,
		"friendship": 1,
		"dialogs": [
			"喵呜~ 南边金沙滩和木栈桥旁边经常有粉色的【海贝壳】，走过去点右侧【拾取】就能捡起来！",
			"东边的小河和南边的大海都能钓鱼，切换到【钓鱼竿】去试试手气吧！",
			"不管你什么时候打开手机上岛，我们都会在这里陪着你，一点也不用赶进度哦。"
		]
	},
	{
		"id": "fox",
		"name": "狐狸阿洛",
		"trait": "独立",
		"pos": Vector2(14.5 * TILE_SIZE, 16.5 * TILE_SIZE),
		"home": Vector2(14.5 * TILE_SIZE, 16.5 * TILE_SIZE),
		"target": Vector2(14.5 * TILE_SIZE, 16.5 * TILE_SIZE),
		"body_col": Color("#F08A61"),
		"ear_col": Color("#544A44"),
		"shirt_col": Color("#39815D"),
		"wait_timer": 4.0,
		"friendship": 1,
		"dialogs": [
			"西北边的松林区长满了松树、小蘑菇和树桩，散步起来特别安静舒服。",
			"点击顶部【地图】可以随时查看全岛的实时地形，支持用手指拖动和放大缩小。",
			"岛建时如果误操作了，随时点右侧的【撤销】或【重做】按钮就能恢复原状。"
		]
	},
	{
		"id": "bear",
		"name": "小熊布朗",
		"trait": "憨厚",
		"pos": Vector2(28.5 * TILE_SIZE, 19.5 * TILE_SIZE),
		"home": Vector2(28.5 * TILE_SIZE, 19.5 * TILE_SIZE),
		"target": Vector2(28.5 * TILE_SIZE, 19.5 * TILE_SIZE),
		"body_col": Color("#B98761"),
		"ear_col": Color("#8A5B45"),
		"shirt_col": Color("#F5DDA1"),
		"wait_timer": 2.8,
		"friendship": 1,
		"dialogs": [
			"呼呼~ 河对岸就是热闹的【海岛杂货铺】，捡到的贝壳、钓到的小鱼都能去那里换铃钱！",
			"我最喜欢吃果树上的红苹果啦，用【伐木斧】砍树就能收获木材和苹果哦。",
			"东北边的高地上有一道清澈的悬崖瀑布，流下来的水汇成了我们的小河。"
		]
	},
	{
		"id": "penguin",
		"name": "企鹅波波",
		"trait": "开朗",
		"pos": Vector2(21.5 * TILE_SIZE, 31.5 * TILE_SIZE),
		"home": Vector2(21.5 * TILE_SIZE, 31.5 * TILE_SIZE),
		"target": Vector2(21.5 * TILE_SIZE, 31.5 * TILE_SIZE),
		"body_col": Color("#5B9BD5"),
		"ear_col": Color("#379CC9"),
		"shirt_col": Color("#F08A61"),
		"wait_timer": 3.6,
		"friendship": 1,
		"dialogs": [
			"噗噗！南边的海滨椰林和木栈桥码头视野超棒，一眼望去全都是蔚蓝的大海！",
			"在海滩旁放几张木长椅和盆栽，吹着海风听着海浪声，烦恼全都飞走啦！"
		]
	}
]

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
	"apple":        {"name": "海岛苹果", "icon_key": "apple",        "type": "consumable", "sell": 50,  "desc": "香甜脆爽的红苹果，可直接使用品尝"}
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

# ==============================================================================
# 图标资源统一加载器（优先 load 工程资源，兼容 Image.load_from_file，零缺失保底）
# ==============================================================================

func _preload_all_icons() -> void:
	for key in ICON_PATHS.keys():
		_get_icon_tex(key)

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

	# 1. 构建自然的椭圆形有机岛屿海岸线（告别生硬方盒）
	var center := Vector2(GRID_WIDTH * 0.5, GRID_HEIGHT * 0.5)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var nx: float = (float(x) - center.x) / (GRID_WIDTH * 0.44)
			var ny: float = (float(y) - center.y) / (GRID_HEIGHT * 0.43)
			var wave: float = 0.06 * sin(float(x) * 0.45) + 0.06 * cos(float(y) * 0.40)
			var dist: float = sqrt(nx * nx + ny * ny) + wave

			if dist > 1.02:
				ground_grid[x][y] = GroundType.DEEP_WATER
				elevation_grid[x][y] = 0
			elif dist > 0.90:
				ground_grid[x][y] = GroundType.SHALLOW_WATER
				elevation_grid[x][y] = 0
			elif dist > 0.76 or (y >= 31 and dist <= 0.90):
				ground_grid[x][y] = GroundType.SAND
				elevation_grid[x][y] = 1
			else:
				ground_grid[x][y] = GroundType.GRASS
				elevation_grid[x][y] = 1

	# 2. 北部与东北二层翠绿高地悬崖 (x: 11..30, y: 6..12)
	for x in range(11, 31):
		for y in range(6, 13):
			if ground_grid[x][y] == GroundType.GRASS:
				if not (x > 27 and y > 10):
					elevation_grid[x][y] = 2

	# 3. 蜿蜒自然的河流与内陆小湖泊（从北部高地瀑布 25,9 蜿蜒流向东南入海口）
	for y in range(8, 37):
		var rx: int = 25
		if y >= 13 and y < 20: rx = 26
		elif y >= 20 and y < 27: rx = 27
		elif y >= 27: rx = 28
		for dx in range(2):
			if is_valid_cell(rx + dx, y) and ground_grid[rx + dx][y] != GroundType.DEEP_WATER:
				ground_grid[rx + dx][y] = GroundType.RIVER
				elevation_grid[rx + dx][y] = 0
	# 河心小湖泊 (24..28, 13..16)
	for x in range(24, 28):
		for y in range(14, 17):
			ground_grid[x][y] = GroundType.RIVER
			elevation_grid[x][y] = 0

	# 4. 两座连接东西两岸的温暖木桥 + 南海岸延伸入海的木栈桥码头
	for x in range(26, 28):
		for y in [20, 21]:
			ground_grid[x][y] = GroundType.BRIDGE
			elevation_grid[x][y] = 1
	for x in range(27, 29):
		for y in [26, 27]:
			ground_grid[x][y] = GroundType.BRIDGE
			elevation_grid[x][y] = 1
	# 南海岸观海木栈桥码头 (x: 20..21, y: 34..39)
	for x in [20, 21]:
		for y in range(34, 40):
			ground_grid[x][y] = GroundType.BRIDGE
			elevation_grid[x][y] = 1

	# 5. 中央喷泉石板大广场 (x: 18..23, y: 19..23) 与有机连接全岛的石板路/木板路网络
	for x in range(18, 24):
		for y in range(19, 24):
			ground_grid[x][y] = GroundType.STONE_PATH
	# 东西主干道（连接西侧家园、中央广场、木桥与东侧杂货铺）
	for x in range(13, 32):
		for y in [20, 21]:
			if ground_grid[x][y] != GroundType.BRIDGE:
				ground_grid[x][y] = GroundType.STONE_PATH
	# 南向景观木板大道（从中央广场直通南海滩与码头）
	for y in range(24, 34):
		for x in [20, 21]:
			if ground_grid[x][y] == GroundType.GRASS or ground_grid[x][y] == GroundType.SAND:
				ground_grid[x][y] = GroundType.WOOD_PATH

	# 6. 放置核心建筑、公共设施与生活叙事细节
	object_grid[15][18] = ObjectType.HOUSE            # 玩家红顶温馨小屋
	object_grid[16][19] = ObjectType.MAILBOX          # 门前珊瑚红信箱
	object_grid[12][23] = ObjectType.VILLAGER_HOUSE   # 动物邻居小黄屋
	object_grid[30][18] = ObjectType.SHOP             # 河东岸海岛杂货铺
	object_grid[20][21] = ObjectType.FOUNTAIN         # 广场中央动态喷泉
	object_grid[18][19] = ObjectType.LAMP             # 广场四角复古街灯
	object_grid[23][19] = ObjectType.LAMP
	object_grid[18][23] = ObjectType.FLOWER_PLANTER   # 广场花坛盆栽
	object_grid[23][23] = ObjectType.FLOWER_PLANTER
	object_grid[19][19] = ObjectType.BENCH            # 广场木长椅
	object_grid[22][19] = ObjectType.BENCH
	object_grid[19][24] = ObjectType.SIGNBOARD        # 路口木质指示牌

	# 家园小花园围栏与耕地
	for fx in [13, 14, 17]:
		object_grid[fx][19] = ObjectType.FENCE
	ground_grid[13][17] = GroundType.TILLED_SOIL
	ground_grid[14][17] = GroundType.TILLED_SOIL
	object_grid[13][17] = ObjectType.FLOWER_PINK
	object_grid[14][17] = ObjectType.FLOWER_WATERED

	# 7. 分区域布置差异化自然生态（告别单调机械重复）
	# (A) 西北松林与高地生态区：松树、橡树、蘑菇、树桩、岩石、花丛
	var pine_coords: Array[Vector2i] = [
		Vector2i(10, 11), Vector2i(12, 9), Vector2i(15, 8), Vector2i(18, 8),
		Vector2i(21, 8), Vector2i(28, 9), Vector2i(9, 14), Vector2i(11, 13)
	]
	for c in pine_coords:
		if ground_grid[c.x][c.y] == GroundType.GRASS:
			object_grid[c.x][c.y] = ObjectType.TREE_PINE

	var oak_coords: Array[Vector2i] = [
		Vector2i(14, 11), Vector2i(19, 11), Vector2i(10, 17), Vector2i(10, 21),
		Vector2i(15, 26), Vector2i(17, 28), Vector2i(31, 15), Vector2i(33, 21),
		Vector2i(31, 25), Vector2i(25, 29)
	]
	for c in oak_coords:
		if ground_grid[c.x][c.y] == GroundType.GRASS and object_grid[c.x][c.y] == ObjectType.NONE:
			object_grid[c.x][c.y] = ObjectType.TREE_OAK

	# (B) 南海岸热带椰林与沙滩贝壳区
	var palm_coords: Array[Vector2i] = [
		Vector2i(14, 31), Vector2i(17, 32), Vector2i(24, 32), Vector2i(30, 30), Vector2i(12, 29)
	]
	for c in palm_coords:
		if ground_grid[c.x][c.y] in [GroundType.SAND, GroundType.GRASS] and object_grid[c.x][c.y] == ObjectType.NONE:
			object_grid[c.x][c.y] = ObjectType.TREE_PALM

	# 点缀岩石、树桩、林间蘑菇、灌木、双色花朵与海滩贝壳
	object_grid[11][15] = ObjectType.STUMP
	object_grid[12][14] = ObjectType.MUSHROOM
	object_grid[16][10] = ObjectType.MUSHROOM
	object_grid[23][11] = ObjectType.ROCK
	object_grid[32][18] = ObjectType.ROCK
	object_grid[15][33] = ObjectType.SHELL
	object_grid[18][34] = ObjectType.SHELL
	object_grid[23][34] = ObjectType.SHELL
	object_grid[26][33] = ObjectType.SHELL
	object_grid[19][32] = ObjectType.BENCH

	for x in range(8, GRID_WIDTH - 8):
		for y in range(8, GRID_HEIGHT - 8):
			if ground_grid[x][y] == GroundType.GRASS and object_grid[x][y] == ObjectType.NONE:
				if abs(x - 20) <= 3 and abs(y - 21) <= 3:
					continue
				var hash_v: int = (x * 13 + y * 29) % 47
				if hash_v == 0:
					object_grid[x][y] = ObjectType.FLOWER_PINK
				elif hash_v == 1:
					object_grid[x][y] = ObjectType.FLOWER_YELLOW
				elif hash_v == 2:
					object_grid[x][y] = ObjectType.BUSH
				elif hash_v == 3 and x > 28:
					object_grid[x][y] = ObjectType.WEED

	player_pos = Vector2(21.5 * TILE_SIZE, 22.5 * TILE_SIZE)
	player_facing = Vector2.DOWN
	undo_stack.clear()
	redo_stack.clear()
	queue_redraw()

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
				var candidate: Vector2 = home + Vector2(randf_range(-48.0, 48.0), randf_range(-48.0, 48.0))
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
		ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM,
		ObjectType.BUSH, ObjectType.BENCH, ObjectType.LAMP, ObjectType.FENCE,
		ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE, ObjectType.SHOP, ObjectType.CONSTRUCTION,
		ObjectType.FOUNTAIN, ObjectType.MAILBOX, ObjectType.FLOWER_PLANTER,
		ObjectType.SIGNBOARD, ObjectType.ROCK, ObjectType.STUMP
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

	if interact_btn_label == null:
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

	interact_btn_label.text = "互动"

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
			_open_dialog_modal("温馨的岛民小屋", "推开木门回到温暖的小屋，阳光洒在奶油色地毯上。\n（已自动为你保存最新《小岛日记》存档）")
			_save_game()
		"mailbox":
			_open_dialog_modal("小岛木制信箱", "收到来自动物居民的明信片：\n「在属于自己的小岛上，慢慢生活。今天也去海边或松林走走吧！」")
		"fountain":
			_spawn_burst_effect(Vector2(nearby_interact_cell) * TILE_SIZE + Vector2(8, 8), PAL_SKY_BLUE)
			_show_toast("在中央清泉喷泉旁许下了温暖的心愿~")
		"signboard":
			_open_dialog_modal("小岛木质指示牌", "↖ 西北：静谧松林与高地瀑布\n⬆ 中央：喷泉广场与温馨小屋\n➡ 河东：海岛杂货铺\n⬇ 正南：阳光金沙滩与观海木栈桥")
		"construction":
			_open_dialog_modal("建筑施工围挡", "新建筑正在施工中，将在现实日期进入次日清晨（05:00后）自动完工落成！")
		"bench":
			_show_toast("坐在温暖的木长椅上听海浪声，真惬意~")
		_:
			_show_toast("靠近小动物、海滩贝壳、喷泉、信箱或杂货铺即可点击互动！")

# ==============================================================================
# 工具使用与快捷栏真实联动
# ==============================================================================

func _on_use_tool_pressed() -> void:
	if game_state != GameState.EXPLORE_MODE:
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
					_show_toast("成功放置了【" + str(item_info["name"]) + "】！")
				else:
					_show_toast("前方格子已有物体或是水面，无法放置")
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
			if new_o not in [ObjectType.HOUSE, ObjectType.VILLAGER_HOUSE, ObjectType.SHOP]:
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
			if new_o in [ObjectType.WEED, ObjectType.TREE_OAK, ObjectType.TREE_PINE]:
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
				if joy_touch_index == -1 and touch.position.x < 220.0 and touch.position.y > 120.0 and touch.position.y < vp_size.y - 24.0:
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

func _update_joystick(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joy_center
	if offset.length() > joy_radius:
		offset = offset.normalized() * joy_radius
	joy_knob_pos = joy_center + offset
	joy_vector = offset / joy_radius
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

# ==============================================================================
# 《小岛日记》多层 Y-Sort 绘本渲染引擎（彻底消除边缘灰块、支持树冠遮挡与地形自动衔接）
# ==============================================================================

func _draw() -> void:
	# 0. 绘制无限延伸的广阔海洋背景与动态海浪（覆盖 [-28..GRID_WIDTH+28]，彻底消灭任何超宽屏灰色边缘）
	var sea_rect := Rect2(-28 * TILE_SIZE, -20 * TILE_SIZE, (GRID_WIDTH + 56) * TILE_SIZE, (GRID_HEIGHT + 40) * TILE_SIZE)
	draw_rect(sea_rect, PAL_OCEAN_BLUE, true)
	for wx in range(-18, GRID_WIDTH + 18, 3):
		for wy in range(-10, GRID_HEIGHT + 10, 3):
			if wx >= 2 and wx < GRID_WIDTH - 2 and wy >= 2 and wy < GRID_HEIGHT - 2:
				continue
			var w_shift: float = sin(env_anim_time * 2.0 + float(wx + wy)) * 2.5
			draw_rect(Rect2(wx * TILE_SIZE + 3 + w_shift, wy * TILE_SIZE + 6, 7, 2), Color(1.0, 1.0, 1.0, 0.28), true)

	# 1. 绘制岛屿网格地形、岸线过渡、河岸、高地瀑布与道路连接
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
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
				if g_type == GroundType.RIVER and y >= 11 and y <= 13:
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
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var o_type: int = object_grid[x][y]
			if o_type != ObjectType.NONE:
				_draw_storybook_object_base(Vector2(x * TILE_SIZE, y * TILE_SIZE), o_type)

		for a in animals:
			var ay_row: int = clampi(int(floor(float(a["pos"].y) / TILE_SIZE)), 0, GRID_HEIGHT - 1)
			if ay_row == y:
				_draw_storybook_animal(a)

		if p_row == y:
			_draw_storybook_player()

	# 4. 顶层树冠与屋顶遮挡层（Tree Canopy Overlay Layer）：让角色走在树后时呈现真实空间层次
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var o_type: int = object_grid[x][y]
			if o_type in [ObjectType.TREE_OAK, ObjectType.TREE_PINE, ObjectType.TREE_PALM]:
				_draw_tree_canopy_layer(Vector2(x * TILE_SIZE, y * TILE_SIZE), o_type)

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
			for dx in range(span):
				for dy in range(span):
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
		ObjectType.CONSTRUCTION:
			draw_rect(Rect2(p.x - 3, p.y - 3, 22, 20), PAL_OUTLINE, true)
			draw_rect(Rect2(p.x - 2, p.y - 2, 20, 18), PAL_SAND, true)
			draw_rect(Rect2(p.x, p.y, 16, 14), PAL_WOOD, false, 2.0)

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

func _draw_storybook_animal(a: Dictionary) -> void:
	var p: Vector2 = a["pos"]
	var body_col: Color = a["body_col"]
	var ear_col: Color = a["ear_col"]
	var shirt_col: Color = a["shirt_col"]
	var id_str: String = str(a["id"])
	var step_bob: float = abs(sin(env_anim_time * 3.5 + p.x)) * 1.0

	draw_rect(Rect2(p.x - 6, p.y + 2, 12, 3), Color(0, 0, 0, 0.22), true)
	draw_rect(Rect2(p.x - 5, p.y - 14 - step_bob, 10, 17), PAL_OUTLINE, true)
	draw_rect(Rect2(p.x - 4, p.y - 5 - step_bob, 8, 7), shirt_col, true)
	draw_rect(Rect2(p.x - 4, p.y - 13 - step_bob, 8, 8), body_col, true)

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

	draw_rect(Rect2(p.x - 3, p.y - 10 - step_bob, 1.5, 2), PAL_OUTLINE, true)
	draw_rect(Rect2(p.x + 1.5, p.y - 10 - step_bob, 1.5, 2), PAL_OUTLINE, true)
	draw_rect(Rect2(p.x - 4, p.y - 8 - step_bob, 1.5, 1), PAL_PINK, true)
	draw_rect(Rect2(p.x + 2.5, p.y - 8 - step_bob, 1.5, 1), PAL_PINK, true)

func _draw_storybook_player() -> void:
	var bob: float = abs(sin(walk_anim_time)) * 1.5
	var px: float = player_pos.x
	var py: float = player_pos.y

	draw_rect(Rect2(px - 6, py + 2, 12, 3), Color(0, 0, 0, 0.26), true)
	draw_rect(Rect2(px - 5, py - 14 - bob, 10, 17), PAL_OUTLINE, true)
	draw_rect(Rect2(px - 4, py - 5 - bob, 8, 7), PAL_OCEAN_BLUE, true)
	draw_rect(Rect2(px - 3, py - 6 - bob, 6, 2), PAL_CORAL, true)
	draw_rect(Rect2(px - 4, py - 13 - bob, 8, 7), PAL_CREAM, true)
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

	build_confirm_box_btn = _make_icon_label_btn("confirm", "确认", Vector2(44, 40), PAL_GRASS, true, 16)[0]
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
		{"id": BuildTool.MOVE_OBJECT,  "name": "移动", "icon": "move_ui"}
	]

	build_tool_buttons.clear()
	for td in tool_defs:
		var res_arr: Array = _make_icon_label_btn(td["icon"], td["name"], Vector2(53, 48), PAL_CREAM_DARK, true, 22)
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
		BuildTool.CLIFF_RAISE:  tool_desc = "【高地】堆筑二层悬崖"
		BuildTool.RIVER_DIG:    tool_desc = "【水域】挖掘河流与湖泊"
		BuildTool.ROAD_PAVE:    tool_desc = "【道路】铺设石路/木路/木桥"
		BuildTool.PLANT_PUT:    tool_desc = "【植物】种植花草/灌木/树木"
		BuildTool.BUILDING_PUT: tool_desc = "【建筑】选址建造新房屋"
		BuildTool.DECOR_PUT:    tool_desc = "【装饰】布置盆栽/长椅/路灯/喷泉"
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
	legend_lbl.text = "【小岛区域图例】\n• 红点：你的当前位置\n• 黄点：5位动物居民\n• 红顶：温馨岛民小屋\n• 蓝顶：河畔杂货铺\n• 白圈：中央喷泉广场\n• 棕色：木桥与观海码头"
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

	# 6. 对话框弹窗
	var dlg_res: Array = _create_modal_base("岛民交谈", "mail_ui", Vector2(450, 200))
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

	var dlg_ok: Button = _make_icon_label_btn("confirm_ui", "真温暖，我知道啦~", Vector2(190, 40), PAL_GRASS, false, 20)[0]
	dlg_ok.position = Vector2(130, 144)
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

	var cfm_yes: Button = _make_icon_label_btn("confirm_ui", "确认执行", Vector2(140, 40), PAL_CORAL, false, 20)[0]
	cfm_yes.position = Vector2(48, 132)
	cfm_yes.pressed.connect(func():
		_close_active_modal()
		if confirm_yes_callable.is_valid():
			confirm_yes_callable.call()
	)
	cfm_panel.add_child(cfm_yes)

	var cfm_no: Button = _make_icon_label_btn("cancel_ui", "取消返回", Vector2(140, 40), PAL_SAND, false, 20)[0]
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

func _open_dialog_modal(title_str: String, body_str: String) -> void:
	dialog_title_label.text = title_str
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
	var cell_px: float = 5.2 * map_zoom
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

func _save_game() -> bool:
	var data: Dictionary = {
		"version": 4,
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
	coins = int(data.get("coins", 1800))
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
					object_grid[x][y] = ObjectType.VILLAGER_HOUSE

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
