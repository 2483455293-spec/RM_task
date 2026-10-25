extends CanvasLayer

# ==========================================
# UI 节点引用
# ==========================================
@onready var blue_outpost_bar: ProgressBar = %blue_outpost_bar
@onready var blue_outpost_label: Label = %blue_outpost_label
@onready var blue_outpost_value: Label = %BlueOutpostValue

@onready var red_outpost_bar: ProgressBar = %red_outpost_bar
@onready var red_outpost_label: Label = %red_outpost_label
@onready var red_outpost_value: Label = %RedOutpostValue

@onready var blue_base_bar: ProgressBar = %blue_base_bar
@onready var blue_base_value: Label = %BlueBaseValue

@onready var red_base_bar: ProgressBar = %red_base_bar
@onready var red_base_value: Label = %RedBaseValue

@onready var blue_shield: Label = %blue_shield
@onready var red_shield: Label = %red_shield

@onready var clock_label: Label = %ClockLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_value_label: Label = %HPBar/HPlabel 
@onready var heat_bar: ProgressBar = %HeatBar
@onready var heat_value_label: Label = %HeatBar/HEATLabel 
@onready var ammo_label: Label = %AmmoLabel

@onready var supply_label: Label = %supply 
@onready var agency_mode: Label = %Mode
@onready var agency_bar: ProgressBar = %ProgressBar
@onready var agency_progress: Label = %Progress
@onready var agency_notice: Label = %Notice

@onready var net_status_label: Label = %NetStatusLabel

# ==========================================
# 3D 场景节点引用
# ==========================================
@export var blue_outpost_3d: Node3D 
@export var red_outpost_3d: Node3D  
@export var energy_agency_3d: Node3D 
@export var blue_base_3d: Node3D 
@export var red_base_3d: Node3D 

var match_state: Node
var infantry: Node
var notice_timer: Timer
var frame_sender_node: Node

# ==========================================
# 初始化
# ==========================================
func _ready():
	if blue_outpost_3d:
		if blue_outpost_3d.has_signal("hp_changed"):
			blue_outpost_3d.hp_changed.connect(_on_blue_outpost_hp_changed)
			_on_blue_outpost_hp_changed(blue_outpost_3d.current_hp, blue_outpost_3d.max_hp)
		if blue_outpost_3d.has_signal("outpost_destroyed"):
			blue_outpost_3d.outpost_destroyed.connect(_on_blue_outpost_destroyed)
	
	if red_outpost_3d:
		if red_outpost_3d.has_signal("hp_changed"):
			red_outpost_3d.hp_changed.connect(_on_red_outpost_hp_changed)
			_on_red_outpost_hp_changed(red_outpost_3d.current_hp, red_outpost_3d.max_hp)
		if red_outpost_3d.has_signal("outpost_destroyed"):
			red_outpost_3d.outpost_destroyed.connect(_on_red_outpost_destroyed)

	if blue_base_3d:
		if blue_base_3d.has_signal("hp_changed"):
			blue_base_3d.hp_changed.connect(_on_blue_base_hp_changed)
			_on_blue_base_hp_changed(blue_base_3d.current_hp, blue_base_3d.max_hp)
		if blue_base_3d.has_signal("outpost_destroyed"):
			blue_base_3d.outpost_destroyed.connect(_on_blue_base_destroyed)
		if blue_base_3d.has_signal("shield_hit"):
			blue_base_3d.shield_hit.connect(_on_blue_shield_hit)

	if red_base_3d:
		if red_base_3d.has_signal("hp_changed"):
			red_base_3d.hp_changed.connect(_on_red_base_hp_changed)
			_on_red_base_hp_changed(red_base_3d.current_hp, red_base_3d.max_hp)
		if red_base_3d.has_signal("outpost_destroyed"):
			red_base_3d.outpost_destroyed.connect(_on_red_base_destroyed)
		if red_base_3d.has_signal("shield_hit"):
			red_base_3d.shield_hit.connect(_on_red_shield_hit)

	if energy_agency_3d:
		if energy_agency_3d.has_signal("update_agency_ui"):
			energy_agency_3d.update_agency_ui.connect(_on_agency_ui_updated)
		if energy_agency_3d.has_signal("show_agency_notice"):
			energy_agency_3d.show_agency_notice.connect(_on_agency_notice)
	
	if supply_label:
		supply_label.visible = false 
	for node in get_tree().current_scene.find_children("*", "Area3D", true, false):
		if node.has_signal("supply_message"):
			node.supply_message.connect(_on_supply_message)

	if blue_shield:
		blue_shield.text = "SHIELD ACTIVE"
		blue_shield.modulate = Color.CYAN
	if red_shield:
		red_shield.text = "SHIELD ACTIVE"
		red_shield.modulate = Color.CYAN

	if agency_mode: agency_mode.text = "小能量机关"
	if agency_bar: 
		agency_bar.max_value = 5
		agency_bar.value = 0
	if agency_progress: agency_progress.text = "0/5"
	if agency_notice: 
		agency_notice.text = ""
		agency_notice.visible = false
		
	notice_timer = Timer.new()
	notice_timer.one_shot = true
	notice_timer.wait_time = 2.5
	notice_timer.timeout.connect(func(): if agency_notice: agency_notice.visible = false)
	add_child(notice_timer)

	match_state = get_tree().current_scene.get_node_or_null("MatchState")
	infantry = get_tree().current_scene.get_node_or_null("Infantry")
	
	if match_state:
		if match_state.has_signal("time_updated"):
			match_state.time_updated.connect(_on_time_updated)
			_on_time_updated(match_state.remaining_s)
		if match_state.has_signal("match_ended"):
			match_state.match_ended.connect(_on_match_ended)
		if match_state.has_signal("pause_state_changed"):
			match_state.pause_state_changed.connect(_on_pause_state_changed)
	
	if infantry and infantry.has_signal("player_status_changed"):
		infantry.player_status_changed.connect(_on_player_status_changed)
		_on_player_status_changed(infantry.hp, infantry.heat, infantry.ammo)

	frame_sender_node = get_tree().current_scene.get_node_or_null("FrameSender")
	if frame_sender_node and frame_sender_node.has_signal("network_status_changed"):
		frame_sender_node.network_status_changed.connect(_on_network_status_changed)
		if net_status_label:
			net_status_label.text = "视觉通道: 未连接"
			net_status_label.modulate = Color.RED

