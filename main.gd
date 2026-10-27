extends Node2D

# ==============================================================================
# 《像素动物岛物语》 —— 100% 手机触屏优先完整实现版 (Godot 4.2+)
# 包含：
# 1. 手机触屏启动界面（开始新游戏二次确认、继续游戏、设置弹窗、退出）
# 2. 左下角大尺寸防卡死虚拟摇杆 + 右侧情境感知交互/工具/取消按钮组
# 3. 底部 6 槽位快捷物品栏（与真实背包、数量、工具使用完整连接）
# 4. 顶部简洁信息栏（现实时间、日期与季节、铃钱、状态提示）+ 右上角功能入口
# 5. 触屏背包网格系统 + 实时同步全岛大地图（支持触屏拖动与缩放）+ 商店与小屋弹窗
# 6. 专职手机岛建模式（10 项工具栏、单指连续画笔、矩形框选预览与二次点击确认、
#    独立视角拖动开关、屏幕一键撤销 Undo 栈、大面积改造无需材料/无耐久度限制）
# 7. 全量本地安全存档（地图地形/高度/物体、背包、快捷栏、货币、设置、切后台自动保存）
# ==============================================================================

const GRID_WIDTH: int = 36
const GRID_HEIGHT: int = 36
const TILE_SIZE: int = 16
const SAVE_PATH: String = "user://island_save_v2.json"
const TEMP_SAVE_PATH: String = "user://island_save_v2.tmp"

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
	FLOWER_WATERED = 12
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

# --- 地图与地形三维状态（仅在变更时 queue_redraw，不在每帧遍历） ---
var ground_grid: Array = []     # [x][y] -> GroundType
var elevation_grid: Array = []  # [x][y] -> 0:水面, 1:平地, 2:二层高地
var object_grid: Array = []     # [x][y] -> ObjectType

# --- 玩家角色与摄像机 ---
var player_pos: Vector2 = Vector2(16.5 * TILE_SIZE, 18.5 * TILE_SIZE)
var player_facing: Vector2 = Vector2.DOWN
var walk_anim_time: float = 0.0
var tool_swing_timer: float = 0.0
const BASE_MOVE_SPEED: float = 88.0
const COLLISION_HALF_SIZE: Vector2 = Vector2(4.5, 4.5)
var camera: Camera2D

# --- 友善的小动物 NPC 列表 ---
var animals: Array = [
	{
		"name": "糯米(小兔)",
		"pos": Vector2(14.5 * TILE_SIZE, 15.5 * TILE_SIZE),
		"home": Vector2(14.5 * TILE_SIZE, 15.5 * TILE_SIZE),
		"target": Vector2(14.5 * TILE_SIZE, 15.5 * TILE_SIZE),
		"color": Color(1.0, 0.94, 0.96),
		"ear_color": Color(0.98, 0.72, 0.78),
		"wait_timer": 2.0,
		"friendship": 1,
		"dialogs": [
			"今天岛上的海风真温柔呀！用右下角的【工具】或【岛建】可以把小岛打扮得更漂亮哦~",
			"听说在【岛建模式】里选择【框选】模式，用手指一拉就能铺好一整片广场呢！",
			"不管你隔多久才来岛上看我，我都会一直在这里等你，完全不用有压力哦！"
		]
	},
	{
		"name": "焦糖(小熊)",
		"pos": Vector2(22.5 * TILE_SIZE, 17.5 * TILE_SIZE),
		"home": Vector2(22.5 * TILE_SIZE, 17.5 * TILE_SIZE),
		"target": Vector2(22.5 * TILE_SIZE, 17.5 * TILE_SIZE),
		"color": Color(0.76, 0.52, 0.34),
		"ear_color": Color(0.55, 0.35, 0.20),
		"wait_timer": 3.5,
		"friendship": 1,
		"dialogs": [
			"嘿嘿，海滩上经常会冲上来漂亮的【海贝壳】，靠近它点右侧的【拾取】就能捡起来啦！",
			"如果你想买新的长椅、街灯或者鲜花包，随时去北边的【杂货铺】看看吧！",
			"累了的话随时点击右上角的【菜单】保存休息，岛上的生活最讲究自在啦。"
		]
	}
]

# --- 物品数据库与真实背包/快捷栏 ---
const ITEM_DB: Dictionary = {
	"shovel": {"name": "铁铲", "icon": "铲", "type": "tool", "color": Color(0.82, 0.65, 0.42), "desc": "挖掘泥土、清除杂草与移植花木（无耐久限制）"},
	"axe": {"name": "伐木斧", "icon": "斧", "type": "tool", "color": Color(0.75, 0.48, 0.35), "desc": "清理挡路的树木并获得木材（无耐久限制）"},
	"watering_can": {"name": "浇水壶", "icon": "壶", "type": "tool", "color": Color(0.42, 0.74, 0.95), "desc": "给鲜花和植物浇水，让花朵盛开发光"},
	"net": {"name": "捕虫网", "icon": "网", "type": "tool", "color": Color(0.58, 0.86, 0.46), "desc": "在草地与花丛旁挥网捕捉蝴蝶"},
	"rod": {"name": "钓鱼竿", "icon": "竿", "type": "tool", "color": Color(0.48, 0.68, 0.88), "desc": "面朝河水或大海抛竿钓鱼"},
	"flower_seed": {"name": "红花苗", "icon": "花", "type": "placeable", "obj_id": ObjectType.FLOWER_RED, "color": Color(0.96, 0.45, 0.58), "desc": "可在草地上直接种植可爱的红花", "price": 50},
	"bush_seed": {"name": "灌木苗", "icon": "灌", "type": "placeable", "obj_id": ObjectType.BUSH, "color": Color(0.32, 0.68, 0.38), "desc": "圆滚滚的四季常青灌木丛", "price": 80},
	"bench_item": {"name": "木长椅", "icon": "椅", "type": "placeable", "obj_id": ObjectType.BENCH, "color": Color(0.78, 0.54, 0.32), "desc": "温暖的户外木制长椅，可放置在岛上", "price": 200},
	"lamp_item": {"name": "复古街灯", "icon": "灯", "type": "placeable", "obj_id": ObjectType.LAMP, "color": Color(0.95, 0.85, 0.42), "desc": "夜晚会发出温暖光芒的像素路灯", "price": 260},
	"wood": {"name": "木材", "icon": "木", "type": "material", "color": Color(0.68, 0.46, 0.26), "desc": "散发清香的天然木材，可出售或装饰", "sell": 40},
	"shell": {"name": "海贝壳", "icon": "贝", "type": "material", "color": Color(0.98, 0.82, 0.88), "desc": "海浪冲上沙滩的精致贝壳，可在商店出售", "sell": 60},
	"fish": {"name": "小海鱼", "icon": "鱼", "type": "material", "color": Color(0.45, 0.78, 0.92), "desc": "刚钓上来的活蹦乱跳小鱼，可在商店出售", "sell": 120},
	"bug": {"name": "黄粉蝶", "icon": "蝶", "type": "material", "color": Color(0.98, 0.90, 0.38), "desc": "花丛间停驻的温暖小蝴蝶，可在商店出售", "sell": 100},
	"apple": {"name": "海岛苹果", "icon": "果", "type": "consumable", "color": Color(0.95, 0.35, 0.35), "desc": "香甜多汁的苹果，可在背包中直接食用", "sell": 50}
}

var inventory: Dictionary = {} # item_id -> count
var hotbar: Array = ["shovel", "axe", "watering_can", "net", "rod", "flower_seed"]
var selected_hotbar_index: int = 0
var selected_bag_item_id: String = ""

# --- 手机虚拟摇杆状态 ---
var joy_center: Vector2 = Vector2(92.0, 272.0)
var joy_radius: float = 48.0
var joy_knob_pos: Vector2 = Vector2(92.0, 272.0)
var joy_vector: Vector2 = Vector2.ZERO
var joy_touch_index: int = -1

# --- 情境互动检测缓存 ---
var nearby_interact_type: String = ""
var nearby_interact_cell: Vector2i = Vector2i(-1, -1)
var nearby_animal_idx: int = -1
var interact_check_accum: float = 0.0

# --- 手机岛建模式状态 ---
var current_build_tool: int = BuildTool.GROUND_GRASS
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
var current_stroke_changes: Array = [] # 单次连续拖动或框选的变更记录
var undo_stack: Array = []             # 撤销栈（最多保存 25 步批量或单步操作）
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
var toast_label: Label
var toast_timer: float = 0.0
var time_Refresh_timer: float = 0.0

var interact_btn: Button
var use_tool_btn: Button
var cancel_btn: Button
var mode_toggle_btn: Button
var hotbar_container: HBoxContainer
var hotbar_buttons: Array = []

var build_toolbar_panel: Control
var build_mode_hint_label: Label
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
var bag_assign_bar: HBoxContainer
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
	# 1. 初始化默认地图与默认背包
	_init_default_island()
	_init_default_inventory()

	# 2. 创建昼夜环境光
	canvas_modulate = CanvasModulate.new()
	add_child(canvas_modulate)

	# 3. 创建平滑摄像机
	camera = Camera2D.new()
	camera.position = player_pos
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	_update_camera_limits()
	add_child(camera)

	# 4. 构建全套手机触控 UI 与弹窗
	_build_all_mobile_ui()
	_update_time_and_lighting()

	# 5. 监听屏幕尺寸变化（适配不同比例手机全面屏与刘海安全区）
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	# 6. 默认进入手机启动主界面
	_switch_game_state(GameState.TITLE_SCREEN)

func _update_camera_limits() -> void:
	if camera == null:
		return
	camera.limit_left = -TILE_SIZE * 2
	camera.limit_top = -TILE_SIZE * 2
	camera.limit_right = (GRID_WIDTH + 2) * TILE_SIZE
	camera.limit_bottom = (GRID_HEIGHT + 2) * TILE_SIZE

