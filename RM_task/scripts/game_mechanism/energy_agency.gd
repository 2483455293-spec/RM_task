extends Node3D

# ==========================================
# 模式与状态枚举
# ==========================================
enum Mode { MINI, LARGE }
var current_mode: Mode = Mode.MINI

enum State { IDLE, PLAYING, WINDOW, FINISHED }
var blue_state: State = State.IDLE
var red_state: State = State.IDLE

@export var player_faction: String = "blue"

# ==========================================
# 可配置参数 (由 ConfigManager 注入)
# ==========================================
var base_rotation_speed: float = PI / 3.0
var mini_timeout: float = 2.5
var large_main_timeout: float = 2.5
var large_window_timeout: float = 1.0

var b_lg_a_min: float = 0.780
var b_lg_a_max: float = 1.045
var b_lg_w_min: float = 1.884
var b_lg_w_max: float = 2.000
var b_lg_b_base: float = 2.090

# ==========================================
# 小能量机关变量
# ==========================================
var blue_current_id: int = 0
var red_current_id: int = 0
var blue_remaining: Array = []
var red_remaining: Array = []
var b_mini_hit: int = 0
var r_mini_hit: int = 0

# ==========================================
# 大能量机关变量
# ==========================================
var b_lg_t: float = 0.0
var b_lg_a: float = 0.0
var b_lg_w: float = 0.0
var b_lg_b: float = 0.0
var b_lg_group: int = 0
var b_lg_active: Array = []

var r_lg_t: float = 0.0
var r_lg_a: float = 0.0
var r_lg_w: float = 0.0
var r_lg_b: float = 0.0
var r_lg_group: int = 0
var r_lg_active: Array = []

# ==========================================
# 信号
# ==========================================
signal update_agency_ui(faction: String, mode_str: String, group: int, max_group: int, time_left: float)
signal show_agency_notice(faction: String, message: String)

# ==========================================
# 节点引用
# ==========================================
@onready var blue_node: Node3D = $blue
@onready var red_node: Node3D = $red
@onready var r_node: MeshInstance3D = $base/R

var blue_targets: Array = []
var red_targets: Array = []

var b_timer_mini: Timer
var b_timer_main: Timer
var b_timer_window: Timer

var r_timer_mini: Timer
var r_timer_main: Timer
var r_timer_window: Timer

func _ready():
	base_rotation_speed = ConfigManager.get_gameplay("agency_mini_rotation", PI / 3.0)
	mini_timeout = ConfigManager.get_gameplay("agency_mini_timeout", 2.5)
	large_main_timeout = ConfigManager.get_gameplay("agency_large_main_timeout", 2.5)
	large_window_timeout = ConfigManager.get_gameplay("agency_large_window_timeout", 1.0)
		
	b_lg_a_min = ConfigManager.get_gameplay("agency_large_a_min", 0.780)
	b_lg_a_max = ConfigManager.get_gameplay("agency_large_a_max", 1.045)
	b_lg_w_min = ConfigManager.get_gameplay("agency_large_w_min", 1.884)
	b_lg_w_max = ConfigManager.get_gameplay("agency_large_w_max", 2.000)
	b_lg_b_base = ConfigManager.get_gameplay("agency_large_b_base", 2.090)

	for i in range(1, 6):
		blue_targets.append(get_node("blue/target" + str(i)))
		red_targets.append(get_node("red/target" + str(i))) 
	
	b_timer_mini = _create_timer(mini_timeout, _on_blue_timer_mini_timeout)
	b_timer_main = _create_timer(large_main_timeout, _on_blue_timer_main_timeout)
	b_timer_window = _create_timer(large_window_timeout, _on_blue_timer_window_timeout)
	
	r_timer_mini = _create_timer(mini_timeout, _on_red_timer_mini_timeout)
	r_timer_main = _create_timer(large_main_timeout, _on_red_timer_main_timeout)
	r_timer_window = _create_timer(large_window_timeout, _on_red_timer_window_timeout)
	
	_init_large_params("blue")
	_init_large_params("red")
	reset_agency()

func _create_timer(time: float, callback: Callable) -> Timer:
	var t = Timer.new()
	t.wait_time = time
	t.one_shot = true
	add_child(t)
	t.timeout.connect(callback)
	return t

func _physics_process(delta):
	if current_mode == Mode.MINI:
		blue_node.rotate_z(base_rotation_speed * delta)
		red_node.rotate_z(base_rotation_speed * delta)
	else:
		# 大能量机关：因为 b_lg_t 和 r_lg_t 永远同步 += delta，且参数一致，所以转动绝对同步
		b_lg_t += delta
		var b_speed = b_lg_a * sin(b_lg_w * b_lg_t) + b_lg_b
		blue_node.rotate_z(b_speed * delta)

		r_lg_t += delta
		var r_speed = r_lg_a * sin(r_lg_w * r_lg_t) + r_lg_b
		red_node.rotate_z(r_speed * delta)

