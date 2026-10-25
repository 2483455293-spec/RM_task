extends CharacterBody3D

# ==========================================
# 导出参数
# ==========================================
@export var faction: String = "blue" 
@export var bullet_scene: PackedScene

# ==========================================
# 配置参数
# ==========================================
var speed: float = 3.5
var jump_speed: float = 2
var mouse_sens: float = 0.002
var max_hp: int = 200
var max_heat: float = 120.0  
var heat_safe: float = 80.0
var max_ammo: int = 150
var accel: float = 6.0
var decel: float = 12.0

# 脱战判定时间（毫秒）
var COMBAT_TIMEOUT_MS: int = 3000

# ==========================================
# 节点引用
# ==========================================
@onready var yaw_node: Node3D = $GimbalYaw
@onready var pitch_node: Node3D = $GimbalYaw/GimbalPitch
@onready var muzzle: Marker3D = $GimbalYaw/GimbalPitch/Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var fire_sound: AudioStreamPlayer = $FireSound 

# ==========================================
# 运行状态
# ==========================================
var hp: int = 0 
var heat: float = 0.0
var ammo: int = 0

# 脱战计时器。初始设为负数，保证开局是脱战状态
var last_combat_time_ms: int = -10000 

# 开火冷却
var last_fire_time_ms: int = 0
const FIRE_COOLDOWN_MS: int = 100 

# 10Hz 冷却累加器
var heat_cool_accum: float = 0.0
const HEAT_COOL_INTERVAL: float = 0.1
const HEAT_COOL_AMOUNT: float = 3.0 

# ==========================================
# 信号
# ==========================================
signal hp_changed(new_hp: int)
signal status_changed(hp: int, heat: float, ammo: int)
signal player_status_changed(hp: int, heat: float, ammo: int)

# ==========================================
# 生命周期
# ==========================================
func _ready():
	if Engine.has_singleton("ConfigManager"):
		speed = ConfigManager.get_infantry("speed", speed)
		jump_speed = ConfigManager.get_infantry("jump_speed", jump_speed)
		mouse_sens = ConfigManager.get_infantry("mouse_sens", mouse_sens)
		max_hp = ConfigManager.get_infantry("max_hp", max_hp)
		max_heat = ConfigManager.get_infantry("max_heat", max_heat)
		heat_safe = ConfigManager.get_infantry("heat_safe", heat_safe)
		max_ammo = ConfigManager.get_infantry("max_ammo", max_ammo)
		accel = ConfigManager.get_infantry("accel", accel)
		decel = ConfigManager.get_infantry("decel", decel)
		COMBAT_TIMEOUT_MS = ConfigManager.get_infantry("combat_timeout_ms", COMBAT_TIMEOUT_MS)
	
	# 【修复】：读取完配置后，让初始血量和弹药直接等于最大值
	hp = max_hp
	ammo = max_ammo
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fire_timer.one_shot = true
	_emit_all_status()

func _emit_all_status() -> void:
	emit_signal("hp_changed", hp)
	emit_signal("status_changed", hp, heat, ammo)
	emit_signal("player_status_changed", hp, heat, ammo)

# ==========================================
# 受击与复位
# ==========================================
func _on_bullet_hit(_bullet_node: Node):
	take_damage(10)

func take_damage(amount: int):
	last_combat_time_ms = Time.get_ticks_msec()
	
	hp = max(hp - amount, 0)
	_emit_all_status()

func reset_robot():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()

# ==========================================
# 开火（精密时间戳判定）
# ==========================================
func fire():
	if ammo <= 0 or heat >= max_heat:
		return
	if not muzzle.is_inside_tree():
		return
	
	var current_time = Time.get_ticks_msec()
	if current_time - last_fire_time_ms < FIRE_COOLDOWN_MS:
		return
		
	last_combat_time_ms = current_time
	last_fire_time_ms = current_time
	fire_timer.start()
	
	ammo -= 1
	heat += 10.0
	_emit_all_status()
	
	if fire_sound:
		if fire_sound.playing:
			fire_sound.stop()
		fire_sound.play()
	
	var bullet = bullet_scene.instantiate()
	bullet.global_transform = muzzle.global_transform
	get_tree().current_scene.add_child(bullet)

# ==========================================
# 提供给外部的脱战检测接口
# ==========================================
func is_in_combat() -> bool:
	var current_time = Time.get_ticks_msec()
	return (current_time - last_combat_time_ms) < COMBAT_TIMEOUT_MS

# ==========================================
# 输入处理
# ==========================================
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		fire()
		
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if Input.is_action_just_pressed("reset"):
		reset_robot()

# ==========================================
# 物理处理（移动与热量冷却）
# ==========================================
func _physics_process(delta: float) -> void:
	var old_heat = heat
	
	if heat > 0:
		heat_cool_accum += delta
		while heat_cool_accum >= HEAT_COOL_INTERVAL:
			heat_cool_accum -= HEAT_COOL_INTERVAL
			heat = max(heat - HEAT_COOL_AMOUNT, 0.0)
			
	if heat != old_heat:
		emit_signal("status_changed", hp, heat, ammo)
		emit_signal("player_status_changed", hp, heat, ammo)
	
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir = yaw_node.global_basis * Vector3(input_vec.x, 0, input_vec.y)
	var target_vel = dir * speed
	
	if input_vec.length() > 0.1:
		velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, decel * delta)
		velocity.z = move_toward(velocity.z, 0, decel * delta)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
	
	move_and_slide()

# ==========================================
# 鼠标控制云台
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw_node.rotate_y(-event.relative.x * mouse_sens)
		pitch_node.rotation.x = clamp(
			pitch_node.rotation.x - event.relative.y * mouse_sens,
			deg_to_rad(-30),
			deg_to_rad(30)
		)

# ==========================================
# 补给区交互接口
# ==========================================
func resupply_tick(heal_percent: float, ammo_amount: int) -> bool:
	if hp >= max_hp and ammo >= max_ammo and heat <= 0:
		return false
		
	var heal_value = int(max_hp * heal_percent)
	
	hp = min(hp + heal_value, max_hp)
	ammo = min(ammo + ammo_amount, max_ammo)
	heat = max(heat - 30.0, 0.0)
	
	_emit_all_status()
	return true