# ==============================================================================
# 地图与背包初始化
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

			if edge_dist <= 1:
				g_type = GroundType.DEEP_WATER
				elev = 0
			elif edge_dist == 2:
				g_type = GroundType.SHALLOW_WATER
				elev = 0
			elif edge_dist <= 4:
				g_type = GroundType.SAND
				elev = 1
			else:
				g_type = GroundType.GRASS
				elev = 1

			# 北部二层小高地景观 (y 在 6..10, x 在 10..17)
			if x >= 10 and x <= 17 and y >= 6 and y <= 10:
				elev = 2

			# 自北向南的小河 (x = 20, 21)
			if edge_dist >= 3 and (x == 20 or x == 21):
				g_type = GroundType.RIVER
				elev = 0

			# 河中央的小木桥 (y = 17, 18)
			if (x == 20 or x == 21) and (y == 17 or y == 18):
				g_type = GroundType.BRIDGE
				elev = 1

			# 中心广场石板路
			if y >= 17 and y <= 18 and x >= 14 and x <= 23 and g_type != GroundType.BRIDGE:
				g_type = GroundType.STONE_PATH

			# 放置玩家温馨小屋 (15, 14) 与 岛屿杂货商店 (24, 14)
			if x == 15 and y == 14:
				o_type = ObjectType.HOUSE
			elif x == 24 and y == 14:
				o_type = ObjectType.SHOP
			elif g_type == GroundType.SAND and ((x + y * 5) % 19 == 0):
				o_type = ObjectType.SHELL
			elif g_type == GroundType.GRASS and elev == 1:
				if (x in [8, 11, 27, 29]) and (y in [9, 13, 23, 27]):
					o_type = ObjectType.TREE
				elif (x == 13 and y == 17):
					o_type = ObjectType.LAMP
				elif (x == 17 and y == 16):
					o_type = ObjectType.BENCH
				elif (x + y * 3) % 17 == 0 and abs(x - 16) > 3:
					o_type = ObjectType.FLOWER_RED
				elif (x * 7 + y) % 23 == 0 and abs(x - 16) > 3:
					o_type = ObjectType.WEED

			g_col.append(g_type)
			e_col.append(elev)
			o_col.append(o_type)

		ground_grid.append(g_col)
		elevation_grid.append(e_col)
		object_grid.append(o_col)

	player_pos = Vector2(16.5 * TILE_SIZE, 18.5 * TILE_SIZE)
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
		"flower_seed": 12,
		"bush_seed": 6,
		"bench_item": 2,
		"lamp_item": 2,
		"shell": 3,
		"wood": 8,
		"apple": 3
	}
	hotbar = ["shovel", "axe", "watering_can", "net", "rod", "flower_seed"]
	selected_hotbar_index = 0

# ==============================================================================
# 主循环：角色移动、小动物散步、情境互动刷新
# ==============================================================================

func _physics_process(delta: float) -> void:
	if game_state == GameState.TITLE_SCREEN or active_modal != null:
		return

	if tool_swing_timer > 0.0:
		tool_swing_timer = maxf(0.0, tool_swing_timer - delta)
		queue_redraw()

	# 仅在日常漫步模式下移动角色（岛建模式下冻结角色移动，避免与触屏拖拽地形冲突）
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
			queue_redraw()
			if hud_overlay_draw != null:
				hud_overlay_draw.queue_redraw()
		elif walk_anim_time != 0.0:
			walk_anim_time = 0.0
			queue_redraw()

	# 小动物悠闲散步
	_update_animals(delta)

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_label != null:
			toast_label.text = ""

	time_Refresh_timer += delta
	if time_Refresh_timer >= 2.0:
		time_Refresh_timer = 0.0
		_update_time_and_lighting()

	if game_state == GameState.EXPLORE_MODE and active_modal == null:
		interact_check_accum += delta
		if interact_check_accum >= 0.12:
			interact_check_accum = 0.0
			_refresh_nearby_interaction()

func _update_animals(delta: float) -> void:
	var any_moved: bool = false
	for i in range(animals.size()):
		var a: Dictionary = animals[i]
		var pos: Vector2 = a["pos"]
		var target: Vector2 = a["target"]
		if pos.distance_to(target) > 2.0:
			var dir: Vector2 = (target - pos).normalized()
			var next_pos: Vector2 = pos + dir * 24.0 * delta
			var cell: Vector2i = world_to_grid(next_pos)
			if is_cell_walkable(cell.x, c_cell_y(cell)) and next_pos.distance_to(player_pos) > 14.0:
				a["pos"] = next_pos
				any_moved = true
			else:
				a["target"] = pos
		else:
			var wt: float = float(a["wait_timer"]) - delta
			if wt <= 0.0:
				wt = randf_range(2.5, 5.5)
				var home: Vector2 = a["home"]
				var candidate: Vector2 = home + Vector2(randf_range(-48.0, 48.0), randf_range(-48.0, 48.0))
				var c_cell: Vector2i = world_to_grid(candidate)
				if is_cell_walkable(c_cell.x, c_cell.y):
					a["target"] = candidate
			a["wait_timer"] = wt
	if any_moved:
		queue_redraw()

func c_cell_y(c: Vector2i) -> int:
	return c.y

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
	if o_type in [ObjectType.TREE, ObjectType.BUSH, ObjectType.BENCH, ObjectType.LAMP, ObjectType.FENCE, ObjectType.HOUSE, ObjectType.SHOP, ObjectType.CONSTRUCTION]:
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
# 情境互动检测与右侧按钮真实响应
# ==============================================================================

func _refresh_nearby_interaction() -> void:
	nearby_interact_type = ""
	nearby_interact_cell = Vector2i(-1, -1)
	nearby_animal_idx = -1

	# 1. 优先检查身边是否有小动物可交谈
	for i in range(animals.size()):
		var a_pos: Vector2 = animals[i]["pos"]
		if player_pos.distance_to(a_pos) <= 26.0:
			nearby_interact_type = "animal"
			nearby_animal_idx = i
			interact_btn.text = "交谈"
			interact_btn.disabled = false
			return

	# 2. 检查面朝格子或周围 1 格内的可互动对象
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
		if obj == ObjectType.SHELL:
			nearby_interact_type = "pickup_shell"
			nearby_interact_cell = c
			interact_btn.text = "拾取"
			interact_btn.disabled = false
			return
		elif obj == ObjectType.SHOP:
			nearby_interact_type = "shop"
			nearby_interact_cell = c
			interact_btn.text = "商店"
			interact_btn.disabled = false
			return
		elif obj == ObjectType.HOUSE:
			nearby_interact_type = "house"
			nearby_interact_cell = c
			interact_btn.text = "进入"
			interact_btn.disabled = false
			return
		elif obj == ObjectType.CONSTRUCTION:
			nearby_interact_type = "construction"
			nearby_interact_cell = c
			interact_btn.text = "查看施工"
			interact_btn.disabled = false
			return
		elif obj == ObjectType.BENCH:
			nearby_interact_type = "bench"
			nearby_interact_cell = c
			interact_btn.text = "休息"
			interact_btn.disabled = false
			return

	interact_btn.text = "互动"
	interact_btn.disabled = false

func _on_interact_pressed() -> void:
	_refresh_nearby_interaction()
	match nearby_interact_type:
		"animal":
			if nearby_animal_idx >= 0 and nearby_animal_idx < animals.size():
				var a: Dictionary = animals[nearby_animal_idx]
				var d_list: Array = a["dialogs"]
				var msg: String = d_list[int(a["friendship"] - 1) % d_list.size()]
				a["friendship"] = int(a["friendship"]) + 1
				_open_dialog_modal(a["name"] + " (友好度 ♥" + str(a["friendship"]) + ")", msg)
		"pickup_shell":
			if is_valid_cell(nearby_interact_cell.x, nearby_interact_cell.y):
				object_grid[nearby_interact_cell.x][nearby_interact_cell.y] = ObjectType.NONE
				_add_item("shell", 1)
				queue_redraw()
				_refresh_nearby_interaction()
				_show_toast("拾取了【海贝壳】×1！已放入背包")
		"shop":
			_open_shop_modal()
		"house":
			_open_dialog_modal("温馨的岛民小屋", "你回到了温暖舒适的小屋里小憩片刻，海风吹拂着窗纱，心情格外宁静放松！\n（当前已自动为你保存最新进度）")
			_save_game()
		"construction":
			_open_dialog_modal("公共设施施工现场", "大型建筑正在施工中，原则上在现实日期进入下一天清晨（05:00后）自动完工。\n你也可以在设置或此处体验温暖的小岛建设！")
		"bench":
			_show_toast("坐在木长椅上吹了会儿海风，真惬意~")
		_:
			_show_toast("附近没有可交互的对象，试试靠近小动物、贝壳、商店或小屋吧！")

