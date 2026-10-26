extends Node2D

# === 阶段 1：可运行的基础项目（地图 + 玩家移动碰撞 + 摄像机 + 现实时间昼夜 + 本地安全存档） ===

const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 32
const TILE_SIZE: int = 16
const SAVE_PATH: String = "user://island_save_v1.json"
const TEMP_SAVE_PATH: String = "user://island_save_v1.tmp"

enum GroundType {
	DEEP_WATER = 0,
	SHALLOW_WATER = 1,
	SAND = 2,
	GRASS = 3,
	RIVER = 4,
	BRIDGE = 5,
	STONE_PATH = 6
}

enum ObjectType {
	NONE = 0,
	TREE = 1,
	FLOWER = 2,
	WEED = 3
}

# 地图二维数组
var ground_grid: Array = []
var object_grid: Array = []

# 玩家状态与摄像机
var player_pos: Vector2 = Vector2(16.5 * TILE_SIZE, 16.5 * TILE_SIZE)
var player_facing: Vector2 = Vector2.DOWN
var walk_anim_time: float = 0.0
const MOVE_SPEED: float = 90.0
const COLLISION_HALF_SIZE: Vector2 = Vector2(4.0, 4.0)
var camera: Camera2D

# 环境光与 UI 节点
var canvas_modulate: CanvasModulate
var time_label: Label
var pos_label: Label
var status_toast_label: Label
var toast_timer: float = 0.0
var time_check_timer: float = 0.0

# 手机左下角触屏虚拟摇杆
var joy_center: Vector2 = Vector2(90.0, 275.0)
var joy_radius: float = 44.0
var joy_knob_pos: Vector2 = Vector2(90.0, 275.0)
var joy_vector: Vector2 = Vector2.ZERO
var joy_touch_index: int = -1
var joy_overlay: Control

func _ready() -> void:
	# 1. 初始化岛屿网格地图
	_init_default_island()

	# 2. 读取本地存档恢复玩家位置
	_load_game()

	# 3. 创建昼夜环境光节点
	canvas_modulate = CanvasModulate.new()
	add_child(canvas_modulate)

	# 4. 创建平滑跟随摄像机
	camera = Camera2D.new()
	camera.position = player_pos
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID_WIDTH * TILE_SIZE
	camera.limit_bottom = GRID_HEIGHT * TILE_SIZE
	add_child(camera)

	# 5. 创建安卓横屏触控界面 (HUD)
	_setup_hud()
	_update_time_and_lighting()
	_show_toast("欢迎来到小岛！拖动左下角摇杆即可散步")

func _physics_process(delta: float) -> void:
	# 同时支持手机触屏摇杆与键盘方向键/WASD
	var kb_input := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	var move_dir: Vector2 = joy_vector if joy_vector.length() > 0.05 else kb_input.limit_length(1.0)

	if move_dir.length() > 0.05:
		player_facing = move_dir.normalized()
		walk_anim_time += delta * 10.0
		_move_player_with_collision(move_dir * MOVE_SPEED * delta)
		camera.position = player_pos
		queue_redraw()
	elif walk_anim_time != 0.0:
		walk_anim_time = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	var cell: Vector2i = world_to_grid(player_pos)
	pos_label.text = "坐标: (%d, %d)" % [cell.x, cell.y]

	time_check_timer += delta
	if time_check_timer >= 2.0:
		time_check_timer = 0.0
		_update_time_and_lighting()

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			status_toast_label.text = ""

# --- 地图初始化与碰撞检查 ---

func _init_default_island() -> void:
	ground_grid.clear()
	object_grid.clear()
	for x in range(GRID_WIDTH):
		var g_col: Array = []
		var o_col: Array = []
		for y in range(GRID_HEIGHT):
			var g_type: int = GroundType.DEEP_WATER
			var o_type: int = ObjectType.NONE
			var edge_dist: int = mini(mini(x, GRID_WIDTH - 1 - x), mini(y, GRID_HEIGHT - 1 - y))

			if edge_dist <= 1:
				g_type = GroundType.DEEP_WATER
			elif edge_dist == 2:
				g_type = GroundType.SHALLOW_WATER
			elif edge_dist <= 4:
				g_type = GroundType.SAND
			else:
				g_type = GroundType.GRASS

			# 小河与木桥
			if edge_dist >= 3 and (x == 19 or x == 20):
				g_type = GroundType.RIVER
			if (x == 19 or x == 20) and (y == 15 or y == 16):
				g_type = GroundType.BRIDGE
			if y == 15 and x >= 14 and x <= 18:
				g_type = GroundType.STONE_PATH

			# 树木、花朵与杂草
			if g_type == GroundType.GRASS:
				if (x in [8, 12, 23, 25]) and (y in [8, 11, 21, 24]):
					o_type = ObjectType.TREE
				elif (x + y * 3) % 17 == 0 and abs(x - 16) > 2:
					o_type = ObjectType.FLOWER
				elif (x * 5 + y) % 23 == 0 and abs(x - 16) > 2:
					o_type = ObjectType.WEED

			g_col.append(g_type)
			o_col.append(o_type)
		ground_grid.append(g_col)
		object_grid.append(o_col)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))