# ==========================================
# 回调：网络状态
# ==========================================
func _on_network_status_changed(is_connected: bool, current_fps: int, msg: String) -> void:
	if net_status_label:
		if is_connected:
			if current_fps > 0:
				net_status_label.text = "视觉: " + msg + " (%d FPS)" % current_fps
			else:
				net_status_label.text = "视觉: " + msg
				
			if "双通道" in msg:
				net_status_label.modulate = Color.GREEN 
			else:
				net_status_label.modulate = Color.YELLOW 
		else:
			net_status_label.text = "视觉: " + msg
			net_status_label.modulate = Color.RED

# ==========================================
# 【核心修复】：动态更新血量和文本
# ==========================================
func _on_player_status_changed(hp: int, heat: float, ammo: int) -> void:
	# 动态获取当前角色的最大血量
	var current_max_hp = 100 
	if infantry:
		current_max_hp = infantry.max_hp
		
	if hp_bar:
		hp_bar.max_value = current_max_hp # 动态使用
		hp_bar.value = hp
	if hp_value_label:
		hp_value_label.text = "%d / %d" % [hp, current_max_hp] # 动态显示
		
	if heat_bar and infantry:
		heat_bar.max_value = infantry.max_heat
		heat_bar.value = heat
	if heat_value_label and infantry:
		heat_value_label.text = "%d / %d" % [int(heat), int(infantry.max_heat)]
	if ammo_label:
		ammo_label.text = "AMMO: %d" % ammo

# ==========================================
# 其他 UI 回调
# ==========================================
func _on_supply_message(show_ui: bool, text: String, color: Color) -> void:
	if supply_label:
		supply_label.visible = show_ui
		if show_ui:
			supply_label.text = text
			supply_label.modulate = color

func _on_blue_outpost_destroyed() -> void:
	if blue_shield:
		blue_shield.text = "SHIELD OFFLINE" 
		blue_shield.modulate = Color.GRAY   