# ==============================================================================
# 工具使用与快捷栏真实联动
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
		_show_toast("前方超出岛屿边界")
		return

	var item_info: Dictionary = ITEM_DB[item_id]
	var g_type: int = ground_grid[f_cell.x][f_cell.y]
	var o_type: int = object_grid[f_cell.x][f_cell.y]

	match item_id:
		"shovel":
			if o_type in [ObjectType.WEED, ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED, ObjectType.BUSH]:
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				if o_type in [ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED]:
					_add_item("flower_seed", 1)
					_show_toast("用铁铲移植了花苗，回收【红花苗】×1")
				elif o_type == ObjectType.BUSH:
					_add_item("bush_seed", 1)
					_show_toast("回收了【灌木苗】×1")
				else:
					_show_toast("用铁铲清理了杂草！")
			elif o_type == ObjectType.NONE and g_type == GroundType.GRASS and elevation_grid[f_cell.x][f_cell.y] == 1:
				ground_grid[f_cell.x][f_cell.y] = GroundType.TILLED_SOIL
				_show_toast("翻松了一块泥土地！")
			elif g_type == GroundType.TILLED_SOIL:
				ground_grid[f_cell.x][f_cell.y] = GroundType.GRASS
				_show_toast("将土地恢复成了平整草地！")
			else:
				_show_toast("铁铲可用于除草、移植花木或翻松草地（大面积改造请点右侧【岛建】）")
		"axe":
			if o_type == ObjectType.TREE:
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_add_item("wood", 3)
				_add_item("apple", 1)
				_show_toast("清理了树木！获得【木材】×3、【海岛苹果】×1")
			elif o_type in [ObjectType.BENCH, ObjectType.LAMP, ObjectType.FENCE]:
				if o_type == ObjectType.BENCH:
					_add_item("bench_item", 1)
				elif o_type == ObjectType.LAMP:
					_add_item("lamp_item", 1)
				object_grid[f_cell.x][f_cell.y] = ObjectType.NONE
				_show_toast("已拆卸回收前方装饰物！")
			else:
				_show_toast("请面朝树木或户外家具再使用伐木斧")
		"watering_can":
			if o_type == ObjectType.FLOWER_RED:
				object_grid[f_cell.x][f_cell.y] = ObjectType.FLOWER_WATERED
				_show_toast("给花朵浇了水，花瓣闪着晶莹的水珠！")
			else:
				_show_toast("请面朝红花使用浇水壶")
		"net":
			if o_type in [ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED, ObjectType.BUSH] or g_type == GroundType.GRASS:
				_add_item("bug", 1)
				_show_toast("挥动捕虫网！捉到了温暖的【黄粉蝶】×1！")
			else:
				_show_toast("在草地或花丛旁挥网更容易捉到小蝴蝶哦")
		"rod":
			if g_type in [GroundType.RIVER, GroundType.SHALLOW_WATER, GroundType.DEEP_WATER]:
				_add_item("fish", 1)
				_show_toast("哗啦！钓上了一条活蹦乱跳的【小海鱼】×1！")
			else:
				_show_toast("请面朝小河或海边水面再使用钓鱼竿")
		_:
			if item_info.get("type", "") == "placeable":
				var count: int = int(inventory.get(item_id, 0))
				if count <= 0:
					_show_toast("该物品数量不足")
					return
				if o_type == ObjectType.NONE and g_type in [GroundType.GRASS, GroundType.SAND, GroundType.STONE_PATH, GroundType.WOOD_PATH, GroundType.TILLED_SOIL] and elevation_grid[f_cell.x][f_cell.y] == 1:
					object_grid[f_cell.x][f_cell.y] = int(item_info["obj_id"])
					_consume_item(item_id, 1)
					_show_toast("已在前方放置【" + str(item_info["name"]) + "】！")
				else:
					_show_toast("前方格子已有物体或是水面，无法放置")
			elif item_info.get("type", "") == "consumable":
				_consume_item(item_id, 1)
				_show_toast("品尝了美味的【" + str(item_info["name"]) + "】，神清气爽！")
			else:
				_show_toast("持有材料：【" + str(item_info["name"]) + "】，可在商店出售换取铃钱")

	queue_redraw()
	_refresh_hotbar_ui()
	_refresh_nearby_interaction()

func _add_item(item_id: String, amount: int) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	# 如果快捷栏有空槽且是新物品，自动放入方便点击
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
# 手机岛建模式：单点、连续笔刷拖拽、矩形框选、规则校验与一键撤销 (Undo)
# ==============================================================================

func _switch_game_state(new_state: int) -> void:
	# 切换状态前重置所有触控输入，彻底防止摇杆或拖拽卡死
	_reset_touch_states()
	game_state = new_state

	if title_panel != null:
		title_panel.visible = (game_state == GameState.TITLE_SCREEN)
	if hud_root != null:
		hud_root.visible = (game_state != GameState.TITLE_SCREEN)

	if game_state == GameState.EXPLORE_MODE:
		if build_toolbar_panel != null:
			build_toolbar_panel.visible = false
		if hotbar_container != null:
			hotbar_container.visible = true
		if interact_btn != null:
			interact_btn.visible = true
		if use_tool_btn != null:
			use_tool_btn.visible = true
		if mode_toggle_btn != null:
			mode_toggle_btn.text = "🛠 岛建"
		if camera != null:
			camera.zoom = Vector2(setting_camera_zoom, setting_camera_zoom)
			camera.position = player_pos
	elif game_state == GameState.BUILD_MODE:
		if build_toolbar_panel != null:
			build_toolbar_panel.visible = true
		if hotbar_container != null:
			hotbar_container.visible = false
		if interact_btn != null:
			interact_btn.visible = false
		if use_tool_btn != null:
			use_tool_btn.visible = false
		if mode_toggle_btn != null:
			mode_toggle_btn.text = "🚶 返回漫步"
		if camera != null:
			# 岛建模式下视野稍微拉广，方便大面积手指操作
			var bz: float = maxf(0.85, setting_camera_zoom * 0.9)
			camera.zoom = Vector2(bz, bz)
		_update_build_ui_labels()

	queue_redraw()
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

## 判断某个格子在当前岛建工具下是否允许修改（保护重要建筑、深海边界、玩家与小动物所在格）
func is_cell_editable_for_tool(gx: int, gy: int, tool_id: int) -> bool:
	if gx <= 2 or gx >= GRID_WIDTH - 3 or gy <= 2 or gy >= GRID_HEIGHT - 3:
		return false
	var obj: int = object_grid[gx][gy]
	# 永久重要建筑（小屋与商店）不可被普通地形工具直接覆盖破坏
	if obj in [ObjectType.HOUSE, ObjectType.SHOP]:
		return false

	# 挖河或建高地时，不能把玩家自己或小动物脚下直接挖成深坑
	if tool_id in [BuildTool.RIVER_DIG, BuildTool.CLIFF_RAISE, BuildTool.BUILDING_PUT]:
		var p_cell: Vector2i = world_to_grid(player_pos)
		if p_cell.x == gx and p_cell.y == gy:
			return false
		for a in animals:
			var a_cell: Vector2i = world_to_grid(a["pos"])
			if a_cell.x == gx and a_cell.y == gy:
				return false
	return true