func is_cell_walkable(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
		return false
	if ground_grid[gx][gy] in [GroundType.DEEP_WATER, GroundType.SHALLOW_WATER, GroundType.RIVER]:
		return false
	if object_grid[gx][gy] == ObjectType.TREE:
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

# --- 像素画面渲染（地图 + 树木花草 + 玩家角色） ---

func _draw() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var g_type: int = ground_grid[x][y]
			draw_rect(rect, _get_ground_color(g_type, (x + y) % 2 == 0), true)

			if g_type == GroundType.BRIDGE:
				draw_rect(Rect2(rect.position.x, rect.position.y + 2, TILE_SIZE, 2), Color(0.45, 0.28, 0.15), true)
				draw_rect(Rect2(rect.position.x, rect.position.y + 12, TILE_SIZE, 2), Color(0.45, 0.28, 0.15), true)
			elif g_type in [GroundType.SHALLOW_WATER, GroundType.RIVER] and (x + y) % 3 == 0:
				draw_rect(Rect2(rect.position.x + 4, rect.position.y + 6, 6, 2), Color(0.85, 0.96, 1.0, 0.5), true)

			var o_type: int = object_grid[x][y]
			if o_type == ObjectType.TREE:
				var p := rect.position
				draw_rect(Rect2(p.x + 3, p.y + 12, 10, 3), Color(0, 0, 0, 0.2), true)
				draw_rect(Rect2(p.x + 6, p.y + 9, 4, 6), Color(0.52, 0.33, 0.18), true)
				draw_rect(Rect2(p.x + 2, p.y + 3, 12, 8), Color(0.24, 0.56, 0.28), true)
				draw_rect(Rect2(p.x + 4, p.y + 1, 8, 6), Color(0.32, 0.66, 0.34), true)
			elif o_type == ObjectType.FLOWER:
				var p := rect.position
				draw_rect(Rect2(p.x + 7, p.y + 9, 2, 4), Color(0.30, 0.60, 0.28), true)
				draw_rect(Rect2(p.x + 5, p.y + 5, 6, 5), Color(0.98, 0.52, 0.65), true)
				draw_rect(Rect2(p.x + 7, p.y + 7, 2, 2), Color(1.0, 0.92, 0.35), true)
			elif o_type == ObjectType.WEED:
				var p := rect.position
				draw_rect(Rect2(p.x + 4, p.y + 8, 2, 5), Color(0.32, 0.58, 0.25), true)
				draw_rect(Rect2(p.x + 7, p.y + 6, 2, 7), Color(0.36, 0.62, 0.28), true)
				draw_rect(Rect2(p.x + 10, p.y + 9, 2, 4), Color(0.32, 0.58, 0.25), true)

	# 绘制玩家像素小人
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

func _get_ground_color(g_type: int, is_alt: bool) -> Color:
	match g_type:
		GroundType.DEEP_WATER: return Color(0.16, 0.45, 0.68) if is_alt else Color(0.18, 0.48, 0.71)
		GroundType.SHALLOW_WATER: return Color(0.28, 0.65, 0.85) if is_alt else Color(0.31, 0.68, 0.88)
		GroundType.SAND: return Color(0.95, 0.87, 0.62) if is_alt else Color(0.93, 0.84, 0.59)
		GroundType.GRASS: return Color(0.45, 0.76, 0.42) if is_alt else Color(0.42, 0.73, 0.39)
		GroundType.RIVER: return Color(0.25, 0.62, 0.86) if is_alt else Color(0.28, 0.66, 0.89)
		GroundType.BRIDGE: return Color(0.68, 0.46, 0.26) if is_alt else Color(0.63, 0.42, 0.23)
		GroundType.STONE_PATH: return Color(0.76, 0.75, 0.72) if is_alt else Color(0.71, 0.70, 0.67)
	return Color.WHITE

# --- 现实时间昼夜同步 ---

func _update_time_and_lighting() -> void:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var h: int = dt.get("hour", 12)
	var mi: int = dt.get("minute", 0)
	var period: String = "夜晚"
	if h >= 5 and h < 8: period = "清晨"
	elif h >= 8 and h < 17: period = "白天"
	elif h >= 17 and h < 20: period = "傍晚"

	time_label.text = "%04d-%02d-%02d %02d:%02d (%s)" % [
		dt.get("year", 2026), dt.get("month", 1), dt.get("day", 1), h, mi, period
	]

	var t: float = float(h) + float(mi) / 60.0
	if t >= 5.0 and t < 8.0:
		canvas_modulate.color = Color(0.95, 0.88, 0.82).lerp(Color.WHITE, (t - 5.0) / 3.0)
	elif t >= 8.0 and t < 17.0:
		canvas_modulate.color = Color.WHITE
	elif t >= 17.0 and t < 19.5:
		canvas_modulate.color = Color.WHITE.lerp(Color(0.96, 0.78, 0.65), (t - 17.0) / 2.5)
	elif t >= 19.5 and t < 21.0:
		canvas_modulate.color = Color(0.96, 0.78, 0.65).lerp(Color(0.52, 0.58, 0.78), (t - 19.5) / 1.5)
	else:
		canvas_modulate.color = Color(0.52, 0.58, 0.78)

# --- 本地安全存档读写 ---

func _save_game() -> bool:
	var data: Dictionary = {
		"version": 1,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"player": {"x": snappedf(player_pos.x, 0.1), "y": snappedf(player_pos.y, 0.1)}
	}
	var file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
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
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("player"):
		var p: Dictionary = parsed["player"]
		var saved_pt := Vector2(float(p.get("x", player_pos.x)), float(p.get("y", player_pos.y)))
		var c: Vector2i = world_to_grid(saved_pt)
		if is_cell_walkable(c.x, c.y):
			player_pos = saved_pt

# --- 安卓横屏触控界面与虚拟摇杆 ---

func _setup_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.10, 0.14, 0.18, 0.72)
	top_bar.position = Vector2(8, 8)
	top_bar.size = Vector2(360, 28)
	hud.add_child(top_bar)

	time_label = Label.new()
	time_label.position = Vector2(16, 12)
	time_label.add_theme_font_size_override("font_size", 13)
	hud.add_child(time_label)

	pos_label = Label.new()
	pos_label.position = Vector2(265, 12)
	pos_label.add_theme_font_size_override("font_size", 13)
	hud.add_child(pos_label)

	var save_btn := Button.new()
	save_btn.text = "保存进度"
	save_btn.position = Vector2(548, 8)
	save_btn.size = Vector2(84, 30)
	save_btn.add_theme_font_size_override("font_size", 13)
	save_btn.pressed.connect(func():
		if _save_game(): _show_toast("已安全保存到手机本地存档！")
	)
	hud.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "回中心"
	reset_btn.position = Vector2(472, 8)
	reset_btn.size = Vector2(68, 30)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.pressed.connect(func():
		player_pos = Vector2(16.5 * TILE_SIZE, 16.5 * TILE_SIZE)
		camera.position = player_pos
		_save_game()
		queue_redraw()
		_show_toast("已回到小岛中心并保存")
	)
	hud.add_child(reset_btn)

	status_toast_label = Label.new()
	status_toast_label.position = Vector2(180, 330)
	status_toast_label.add_theme_font_size_override("font_size", 13)
	status_toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	hud.add_child(status_toast_label)

	joy_overlay = Control.new()
	joy_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_overlay.draw.connect(func():
		joy_overlay.draw_circle(joy_center, joy_radius, Color(0.1, 0.12, 0.15, 0.45))
		joy_overlay.draw_arc(joy_center, joy_radius, 0, TAU, 32, Color(1, 1, 1, 0.55), 2.0)
		joy_overlay.draw_circle(joy_knob_pos, 18.0, Color(0.98, 0.92, 0.72, 0.85))
	)
	hud.add_child(joy_overlay)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if joy_touch_index == -1 and touch.position.x < 260.0 and touch.position.y > 140.0:
				joy_touch_index = touch.index
				_update_joystick(touch.position)
		else:
			if touch.index == joy_touch_index:
				joy_touch_index = -1
				joy_knob_pos = joy_center
				joy_vector = Vector2.ZERO
				joy_overlay.queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joy_touch_index:
			_update_joystick(drag.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - joy_center
	if offset.length() > joy_radius:
		offset = offset.normalized() * joy_radius
	joy_knob_pos = joy_center + offset
	joy_vector = offset / joy_radius
	joy_overlay.queue_redraw()

func _show_toast(msg: String) -> void:
	status_toast_label.text = msg
	toast_timer = 3.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_game()
