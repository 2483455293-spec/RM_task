extends Node3D

# ==========================================
# 基础属性
# ==========================================
# 【重构】：不再写死，由 ConfigManager 注入
var max_hp: float = 1500
var current_hp: float
var is_destroyed: bool = false

signal hp_changed(current, max)
signal outpost_destroyed

# 引用旋转节点和底座节点
@onready var rotator = $rotator
@onready var base_node = $base

func _ready() -> void:

	max_hp = ConfigManager.get_buildings("outpost_max_hp", 1500)

		
	current_hp = max_hp

func take_damage(amount: float) -> void:
	if is_destroyed: return
	
	current_hp = maxf(current_hp - amount, 0.0)
	hp_changed.emit(current_hp, max_hp)
	print("红方前哨站受击，当前血量：", current_hp)
	
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	is_destroyed = true
	print("红方前哨站已被摧毁！")
	
	# 1. 停止旋转
	if rotator.has_method("stop_rotation"):
		rotator.stop_rotation()
	
	# 2. 遍历所有装甲板，关闭检测并强制熄灯 (处理 rotator 下的)
	for child in rotator.get_children():
		if child is Area3D:
			child.set_deferred("monitoring", false)
			if child.has_method("turn_off_light"):
				child.turn_off_light()
				
	# 3. 遍历底座下的灯条 (处理 base 下的 1, 2, 3)
	if base_node:
		for child in base_node.get_children():
			if child is MeshInstance3D:
				_turn_off_mesh_emission(child)
	
	# 4. 触发全局事件
	outpost_destroyed.emit()

# 辅助函数：关闭网格的自发光
func _turn_off_mesh_emission(mesh: MeshInstance3D):
	if mesh:
		if not mesh.material_override:
			var mat = mesh.get_active_material(0) as StandardMaterial3D
			if mat:
				mesh.material_override = mat.duplicate()
		
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override.emission_enabled = false