func _process(_delta):
	_emit_ui_state("blue")
	_emit_ui_state("red")

func _emit_ui_state(faction: String):
	var state = blue_state if faction == "blue" else red_state
	var mode_str = "小能量机关" if current_mode == Mode.MINI else "大能量机关"
	
	var group = 0
	var max_group = 5
	var time_left = 0.0
	
	if current_mode == Mode.MINI:
		group = b_mini_hit if faction == "blue" else r_mini_hit
		if state == State.FINISHED:
			group = 5
		elif state == State.PLAYING:
			time_left = b_timer_mini.time_left if faction == "blue" else r_timer_mini.time_left
	else:
		group = b_lg_group if faction == "blue" else r_lg_group
		if state == State.PLAYING:
			time_left = b_timer_main.time_left if faction == "blue" else r_timer_main.time_left
		elif state == State.WINDOW:
			time_left = b_timer_window.time_left if faction == "blue" else r_timer_window.time_left
			
	update_agency_ui.emit(faction, mode_str, group, max_group, time_left)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if player_faction == "blue":
				if current_mode == Mode.MINI: start_mini_game("blue")
				else: start_large_game("blue")
			elif player_faction == "red":
				if current_mode == Mode.MINI: start_mini_game("red")
				else: start_large_game("red")
				
		elif event.keycode == KEY_M:
			current_mode = Mode.LARGE if current_mode == Mode.MINI else Mode.MINI
			_init_large_params("blue")
			_init_large_params("red")
			reset_agency()
			print("【系统】已切换至 ", "大能量机关" if current_mode == Mode.LARGE else "小能量机关")

func start_mini_game(faction: String):
	reset_single_agency(faction)
	
	if faction == "blue":
		blue_state = State.PLAYING
		blue_remaining = [1, 2, 3, 4, 5]
		blue_remaining.shuffle()
		b_mini_hit = 0
		_pick_mini_target("blue")
	else:
		red_state = State.PLAYING
		red_remaining = [1, 2, 3, 4, 5]
		red_remaining.shuffle()
		r_mini_hit = 0
		_pick_mini_target("red")
	
	_set_light(r_node, true)

func _pick_mini_target(faction: String):
	show_agency_notice.emit(faction, "") 
	
	var remaining = blue_remaining if faction == "blue" else red_remaining
	var targets_array = blue_targets if faction == "blue" else red_targets
	
	if remaining.is_empty():
		return
		
	var current_id = remaining.pop_front()
	if faction == "blue": blue_current_id = current_id
	else: red_current_id = current_id
	
	var target_node = targets_array[current_id - 1]
	if target_node:
		if target_node.has_node("target"): target_node.get_node("target").visible = true
		if target_node.has_node("light"): _set_light(target_node.get_node("light"), true)
		if target_node.has_node("target"): _set_light(target_node.get_node("target"), true)
		
		if faction == "blue": b_timer_mini.start()
		else: r_timer_mini.start()
		
		print("【", faction, " 小能量机关】点亮靶子: ", current_id, "，倒计时 ", mini_timeout, "s！")

func _on_blue_timer_mini_timeout():
	if blue_state == State.PLAYING:
		reset_single_agency("blue")
		show_agency_notice.emit("blue", "未在%.1fs内击中有效靶，激活失败！" % mini_timeout)

func _on_red_timer_mini_timeout():
	if red_state == State.PLAYING:
		reset_single_agency("red")
		show_agency_notice.emit("red", "未在%.1fs内击中有效靶，激活失败！" % mini_timeout)

func _init_large_params(faction: String):
	if faction == "blue":
		b_lg_t = 0.0
		b_lg_a = randf_range(b_lg_a_min, b_lg_a_max)
		b_lg_w = randf_range(b_lg_w_min, b_lg_w_max)
		b_lg_b = b_lg_b_base - b_lg_a
		b_lg_group = 0
		b_lg_active.clear()
	else:
		r_lg_t = 0.0
		r_lg_a = b_lg_a
		r_lg_w = b_lg_w
		r_lg_b = b_lg_b
		r_lg_group = 0
		r_lg_active.clear()

func start_large_game(faction: String):
	# 【核心修复】：先重置两方，并重新同步初始化参数
	reset_single_agency("blue")
	reset_single_agency("red")
	_init_large_params("blue")
	_init_large_params("red")
	
	if faction == "blue": 
		blue_state = State.PLAYING
		_pick_large_targets("blue")
	else: 
		red_state = State.PLAYING
		_pick_large_targets("red")
	
	_set_light(r_node, true)