## 对单个格子执行岛建修改，并将修改前的旧状态记入 stroke_changes 以便一键撤销
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
			# 铲平地形并批量清除杂草、普通装饰与施工牌
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
			if build_sub_road == GroundType.BRIDGE:
				new_g = GroundType.BRIDGE
				new_e = 1
			else:
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

	# 检查当前笔触是否已经记录过该格子的初始状态（防止同一笔划滑过两次覆盖初始值）
	var already_recorded: bool = false
	for item in stroke_changes:
		if item["x"] == gx and item["y"] == gy:
			already_recorded = true
			break
	if not already_recorded:
		stroke_changes.append({
			"x": gx,
			"y": gy,
			"old_g": old_g,
			"old_e": old_e,
			"old_o": old_o
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
	queue_redraw()
	_update_build_ui_labels()
	_show_toast("已撤销上一步岛建修改（共恢复 %d 个格子）" % last_changes.size())

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
	queue_redraw()
	if modified_count > 0:
		_show_toast("已完成区域批量改造（共修改 %d 格，可随时点击【撤销】恢复）" % modified_count)
	else:
		_show_toast("所选区域无需修改或处于受保护区域")

# ==============================================================================
# 统一触屏输入处理（虚拟摇杆 + 触屏岛建单指连续涂抹/矩形框选/视角平移）
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.TITLE_SCREEN or active_modal != null:
		return

	# 1. 日常漫步模式：左下角多点触控虚拟摇杆
	if game_state == GameState.EXPLORE_MODE:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				# 左下区域（避开底部快捷栏与顶部信息栏）激活虚拟摇杆
				if joy_touch_index == -1 and touch.position.x < 220.0 and touch.position.y > 120.0 and touch.position.y < 325.0:
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

	# 2. 手机岛建模式：专职触控编辑（绝不移动角色，且视角平移与绘制严格分离）
	if game_state == GameState.BUILD_MODE:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				# 忽略顶部状态栏 (y < 44) 与底部岛建工具栏 (y > 282) 及右侧按钮区 (x > 530)
				if touch.position.y < 44.0 or touch.position.y > 282.0 or touch.position.x > 530.0:
					return
				if build_touch_index == -1:
					build_touch_index = touch.index
					var world_pt: Vector2 = get_canvas_transform().affine_inverse() * touch.position
					var cell: Vector2i = world_to_grid(world_pt)

					if is_camera_pan_mode:
						# 视角拖动模式：单指平滑移动地图视角
						build_drag_start_cell = cell
					elif is_box_select_mode:
						# 矩形框选模式：如果已有待确认框且再次点击框内，则直接确认执行！
						if has_pending_box and pending_box_rect.has_point(cell):
							_execute_pending_box_selection()
							build_touch_index = -1
							return
						build_drag_start_cell = cell
						build_drag_curr_cell = cell
						_update_pending_box_from_drag()
						queue_redraw()
					else:
						# 单点 / 连续画笔涂抹模式：手指按下立即修改当前格，拖动连续修改
						current_stroke_changes.clear()
						build_drag_curr_cell = cell
						if _apply_build_tool_to_cell(cell.x, cell.y, current_build_tool, current_stroke_changes):
							queue_redraw()
			else:
				if touch.index == build_touch_index:
					build_touch_index = -1
					if not is_camera_pan_mode and not is_box_select_mode:
						if not current_stroke_changes.is_empty():
							_commit_stroke_to_undo(current_stroke_changes)
							current_stroke_changes.clear()
					queue_redraw()

		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == build_touch_index:
				if is_camera_pan_mode:
					camera.position -= drag.relative / camera.zoom.x
					var map_px := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
					camera.position.x = clampf(camera.position.x, 64.0, map_px.x - 64.0)
					camera.position.y = clampf(camera.position.y, 64.0, map_px.y - 64.0)
					queue_redraw()
				else:
					var world_pt: Vector2 = get_canvas_transform().affine_inverse() * drag.position
					var cell: Vector2i = world_to_grid(world_pt)
					if cell != build_drag_curr_cell:
						build_drag_curr_cell = cell
						if is_box_select_mode:
							_update_pending_box_from_drag()
							queue_redraw()
						else:
							if _apply_build_tool_to_cell(cell.x, cell.y, current_build_tool, current_stroke_changes):
								queue_redraw()

func _update_pending_box_from_drag() -> void:
	if not is_valid_cell(build_drag_start_cell.x, build_drag_start_cell.y):
		return
	var x1: int = clampi(mini(build_drag_start_cell.x, build_drag_curr_cell.x), 2, GRID_WIDTH - 3)
	var y1: int = clampi(mini(build_drag_start_cell.y, build_drag_curr_cell.y), 2, GRID_HEIGHT - 3)
	var x2: int = clampi(maxi(build_drag_start_cell.x, build_drag_curr_cell.x), 2, GRID_WIDTH - 3)
	var y2: int = clampi(maxi(build_drag_start_cell.y, build_drag_curr_cell.y), 2, GRID_HEIGHT - 3)

	if x2 - x1 + 1 > MAX_BOX_SPAN:
		x2 = x1 + MAX_BOX_SPAN - 1
	if y2 - y1 + 1 > MAX_BOX_SPAN:
		y2 = y1 + MAX_BOX_SPAN - 1

	pending_box_rect = Rect2i(x1, y1, x2 - x1 + 1, y2 - y1 + 1)
	has_pending_box = true
	if build_confirm_box_btn != null:
		build_confirm_box_btn.visible = true
		build_confirm_box_btn.text = "✅ 确认框选 (%d×%d)" % [pending_box_rect.size.x, pending_box_rect.size.y]

func _update_joystick(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joy_center
	# 即使手指滑出摇杆圆圈范围，依然平滑锁定在圆周方向上，绝不失控
	if offset.length() > joy_radius:
		offset = offset.normalized() * joy_radius
	joy_knob_pos = joy_center + offset
	joy_vector = offset / joy_radius
	if hud_overlay_draw != null:
		hud_overlay_draw.queue_redraw()

# ==============================================================================
# 像素世界渲染（地图、二层高地悬崖边缘、建筑、小动物、玩家、岛建红绿预览框）
# ==============================================================================

func _draw() -> void:
	# 1. 绘制底层地形与二层高地悬崖
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var g_type: int = ground_grid[x][y]
			var elev: int = elevation_grid[x][y]
			var is_alt: bool = ((x + y) % 2 == 0)

			var base_col: Color = _get_ground_color(g_type, elev, is_alt)
			draw_rect(rect, base_col, true)

			# 二层高地立体悬崖边缘表现
			if elev == 2:
				if y + 1 < GRID_HEIGHT and elevation_grid[x][y + 1] < 2:
					draw_rect(Rect2(rect.position.x, rect.position.y + 12, TILE_SIZE, 4), Color(0.55, 0.42, 0.28), true)
					draw_rect(Rect2(rect.position.x, rect.position.y + 11, TILE_SIZE, 1), Color(0.68, 0.88, 0.52), true)
				if x > 0 and elevation_grid[x - 1][y] < 2:
					draw_rect(Rect2(rect.position.x, rect.position.y, 2, TILE_SIZE), Color(0.58, 0.45, 0.30), true)
				if x + 1 < GRID_WIDTH and elevation_grid[x + 1][y] < 2:
					draw_rect(Rect2(rect.position.x + 14, rect.position.y, 2, TILE_SIZE), Color(0.58, 0.45, 0.30), true)

			# 地面纹理细节
			if g_type == GroundType.BRIDGE:
				draw_rect(Rect2(rect.position.x, rect.position.y + 2, TILE_SIZE, 2), Color(0.45, 0.28, 0.15), true)
				draw_rect(Rect2(rect.position.x, rect.position.y + 12, TILE_SIZE, 2), Color(0.45, 0.28, 0.15), true)
			elif g_type == GroundType.STONE_PATH:
				draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, 5, 5), Color(0.82, 0.81, 0.78), true)
				draw_rect(Rect2(rect.position.x + 9, rect.position.y + 9, 5, 5), Color(0.82, 0.81, 0.78), true)
			elif g_type == GroundType.WOOD_PATH:
				draw_rect(Rect2(rect.position.x, rect.position.y + 7, TILE_SIZE, 1), Color(0.52, 0.35, 0.20), true)
			elif g_type in [GroundType.SHALLOW_WATER, GroundType.RIVER] and (x + y) % 3 == 0:
				draw_rect(Rect2(rect.position.x + 4, rect.position.y + 6, 6, 2), Color(0.85, 0.96, 1.0, 0.55), true)

			# 岛建模式下的轻量辅助网格线
			if game_state == GameState.BUILD_MODE and setting_show_grid_in_build and x >= 3 and x < GRID_WIDTH - 3 and y >= 3 and y < GRID_HEIGHT - 3:
				draw_rect(rect, Color(1, 1, 1, 0.12), false, 1.0)

	# 2. 绘制地面物体与建筑
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var o_type: int = object_grid[x][y]
			if o_type != ObjectType.NONE:
				_draw_map_object(Vector2(x * TILE_SIZE, y * TILE_SIZE), o_type)

	# 3. 漫步模式下高亮显示玩家面朝的操作格
	if game_state == GameState.EXPLORE_MODE:
		var fc: Vector2i = get_front_cell()
		if is_valid_cell(fc.x, fc.y):
			draw_rect(Rect2(fc.x * TILE_SIZE + 1, fc.y * TILE_SIZE + 1, TILE_SIZE - 2, TILE_SIZE - 2), Color(1.0, 0.96, 0.55, 0.45), false, 1.2)

	# 4. 绘制小动物居民
	for a in animals:
		_draw_animal(a)

	# 5. 绘制玩家像素小人
	_draw_player()

	# 6. 岛建模式下绘制红绿合法性预览框（批量框选或单格笔刷）
	if game_state == GameState.BUILD_MODE:
		if has_pending_box:
			for gx in range(pending_box_rect.position.x, pending_box_rect.end.x):
				for gy in range(pending_box_rect.position.y, pending_box_rect.end.y):
					var cell_rect := Rect2(gx * TILE_SIZE, gy * TILE_SIZE, TILE_SIZE, TILE_SIZE)
					var ok: bool = is_cell_editable_for_tool(gx, gy, current_build_tool)
					var fill_col := Color(0.2, 0.95, 0.35, 0.38) if ok else Color(0.95, 0.25, 0.25, 0.45)
					draw_rect(cell_rect, fill_col, true)
			var box_px := Rect2(pending_box_rect.position * TILE_SIZE, pending_box_rect.size * TILE_SIZE)
			draw_rect(box_px, Color(1.0, 0.95, 0.3, 0.95), false, 2.0)
		elif is_valid_cell(build_drag_curr_cell.x, build_drag_curr_cell.y):
			var c_rect := Rect2(build_drag_curr_cell.x * TILE_SIZE, build_drag_curr_cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var ok: bool = is_cell_editable_for_tool(build_drag_curr_cell.x, build_drag_curr_cell.y, current_build_tool)
			draw_rect(c_rect, Color(0.2, 0.95, 0.35, 0.45) if ok else Color(0.95, 0.25, 0.25, 0.45), true)
			draw_rect(c_rect, Color.WHITE, false, 1.5)

func _get_ground_color(g_type: int, elev: int, is_alt: bool) -> Color:
	if elev == 2 and g_type == GroundType.GRASS:
		return Color(0.52, 0.83, 0.46) if is_alt else Color(0.49, 0.80, 0.43)
	match g_type:
		GroundType.DEEP_WATER: return Color(0.16, 0.45, 0.68) if is_alt else Color(0.18, 0.48, 0.71)
		GroundType.SHALLOW_WATER: return Color(0.28, 0.65, 0.85) if is_alt else Color(0.31, 0.68, 0.88)
		GroundType.SAND: return Color(0.95, 0.87, 0.62) if is_alt else Color(0.93, 0.84, 0.59)
		GroundType.GRASS: return Color(0.45, 0.76, 0.42) if is_alt else Color(0.42, 0.73, 0.39)
		GroundType.RIVER: return Color(0.25, 0.62, 0.86) if is_alt else Color(0.28, 0.66, 0.89)
		GroundType.BRIDGE: return Color(0.68, 0.46, 0.26) if is_alt else Color(0.63, 0.42, 0.23)
		GroundType.STONE_PATH: return Color(0.74, 0.73, 0.70) if is_alt else Color(0.70, 0.69, 0.66)
		GroundType.WOOD_PATH: return Color(0.72, 0.52, 0.32) if is_alt else Color(0.68, 0.48, 0.29)
		GroundType.TILLED_SOIL: return Color(0.58, 0.42, 0.26) if is_alt else Color(0.54, 0.39, 0.24)
	return Color.WHITE

func _draw_map_object(p: Vector2, o_type: int) -> void:
	match o_type:
		ObjectType.TREE:
			draw_rect(Rect2(p.x + 3, p.y + 12, 10, 3), Color(0, 0, 0, 0.22), true)
			draw_rect(Rect2(p.x + 6, p.y + 9, 4, 6), Color(0.52, 0.33, 0.18), true)
			draw_rect(Rect2(p.x + 2, p.y + 3, 12, 8), Color(0.24, 0.56, 0.28), true)
			draw_rect(Rect2(p.x + 4, p.y + 1, 8, 6), Color(0.32, 0.66, 0.34), true)
		ObjectType.FLOWER_RED, ObjectType.FLOWER_WATERED:
			draw_rect(Rect2(p.x + 7, p.y + 9, 2, 4), Color(0.30, 0.60, 0.28), true)
			draw_rect(Rect2(p.x + 5, p.y + 5, 6, 5), Color(0.98, 0.42, 0.55), true)
			draw_rect(Rect2(p.x + 7, p.y + 7, 2, 2), Color(1.0, 0.92, 0.35), true)
			if o_type == ObjectType.FLOWER_WATERED:
				draw_rect(Rect2(p.x + 3, p.y + 3, 2, 2), Color(0.65, 0.95, 1.0), true)
		ObjectType.WEED:
			draw_rect(Rect2(p.x + 4, p.y + 8, 2, 5), Color(0.32, 0.58, 0.25), true)
			draw_rect(Rect2(p.x + 7, p.y + 6, 2, 7), Color(0.36, 0.62, 0.28), true)
			draw_rect(Rect2(p.x + 10, p.y + 9, 2, 4), Color(0.32, 0.58, 0.25), true)
		ObjectType.SHELL:
			draw_rect(Rect2(p.x + 5, p.y + 7, 6, 5), Color(0.98, 0.80, 0.86), true)
			draw_rect(Rect2(p.x + 6, p.y + 6, 4, 2), Color(1.0, 0.92, 0.95), true)
		ObjectType.BUSH:
			draw_rect(Rect2(p.x + 2, p.y + 5, 12, 9), Color(0.26, 0.58, 0.30), true)
			draw_rect(Rect2(p.x + 4, p.y + 3, 8, 6), Color(0.34, 0.68, 0.38), true)
		ObjectType.BENCH:
			draw_rect(Rect2(p.x + 2, p.y + 6, 12, 6), Color(0.76, 0.50, 0.26), true)
			draw_rect(Rect2(p.x + 3, p.y + 12, 2, 3), Color(0.42, 0.28, 0.14), true)
			draw_rect(Rect2(p.x + 11, p.y + 12, 2, 3), Color(0.42, 0.28, 0.14), true)
		ObjectType.LAMP:
			draw_rect(Rect2(p.x + 7, p.y + 5, 2, 10), Color(0.25, 0.28, 0.32), true)
			draw_rect(Rect2(p.x + 4, p.y + 2, 8, 4), Color(1.0, 0.92, 0.45), true)
		ObjectType.FENCE:
			draw_rect(Rect2(p.x + 2, p.y + 4, 3, 10), Color(0.85, 0.72, 0.52), true)
			draw_rect(Rect2(p.x + 11, p.y + 4, 3, 10), Color(0.85, 0.72, 0.52), true)
			draw_rect(Rect2(p.x + 1, p.y + 7, 14, 2), Color(0.78, 0.64, 0.44), true)
		ObjectType.HOUSE:
			draw_rect(Rect2(p.x - 4, p.y - 6, 24, 20), Color(0.96, 0.90, 0.78), true)
			draw_rect(Rect2(p.x - 6, p.y - 12, 28, 8), Color(0.88, 0.38, 0.32), true)
			draw_rect(Rect2(p.x + 5, p.y + 5, 6, 9), Color(0.55, 0.35, 0.20), true)
		ObjectType.SHOP:
			draw_rect(Rect2(p.x - 4, p.y - 6, 24, 20), Color(0.88, 0.94, 0.98), true)
			draw_rect(Rect2(p.x - 6, p.y - 12, 28, 8), Color(0.28, 0.58, 0.85), true)
			draw_rect(Rect2(p.x + 5, p.y + 5, 6, 9), Color(0.75, 0.48, 0.22), true)
		ObjectType.CONSTRUCTION:
			draw_rect(Rect2(p.x - 2, p.y - 2, 20, 18), Color(0.85, 0.68, 0.38), true)
			draw_rect(Rect2(p.x, p.y, 16, 14), Color(0.45, 0.32, 0.18), false, 2.0)

func _draw_animal(a: Dictionary) -> void:
	var p: Vector2 = a["pos"]
	var col: Color = a["color"]
	var ear_col: Color = a["ear_color"]
	draw_rect(Rect2(p.x - 5, p.y + 2, 10, 3), Color(0, 0, 0, 0.24), true)
	draw_rect(Rect2(p.x - 4, p.y - 5, 8, 7), Color(0.95, 0.62, 0.45), true)
	draw_rect(Rect2(p.x - 4, p.y - 12, 8, 7), col, true)
	draw_rect(Rect2(p.x - 4, p.y - 16, 3, 4), ear_col, true)
	draw_rect(Rect2(p.x + 1, p.y - 16, 3, 4), ear_col, true)
	draw_rect(Rect2(p.x - 2, p.y - 9, 1.5, 2), Color(0.15, 0.15, 0.15), true)
	draw_rect(Rect2(p.x + 1, p.y - 9, 1.5, 2), Color(0.15, 0.15, 0.15), true)

func _draw_player() -> void:
	var bob: float = abs(sin(walk_anim_time)) * 1.5
	var px: float = player_pos.x
	var py: float = player_pos.y
	draw_rect(Rect2(px - 5, py + 2, 10, 3), Color(0, 0, 0, 0.28), true)
	draw_rect(Rect2(px - 4, py - 5 - bob, 8, 7), Color(0.28, 0.56, 0.88), true)
	draw_rect(Rect2(px - 4, py - 12 - bob, 8, 7), Color(1.0, 0.86, 0.74), true)
	draw_rect(Rect2(px - 6, py - 14 - bob, 12, 3), Color(0.95, 0.78, 0.35), true)
	draw_rect(Rect2(px - 4, py - 16 - bob, 8, 2), Color(0.92, 0.62, 0.28), true)
	var eye_x: float = clampf(player_facing.x * 1.5, -1.5, 1.5)
	draw_rect(Rect2(px - 2.5 + eye_x, py - 9 - bob, 1.5, 2), Color(0.18, 0.15, 0.15), true)
	draw_rect(Rect2(px + 1.0 + eye_x, py - 9 - bob, 1.5, 2), Color(0.18, 0.15, 0.15), true)

	# 挥动工具时的视觉反馈
	if tool_swing_timer > 0.0:
		var swing_pos: Vector2 = player_pos + player_facing.normalized() * 10.0
		draw_circle(swing_pos, 5.0, Color(1.0, 0.95, 0.6, 0.85))

# ==============================================================================
# 手机全面屏 UI 架构（启动界面 + HUD + 快捷栏 + 岛建栏 + 背包/地图/设置/商店弹窗）
# ==============================================================================

func _make_touch_btn(txt: String, min_size: Vector2, bg_col: Color = Color(0.18, 0.25, 0.32, 0.92)) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = min_size
	btn.size = min_size
	btn.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1.0, 0.96, 0.82, 0.45)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = bg_col.lightened(0.22)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_pressed)
	return btn

