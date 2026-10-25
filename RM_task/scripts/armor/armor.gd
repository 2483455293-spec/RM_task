extends Area3D

# ==========================================
# 配置参数 (由 ConfigManager 注入)
# ==========================================
var flash_duration: float = 0.15
var valid_hit_speed_threshold: float = 10
var damage_to_outpost: float = 10.0

var is_flashing: bool = false

# ==========================================
# 节点引用
# ==========================================
@onready var led_left: MeshInstance3D = $"LED_Left"
@onready var led_right: MeshInstance3D = $"LED_Right"

@onready var hit_sound: AudioStreamPlayer3D = $HitSound

@onready var outpost = _find_outpost()

func _find_outpost():
	var node = get_parent()
	while node:
		if node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null

func _ready():
	# 从全局单例读取装甲板参数
	flash_duration = ConfigManager.get_gameplay("armor_flash_duration", 0.15)
	valid_hit_speed_threshold = ConfigManager.get_gameplay("armor_valid_min_speed", 5.0)
	damage_to_outpost = ConfigManager.get_gameplay("armor_damage", 10.0)

	if not outpost:
		printerr("装甲板配置错误：找不到挂载了 outpost.gd 的节点！")

	if hit_sound and hit_sound.stream:
		hit_sound.play()
		hit_sound.stop()


# ==========================================
# 接收来自子弹扫掠后的法向速度
# ==========================================
func _on_bullet_hit(normal_speed: float):
	if not outpost or outpost.is_destroyed: return
	
	# 判断法向速度是否达标
	if normal_speed >= valid_hit_speed_threshold:

		if hit_sound:
			if hit_sound.playing:
				hit_sound.stop()
			hit_sound.play()
			
		# 处理扣血和灯光
		outpost.take_damage(damage_to_outpost)
		
		if not is_flashing:
			_flash_leds()
			
	else:
		print("擦边球，无效击打！速度：", normal_speed)

# ==========================================
# LED 闪烁反馈
# ==========================================
func _flash_leds():
	is_flashing = true
	_toggle_emission(led_left, false)
	_toggle_emission(led_right, false)
	
	await get_tree().create_timer(flash_duration).timeout
	
	if not outpost.is_destroyed:
		_toggle_emission(led_left, true)
		_toggle_emission(led_right, true)
	is_flashing = false

# ==========================================
# 供 outpost.gd 在死亡时调用
# ==========================================
func turn_off_light():
	is_flashing = false 
	_toggle_emission(led_left, false)
	_toggle_emission(led_right, false)

# ==========================================
# 辅助函数：开关材质发光
# ==========================================
func _toggle_emission(mesh: MeshInstance3D, enable: bool):
	if mesh:
		if not mesh.material_override:
			var mat = mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mesh.material_override = mat.duplicate()
		
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override.emission_enabled = enable