func _pick_large_targets(faction: String):
	show_agency_notice.emit(faction, "") 
	
	var group = b_lg_group if faction == "blue" else r_lg_group
	var targets_array = blue_targets if faction == "blue" else red_targets
	var active = b_lg_active if faction == "blue" else r_lg_active
	
	if group >= 5:
		_finish_game(faction)
		return

	active.clear()
	var pool = [1, 2, 3, 4, 5]
	pool.shuffle()
	active.append(pool[0])
	active.append(pool[1])
	
	for i in range(5):
		var n = targets_array[i]
		if n:
			if n.has_node("light"): _set_light(n.get_node("light"), false)
			if n.has_node("target"): 
				n.get_node("target").visible = false
				_set_light(n.get_node("target"), false)
	
	for i in range(5):
		var id = i + 1
		var n = targets_array[i]
		if n:
			if group > 0 and id not in active:
				if n.has_node("midl"): 
					n.get_node("midl").visible = true
					_set_light(n.get_node("midl"), true)
				if n.has_node("down"): _set_light(n.get_node("down"), true)
			else:
				if n.has_node("midl"): 
					n.get_node("midl").visible = false
					_set_light(n.get_node("midl"), false)
				if n.has_node("down"): _set_light(n.get_node("down"), false)
				
	for id in active:
		var node = targets_array[id - 1]
		if node:
			if node.has_node("target"): 
				node.get_node("target").visible = true
				_set_light(node.get_node("target"), true)
			if node.has_node("light"): _set_light(node.get_node("light"), true)
	
	if faction == "blue": 
		blue_state = State.PLAYING
		b_timer_main.start()
	else: 
		red_state = State.PLAYING
		r_timer_main.start()
		
	print("【", faction, " 大能量机关】第 ", group + 1, " 组，点亮靶子: ", active, "，倒计时 ", large_main_timeout, "s！")

func _on_blue_timer_main_timeout():
	if blue_state == State.PLAYING:
		reset_single_agency("blue")
		show_agency_notice.emit("blue", "未在%.1fs内击中有效靶，激活失败！" % large_main_timeout)
	elif blue_state == State.WINDOW:
		b_timer_window.stop()
		b_lg_group += 1
		_pick_large_targets("blue")

func _on_red_timer_main_timeout():
	if red_state == State.PLAYING:
		reset_single_agency("red")
		show_agency_notice.emit("red", "未在%.1fs内击中有效靶，激活失败！" % large_main_timeout)
	elif red_state == State.WINDOW:
		r_timer_window.stop()
		r_lg_group += 1
		_pick_large_targets("red")

func _on_blue_timer_window_timeout():
	if blue_state == State.WINDOW:
		b_timer_main.stop()
		b_lg_group += 1
		_pick_large_targets("blue")

func _on_red_timer_window_timeout():
	if red_state == State.WINDOW:
		r_timer_main.stop()
		r_lg_group += 1
		_pick_large_targets("red")

func on_target_hit(faction: String, target_id: int):
	if current_mode == Mode.MINI:
		_handle_mini_hit(faction, target_id)
	else:
		_handle_large_hit(faction, target_id)

func _handle_mini_hit(faction: String, target_id: int):
	var state = blue_state if faction == "blue" else red_state
	var current_id = blue_current_id if faction == "blue" else red_current_id
	var targets_array = blue_targets if faction == "blue" else red_targets
	
	if state != State.PLAYING:
		return
		
	if target_id != current_id:
		reset_single_agency(faction)
		show_agency_notice.emit(faction, "击中非指定目标，激活失败！")
		return
		
	if faction == "blue": 
		b_timer_mini.stop()
		b_mini_hit += 1
	else: 
		r_timer_mini.stop()
		r_mini_hit += 1
	
	show_agency_notice.emit(faction, "") 
	
	var target_node = targets_array[target_id - 1]
	if target_node:
		if target_node.has_node("light"): _set_light(target_node.get_node("light"), false)
		if target_node.has_node("target"): target_node.get_node("target").visible = false
		if target_node.has_node("ring"): _set_light(target_node.get_node("ring"), true)
		if target_node.has_node("midl"): 
			target_node.get_node("midl").visible = true
			_set_light(target_node.get_node("midl"), true)
		if target_node.has_node("down"): _set_light(target_node.get_node("down"), true)
	
	if (faction == "blue" and b_mini_hit >= 5) or (faction == "red" and r_mini_hit >= 5):
		_finish_game(faction)
	else:
		await get_tree().create_timer(0.2).timeout
		_pick_mini_target(faction)