func _build_all_mobile_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# ---------------- 1. 游戏的正式手机启动界面 ----------------
	title_panel = Control.new()
	title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(title_panel)

	var title_bg := ColorRect.new()
	title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bg.color = Color(0.08, 0.16, 0.24, 0.82)
	title_panel.add_child(title_bg)

	var title_card := Panel.new()
	title_card.size = Vector2(340, 270)
	title_card.position = Vector2(150, 45)
	title_panel.add_child(title_card)

	var game_title_lbl := Label.new()
	game_title_lbl.text = "🌴 像素动物岛物语 🌴"
	game_title_lbl.position = Vector2(55, 18)
	game_title_lbl.add_theme_font_size_override("font_size", 22)
	game_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62))
	title_card.add_child(game_title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "温暖单机 · 自由岛建 · 触屏畅玩版"
	sub_lbl.position = Vector2(72, 48)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	title_card.add_child(sub_lbl)

	var btn_continue := _make_touch_btn("▶ 继续游戏 (读取存档)", Vector2(240, 42), Color(0.22, 0.56, 0.36))
	btn_continue.position = Vector2(50, 82)
	btn_continue.pressed.connect(func():
		if FileAccess.file_exists(SAVE_PATH):
			_load_game()
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("欢迎回到小岛！已恢复上次的岛屿进度")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_save_game()
			_show_toast("欢迎来到你的新岛屿！拖动左下角摇杆即可移动")
	)
	title_card.add_child(btn_continue)

	var btn_new_game := _make_touch_btn("✨ 开始新游戏", Vector2(240, 42), Color(0.26, 0.46, 0.68))
	btn_new_game.position = Vector2(50, 132)
	btn_new_game.pressed.connect(func():
		if FileAccess.file_exists(SAVE_PATH):
			_ask_confirm("开始新游戏将覆盖当前本地存档，确定要重新生成初始岛屿吗？", func():
				_init_default_island()
				_init_default_inventory()
				_save_game()
				_refresh_hotbar_ui()
				_switch_game_state(GameState.EXPLORE_MODE)
				_show_toast("新岛屿已创建！开始你的温暖海岛生活吧")
			)
		else:
			_init_default_island()
			_init_default_inventory()
			_save_game()
			_refresh_hotbar_ui()
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("欢迎来到你的新岛屿！")
	)
	title_card.add_child(btn_new_game)

	var btn_title_settings := _make_touch_btn("⚙ 游戏设置", Vector2(115, 42), Color(0.32, 0.36, 0.42))
	btn_title_settings.position = Vector2(50, 182)
	btn_title_settings.pressed.connect(func(): _open_modal(settings_modal))
	title_card.add_child(btn_title_settings)

	var btn_title_quit := _make_touch_btn("🚪 退出游戏", Vector2(115, 42), Color(0.58, 0.28, 0.28))
	btn_title_quit.position = Vector2(175, 182)
	btn_title_quit.pressed.connect(func():
		_ask_confirm("确定要保存并退出《像素动物岛物语》吗？", func():
			_save_game()
			get_tree().quit()
		)
	)
	title_card.add_child(btn_title_quit)

	# ---------------- 2. 游戏内主 HUD ----------------
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_root)

	# 左下角虚拟摇杆绘制层
	hud_overlay_draw = Control.new()
	hud_overlay_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_overlay_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_overlay_draw.draw.connect(_on_draw_hud_overlay)
	hud_root.add_child(hud_overlay_draw)

	# 2.1 顶部简洁信息栏（避开左右圆角，预留安全边距）
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.08, 0.12, 0.16, 0.78)
	top_bar.position = Vector2(14, 8)
	top_bar.size = Vector2(315, 32)
	hud_root.add_child(top_bar)

	top_time_label = Label.new()
	top_time_label.position = Vector2(22, 14)
	top_time_label.add_theme_font_size_override("font_size", 12)
	hud_root.add_child(top_time_label)

	top_coin_label = Label.new()
	top_coin_label.position = Vector2(235, 14)
	top_coin_label.add_theme_font_size_override("font_size", 12)
	top_coin_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
	hud_root.add_child(top_coin_label)

	# 2.2 顶部右侧触屏功能入口（岛建、背包、地图、菜单）
	mode_toggle_btn = _make_touch_btn("🛠 岛建", Vector2(82, 36), Color(0.76, 0.46, 0.18))
	mode_toggle_btn.position = Vector2(336, 8)
	mode_toggle_btn.pressed.connect(func():
		if game_state == GameState.EXPLORE_MODE:
			_switch_game_state(GameState.BUILD_MODE)
			_show_toast("已进入【手机岛建模式】：单指点按/拖动即可改造，右上角可一键撤销")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("已返回【日常漫步模式】")
	)
	hud_root.add_child(mode_toggle_btn)

	var bag_top_btn := _make_touch_btn("🎒 背包", Vector2(68, 36), Color(0.24, 0.45, 0.62))
	bag_top_btn.position = Vector2(422, 8)
	bag_top_btn.pressed.connect(func(): _open_bag_modal())
	hud_root.add_child(bag_top_btn)

	var map_top_btn := _make_touch_btn("🗺 地图", Vector2(68, 36), Color(0.24, 0.52, 0.42))
	map_top_btn.position = Vector2(494, 8)
	map_top_btn.pressed.connect(func(): _open_map_modal())
	hud_root.add_child(map_top_btn)

	var menu_top_btn := _make_touch_btn("☰ 菜单", Vector2(60, 36), Color(0.32, 0.35, 0.42))
	menu_top_btn.position = Vector2(566, 8)
	menu_top_btn.pressed.connect(func(): _open_modal(pause_menu_modal))
	hud_root.add_child(menu_top_btn)

	# 状态提示文字（顶部中央下方，不遮挡操作）
	toast_label = Label.new()
	toast_label.position = Vector2(140, 46)
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.62))
	hud_root.add_child(toast_label)

	# 2.3 右侧主要操作按钮区（大拇指热区：互动、使用工具、取消）
	interact_btn = _make_touch_btn("互动", Vector2(82, 50), Color(0.22, 0.58, 0.38))
	interact_btn.position = Vector2(542, 165)
	interact_btn.pressed.connect(_on_interact_pressed)
	hud_root.add_child(interact_btn)

	use_tool_btn = _make_touch_btn("使用工具", Vector2(82, 50), Color(0.25, 0.48, 0.72))
	use_tool_btn.position = Vector2(542, 223)
	use_tool_btn.pressed.connect(_on_use_tool_pressed)
	hud_root.add_child(use_tool_btn)

	cancel_btn = _make_touch_btn("✖ 取消", Vector2(82, 42), Color(0.55, 0.28, 0.28))
	cancel_btn.position = Vector2(542, 281)
	cancel_btn.pressed.connect(_on_cancel_button_pressed)
	hud_root.add_child(cancel_btn)

	# 2.4 底部 6 槽位快捷物品栏
	hotbar_container = HBoxContainer.new()
	hotbar_container.position = Vector2(172, 302)
	hotbar_container.add_theme_constant_override("separation", 6)
	hud_root.add_child(hotbar_container)

	hotbar_buttons.clear()
	for i in range(6):
		var slot_btn := _make_touch_btn("", Vector2(52, 48), Color(0.15, 0.20, 0.26, 0.92))
		var idx: int = i
		slot_btn.pressed.connect(func():
			selected_hotbar_index = idx
			_refresh_hotbar_ui()
			var id_str: String = hotbar[idx]
			if id_str != "" and ITEM_DB.has(id_str):
				_show_toast("已切换手持：【" + str(ITEM_DB[id_str]["name"]) + "】")
			else:
				_show_toast("选中了空槽位 #" + str(idx + 1))
		)
		hotbar_container.add_child(slot_btn)
		hotbar_buttons.append(slot_btn)

	# ---------------- 3. 手机岛建模式专属工具栏 ----------------
	_build_terraforming_toolbar()

	# ---------------- 4. 构建所有触屏弹窗（背包、地图、菜单、设置、商店、对话、确认框） ----------------
	_build_all_modals()
	_refresh_hotbar_ui()