func _on_red_outpost_destroyed() -> void:
	if red_shield:
		red_shield.text = "SHIELD OFFLINE"
		red_shield.modulate = Color.GRAY

func _on_blue_shield_hit() -> void:
	if blue_shield:
		_flash_label(blue_shield)

func _on_red_shield_hit() -> void:
	if red_shield:
		_flash_label(red_shield)

func _flash_label(label_node: Label):
	if label_node.has_meta("flash_tween"):
		var old_tween = label_node.get_meta("flash_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			
	label_node.modulate.a = 1.0
	var tween = create_tween()
	label_node.set_meta("flash_tween", tween)
	
	for i in range(2):
		tween.tween_property(label_node, "modulate:a", 0.2, 0.1)
		tween.tween_property(label_node, "modulate:a", 1.0, 0.1)

func _on_blue_base_hp_changed(current: float, max_hp: float) -> void:
	if blue_base_bar:
		blue_base_bar.max_value = max_hp
		blue_base_bar.value = current
	if blue_base_value:
		blue_base_value.text = "%d / %d" % [current, max_hp]

func _on_red_base_hp_changed(current: float, max_hp: float) -> void:
	if red_base_bar:
		red_base_bar.max_value = max_hp
		red_base_bar.value = current
	if red_base_value:
		red_base_value.text = "%d / %d" % [current, max_hp]

func _on_blue_base_destroyed() -> void:
	print("【比赛结束】蓝方基地被摧毁，红方胜利！")
	if blue_shield: blue_shield.visible = false
	if match_state and match_state.has_method("end_match"):
		match_state.end_match(false) 

func _on_red_base_destroyed() -> void:
	print("【比赛结束】红方基地被摧毁，蓝方胜利！")
	if red_shield: red_shield.visible = false
	if match_state and match_state.has_method("end_match"):
		match_state.end_match(true) 

func _on_blue_outpost_hp_changed(current: float, max_hp: float) -> void:
	if blue_outpost_bar:
		blue_outpost_bar.max_value = max_hp
		blue_outpost_bar.value = current
	if blue_outpost_value:
		blue_outpost_value.text = "%d / %d" % [current, max_hp]

func _on_red_outpost_hp_changed(current: float, max_hp: float) -> void:
	if red_outpost_bar:
		red_outpost_bar.max_value = max_hp
		red_outpost_bar.value = current
	if red_outpost_value:
		red_outpost_value.text = "%d / %d" % [current, max_hp]

func _on_agency_ui_updated(faction: String, mode_str: String, group: int, max_group: int, time_left: float):
	if faction != "blue": return 
	if agency_mode:
		agency_mode.text = mode_str
		agency_mode.modulate = Color.CYAN
	if agency_bar:
		agency_bar.max_value = max_group
		agency_bar.value = group
	if agency_progress:
		if time_left > 0.05:
			agency_progress.text = "%d/%d, 还剩 %.1fs" % [group, max_group, time_left]
		else:
			agency_progress.text = "%d/%d" % [group, max_group]

func _on_agency_notice(faction: String, message: String):
	if faction != "blue": return 
	if agency_notice:
		if message == "":
			agency_notice.visible = false
			agency_notice.text = ""
			notice_timer.stop()
			return
		agency_notice.text = message
		agency_notice.visible = true
		if "成功" in message:
			agency_notice.modulate = Color.GREEN
		else:
			agency_notice.modulate = Color.RED
		notice_timer.start()

func _on_time_updated(remain_sec: float) -> void:
	if clock_label:
		var total_seconds = ceili(remain_sec)
		var minutes = floori(total_seconds / 60.0)
		var seconds = total_seconds % 60
		clock_label.text = "%02d:%02d" % [minutes, seconds]

func _on_match_ended(is_win: bool) -> void:
	if clock_label:
		if is_win:
			clock_label.text = "VICTORY"
			clock_label.modulate = Color.GREEN
		else:
			clock_label.text = "DEFEAT"
			clock_label.modulate = Color.RED

func _on_pause_state_changed(is_paused: bool) -> void:
	if clock_label:
		if is_paused:
			clock_label.modulate = Color.YELLOW
			clock_label.text = "PAUSED"
		else:
			clock_label.modulate = Color.WHITE
