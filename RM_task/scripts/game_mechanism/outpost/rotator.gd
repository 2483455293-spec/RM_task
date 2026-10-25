extends Node3D

# ==========================================
# 旋转属性
# ==========================================
var rotation_speed: float = 0.8 * PI 

func _ready() -> void:

	rotation_speed = ConfigManager.get_buildings("outpost_rotation_speed", 0.8 * PI)


func _physics_process(delta: float) -> void:
	rotate_y(rotation_speed * delta)

func stop_rotation():
	set_physics_process(false)