func _build_terraforming_toolbar() -> void:
	build_toolbar_panel = Control.new()
	build_toolbar_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_toolbar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_toolbar_panel.visible = false
	hud_root.add_child(build_toolbar_panel)

	# 右侧岛建辅助按钮组（撤销、画笔/框选切换、视角拖动开关、子类型切换、框选确认）
	build_undo_btn = _make_touch_btn("↩ 撤销(0)", Vector2(88, 42), Color(0.68, 0.42, 0.20))
	build_undo_btn.position = Vector2(536, 52)
	build_undo_btn.pressed.connect(_on_build_undo_pressed)
	build_toolbar_panel.add_child(build_undo_btn)

	build_brush_mode_btn = _make_touch_btn("🖌 连续画笔", Vector2(88, 42), Color(0.24, 0.52, 0.68))
	build_brush_mode_btn.position = Vector2(536, 100)
	build_brush_mode_btn.pressed.connect(func():
		is_camera_pan_mode = false
		is_box_select_mode = not is_box_select_mode
		has_pending_box = false
		build_confirm_box_btn.visible = false
		_update_build_ui_labels()
		queue_redraw()
	)
	build_toolbar_panel.add_child(build_brush_mode_btn)

	build_pan_mode_btn = _make_touch_btn("✋ 移视角:关", Vector2(88, 42), Color(0.32, 0.38, 0.45))
	build_pan_mode_btn.position = Vector2(536, 148)
	build_pan_mode_btn.pressed.connect(func():
		is_camera_pan_mode = not is_camera_pan_mode
		_update_build_ui_labels()
		if is_camera_pan_mode:
			_show_toast("已开启【单指拖动视角】模式，拖动屏幕可查看全岛")
		else:
			_show_toast("已返回【触屏绘制】模式")
	)
	build_toolbar_panel.add_child(build_pan_mode_btn)

	build_sub_cycle_btn = _make_touch_btn("切换样式", Vector2(88, 40), Color(0.42, 0.36, 0.58))
	build_sub_cycle_btn.position = Vector2(536, 196)
	build_sub_cycle_btn.pressed.connect(_on_cycle_build_subtype)
	build_toolbar_panel.add_child(build_sub_cycle_btn)

	build_confirm_box_btn = _make_touch_btn("✅ 确认框选", Vector2(132, 42), Color(0.20, 0.65, 0.32))
	build_confirm_box_btn.position = Vector2(396, 236)
	build_confirm_box_btn.visible = false
	build_confirm_box_btn.pressed.connect(_execute_pending_box_selection)
	build_toolbar_panel.add_child(build_confirm_box_btn)

	# 底部岛建 8 大核心工具入口条
	var bottom_bg := ColorRect.new()
	bottom_bg.color = Color(0.08, 0.12, 0.16, 0.90)
	bottom_bg.position = Vector2(12, 286)
	bottom_bg.size = Vector2(520, 66)
	build_toolbar_panel.add_child(bottom_bg)

	build_mode_hint_label = Label.new()
	build_mode_hint_label.position = Vector2(18, 288)
	build_mode_hint_label.add_theme_font_size_override("font_size", 11)
	build_mode_hint_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
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
		var t_btn := _make_touch_btn(td["name"], Vector2(60, 42), Color(0.18, 0.26, 0.34))
		var tid: int = int(td["id"])
		t_btn.pressed.connect(func():
			current_build_tool = tid
			is_camera_pan_mode = false
			has_pending_box = false
			build_confirm_box_btn.visible = false
			_update_build_ui_labels()
			queue_redraw()
		)
		tool_hbox.add_child(t_btn)
		build_tool_buttons.append({"id": tid, "btn": t_btn})

func _on_cycle_build_subtype() -> void:
	if current_build_tool == BuildTool.ROAD_PAVE:
		if build_sub_road == GroundType.STONE_PATH:
			build_sub_road = GroundType.WOOD_PATH
			_show_toast("道路样式切换为：【木板路】")
		elif build_sub_road == GroundType.WOOD_PATH:
			build_sub_road = GroundType.BRIDGE
			_show_toast("道路样式切换为：【水上木桥】")
		else:
			build_sub_road = GroundType.STONE_PATH
			_show_toast("道路样式切换为：【石板路】")
	elif current_build_tool == BuildTool.PLANT_PUT:
		if build_sub_plant == ObjectType.FLOWER_RED:
			build_sub_plant = ObjectType.BUSH
			_show_toast("植物样式切换为：【常青灌木】")
		elif build_sub_plant == ObjectType.BUSH:
			build_sub_plant = ObjectType.TREE
			_show_toast("植物样式切换为：【海岛绿树】")
		else:
			build_sub_plant = ObjectType.FLOWER_RED
			_show_toast("植物样式切换为：【红花】")
	elif current_build_tool == BuildTool.DECOR_PUT:
		if build_sub_decor == ObjectType.BENCH:
			build_sub_decor = ObjectType.LAMP
			_show_toast("装饰样式切换为：【复古街灯】")
		elif build_sub_decor == ObjectType.LAMP:
			build_sub_decor = ObjectType.FENCE
			_show_toast("装饰样式切换为：【木栅栏】")
		else:
			build_sub_decor = ObjectType.BENCH
			_show_toast("装饰样式切换为：【木长椅】")
	else:
		_show_toast("当前工具无需切换子样式（铺道路/种植物/放装饰可切换多种样式）")
	_update_build_ui_labels()