func _handle_large_hit(faction: String, target_id: int):
	var state = blue_state if faction == "blue" else red_state
	var active = b_lg_active if faction == "blue" else r_lg_active
	var targets_array = blue_targets if faction == "blue" else red_targets
	
	if target_id not in active:
		reset_single_agency(faction)
		show_agency_notice.emit(faction, "击中非指定目标，激活失败！")
		return
		
	var target_node = targets_array[target_id - 1]
	
	if target_node:
		if target_node.has_node("light"): _set_light(target_node.get_node("light"), false)
		if target_node.has_node("target"): target_node.get_node("target").visible = false
	
	show_agency_notice.emit(faction, "") 
	
	if state == State.PLAYING:
		for i in range(5):
			var n = targets_array[i]
			if n:
				var is_target_visible = false
				if n.has_node("target"):
					is_target_visible = n.get_node("target").visible
				
				if not is_target_visible:
					if n.has_node("midl"): 
						n.get_node("midl").visible = true
						_set_light(n.get_node("midl"), true)
					if n.has_node("down"): _set_light(n.get_node("down"), true)
		
		if faction == "blue": 
			blue_state = State.WINDOW
			b_timer_window.start()
		else: 
			red_state = State.WINDOW
			r_timer_window.start()
			
	elif state == State.WINDOW:
		if faction == "blue": 
			b_timer_window.stop()
			b_timer_main.stop()
			b_lg_group += 1
		else: 
			r_timer_window.stop()
			r_timer_main.stop()
			r_lg_group += 1
			
		_pick_large_targets(faction)

func _finish_game(faction: String):
	if faction == "blue": blue_state = State.FINISHED
	else: red_state = State.FINISHED
	
	show_agency_notice.emit(faction, "激活成功！")
	
	_all_lights_off_single(faction)
	await get_tree().create_timer(0.5).timeout
	_apply_finish_lights(faction)
	await get_tree().create_timer(0.75).timeout 
	_all_lights_off_single(faction)
	await get_tree().create_timer(0.5).timeout 
	_apply_finish_lights(faction)

func _apply_finish_lights(faction: String):
	var targets_array = blue_targets if faction == "blue" else red_targets
	for i in range(5):
		var node = targets_array[i]
		if node:
			if node.has_node("ring"): _set_light(node.get_node("ring"), true)
			if node.has_node("up"): _set_light(node.get_node("up"), true)
			if node.has_node("mid"): _set_light(node.get_node("mid"), true)
			if node.has_node("midl"): 
				node.get_node("midl").visible = true
				_set_light(node.get_node("midl"), true)
			if node.has_node("down"): _set_light(node.get_node("down"), true)
	_set_light(r_node, true)

func reset_agency():
	reset_single_agency("blue")
	reset_single_agency("red")

func reset_single_agency(faction: String):
	show_agency_notice.emit(faction, "") 
	
	if faction == "blue":
		blue_state = State.IDLE
		b_timer_mini.stop()
		b_timer_main.stop()
		b_timer_window.stop()
		b_lg_active.clear()
		b_mini_hit = 0
	else:
		red_state = State.IDLE
		r_timer_mini.stop()
		r_timer_main.stop()
		r_timer_window.stop()
		r_lg_active.clear()
		r_mini_hit = 0
	_all_lights_off_single(faction)

func _set_light(root_node: Node, enable: bool):
	if root_node == null: return
	if root_node is MeshInstance3D:
		var mat = root_node.get_active_material(0) as StandardMaterial3D
		if mat:
			if not root_node.material_override:
				root_node.material_override = mat.duplicate()
			if root_node.material_override is StandardMaterial3D:
				root_node.material_override.emission_enabled = enable
	for child in root_node.get_children():
		_set_light(child, enable)

func _all_lights_off_single(faction: String):
	var targets_array = blue_targets if faction == "blue" else red_targets
	for i in range(5):
		var node = targets_array[i]
		if node:
			_set_light(node, false)
			if node.has_node("midl"): 
				node.get_node("midl").visible = false
			if node.has_node("target"):
				node.get_node("target").visible = true

func check_target_valid(faction: String, target_id: int) -> bool:
	if current_mode == Mode.MINI:
		var state = blue_state if faction == "blue" else red_state
		if state != State.PLAYING: return false
		var current_id = blue_current_id if faction == "blue" else red_current_id
		return target_id == current_id
	else:
		var state = blue_state if faction == "blue" else red_state
		if state == State.PLAYING or state == State.WINDOW:
			var active = b_lg_active if faction == "blue" else r_lg_active
			return target_id in active
		return false
