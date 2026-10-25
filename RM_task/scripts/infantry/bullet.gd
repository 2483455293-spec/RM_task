extends Node3D

# ==========================================
# RM 参数配置 (默认值，可被外部覆盖)
# ==========================================
var bullet_speed: float = -1.0         
var gravity: float = 9.8                
var valid_hit_min_normal_speed: float = 10.0 
var bullet_lifetime: float = 3.0        

# 碰撞掩码通常和场景物理层绑定，保留 export 方便微调
@export var collision_mask: int = 1 | 4 | 32 

var velocity: Vector3
var life_timer: float = 0.0
var shooter: Node3D = null 

func _ready() -> void:
	if bullet_speed < 0 and Engine.has_singleton("ConfigManager"):
		bullet_speed = ConfigManager.get_infantry("bullet_speed", 25.0)
		gravity = ConfigManager.get_infantry("bullet_gravity", 9.8)
		bullet_lifetime = ConfigManager.get_infantry("bullet_lifetime", 3.0)
		valid_hit_min_normal_speed = ConfigManager.get_infantry("valid_hit_min_normal_speed", 10.0)
	elif bullet_speed < 0:
		# 兜底默认值
		bullet_speed = 25.0
		
	# 赋予初速度
	velocity = -global_basis.z * bullet_speed
	
	var mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 1.0, 0.2) 
		mat.emission_enabled = true
		mat.emission = Color(0.6, 1.0, 0.2)
		mesh_instance.material_override = mat

func _physics_process(delta: float) -> void:
	life_timer += delta
	if life_timer > bullet_lifetime:
		queue_free()
		return

	var old_pos: Vector3 = global_position
	# 重力积分
	velocity += Vector3.DOWN * gravity * delta
	var disp: Vector3 = velocity * delta
	var new_pos: Vector3 = old_pos + disp

	# 扫掠射线检测
	var query = PhysicsRayQueryParameters3D.new()
	query.from = old_pos
	query.to = new_pos
	query.collision_mask = collision_mask
	query.collide_with_areas = true  
	query.collide_with_bodies = true 
	query.hit_from_inside = true     
	
	# 排除开枪者自身
	if shooter:
		query.exclude = [shooter.get_rid()]

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result:
		global_position = result.position
		var hit_collider = result.collider
		var normal = result.normal
		var normal_speed = velocity.dot(-normal)

		# 命中判定
		if hit_collider.has_method("_on_bullet_hit"):
			# 把法向速度传给靶心或装甲板
			hit_collider._on_bullet_hit(normal_speed)
		
		queue_free()
		return

	global_position = new_pos