func _update_build_ui_labels() -> void:
	if build_undo_btn == null:
		return
	build_undo_btn.text = "↩ 撤销(%d)" % undo_stack.size()
	build_brush_mode_btn.text = "🔲 矩形框选" if is_box_select_mode else "🖌 连续画笔"
	build_pan_mode_btn.text = "✋ 移视角:开" if is_camera_pan_mode else "✋ 移视角:关"

	var tool_desc: String = ""
	match current_build_tool:
		BuildTool.GROUND_GRASS: tool_desc = "【草地工具】将水域或道路恢复为平整草地"
		BuildTool.FLATTEN: tool_desc = "【铲平清理】铲平高地、填平河道并批量清除杂草树木"
		BuildTool.CLIFF_RAISE: tool_desc = "【建造高地】垫高地面形成立体二层悬崖"
		BuildTool.RIVER_DIG: tool_desc = "【挖掘河道】开凿清澈河流与湖泊"
		BuildTool.ROAD_PAVE:
			var r_name: String = "石板路" if build_sub_road == GroundType.STONE_PATH else ("木板路" if build_sub_road == GroundType.WOOD_PATH else "木桥")
			tool_desc = "【道路铺设：%s】（可点右侧[切换样式]）" % r_name
		BuildTool.PLANT_PUT:
			var p_name: String = "红花" if build_sub_plant == ObjectType.FLOWER_RED else ("灌木" if build_sub_plant == ObjectType.BUSH else "绿树")
			tool_desc = "【植物放置：%s】（可点右侧[切换样式]）" % p_name
		BuildTool.DECOR_PUT:
			var d_name: String = "木长椅" if build_sub_decor == ObjectType.BENCH else ("复古街灯" if build_sub_decor == ObjectType.LAMP else "木栅栏")
			tool_desc = "【装饰放置：%s】（可点右侧[切换样式]）" % d_name
		BuildTool.BUILDING_PUT:
			tool_desc = "【建筑选址】放置大型建筑施工围挡（次日清晨完工）"

	var mode_str: String = "单指拖动移视角" if is_camera_pan_mode else ("拖动拉框 -> 点击绿框确认" if is_box_select_mode else "单指按住滑动连续涂抹")
	build_mode_hint_label.text = "%s | 当前操作：%s" % [tool_desc, mode_str]

	for item in build_tool_buttons:
		var b: Button = item["btn"]
		b.modulate = Color(1.0, 0.95, 0.55) if int(item["id"]) == current_build_tool else Color.WHITE

func _on_cancel_button_pressed() -> void:
	if active_modal != null:
		_close_active_modal()
		return
	if game_state == GameState.BUILD_MODE:
		if has_pending_box:
			has_pending_box = false
			build_confirm_box_btn.visible = false
			queue_redraw()
			_show_toast("已取消当前矩形框选预览")
		elif is_camera_pan_mode:
			is_camera_pan_mode = false
			_update_build_ui_labels()
			_show_toast("已退出视角移动模式")
		else:
			_switch_game_state(GameState.EXPLORE_MODE)
			_show_toast("已退出岛建模式，返回漫步状态")
	else:
		_reset_touch_states()
		_show_toast("已取消当前动作并重置触控状态")

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
		btn.modulate = Color(1.0, 0.94, 0.52) if i == selected_hotbar_index else Color.WHITE

func _on_draw_hud_overlay() -> void:
	if game_state != GameState.EXPLORE_MODE or active_modal != null:
		return
	# 绘制左下角大尺寸半透明拇指摇杆
	hud_overlay_draw.draw_circle(joy_center, joy_radius, Color(0.08, 0.12, 0.16, 0.45))
	hud_overlay_draw.draw_arc(joy_center, joy_radius, 0.0, TAU, 36, Color(1.0, 0.96, 0.85, 0.60), 2.0)
	hud_overlay_draw.draw_circle(joy_knob_pos, 20.0, Color(0.98, 0.90, 0.65, 0.88))

# ==============================================================================
# 模态弹窗系统（背包、岛屿全图、暂停菜单、设置、商店、对话、二次确认）
# ==============================================================================

func _create_modal_base(title_str: String, panel_size: Vector2) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	ui_layer.add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.55)
	root.add_child(dimmer)

	var panel := Panel.new()
	panel.size = panel_size
	panel.position = (Vector2(640, 360) - panel_size) * 0.5
	root.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = title_str
	title_lbl.position = Vector2(18, 12)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65))
	panel.add_child(title_lbl)

	var close_btn := _make_touch_btn("✖ 关闭", Vector2(72, 34), Color(0.58, 0.26, 0.26))
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
	var bag_res: Array = _create_modal_base("🎒 岛民背包与快捷栏装备", Vector2(540, 300))
	bag_modal = bag_res[0]
	var bag_panel: Panel = bag_res[1]

	bag_grid_container = GridContainer.new()
	bag_grid_container.columns = 5
	bag_grid_container.position = Vector2(18, 52)
	bag_grid_container.add_theme_constant_override("h_separation", 8)
	bag_grid_container.add_theme_constant_override("v_separation", 8)
	bag_panel.add_child(bag_grid_container)

	bag_detail_label = Label.new()
	bag_detail_label.position = Vector2(18, 206)
	bag_detail_label.size = Vector2(500, 36)
	bag_detail_label.add_theme_font_size_override("font_size", 12)
	bag_panel.add_child(bag_detail_label)

	bag_assign_bar = HBoxContainer.new()
	bag_assign_bar.position = Vector2(18, 246)
	bag_assign_bar.add_theme_constant_override("separation", 6)
	bag_panel.add_child(bag_assign_bar)

	var use_in_bag_btn := _make_touch_btn("立即使用/放置", Vector2(110, 38), Color(0.22, 0.56, 0.36))
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
		var assign_btn := _make_touch_btn("装入槽" + str(s + 1), Vector2(60, 38), Color(0.26, 0.45, 0.65))
		assign_btn.pressed.connect(func():
			if selected_bag_item_id == "":
				_show_toast("请先点击上方网格中的一件物品")
				return
			hotbar[slot_idx] = selected_bag_item_id
			selected_hotbar_index = slot_idx
			_refresh_hotbar_ui()
			_show_toast("已将【" + str(ITEM_DB[selected_bag_item_id]["name"]) + "】装入快捷栏槽位 #" + str(slot_idx + 1))
		)
		bag_assign_bar.add_child(assign_btn)

	# 2. 完整岛屿地图弹窗（实时同步地形数据 + 支持触屏拖动与缩放）
	var map_res: Array = _create_modal_base("🗺 岛屿实时全景地图 (可单指拖动查看)", Vector2(540, 310))
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
	legend_lbl.position = Vector2(392, 54)
	legend_lbl.text = "【图例说明】\n🔴 你的当前位置\n🟡 小动物居民\n🏠 玩家温馨小屋\n🏪 岛屿杂货铺\n🟫 木桥与道路\n🟦 河流与海洋\n🟩 平地与高地"
	legend_lbl.add_theme_font_size_override("font_size", 12)
	map_panel.add_child(legend_lbl)

	var zoom_in_btn := _make_touch_btn("🔍 放大地图", Vector2(125, 38), Color(0.26, 0.48, 0.65))
	zoom_in_btn.position = Vector2(392, 205)
	zoom_in_btn.pressed.connect(func():
		map_zoom = clampf(map_zoom + 0.35, 1.0, 2.4)
		map_canvas.queue_redraw()
	)
	map_panel.add_child(zoom_in_btn)

	var zoom_out_btn := _make_touch_btn("🔎 缩小/复位", Vector2(125, 38), Color(0.32, 0.42, 0.52))
	zoom_out_btn.position = Vector2(392, 250)
	zoom_out_btn.pressed.connect(func():
		map_zoom = 1.0
		map_pan_offset = Vector2.ZERO
		map_canvas.queue_redraw()
	)
	map_panel.add_child(zoom_out_btn)

	# 3. 暂停与综合菜单弹窗
	var menu_res: Array = _create_modal_base("☰ 岛屿生活菜单", Vector2(340, 280))
	pause_menu_modal = menu_res[0]
	var menu_panel: Panel = menu_res[1]

	var m_bag := _make_touch_btn("🎒 打开背包", Vector2(260, 38), Color(0.24, 0.46, 0.64))
	m_bag.position = Vector2(40, 52)
	m_bag.pressed.connect(func(): _open_bag_modal())
	menu_panel.add_child(m_bag)

	var m_map := _make_touch_btn("🗺 查看岛屿地图", Vector2(260, 38), Color(0.24, 0.54, 0.42))
	m_map.position = Vector2(40, 96)
	m_map.pressed.connect(func(): _open_map_modal())
	menu_panel.add_child(m_map)

	var m_set := _make_touch_btn("⚙ 游戏设置", Vector2(260, 38), Color(0.35, 0.40, 0.48))
	m_set.position = Vector2(40, 140)
	m_set.pressed.connect(func(): _open_modal(settings_modal))
	menu_panel.add_child(m_set)

	var m_save := _make_touch_btn("💾 立即保存进度", Vector2(260, 38), Color(0.22, 0.58, 0.36))
	m_save.position = Vector2(40, 184)
	m_save.pressed.connect(func():
		if _save_game():
			_close_active_modal()
			_show_toast("已将全部岛屿地形、背包与进度安全保存到手机本地！")
	)
	menu_panel.add_child(m_save)

	var m_title := _make_touch_btn("🏠 保存并返回标题画面", Vector2(260, 38), Color(0.58, 0.32, 0.28))
	m_title.position = Vector2(40, 228)
	m_title.pressed.connect(func():
		_ask_confirm("返回主菜单前会自动保存当前进度，确定返回吗？", func():
			_save_game()
			_close_active_modal()
			_switch_game_state(GameState.TITLE_SCREEN)
		)
	)
	menu_panel.add_child(m_title)

	# 4. 触屏设置界面（带触屏滑块与开关按钮）
	var set_res: Array = _create_modal_base("⚙ 手机触控与画面设置", Vector2(440, 260))
	settings_modal = set_res[0]
	var set_panel: Panel = set_res[1]

	var zoom_lbl := Label.new()
	zoom_lbl.text = "视野缩放比例:"
	zoom_lbl.position = Vector2(24, 62)
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
	spd_lbl.text = "角色移动速度:"
	spd_lbl.position = Vector2(24, 112)
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

	var grid_toggle_btn := _make_touch_btn("岛建网格线显示：开启", Vector2(240, 40), Color(0.26, 0.48, 0.58))
	grid_toggle_btn.position = Vector2(100, 162)
	grid_toggle_btn.pressed.connect(func():
		setting_show_grid_in_build = not setting_show_grid_in_build
		grid_toggle_btn.text = "岛建网格线显示：" + ("开启" if setting_show_grid_in_build else "关闭")
		queue_redraw()
	)
	set_panel.add_child(grid_toggle_btn)

	# 5. 商店弹窗（购买种子家具、一键出售收集品）
	var shop_res: Array = _create_modal_base("🏪 海岛杂货铺", Vector2(480, 280))
	shop_modal = shop_res[0]
	var shop_panel: Panel = shop_res[1]

	var shop_items: Array = ["flower_seed", "bush_seed", "bench_item", "lamp_item"]
	for idx in range(shop_items.size()):
		var sid: String = shop_items[idx]
		var sinfo: Dictionary = ITEM_DB[sid]
		var price: int = int(sinfo.get("price", 100))
		var buy_btn := _make_touch_btn("购买【%s】(-%d铃钱)" % [sinfo["name"], price], Vector2(210, 42), Color(0.24, 0.50, 0.38))
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

	var sell_btn := _make_touch_btn("💰 一键出售背包里的贝壳/鱼/蝴蝶/苹果", Vector2(430, 46), Color(0.72, 0.48, 0.18))
	sell_btn.position = Vector2(24, 185)
	sell_btn.pressed.connect(func():
		var earned: int = 0
		for sell_id in ["shell", "fish", "bug", "apple"]:
			var c: int = int(inventory.get(sell_id, 0))
			if c > 0:
				earned += c * int(ITEM_DB[sell_id].get("sell", 50))
				inventory.erase(sell_id)
		if earned > 0:
			coins += earned
			_refresh_hotbar_ui()
			_update_time_and_lighting()
			_show_toast("出售收集品获得 %d 铃钱！" % earned)
		else:
			_show_toast("背包里暂时没有可出售的贝壳、鱼、蝴蝶或苹果哦")
	)
	shop_panel.add_child(sell_btn)

	# 6. 对话框弹窗
	var dlg_res: Array = _create_modal_base("💬 对话", Vector2(440, 200))
	dialog_modal = dlg_res[0]
	var dlg_panel: Panel = dlg_res[1]
	dialog_title_label = dlg_res[2]

	dialog_body_label = Label.new()
	dialog_body_label.position = Vector2(22, 54)
	dialog_body_label.size = Vector2(396, 86)
	dialog_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_body_label.add_theme_font_size_override("font_size", 14)
	dlg_panel.add_child(dialog_body_label)

	var dlg_ok := _make_touch_btn("好的，知道了", Vector2(160, 40), Color(0.24, 0.56, 0.38))
	dlg_ok.position = Vector2(140, 144)
	dlg_ok.pressed.connect(_close_active_modal)
	dlg_panel.add_child(dlg_ok)

	# 7. 二次确认弹窗（用于覆盖新存档、返回主菜单、退出等保护）
	var cfm_res: Array = _create_modal_base("⚠ 请确认操作", Vector2(400, 190))
	confirm_modal = cfm_res[0]
	var cfm_panel: Panel = cfm_res[1]

	confirm_label = Label.new()
	confirm_label.position = Vector2(22, 54)
	confirm_label.size = Vector2(356, 68)
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.add_theme_font_size_override("font_size", 14)
	cfm_panel.add_child(confirm_label)

	var cfm_yes := _make_touch_btn("✅ 确认执行", Vector2(140, 40), Color(0.68, 0.28, 0.28))
	cfm_yes.position = Vector2(48, 132)
	cfm_yes.pressed.connect(func():
		_close_active_modal()
		if confirm_yes_callable.is_valid():
			confirm_yes_callable.call()
	)
	cfm_panel.add_child(cfm_yes)

	var cfm_no := _make_touch_btn("取消返回", Vector2(140, 40), Color(0.32, 0.38, 0.45))
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
		var btn_txt: String = "%s %s\n数量: %d" % [info["icon"], info["name"], cnt]
		var item_btn := _make_touch_btn(btn_txt, Vector2(94, 44), Color(0.20, 0.30, 0.40))
		var id_copy: String = str(item_id)
		if id_copy == selected_bag_item_id:
			item_btn.modulate = Color(1.0, 0.94, 0.55)
		item_btn.pressed.connect(func():
			selected_bag_item_id = id_copy
			_open_bag_modal()
		)
		bag_grid_container.add_child(item_btn)

	if selected_bag_item_id != "" and ITEM_DB.has(selected_bag_item_id):
		var d_info: Dictionary = ITEM_DB[selected_bag_item_id]
		bag_detail_label.text = "已选：【%s】 — %s\n（点击下方按钮可直接装备到任意快捷栏槽位或立即使用）" % [d_info["name"], d_info["desc"]]
	else:
		bag_detail_label.text = "点击上方物品查看详情并放入底部快捷栏"

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
				map_canvas.draw_rect(r.grow(1.5), Color(0.95, 0.35, 0.30), true)
			elif obj == ObjectType.SHOP:
				map_canvas.draw_rect(r.grow(1.5), Color(0.25, 0.55, 0.95), true)
			elif obj == ObjectType.TREE:
				map_canvas.draw_rect(r, Color(0.18, 0.48, 0.22), true)

	# 绘制小动物位置
	for a in animals:
		var ac: Vector2i = world_to_grid(a["pos"])
		var ap := Vector2(start_origin.x + (ac.x + 0.5) * cell_px, start_origin.y + (ac.y + 0.5) * cell_px)
		map_canvas.draw_circle(ap, 3.5 * map_zoom, Color(1.0, 0.88, 0.25))

	# 绘制玩家实时位置
	var pc: Vector2i = world_to_grid(player_pos)
	var pp := Vector2(start_origin.x + (pc.x + 0.5) * cell_px, start_origin.y + (pc.y + 0.5) * cell_px)
	map_canvas.draw_circle(pp, 4.5 * map_zoom, Color(1.0, 0.22, 0.22))
	map_canvas.draw_arc(pp, 5.5 * map_zoom, 0, TAU, 16, Color.WHITE, 1.5)

# ==============================================================================
# 现实时间、季节、昼夜光影与全面屏安全区自适应
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
	elif h >= 17 and h < 20: period = "傍晚"

	if top_time_label != null:
		top_time_label.text = "%02d月%02d日(%s) %02d:%02d [%s]" % [month, int(dt.get("day", 1)), season, h, mi, period]
	if top_coin_label != null:
		top_coin_label.text = "💰 %d 铃钱" % coins

	var t: float = float(h) + float(mi) / 60.0
	if t >= 5.0 and t < 8.0:
		canvas_modulate.color = Color(0.95, 0.88, 0.82).lerp(Color.WHITE, (t - 5.0) / 3.0)
	elif t >= 8.0 and t < 17.0:
		canvas_modulate.color = Color.WHITE
	elif t >= 17.0 and t < 19.5:
		canvas_modulate.color = Color.WHITE.lerp(Color(0.96, 0.78, 0.65), (t - 17.0) / 2.5)
	elif t >= 19.5 and t < 21.0:
		canvas_modulate.color = Color(0.96, 0.78, 0.65).lerp(Color(0.56, 0.62, 0.82), (t - 19.5) / 1.5)
	else:
		canvas_modulate.color = Color(0.56, 0.62, 0.82)

func _on_viewport_size_changed() -> void:
	if hud_root == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var right_x: float = maxf(640.0, vp_size.x) - 18.0 # 预留安全区防圆角/刘海裁切

	if interact_btn != null: interact_btn.position.x = right_x - 84.0
	if use_tool_btn != null: use_tool_btn.position.x = right_x - 84.0
	if cancel_btn != null: cancel_btn.position.x = right_x - 84.0
	if build_undo_btn != null: build_undo_btn.position.x = right_x - 90.0
	if build_brush_mode_btn != null: build_brush_mode_btn.position.x = right_x - 90.0
	if build_pan_mode_btn != null: build_pan_mode_btn.position.x = right_x - 90.0
	if build_sub_cycle_btn != null: build_sub_cycle_btn.position.x = right_x - 90.0

func _show_toast(msg: String) -> void:
	if toast_label != null:
		toast_label.text = msg
	toast_timer = 3.2

# ==============================================================================
# 本地安全持久化存档（保存完整岛建地形、高度、物体、背包、快捷栏、货币与坐标）
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
		"version": 2,
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

	# 检查跨天施工完工（次日清晨 05:00 后施工围挡自动变为正式小屋/设施）
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

## 手机切后台、锁屏、焦点丢失或退出时：立即重置触控状态防卡死，并自动保存进度
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_reset_touch_states()
		if game_state != GameState.TITLE_SCREEN:
			_save_game()
